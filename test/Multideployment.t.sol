// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../contracts/interfaces/IPulseRaiser.sol";
import {Merkle} from "./murky/Merkle.sol";

import "./utils/Deplooyer.sol";
import {PulseRaiser} from "../contracts/PulseRaiser.sol";
import {Shibart} from "../contracts/Shibart.sol";

interface IIssuable {
    function issue(uint256 wad) external;
}

interface IERC20U {
    function approve(address spender, uint256 amount) external;
}

interface IShibart {
    function supplyCap() external view returns (uint256);
}

interface IPulseRaiserExt is IPulseRaiser {
    function launchAt() external view returns (uint32);

    function pointsGained(address account) external view returns (uint256);

    function tokenPerPoint() external view returns (uint256);

    function owner() external view returns (address);

    function raiseLocal() external view returns (uint256);

    function pointsLocal() external view returns (uint256);
}

contract MultideploymentTest is Test, Deplooyer {
    address internal WALLET = vm.addr(2);
    address internal DEPLOYER = vm.addr(1);

    Merkle m = new Merkle();

    uint256 ethFork;
    uint256 bscFork;
    uint256 arbFork;

    uint16 numEthereumContributors = 100;
    uint16 numBinanceContributors = 220;
    uint16 numArbitrumContributors = 60;

    // Ethereum contributors
    address[] eContributors;

    // BSC contributors
    address[] bContributors;

    // Arbitrum contributors
    address[] aContributors;

    mapping(address => uint256) internal pointsPerAccount;
    address[] internal collatableAccounts;
    uint256 internal collatablePoints;

    address[] eTokens;
    address[] aTokens;
    address[] bTokens;

    address private E_RAISER;
    address private B_RAISER;
    address private A_RAISER;

    address private VESTING;
    address private GT;


    function setUp() public {
        eTokens = Constants.ethereumMainnetRaiserTokens();
        aTokens = Constants.arbitrumMainnetRaiserTokens();
        bTokens = Constants.BSCMainnetRaiserTokens();

        for (uint256 r = 0; r < numEthereumContributors; r++) {
            eContributors.push(vm.addr(100000 + r));
        }

        for (uint256 r = 0; r < numArbitrumContributors; r++) {
            aContributors.push(vm.addr(200000 + r));
        }

        for (uint256 r = 0; r < numBinanceContributors; r++) {
            bContributors.push(vm.addr(300000 + r));
        }

        vm.makePersistent(address(m));

        arbFork = vm.createFork(vm.envString("ARBITRUM_MAINNET_RPC")); 

        bscFork = vm.createFork(vm.envString("BSC_MAINNET_RPC"));

        ethFork = vm.createFork(vm.envString("ETHEREUM_MAINNET_RPC"));

        vm.selectFork(ethFork);
        (, PulseRaiser p, , Shibart gt) = Deplooyer.deployEthereumMainnet(
            DEPLOYER,
            WALLET
        );

        GT = address(gt);
        E_RAISER = address(p);

        vm.selectFork(bscFork);
        Deplooyer.deployBSCMainnet(DEPLOYER, WALLET);

        (, PulseRaiser pb) = Deplooyer.deployBSCMainnet(DEPLOYER, WALLET);

        B_RAISER = address(pb);

        vm.selectFork(arbFork);
        Deplooyer.deployArbitrumMainnet(DEPLOYER, WALLET);

        (, PulseRaiser pa) = Deplooyer.deployArbitrumMainnet(DEPLOYER, WALLET);

        A_RAISER = address(pa);
    }

    function test_contribution_multi() public {
        print_wallet_state();

        // loop through 20 days, collect contributions
        for (uint8 d = 0; d < 20; d++) {
            _contribs(
                d,
                ethFork,
                E_RAISER,
                d * (numEthereumContributors / 20),
                numEthereumContributors / 20,
                eTokens,
                eContributors,
                1 ether
            );

            _contribs(
                d,
                arbFork,
                A_RAISER,
                d * (numArbitrumContributors / 20),
                numArbitrumContributors / 20,
                aTokens,
                aContributors,
                1 ether
            );

            _contribs(
                d,
                bscFork,
                B_RAISER,
                d * (numBinanceContributors / 20),
                numBinanceContributors / 20,
                bTokens,
                bContributors,
                1 ether
            );
        }

        print_wallet_state();


        // collate
        bytes32[] memory data = generateMerkle(
            B_RAISER,
            bContributors,
            A_RAISER,
            aContributors
        );

        vm.selectFork(ethFork);
        vm.warp(IPulseRaiserExt(E_RAISER).launchAt() + 20 days + 1);

        bytes32 merkleRoot = m.getRoot(data);
        address ethPulseRaiserOwner = IPulseRaiserExt(E_RAISER).owner();
        vm.prank(ethPulseRaiserOwner);
        IPulseRaiser(E_RAISER).collate(merkleRoot, collatablePoints);
        vm.prank(ethPulseRaiserOwner);
        IPulseRaiser(E_RAISER).distribute();

        uint256 tokenPerPoint = IPulseRaiserExt(E_RAISER).tokenPerPoint();

        // execute local claims
        for (uint256 r = 0; r < eContributors.length; r++) {
            address account = eContributors[r];
            uint256 expectedTokenBalance = IPulseRaiserExt(E_RAISER)
                .pointsGained(account) * tokenPerPoint;
            bytes32[] memory proof;

            assertGt(expectedTokenBalance, 0);

            vm.prank(account);
            IPulseRaiser(E_RAISER).claim(r, 0, proof);

            assertEq(expectedTokenBalance, IERC20(GT).balanceOf(account));
        }

        // execute collated claims
        // first, binance
        for (uint256 cb = 0; cb < bContributors.length; cb++) {
            address account = bContributors[cb];
            uint256 points = pointsPerAccount[account];
            uint256 expectedTokenBalance = points * tokenPerPoint;
            uint256 r = cb;
            bytes32[] memory proof = m.getProof(data, r);
            if (points > 0) {
                vm.prank(account);
                IPulseRaiser(E_RAISER).claim(r, points, proof);
            }
            assertEq(expectedTokenBalance, IERC20(GT).balanceOf(account));
        }
        // now arb
        for (uint256 ca = 0; ca < aContributors.length; ca++) {
            address account = aContributors[ca];
            uint256 points = pointsPerAccount[account];
            uint256 expectedTokenBalance = points * tokenPerPoint;
            uint256 r = bContributors.length + ca;
            bytes32[] memory proof = m.getProof(data, r);

            if (points > 0) {
                vm.prank(account);
                IPulseRaiser(E_RAISER).claim(r, points, proof);
            }

            assertEq(expectedTokenBalance, IERC20(GT).balanceOf(account));
        }

        // token hard cap vs total supply
        console.log("$SHIBART supply cap: ", IShibart(GT).supplyCap());
        console.log("$SHIBART total supply: ", IERC20(GT).totalSupply());

        // $SHIBART supply cap:   1000000000000000000000000000000
        // $SHIBART total supply:  999999999999999999984389210151
        // dust: 15610789849 (15 gwei)
        print_wallet_state();
    }

    function print_wallet_state() internal {
        console.log("");
        // raise stats
        vm.selectFork(ethFork);
        for (uint8 t = 0; t < eTokens.length; t++) {
            address token = eTokens[t];
            uint256 balance = IERC20(token).balanceOf(WALLET);
            console.log("RW: %s => %s", getLabel(ethFork, token), balance);
        }
        console.log("Raised USDT (Ethereum): %s", IPulseRaiserExt(E_RAISER).raiseLocal());
        console.log("vs %s points", IPulseRaiserExt(E_RAISER).pointsLocal());

        vm.selectFork(bscFork);
        for (uint8 t = 0; t < bTokens.length; t++) {
            address token = bTokens[t];
            uint256 balance = IERC20(token).balanceOf(WALLET);
            console.log("RW: %s => %s", getLabel(bscFork, token), balance);
        }
        console.log("Raised USDT (BSC): %s", IPulseRaiserExt(B_RAISER).raiseLocal());
        console.log("vs %s points", IPulseRaiserExt(B_RAISER).pointsLocal());

        vm.selectFork(arbFork);
        for (uint8 t = 0; t < aTokens.length; t++) {
            address token = aTokens[t];
            uint256 balance = IERC20(token).balanceOf(WALLET);
                
            console.log("RW: %s => %s", getLabel(arbFork, token), balance);
        }
        console.log("Raised USDT (Arb): %s", IPulseRaiserExt(A_RAISER).raiseLocal());
        console.log("vs %s points", IPulseRaiserExt(A_RAISER).pointsLocal());

    }

    // generate a merkle for contributors from BSC and Arbitrum
    function generateMerkle(
        address raiserB,
        address[] memory contributorsB,
        address raiserA,
        address[] memory contributorsA
    ) internal returns (bytes32[] memory data) {
        uint256 countAccounts;

        vm.selectFork(bscFork);
        for (uint256 cb = 0; cb < contributorsB.length; cb++) {
            address account = contributorsB[cb];
            uint256 points = IPulseRaiserExt(raiserB).pointsGained(account);
            if (points > 0) {
                pointsPerAccount[account] += points;
                countAccounts++;
                collatablePoints += points;
                collatableAccounts.push(account);
            }
        }

        vm.selectFork(arbFork);
        for (uint256 ca = 0; ca < contributorsA.length; ca++) {
            address account = contributorsA[ca];
            uint256 points = IPulseRaiserExt(raiserA).pointsGained(account);
            if (points > 0) {
                pointsPerAccount[account] += points;
                countAccounts++;
                collatablePoints += points;
                collatableAccounts.push(account);
            }
        }

        vm.selectFork(ethFork);
        data = new bytes32[](countAccounts);

        for (uint256 r = 0; r < countAccounts; r++) {
            address account = collatableAccounts[r];
            uint256 points = pointsPerAccount[account];
            data[r] = keccak256(abi.encodePacked(r, account, points));
        }
    }

    function _contribs(
        uint8 day,
        uint256 fork,
        address raiser,
        uint16 startWithContributor,
        uint16 numContributors,
        address[] memory tokens,
        address[] memory contributors,
        uint256 amount
    ) public {
        vm.selectFork(fork);
        vm.warp(IPulseRaiserExt(raiser).launchAt() + day * 1 days + 1);

        for (
            uint256 r = startWithContributor;
            r < startWithContributor + numContributors;
            r++
        ) {
            // pick an Ethereum contributor
            address account = contributors[r];

            // pick a token (cycle through)
            address token = tokens[block.timestamp % tokens.length];

            // mint some directly from the contract
            deal(token, account, amount);
            
            vm.prank(account, account);
            IERC20U(token).approve(raiser, amount);

            // contribute and get points credited
            vm.prank(account, account);
            IPulseRaiser(raiser).contribute(token, amount, address(0));

            // advance time so that a different token is picked next time
            vm.warp(block.timestamp + 1);
        }
    }
}
