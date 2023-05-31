// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "forge-std/console.sol";

import {Shibart} from "../contracts/Shibart.sol";
import {IShibartEvents} from "../contracts/interfaces/IShibartEvents.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IERC20Events {
    event Transfer(address indexed from, address indexed to, uint256 amount);
}

interface IERC20USDT {
    function approve(address spender, uint256 amount) external;
}

contract ShibartTest is Test, IShibartEvents, IERC20Events {
    using SafeERC20 for IERC20;
    uint256 ethereumMainnetFork;

    string ETHEREUM_MAINNET_RPC = vm.envString("ETHEREUM_MAINNET_RPC");

    address deployer = vm.addr(1);
    address raiseWallet = vm.addr(2);
    address defaultAccount = vm.addr(3);

    uint256 private constant SHIBART_FULL_SUPPLY = 1_000_000_000 ether;

    Shibart gt;

    function setUp() public {
        vm.label(address(gt), "GenerationToken");
        vm.label(deployer, "Deployer");

        ethereumMainnetFork = vm.createFork(ETHEREUM_MAINNET_RPC, 17200000);
        vm.selectFork(ethereumMainnetFork);

        vm.prank(deployer);
        gt = new Shibart(deployer, SHIBART_FULL_SUPPLY);
    }

    function test_sanity_checks() public {
        assertEq(gt.supplyCap(), SHIBART_FULL_SUPPLY);
        assertEq(gt.distributionSupply(), SHIBART_FULL_SUPPLY / 2);
        assertEq(gt.owner(), deployer);
        assertEq(gt.balanceOf(deployer), SHIBART_FULL_SUPPLY / 2);
        assertEq(gt.raiser(), address(0));
        assertEq(gt.totalSupply(), SHIBART_FULL_SUPPLY / 2);
    }

    function test_setPulseRaiser_non_owner_reverts() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(defaultAccount);
        gt.setPulseRaiser(address(0));
    }

    function test_setPulseRaiser_zero_address_reverts() public {
        vm.expectRevert("Zero Raiser Address");
        vm.prank(deployer);
        gt.setPulseRaiser(address(0));
    }

    function test_setPulseRaiser_reentry_reverts() public {
        vm.prank(deployer);
        gt.setPulseRaiser(address(this));

        vm.expectRevert("Already Set");
        vm.prank(deployer);
        gt.setPulseRaiser(address(this));
    }

    function test_setPulseRaiser_executes() public {
        vm.expectEmit(true, true, false, false, address(gt));
        emit PulseRaiserSet(address(this));
        vm.prank(deployer);
        gt.setPulseRaiser(address(this));
        assertEq(gt.raiser(), address(this));
    }

    function test_distribute_zero_address_reverts() public {
        vm.prank(deployer);
        gt.setPulseRaiser(deployer);

        vm.expectRevert("Zero Account");
        vm.prank(deployer);
        gt.distribute(address(0), 1);
    }

    function test_distribute_zero_amount_reverts() public {
        vm.prank(deployer);
        gt.setPulseRaiser(deployer);

        vm.expectRevert("Zero Amount");
        vm.prank(deployer);
        gt.distribute(deployer, 0);
    }

    function test_distribute_non_pulseraiser_reverts() public {
        vm.prank(deployer);
        gt.setPulseRaiser(deployer);

        vm.expectRevert("UNAUTHORIZED");
        vm.prank(defaultAccount);
        gt.distribute(deployer, 100);
    }

    function test_distribute_supply_cap_exceeded_reverts() public {
        vm.prank(deployer);
        gt.setPulseRaiser(deployer);

        vm.expectRevert("Supply Cap Exceeded");
        vm.prank(deployer);
        gt.distribute(deployer, SHIBART_FULL_SUPPLY / 2 + 1);
    }

    function test_distribute_executes() public {
        vm.prank(deployer);
        gt.setPulseRaiser(deployer);

        vm.expectEmit(true, true, true, false, address(gt));
        emit Distributed(defaultAccount, SHIBART_FULL_SUPPLY / 2);
        vm.expectEmit(true, true, true, true, address(gt));
        emit Transfer(address(0), defaultAccount, SHIBART_FULL_SUPPLY / 2);

        vm.prank(deployer);
        gt.distribute(defaultAccount, SHIBART_FULL_SUPPLY / 2);

        assertEq(gt.totalSupply(), SHIBART_FULL_SUPPLY);
        assertEq(gt.balanceOf(defaultAccount), SHIBART_FULL_SUPPLY / 2);
    }
}
