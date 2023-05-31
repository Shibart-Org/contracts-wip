// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "forge-std/console.sol";

import {PulseRaiser} from "../contracts/PulseRaiser.sol";
import {Shibart} from "../contracts/Shibart.sol";
import {NormalizationStrategy} from "../contracts/defs/NormalizationStrategy.sol";

import {PulseRaiserCommons} from "./PulseRaiserPF.sol";

contract PulseRaiserArbitrumMainnetTest is PulseRaiserCommons {
    address public constant ARBITRUM_UNISWAP_FACTORY =
        0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;

    // v2
    address public constant ARBITRUM_UNISWAP_ROUTER =
        0x10ED43C718714eb63d5aA57B78B54704E256024E;

    address public constant ARBITRUM_WRAPPED_NATIVE =
        0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    address public constant ARBITRUM_NORMALIZATION_TOKEN =
        0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    // "W" ETH
    address public constant ARBITRUM_WETH =
        0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    // WBTC
    address public constant ARBITRUM_WBTC =
        0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;

    // USDC Token
    address public constant ARBITRUM_USDC =
        0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;

    // WETH/ETH->USD Price Feed
    address public constant ARB_ETH_USD_FEED =
        0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;
    // BTC->USD
    address public constant ARB_BTC_USD_FEED =
        0x6ce185860a4963106506C203335A2910413708e9;

    function setUp() public {
        fork = vm.createFork(vm.envString("ARBITRUM_MAINNET_RPC"), 96400000);
        vm.selectFork(fork);

        deployer = vm.addr(1);
        raiseWallet = vm.addr(2);
        defaultAccount = vm.addr(3);
        vm.label(address(gt), "GenerationToken");
        vm.label(deployer, "Deployer");
        vm.label(raiseWallet, "RaiseWallet");

        address[] memory stables = new address[](2);
        stables[0] = ARBITRUM_NORMALIZATION_TOKEN;
        stables[1] = ARBITRUM_USDC;

        address[] memory assets = new address[](2);
        assets[0] = ARBITRUM_WRAPPED_NATIVE;
        assets[1] = ARBITRUM_WBTC;

        address[] memory feeds = new address[](2);
        feeds = new address[](2);
        feeds[0] = ARB_ETH_USD_FEED;
        feeds[1] = ARB_BTC_USD_FEED;

        canonicalNormalizationToken = ARBITRUM_NORMALIZATION_TOKEN;
        wrappedNative = ARBITRUM_WRAPPED_NATIVE;
        wrappedBtc = ARBITRUM_WBTC;
        usdcToken = ARBITRUM_USDC;

        vm.prank(deployer);
        pRaiser = new PulseRaiser(
            address(0),
            ARBITRUM_WRAPPED_NATIVE,
            ARBITRUM_NORMALIZATION_TOKEN,
            ARBITRUM_UNISWAP_ROUTER,
            raiseWallet,
            uint32(block.timestamp) + LAUNCH_OFFSET,
            POINTS,
            stables,
            assets,
            feeds,
            NormalizationStrategy.PriceFeed
        );
        deploymentTime = uint32(block.timestamp);
        vm.label(address(pRaiser), "ArbitrumRaiser");
    }

    function test_sanity() public {
        assertEq(
            address(pRaiser.sequencerUptimeFeed()),
            pRaiser.ARB_MAINNET_SEQ_FEED()
        );
    }
}
