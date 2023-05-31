// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "forge-std/console.sol";

import {PulseRaiser} from "../contracts/PulseRaiser.sol";
import {Shibart} from "../contracts/Shibart.sol";
import {IPulseRaiserEvents} from "../contracts/interfaces/IPulseRaiserEvents.sol";
import {IShibartEvents} from "../contracts/interfaces/IShibartEvents.sol";
import {IOwnablePausableEvents} from "../contracts/interfaces/IOwnablePausableEvents.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Merkle} from "./murky/Merkle.sol";

interface IERC20Events {
    event Transfer(address indexed from, address indexed to, uint256 amount);
}

interface IERC20USDT {
    function approve(address spender, uint256 amount) external;
}

contract PulseRaiserCommons is
    Test,
    IPulseRaiserEvents,
    IShibartEvents,
    IERC20Events,
    IOwnablePausableEvents
{
    using SafeERC20 for IERC20;
    uint256 fork;
    address canonicalNormalizationToken;
    address wrappedNative;
    address wrappedBtc;
    address usdcToken;

    // string ETHEREUM_MAINNET_RPC = ;
    // string BSC_MAINNET_RPC = ;

    address deployer; // = vm.addr(1);
    address raiseWallet; // = vm.addr(2);
    address defaultAccount; //= vm.addr(3);

    // v3
    address internal constant ETHEREUM_UNISWAP_FACTORY =
        0x1F98431c8aD98523631AE4a59f267346ea31F984;

    // v2
    address internal constant ETHEREUM_UNISWAP_ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    address internal constant ETHEREUM_WRAPPED_NATIVE =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address internal constant ETHEREUM_NORMALIZATION_TOKEN =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address internal constant ETHEREUM_WBTC =
        0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    address internal constant ETHEREUM_USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // WETH/ETH->USD Price Feed
    address internal constant ETH_USD_FEED =
        0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    // BTC->USD
    address internal constant BTC_USD_FEED =
        0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;

    uint32 internal constant POINTS = 10000;
    uint32 internal constant LAUNCH_OFFSET = 1 days;
    uint256 internal constant SHIBART_FULL_SUPPLY = 1_000_000_000 ether;
    uint32 internal deploymentTime;

    Shibart gt;
    PulseRaiser pRaiser;

    //#region owner-only fns
    function test_modifyPriceBase_non_owner_reverts() public {
        uint8 dayIndex_ = 0;
        uint16 priceBase_ = 1;
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(defaultAccount, defaultAccount);
        pRaiser.modifyPriceBase(dayIndex_, priceBase_);
    }

    function test_modifyPriceBase_day_not_in_range_reverts() public {
        uint8 dayIndex_ = 20;
        uint16 priceBase_ = 1;
        vm.expectRevert("Expected a 0-19 Day Index");
        vm.prank(deployer, deployer);
        pRaiser.modifyPriceBase(dayIndex_, priceBase_);
    }

    function test_modifyPriceBase_invalid_base_reverts() public {
        uint8 dayIndex_ = 0;
        uint16 invalidBase1_ = 0;
        uint16 invalidBase2_ = 1024;

        vm.expectRevert("Zero Price Base");
        vm.prank(deployer, deployer);
        pRaiser.modifyPriceBase(dayIndex_, invalidBase1_);

        vm.expectRevert("Price Base Exceeds 10 Bits");
        vm.prank(deployer, deployer);
        pRaiser.modifyPriceBase(dayIndex_, invalidBase2_);
    }

    function test_modifyPriceBase_executes() public {
        // changes each day without changing all the other days
        // emits an event
        uint256 LOWEST_10_BITS_MASK = 1023;
        uint16[] memory priceBases = new uint16[](20);
        uint256 encodedpp = pRaiser.encodedpp();

        for (uint8 day = 0; day < 20; day++) {
            priceBases[day] = uint16(
                (encodedpp >> (day * 10)) & LOWEST_10_BITS_MASK
            );
        }

        // modify base for each day separately and on each step compare all
        // days' bases to our local assumption about the config
        for (uint8 day = 0; day < 20; day++) {
            vm.expectEmit(true, true, true, true, address(pRaiser));
            emit PriceBaseModified(day, priceBases[day] * 2);
            vm.prank(deployer, deployer);
            pRaiser.modifyPriceBase(day, priceBases[day] * 2);
            priceBases[day] *= 2;
            uint256 encodedpp_ = pRaiser.encodedpp();

            for (uint8 e = 0; e < 20; e++) {
                // console.log("Day %s [%s] => %s", day, e, (encodedpp_ >> (e * 10)) & LOWEST_10_BITS_MASK);
                assertEq(
                    priceBases[e],
                    (encodedpp_ >> (e * 10)) & LOWEST_10_BITS_MASK
                );
            }
        }
    }

    function test_modifyPriceBases_non_owner_reverts() public {
        uint16[] memory priceBases = new uint16[](20);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(defaultAccount, defaultAccount);
        pRaiser.modifyPriceBases(priceBases);
    }

    function test_modifyPriceBases_count_mismatch_reverts() public {
        uint16[] memory priceBases0;
        uint16[] memory priceBases19 = new uint16[](19);
        uint16[] memory priceBases21 = new uint16[](21);

        vm.expectRevert("Invalid Bases Count");
        vm.prank(deployer, deployer);
        pRaiser.modifyPriceBases(priceBases0);

        vm.expectRevert("Invalid Bases Count");
        vm.prank(deployer, deployer);
        pRaiser.modifyPriceBases(priceBases19);

        vm.expectRevert("Invalid Bases Count");
        vm.prank(deployer, deployer);
        pRaiser.modifyPriceBases(priceBases21);
    }

    function test_modifyPriceBases_invalid_base_reverts() public {
        uint16[] memory priceBases0 = new uint16[](20);
        uint16[] memory priceBases1024 = new uint16[](20);

        for (uint8 d = 0; d < 20; d++) {
            if (d == 5) {
                priceBases0[d] = 0;
                priceBases1024[d] = 1024;
            } else {
                priceBases0[d] = d + 10;
                priceBases1024[d] = d + 10;
            }
        }

        vm.expectRevert("Zero Price Base");
        vm.prank(deployer, deployer);
        pRaiser.modifyPriceBases(priceBases0);

        vm.expectRevert("Price Base Exceeds 10 Bits");
        vm.prank(deployer, deployer);
        pRaiser.modifyPriceBases(priceBases1024);

        for (uint8 d = 0; d < 20; d++) {
            if (d == 0) {
                priceBases0[d] = 0;
                priceBases1024[d] = 1024;
            } else {
                priceBases0[d] = d + 10;
                priceBases1024[d] = d + 10;
            }
        }

        vm.expectRevert("Zero Price Base");
        vm.prank(deployer, deployer);
        pRaiser.modifyPriceBases(priceBases0);

        vm.expectRevert("Price Base Exceeds 10 Bits");
        vm.prank(deployer, deployer);
        pRaiser.modifyPriceBases(priceBases1024);

        for (uint8 d = 0; d < 20; d++) {
            if (d == 19) {
                priceBases0[d] = 0;
                priceBases1024[d] = 1024;
            } else {
                priceBases0[d] = d + 10;
                priceBases1024[d] = d + 10;
            }
        }

        vm.expectRevert("Zero Price Base");
        vm.prank(deployer, deployer);
        pRaiser.modifyPriceBases(priceBases0);

        vm.expectRevert("Price Base Exceeds 10 Bits");
        vm.prank(deployer, deployer);
        pRaiser.modifyPriceBases(priceBases1024);
    }

    function test_modifyPriceBases_executes() public {
        uint256 LOWEST_10_BITS_MASK = 1023;
        uint16[] memory priceBases = new uint16[](20);
        uint256[] memory prices = new uint256[](20);
        uint256 encodedpp = pRaiser.encodedpp();

        for (uint8 day = 0; day < 20; day++) {
            priceBases[day] =
                2 *
                uint16((encodedpp >> (day * 10)) & LOWEST_10_BITS_MASK);

            prices[day] = uint256(priceBases[day]) * 1e16;
        }

        vm.expectEmit(true, false, false, false, address(pRaiser));
        emit PriceBasesBatchModified();

        vm.prank(deployer, deployer);
        pRaiser.modifyPriceBases(priceBases);

        for (uint8 d = 0; d < 20; d++) {
            vm.warp(deploymentTime + LAUNCH_OFFSET + 1 + (1 days) * d);
            assertEq(pRaiser.currentPrice(), prices[d]);
        }
    }

    function test_collate_non_owner_reverts() public {
        bytes32 merkleRoot;
        uint256 pointsOtherNetworks = 1;
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(defaultAccount, defaultAccount);
        pRaiser.collate(merkleRoot, pointsOtherNetworks);
    }

    function test_collate_sale_in_progress_reverts() public {
        // short-circuit for non-Ethereum deployment
        if (address(pRaiser.token()) == address(0)) return;

        bytes32 merkleRoot;
        uint256 pointsOtherNetworks = 1;

        for (uint8 d = 0; d < 20; d++) {
            vm.warp(deploymentTime + LAUNCH_OFFSET + 1 + (1 days) * d);

            vm.expectRevert("Wait for Sale to Complete");
            vm.prank(deployer, deployer);
            pRaiser.collate(merkleRoot, pointsOtherNetworks);
        }
    }

    function test_collate_executes() public {
        // short-circuit for non-Ethereum deployment
        if (address(pRaiser.token()) == address(0)) return;

        bytes32 merkleRoot = bytes32(uint256(256));
        uint256 pointsOtherNetworks = 1000;
        uint256 expectedTokenPerPoint = gt.distributionSupply() /
            pointsOtherNetworks;

        vm.warp(pRaiser.launchAt() + 20 days + 1);

        vm.expectEmit(true, true, true, false, address(pRaiser));
        emit TotalPointsAllocated(pointsOtherNetworks, expectedTokenPerPoint);

        vm.prank(deployer, deployer);
        pRaiser.collate(merkleRoot, pointsOtherNetworks);

        assertEq(pRaiser.merkleRoot(), merkleRoot);
        assertEq(expectedTokenPerPoint, pRaiser.tokenPerPoint());
    }

    function test_collate_executes_2() public {
        // short-circuit for non-Ethereum deployment
        if (address(pRaiser.token()) == address(0)) return;

        address account = defaultAccount;
        bytes32 merkleRoot = bytes32(uint256(256));
        uint256 pointsOtherNetworks = 1000;
        uint256 pointsLocal = 1000;
        uint256 expectedTokenPerPoint = gt.distributionSupply() /
            (pointsOtherNetworks + pointsLocal);

        deal(canonicalNormalizationToken, account, 1 ether);
        assertEq(
            IERC20(canonicalNormalizationToken).balanceOf(account),
            1 ether
        );
        vm.prank(account, account);
        IERC20USDT(canonicalNormalizationToken).approve(
            address(pRaiser),
            1 ether
        );

        vm.warp(pRaiser.launchAt() + 1);

        vm.prank(account, account);
        pRaiser.contribute(canonicalNormalizationToken, 0.1 ether);

        vm.warp(pRaiser.launchAt() + 20 days + 1);

        vm.expectEmit(true, true, true, false, address(pRaiser));
        emit TotalPointsAllocated(
            pointsOtherNetworks + pointsLocal,
            expectedTokenPerPoint
        );

        vm.prank(deployer, deployer);
        pRaiser.collate(merkleRoot, pointsOtherNetworks);

        assertEq(pRaiser.merkleRoot(), merkleRoot);
        assertEq(expectedTokenPerPoint, pRaiser.tokenPerPoint());
        assertEq(pRaiser.pointsLocal(), pointsLocal);
    }

    function test_distribute_non_owner_reverts() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(defaultAccount);
        pRaiser.distribute();
    }

    function test_distribute_before_collate_reverts() public {
        vm.expectRevert("Collate First");
        vm.prank(deployer);
        pRaiser.distribute();
    }

    function test_distribute_executes() public {
        // short-circuit for non-Ethereum deployment
        if (address(pRaiser.token()) == address(0)) return;

        assertEq(pRaiser.claimsEnabled(), false);

        bytes32 merkleRoot = bytes32(uint256(256));
        uint256 pointsOtherNetworks = 1000;

        vm.warp(pRaiser.launchAt() + 20 days + 1);

        vm.prank(deployer);
        pRaiser.collate(merkleRoot, pointsOtherNetworks);

        vm.expectEmit(true, false, false, false, address(pRaiser));
        emit ClaimsEnabled();

        vm.prank(deployer);
        pRaiser.distribute();

        assertEq(pRaiser.claimsEnabled(), true);
    }

    function test_toggle_non_owner_reverts() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(defaultAccount);
        pRaiser.toggle();
    }

    function test_toggle_executes() public {
        assertEq(pRaiser.paused(), false);

        vm.expectEmit(true, true, false, false, address(pRaiser));
        emit PauseStateSet(true);
        vm.prank(deployer);
        pRaiser.toggle();

        assertEq(pRaiser.paused(), true);

        vm.expectEmit(true, true, false, false, address(pRaiser));
        emit PauseStateSet(false);
        vm.prank(deployer);
        pRaiser.toggle();

        assertEq(pRaiser.paused(), false);
    }

    function test_controlAssetsWhitelisting_non_owner_reverts() public {
        // TODO:
    }

    function test_controlAssetsWhitelisting_executes() public {
        // TODO:
    }

    function test_controlStables_non_owner_reverts() public {
        // TODO:
    }

    function test_controlStables_executes() public {
        // TODO:
    }

    //#endregion

    //#region mutators
    function test_contribute_paused_reverts() public {
        vm.warp(deploymentTime + LAUNCH_OFFSET + 1);

        deal(canonicalNormalizationToken, defaultAccount, 1 ether);
        vm.prank(defaultAccount, defaultAccount);
        IERC20USDT(canonicalNormalizationToken).approve(
            address(pRaiser),
            1 ether
        );

        vm.prank(deployer);

        pRaiser.toggle();

        vm.expectRevert("Contract Paused");
        vm.prank(defaultAccount, defaultAccount);
        pRaiser.contribute(canonicalNormalizationToken, 1 ether);
    }

    function test_contribute_not_in_progress_reverts() public {
        vm.warp(deploymentTime + LAUNCH_OFFSET - 1);

        deal(canonicalNormalizationToken, defaultAccount, 1 ether);
        vm.prank(defaultAccount, defaultAccount);
        IERC20USDT(canonicalNormalizationToken).approve(
            address(pRaiser),
            1 ether
        );

        vm.expectRevert("Sale Not In Progress");
        vm.prank(defaultAccount, defaultAccount);
        pRaiser.contribute(canonicalNormalizationToken, 1 ether);

        vm.warp(deploymentTime + LAUNCH_OFFSET + 20 days + 1);

        vm.expectRevert("Sale Ended");
        vm.prank(defaultAccount, defaultAccount);
        pRaiser.contribute(canonicalNormalizationToken, 1 ether);
    }

    function test_contribute_not_an_eoa_reverts() public {
        vm.warp(deploymentTime + LAUNCH_OFFSET + 1);

        deal(canonicalNormalizationToken, defaultAccount, 1 ether);
        vm.prank(defaultAccount, defaultAccount);
        IERC20USDT(canonicalNormalizationToken).approve(
            address(pRaiser),
            1 ether
        );

        vm.expectRevert("Caller Not an EOA");
        vm.prank(defaultAccount, deployer);
        pRaiser.contribute(canonicalNormalizationToken, 1 ether);
    }

    function test_contribute_insufficient_contribution_reverts() public {
        vm.warp(deploymentTime + LAUNCH_OFFSET + 1);

        deal(canonicalNormalizationToken, defaultAccount, 1 ether);
        vm.prank(defaultAccount, defaultAccount);
        IERC20USDT(canonicalNormalizationToken).approve(address(pRaiser), 2);

        vm.expectRevert("Insufficient Contribution");
        vm.prank(defaultAccount, defaultAccount);
        pRaiser.contribute(canonicalNormalizationToken, 2);
    }

    function test_contribute_executes() public {
        // SEE ELSEWHERE
    }

    function test_claim_paused_reverts() public {
        // short-circuit for non-Ethereum deployment
        if (address(pRaiser.token()) == address(0)) return;
        (
            Merkle m,
            uint256 totalPoints,
            bytes32[] memory data,
            address[] memory accounts
        ) = generateMerkle(30);

        bytes32 merkleRoot = m.getRoot(data);

        vm.warp(pRaiser.launchAt() + 20 days + 1);

        vm.startPrank(deployer);
        pRaiser.collate(merkleRoot, totalPoints);
        pRaiser.distribute();
        pRaiser.toggle();
        vm.stopPrank();

        address account = accounts[0];
        uint256 points = 1000;
        bytes32[] memory proof = m.getProof(data, 0);

        vm.expectRevert("Contract Paused");
        vm.prank(account, account);
        pRaiser.claim(0, points, proof);
    }

    function test_claim_not_in_progress_reverts() public {
        // short-circuit for non-Ethereum deployment
        if (address(pRaiser.token()) == address(0)) return;
        (
            Merkle m,
            uint256 totalPoints,
            bytes32[] memory data,
            address[] memory accounts
        ) = generateMerkle(30);

        bytes32 merkleRoot = m.getRoot(data);

        address account = accounts[0];
        uint256 points = 1000;
        bytes32[] memory proof = m.getProof(data, 0);

        vm.expectRevert("Wait for Claims");
        vm.prank(account, account);
        pRaiser.claim(0, points, proof);

        vm.warp(pRaiser.launchAt() + 20 days + 1);

        vm.expectRevert("Wait for Claims");
        vm.prank(account, account);
        pRaiser.claim(0, points, proof);

        vm.prank(deployer);
        pRaiser.collate(merkleRoot, totalPoints);

        vm.expectRevert("Wait for Claims");
        vm.prank(account, account);
        pRaiser.claim(0, points, proof);
    }

    function test_claim_proof_reuse_reverts() public {
        // SEE test_claim_executes
    }

    function test_claim_invalid_proof_reuse_reverts() public {
        // short-circuit for non-Ethereum deployment
        if (address(pRaiser.token()) == address(0)) return;

        (
            Merkle m,
            uint256 totalPoints,
            bytes32[] memory data,
            address[] memory accounts
        ) = generateMerkle(30);

        bytes32 merkleRoot = m.getRoot(data);

        vm.warp(pRaiser.launchAt() + 20 days + 1);

        vm.prank(deployer);
        pRaiser.collate(merkleRoot, totalPoints);
        vm.prank(deployer);
        pRaiser.distribute();

        for (uint256 r = 0; r < accounts.length - 1; r++) {
            address account = accounts[r];
            uint256 points = 1000 + r * 1000;
            bytes32[] memory proof = m.getProof(data, r);
            bytes32[] memory nextProof = m.getProof(data, r + 1);

            vm.expectRevert("Invalid Merkle Proof");
            vm.prank(account, account);
            pRaiser.claim(r + 1, points, proof);

            vm.expectRevert("Invalid Merkle Proof");
            vm.prank(account, account);
            pRaiser.claim(r, points - 1, proof);

            vm.expectRevert("Invalid Merkle Proof");
            vm.prank(account, account);
            pRaiser.claim(r, points, nextProof);
        }
    }

    function test_claim_executes() public {
        // short-circuit for non-Ethereum deployment
        if (address(pRaiser.token()) == address(0)) return;

        (
            Merkle m,
            uint256 totalPoints,
            bytes32[] memory data,
            address[] memory accounts
        ) = generateMerkle(30);

        bytes32 merkleRoot = m.getRoot(data);

        vm.warp(pRaiser.launchAt() + 20 days + 1);

        vm.prank(deployer);
        pRaiser.collate(merkleRoot, totalPoints);
        vm.prank(deployer);
        pRaiser.distribute();

        uint256 tokenPerPoint = pRaiser.tokenPerPoint();

        for (uint256 r = 0; r < accounts.length; r++) {
            address account = accounts[r];
            uint256 points = 1000 + r * 1000;
            uint256 expectedTokenBalance = points * tokenPerPoint;
            assertGt(expectedTokenBalance, 0);
            bytes32[] memory proof = m.getProof(data, r);

            vm.expectEmit(true, true, true, false, address(gt));
            emit Distributed(account, expectedTokenBalance);
            vm.expectEmit(true, true, true, true, address(gt));
            emit Transfer(address(0), account, expectedTokenBalance);

            vm.prank(account, account);
            pRaiser.claim(r, points, proof);

            vm.expectRevert("Proof Already Used");
            vm.prank(account, account);
            pRaiser.claim(r, points, proof);

            assertEq(expectedTokenBalance, gt.balanceOf(account));
        }
    }

    function test_claim_local_executes_once() public {
        // short-circuit for non-Ethereum deployment
        if (address(pRaiser.token()) == address(0)) return;

        vm.warp(deploymentTime + LAUNCH_OFFSET + 1);

        deal(canonicalNormalizationToken, defaultAccount, 1 ether);
        vm.prank(defaultAccount, defaultAccount);
        IERC20USDT(canonicalNormalizationToken).approve(
            address(pRaiser),
            1 ether
        );

        vm.prank(defaultAccount, defaultAccount);
        pRaiser.contribute(canonicalNormalizationToken, 1 ether);

        vm.warp(pRaiser.launchAt() + 20 days + 1);

        vm.prank(deployer);
        pRaiser.collate(bytes32(0), 0);
        vm.prank(deployer);
        pRaiser.distribute();

        uint256 tokenPerPoint = pRaiser.tokenPerPoint();
        uint256 expectedTokenBalance = pRaiser.pointsGained(defaultAccount) *
            tokenPerPoint;
        assertGt(expectedTokenBalance, 0);

        vm.expectEmit(true, true, true, false, address(gt));
        emit Distributed(defaultAccount, expectedTokenBalance);
        vm.expectEmit(true, true, true, true, address(gt));
        emit Transfer(address(0), defaultAccount, expectedTokenBalance);

        bytes32[] memory proof;
        vm.prank(defaultAccount, defaultAccount);
        pRaiser.claim(0, 0, proof);

        assertEq(expectedTokenBalance, gt.balanceOf(defaultAccount));

        vm.prank(defaultAccount, defaultAccount);
        pRaiser.claim(0, 0, proof);

        assertEq(expectedTokenBalance, gt.balanceOf(defaultAccount));
    }

    //#endregion

    function test_currentPrice_estimate_progression() public {
        uint256[] memory dailyBasePointPrice = new uint256[](20);
        dailyBasePointPrice[0] = 1000000000000000000; // $1 per set amout of points
        dailyBasePointPrice[1] = 1000000000000000000;
        dailyBasePointPrice[2] = 1000000000000000000;
        dailyBasePointPrice[3] = 1000000000000000000;
        dailyBasePointPrice[4] = 1000000000000000000;
        dailyBasePointPrice[5] = 1050000000000000000; // $1.05
        dailyBasePointPrice[6] = 1100000000000000000; // $1.10
        dailyBasePointPrice[7] = 1210000000000000000; // $1.21
        dailyBasePointPrice[8] = 1330000000000000000; // $1.33
        dailyBasePointPrice[9] = 1460000000000000000; // $1.46
        dailyBasePointPrice[10] = 1610000000000000000; // $1.61
        dailyBasePointPrice[11] = 1770000000000000000; // $1.77
        dailyBasePointPrice[12] = 1950000000000000000; // $1.95
        dailyBasePointPrice[13] = 2150000000000000000; // $2.15
        dailyBasePointPrice[14] = 2360000000000000000; // etc
        dailyBasePointPrice[15] = 2600000000000000000; //
        dailyBasePointPrice[16] = 2860000000000000000; //
        dailyBasePointPrice[17] = 3430000000000000000; //
        dailyBasePointPrice[18] = 4110000000000000000; //
        dailyBasePointPrice[19] = 4930000000000000000; // $4.93

        for (uint8 d = 0; d < 20; d++) {
            vm.warp(deploymentTime + LAUNCH_OFFSET + 1 + (1 days) * d);
            // confirm price progression
            assertEq(pRaiser.currentPrice(), dailyBasePointPrice[d]);
            // confirm that today's amount converts to the set amount of points
            assertEq(
                pRaiser.estimate(
                    canonicalNormalizationToken,
                    dailyBasePointPrice[d]
                ),
                pRaiser.points()
            );
        }
    }

    //
    // #estimate
    //
    function test_estimate_sale_not_in_progress_reverts() public {
        vm.expectRevert("Sale Not In Progress");
        pRaiser.estimate(wrappedNative, 1);

        vm.warp(deploymentTime + LAUNCH_OFFSET + 20 days + 1);
        vm.expectRevert("Sale Ended");
        pRaiser.estimate(wrappedNative, 1);
    }

    function test_estimate_non_whitelisted_token_reverts() public {
        address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

        vm.warp(deploymentTime + LAUNCH_OFFSET + 1 days);
        vm.expectRevert("Invalid Payment Asset");
        pRaiser.estimate(DAI, 1);
    }

    function test_estimate_amount_too_small_returns_zero() public {
        vm.warp(deploymentTime + LAUNCH_OFFSET);
        assertEq(pRaiser.estimate(wrappedNative, 1), 0);
        assertEq(pRaiser.estimate(canonicalNormalizationToken, 1), 0);
    }

    function test_estimate_amount_executes() public {
        vm.warp(deploymentTime + LAUNCH_OFFSET);
        assertEq(
            pRaiser.estimate(canonicalNormalizationToken, 1 ether),
            pRaiser.points()
        );

        assertEq(
            pRaiser.estimate(canonicalNormalizationToken, 2 ether),
            pRaiser.points() * 2
        );

        assertEq(
            pRaiser.estimate(
                canonicalNormalizationToken,
                1 ether + (1 ether / 20)
            ),
            pRaiser.points() + 500
        );

        console.log(block.number);

        console.log(
            "1 ETH == $1901.99 --> %s points",
            pRaiser.estimate(wrappedNative, 1 ether)
        );
    }

    function test_estimate_non_whitelisted_tokens_reverts() public {
        vm.warp(deploymentTime + LAUNCH_OFFSET);
        console.log(
            "normalized (W)ETH: %s",
            pRaiser.normalize(wrappedNative, 1 ether)
        );
        console.log(
            "normalized USDT: %s",
            pRaiser.normalize(canonicalNormalizationToken, 1 ether)
        );
        // pRaiser.estimate(canonicalNormalizationToken, 2);
        console.log(
            "normalized WBTC: %s",
            pRaiser.normalize(wrappedBtc, 1 ether)
        );
        // pRaiser.estimate(ETHEREUM_WBTC, 3);

        console.log(
            "points for 1 (W)ETH: %s",
            pRaiser.estimate(wrappedNative, 1 ether)
        );
        console.log(
            "points for 1 USDT: %s",
            pRaiser.estimate(canonicalNormalizationToken, 1 ether)
        );
        // pRaiser.estimate(canonicalNormalizationToken, 2);
        console.log(
            "points for 1 WBTC: %s",
            pRaiser.estimate(wrappedBtc, 1 ether)
        );

        console.log(
            "points for almost 1 USDT: %s",
            pRaiser.estimate(canonicalNormalizationToken, 1 ether - 1)
        );
        console.log(
            "points for 1 wei USDT: %s",
            pRaiser.estimate(canonicalNormalizationToken, 1)
        );
        console.log(
            "points for 3 wei WBTC: %s",
            pRaiser.estimate(wrappedBtc, 3)
        );
        console.log(
            "points for 1/10000 USDT: %s",
            pRaiser.estimate(canonicalNormalizationToken, 1 ether / 10000)
        );
        console.log(
            "points for 1/10001 USDT: %s",
            pRaiser.estimate(
                canonicalNormalizationToken,
                1 ether / uint256(10001)
            )
        );

        vm.expectRevert();
        // DAI
        pRaiser.estimate(0x6B175474E89094C44Da98b954EedeAC495271d0F, 4);
    }

    function test_estimate_executes() public {
        // per specification, we should be able to accept ETH, WETH, WBTC, USDT, USDC
        // (on Ethereum), and potentially a combination of ETH/any (via payable)

        address buyerEth = vm.addr(101);
        vm.label(buyerEth, "BuyerETH");
        address buyerWeth = vm.addr(102);
        vm.label(buyerWeth, "BuyerWETH");
        address buyerEthWethCombo = vm.addr(103);
        vm.label(buyerEthWethCombo, "BuyerETHWETH");
        address buyerWbtc = vm.addr(104);
        vm.label(buyerWbtc, "BuyerWBTC");
        address buyerUsdt = vm.addr(105);
        vm.label(buyerUsdt, "BuyerUSDT");
        address buyerUsdc = vm.addr(106);
        vm.label(buyerUsdc, "BuyerUSDC");

        for (uint8 d = 0; d < 20; d++) {
            // jump to day #d
            vm.warp(deploymentTime + LAUNCH_OFFSET + 1 + (1 days) * d);

            // WETH is used to estimate points for both ETH and WETH
            uint256 ethWethPoints = pRaiser.estimate(
                wrappedNative,
                .5 ether
            );
            uint256 wbtcPoints = pRaiser.estimate(wrappedBtc, 0.5 ether);
            uint256 usdtPoints = pRaiser.estimate(
                canonicalNormalizationToken,
                10 ether
            );
            uint256 usdcPoints = pRaiser.estimate(usdcToken, 5 ether);

            console.log("Day %s", d + 1);
            console.log("   ETH: %s (points per 0.5 ETH)", ethWethPoints);
            console.log("   WBTC: %s (points per 0.5 BTC)", wbtcPoints);
            console.log("   USDT: %s (points per 10 USD)", usdtPoints);
            console.log("   USDC: %s (points per 5 USD)", usdcPoints);

            estimate_executes_eth(0.5 ether, buyerEth, ethWethPoints);
            estimate_executes_eth_and_weth(
                0.5 ether,
                0.5 ether,
                buyerEthWethCombo,
                ethWethPoints
            );
            estimate_executes_with_token_amount(
                wrappedBtc,
                0.5 ether,
                buyerWbtc,
                wbtcPoints
            );

            estimate_executes_with_token_amount(
                usdcToken,
                5 ether,
                buyerUsdc,
                usdcPoints
            );

            estimate_executes_with_token_amount(
                canonicalNormalizationToken,
                10 ether,
                buyerUsdt,
                usdtPoints
            );
        }
    }

    function estimate_executes_eth(
        uint256 amount,
        address account,
        uint256 expectedPoints
    ) internal {
        deal(account, amount);

        uint256 accountPointsGainedPre = pRaiser.pointsGained(account);
        vm.prank(account, account);
        pRaiser.contribute{value: amount}(address(0), 100);

        uint256 accountPointsGainedPost = pRaiser.pointsGained(account);
        assertEq(
            accountPointsGainedPost - accountPointsGainedPre,
            expectedPoints
        );
    }

    function estimate_executes_eth_and_weth(
        uint256 amountEth,
        uint256 amountWeth,
        address account,
        uint256 expectedPoints
    ) internal {
        // contribute ETH and WETH simultaneously
        deal(wrappedNative, account, amountEth);
        deal(account, amountWeth);

        assertEq(
            IERC20(wrappedNative).balanceOf(account),
            amountWeth
        );
        vm.prank(account, account);
        IERC20(wrappedNative).approve(address(pRaiser), amountWeth);

        uint256 accountPointsGainedPre = pRaiser.pointsGained(account);
        vm.prank(account, account);
        pRaiser.contribute{value: amountEth}(
            wrappedNative,
            amountWeth
        );
        uint256 accountPointsGainedPost = pRaiser.pointsGained(account);
        // NOTE: because amounts are rounded due to solidity division,
        // combining two assets could yield a slight difference in the estimate
        // of the points credited to the contributor's account; hence the
        // WithinRange assessment of this result
        assertWithinRange(
            accountPointsGainedPost - accountPointsGainedPre,
            expectedPoints * 2 - 1,
            expectedPoints * 2 + 1
        );
    }

    function estimate_executes_with_token_amount(
        address token,
        uint256 amount,
        address account,
        uint256 expectedPoints
    ) internal {
        deal(token, account, amount);
        assertEq(IERC20(token).balanceOf(account), amount);
        vm.prank(account, account);
        if (token == canonicalNormalizationToken) {
            IERC20USDT(token).approve(address(pRaiser), amount);
        } else {
            IERC20(token).approve(address(pRaiser), amount);
        }

        assertGe(IERC20(token).allowance(account, address(pRaiser)), amount);

        uint256 accountPointsGainedPre = pRaiser.pointsGained(account);
        vm.prank(account, account);
        pRaiser.contribute(token, amount);
        uint256 accountPointsGainedPost = pRaiser.pointsGained(account);
        assertEq(
            accountPointsGainedPost - accountPointsGainedPre,
            expectedPoints
        );
    }

    //
    // - GENERAL HELPERS
    //
    function assertWithinRange(
        uint256 value,
        uint256 rangeL,
        uint256 rangeR
    ) internal {
        assertGe(value, rangeL);
        assertLe(value, rangeR);
    }

    function generateMerkle(
        uint256 count
    )
        internal
        returns (
            Merkle m,
            uint256 totalPoints,
            bytes32[] memory data,
            address[] memory accounts
        )
    {
        m = new Merkle();
        data = new bytes32[](count);
        accounts = new address[](count);

        // uint256 points = randomNumber(1000);

        for (uint256 r = 0; r < count; r++) {
            accounts[r] = vm.addr(r + 1000);
            uint256 points = 1000 + r * 1000;
            totalPoints += points;
            data[r] = keccak256(abi.encodePacked(r, accounts[r], points));
        }
    }
}
