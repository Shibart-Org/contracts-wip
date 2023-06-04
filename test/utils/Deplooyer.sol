// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";

import {PulseRaiser} from "../../contracts/PulseRaiser.sol";
import {PrescheduledTokenVesting} from "../../contracts/PrescheduledTokenVesting.sol";
import {Shibart} from "../../contracts/Shibart.sol";
import {Constants} from "./Constants.sol";
import {NormalizationStrategy} from "../../contracts/defs/NormalizationStrategy.sol";

contract Deplooyer is Test, Constants {
    function deployArbitrumMainnet(
        address deployer_,
        address wallet_
    ) public returns (uint32 deploymentTime, PulseRaiser raiser) {
        address[] memory stables = new address[](2);
        stables[0] = Constants.ARB_MAINNET_USDT;
        stables[1] = Constants.ARB_MAINNET_USDC;

        address[] memory assets = new address[](2);
        assets[0] = Constants.ARB_MAINNET_WETH;
        assets[1] = Constants.ARB_MAINNET_WBTC;

        address[] memory feeds = new address[](2);
        feeds = new address[](2);
        feeds[0] = Constants.ARB_MAINNET_FEED_ETH_USD;
        feeds[1] = Constants.ARB_MAINNET_FEED_BTC_USD;

        vm.prank(deployer_);
        raiser = new PulseRaiser(
            address(0),
            Constants.ARB_MAINNET_WETH,
            Constants.ARB_MAINNET_USDT,
            address(0),
            wallet_,
            Constants.POINTS,
            stables,
            assets,
            feeds,
            NormalizationStrategy.PriceFeed
        );

        deploymentTime = uint32(block.timestamp);

        vm.expectRevert("Sale Time Not Set");
        raiser.contribute{value: 1 ether}(address(0), 0, address(0));

        vm.prank(deployer_);
        raiser.launch(deploymentTime + 1 days);

        vm.label(address(raiser), "ArbMainnetRaiser");
    }

    function deployBSCMainnet(
        address deployer_,
        address wallet_
    ) public returns (uint32 deploymentTime, PulseRaiser raiser) {
        address[] memory stables = new address[](3);
        stables[0] = Constants.BSC_MAINNET_BUSD;
        stables[1] = Constants.BSC_MAINNET_USDT;
        stables[2] = Constants.BSC_MAINNET_USDC;

        address[] memory assets = new address[](2);
        assets[0] = Constants.BSC_MAINNET_WBNB;
        assets[1] = Constants.BSC_MAINNET_BTCB;

        address[] memory feeds = new address[](2);
        feeds = new address[](2);
        feeds[0] = Constants.BSC_MAINNET_FEED_BNB_USD;
        feeds[1] = Constants.BSC_MAINNET_FEED_BTC_USD;

        vm.prank(deployer_);
        raiser = new PulseRaiser(
            address(0),
            Constants.BSC_MAINNET_WBNB,
            Constants.BSC_MAINNET_USDT,
            address(0),
            wallet_,
            Constants.POINTS,
            stables,
            assets,
            feeds,
            NormalizationStrategy.PriceFeed
        );

        deploymentTime = uint32(block.timestamp);

        vm.expectRevert("Sale Time Not Set");
        raiser.contribute{value: 1 ether}(address(0), 0, address(0));

        vm.prank(deployer_);
        raiser.launch(deploymentTime + 1 days);

        vm.label(address(raiser), "BSCMainnetRaiser");
    }

    function deployEthereumMainnet(
        address deployer_,
        address wallet_
    )
        public
        returns (
            uint32 deploymentTime,
            PulseRaiser raiser,
            PrescheduledTokenVesting ptv,
            Shibart gt
        )
    {
        vm.prank(deployer_);
        gt = new Shibart(deployer_, Constants.SHIBART_FULL_SUPPLY);

        address[] memory stables = new address[](2);
        stables[0] = Constants.ETH_MAINNET_USDT;
        stables[1] = Constants.ETH_MAINNET_USDC;

        address[] memory assets = new address[](2);
        assets[0] = Constants.ETH_MAINNET_WETH;
        assets[1] = Constants.ETH_MAINNET_WBTC;

        address[] memory feeds = new address[](2);
        feeds = new address[](2);
        feeds[0] = Constants.ETH_MAINNET_FEED_ETH_USD;
        feeds[1] = Constants.ETH_MAINNET_FEED_BTC_USD;

        vm.prank(deployer_);
        raiser = new PulseRaiser(
            address(gt),
            Constants.ETH_MAINNET_WETH,
            Constants.ETH_MAINNET_USDT,
            address(0),
            wallet_,
            Constants.POINTS,
            stables,
            assets,
            feeds,
            NormalizationStrategy.PriceFeed
        );

        deploymentTime = uint32(block.timestamp);

        vm.expectRevert("Sale Time Not Set");
        raiser.contribute{value: 1 ether}(address(0), 0, address(0));

        vm.prank(deployer_);
        raiser.launch(deploymentTime + 1 days);

        vm.prank(deployer_);
        gt.setPulseRaiser(address(raiser));

        ptv = new PrescheduledTokenVesting(address(gt));

        vm.label(address(raiser), "EthereumMainnetRaiser");
        vm.label(address(ptv), "EthereumTokenVesting");
        vm.label(address(gt), "EthereumShibart");
    }
}
