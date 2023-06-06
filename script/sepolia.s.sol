// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "forge-std/Script.sol";
import "../contracts/PulseRaiser.sol";
import "../contracts/Shibart.sol";
import {PrescheduledTokenVesting} from "../contracts/PrescheduledTokenVesting.sol";
import "../test/utils/Constants.sol";

contract SepoliaSystem is Script, Constants {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TESTNET_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployer_ = 0x1d34251A9FdC743568840B640CE1E7481E0fD370;
        address wallet_ = 0x1d34251A9FdC743568840B640CE1E7481E0fD370;

        Shibart gt = new Shibart(deployer_, Constants.SHIBART_FULL_SUPPLY);

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

        PulseRaiser raiser = new PulseRaiser(
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
     
        raiser.launch(uint32(block.timestamp) + 1 days);
        gt.setPulseRaiser(address(raiser));

        PrescheduledTokenVesting ptv = new PrescheduledTokenVesting(address(gt));

        // done
        vm.stopBroadcast();
    }
}