// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "forge-std/console.sol";

import {PulseRaiser} from "../contracts/PulseRaiser.sol";
import {Shibart} from "../contracts/Shibart.sol";
import {NormalizationStrategy} from "../contracts/defs/NormalizationStrategy.sol";

import {PulseRaiserCommons} from "./PulseRaiserPF.sol";

contract PulseRaiserBSCMainnetTest is PulseRaiserCommons {
    address public constant BSC_UNISWAP_FACTORY =
        0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;

    // v2
    address public constant BSC_UNISWAP_ROUTER =
        0x10ED43C718714eb63d5aA57B78B54704E256024E;

    address public constant BSC_WRAPPED_NATIVE =
        0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    address public constant BSC_NORMALIZATION_TOKEN =
        0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;

    // "W" ETH (peg)
    address public constant BSC_WETH =
        0x2170Ed0880ac9A755fd29B2688956BD959F933F8;

    // BTCB
    address public constant BSC_WBTC =
        0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;

    // USDC Token
    address public constant BSC_USDC =
        0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;

    // BUSD token
    address public constant BSC_BUSD =
        0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;

    address public constant BSC_USDT =
        0x524bC91Dc82d6b90EF29F76A3ECAaBAffFD490Bc;

    // WETH/ETH->USD Price Feed
    address public constant BSC_ETH_USD_FEED =
        0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e;
    // BTC->USD
    address public constant BSC_BTC_USD_FEED =
        0x264990fbd0A4796A3E3d8E37C4d5F87a3aCa5Ebf;
    // WBNB/BNB ->USD
    address public constant BSC_BNB_USD_FEED =
        0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE;

    function setUp() public {
        fork = vm.createFork(vm.envString("BSC_MAINNET_RPC"), 28000000);
        vm.selectFork(fork);

        deployer = vm.addr(1);
        raiseWallet = vm.addr(2);
        defaultAccount = vm.addr(3);
        vm.label(address(gt), "GenerationToken");
        vm.label(deployer, "Deployer");
        vm.label(raiseWallet, "RaiseWallet");

        address[] memory stables = new address[](3);
        stables[0] = BSC_BUSD;
        stables[1] = BSC_USDC;
        stables[2] = BSC_USDT;

        address[] memory assets = new address[](3);
        assets[0] = BSC_WETH;
        assets[1] = BSC_WBTC;
        assets[2] = BSC_WRAPPED_NATIVE;

        address[] memory feeds = new address[](3);
        feeds[0] = BSC_ETH_USD_FEED;
        feeds[1] = BSC_BTC_USD_FEED;
        feeds[2] = BSC_BNB_USD_FEED;

        canonicalNormalizationToken = BSC_BUSD;
        wrappedNative = BSC_WRAPPED_NATIVE;
        wrappedBtc = BSC_WBTC;
        usdcToken = BSC_USDC;

        vm.prank(deployer);
        pRaiser = new PulseRaiser(
            address(0),
            BSC_WRAPPED_NATIVE,
            BSC_NORMALIZATION_TOKEN,
            BSC_UNISWAP_ROUTER,
            raiseWallet,
            uint32(block.timestamp) + LAUNCH_OFFSET,
            POINTS,
            stables,
            assets,
            feeds,
            NormalizationStrategy.PriceFeed
        );
        deploymentTime = uint32(block.timestamp);
        vm.label(address(pRaiser), "BSCRaiser");

        // vm.prank(deployer);
        // gt.setPulseRaiser(address(pRaiser));
    }

    function test_sanity() public {
        assertEq(address(pRaiser.sequencerUptimeFeed()), address(0));
    }
}
