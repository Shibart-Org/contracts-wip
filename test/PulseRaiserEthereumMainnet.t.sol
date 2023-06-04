// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "forge-std/console.sol";

import {PulseRaiser} from "../contracts/PulseRaiser.sol";
import {Shibart} from "../contracts/Shibart.sol";
import {NormalizationStrategy} from "../contracts/defs/NormalizationStrategy.sol";

import {PulseRaiserCommons} from "./PulseRaiserPF.sol";

contract PulseRaiserEthereumMainnetTest is
    PulseRaiserCommons
{
    function setUp() public {
        fork = vm.createFork(vm.envString("ETHEREUM_MAINNET_RPC"), 17200000);
        vm.selectFork(fork);

        deployer = vm.addr(1);
        // not used anymore, wallet is hardcoded
        raiseWallet = vm.addr(2);
        defaultAccount = vm.addr(3);
        vm.label(address(gt), "GenerationToken");
        vm.label(deployer, "Deployer");
        vm.label(raiseWallet, "RaiseWallet");
      

        vm.prank(deployer);
        gt = new Shibart(deployer, SHIBART_FULL_SUPPLY);

        
        address[] memory stables = new address[](2);
        stables[0] = ETHEREUM_NORMALIZATION_TOKEN;
        stables[1] = ETHEREUM_USDC;

        address[] memory assets = new address[](2);
        assets[0] = ETHEREUM_WRAPPED_NATIVE;
        assets[1] = ETHEREUM_WBTC;

        address[] memory feeds = new address[](2);
        feeds = new address[](2);
        feeds[0] = ETH_USD_FEED;
        feeds[1] = BTC_USD_FEED;

        canonicalNormalizationToken = ETHEREUM_NORMALIZATION_TOKEN;
        wrappedNative = ETHEREUM_WRAPPED_NATIVE;
        wrappedBtc = ETHEREUM_WBTC;
        usdcToken = ETHEREUM_USDC;

        vm.prank(deployer);
        pRaiser = new PulseRaiser(
            address(gt),
            ETHEREUM_WRAPPED_NATIVE,
            ETHEREUM_NORMALIZATION_TOKEN,
            ETHEREUM_UNISWAP_ROUTER,
            deployer,
            POINTS,
            stables,
            assets,
            feeds,
            NormalizationStrategy.PriceFeed
        );
        deploymentTime = uint32(block.timestamp);

        vm.expectRevert("Sale Time Not Set");
        pRaiser.contribute{value: 1 ether}(address(0), 0, address(0));

        vm.prank(deployer);
        pRaiser.launch(deploymentTime + LAUNCH_OFFSET);


        vm.label(address(pRaiser), "EthereumRaiser");

        vm.prank(deployer);
        gt.setPulseRaiser(address(pRaiser));

       
    }

    function test_sanity() public {
        assertEq(address(pRaiser.sequencerUptimeFeed()), address(0));
    }
}
