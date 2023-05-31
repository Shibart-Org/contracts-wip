// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";

import {Shibart} from "../contracts/Shibart.sol";
import {PrescheduledTokenVesting} from "../contracts/PrescheduledTokenVesting.sol";
import {VestingSchedule} from "../contracts/defs/VestingSchedule.sol";
import {ITokenVestingEvents} from "../contracts/interfaces/ITokenVestingEvents.sol";

interface IERC20Events {
    event Transfer(address indexed from, address indexed to, uint256 amount);
}

contract TokenVestingTest is Test, ITokenVestingEvents, IERC20Events {
    uint256 TOTAL_SUPPLY = 2_000_000_000 ether;
    uint256 INITIAL_TOKEN_BALANCE = 400_000_000 ether;
    address defaultAccount = vm.addr(10000000);
    address deployer = vm.addr(1);
    address b_team1 = vm.addr(2);
    address b_team2 = vm.addr(3);
    address b_team3 = vm.addr(4);
    address b_infl1 = vm.addr(5);
    address b_infl2 = vm.addr(6);
    address b_dev1 = vm.addr(7);
    address b_dev2 = vm.addr(8);
    Shibart token;
    PrescheduledTokenVesting vesting;

    function setUp() public {
        vm.startPrank(deployer);
        token = new Shibart(deployer, TOTAL_SUPPLY);
        vesting = new PrescheduledTokenVesting(address(token));
        token.transfer(address(vesting), INITIAL_TOKEN_BALANCE);
    }

    function test_post_deployment_sanity_checks() public {
        assertEq(0, vesting.getVestingSchedulesTotalAmount());
        assertEq(address(token), vesting.getToken());
    }

    //#region mutators
    function test_createVestingSchedule_non_owner_reverts() public {
        address beneficiary = b_team1;
        uint64 start = uint64(block.timestamp) + 10 days;
        uint64 cliff = 0;
        uint64 duration = 30 days;
        uint64 slicePeriodSeconds = 1 days;
        uint256 amount = 100_000 ether;
        bool revocable = false;

        vm.expectRevert("UNAUTHORIZED");
        vm.prank(defaultAccount);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );
    }

    function test_createVestingSchedule_zero_beneficiary_reverts() public {
        address beneficiary = address(0);
        uint64 start = uint64(block.timestamp) + 10 days;
        uint64 cliff = 0;
        uint64 duration = 30 days;
        uint64 slicePeriodSeconds = 1 days;
        uint256 amount = 100_000 ether;
        bool revocable = false;

        vm.expectRevert("Zero Beneficiary Address");
        vm.prank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );
    }

    function test_createVestingSchedule_zero_amount_reverts() public {
        address beneficiary = b_team1;
        uint64 start = uint64(block.timestamp) + 10 days;
        uint64 cliff = 0;
        uint64 duration = 30 days;
        uint64 slicePeriodSeconds = 1 days;
        uint256 amount = 0;
        bool revocable = false;

        vm.expectRevert("Zero Amount");
        vm.prank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );
    }

    function test_createVestingSchedule_amount_exceeds_free_balance_reverts() public {
        uint256 balance = vesting.getWithdrawableAmount();
        uint256 excessiveAmount = balance + 1;

        address beneficiary = b_team1;
        uint64 start = uint64(block.timestamp) + 10 days;
        uint64 cliff = 0;
        uint64 duration = 30 days;
        uint64 slicePeriodSeconds = 1 days;
        uint256 amount = excessiveAmount;
        bool revocable = false;

        vm.expectRevert("Insufficient Token Balance");
        vm.prank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        amount = balance / 2;
        vm.prank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        amount = balance / 2 + 1;
        vm.expectRevert("Insufficient Token Balance");
        vm.prank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );
    }

    function test_createVestingSchedule_zero_duration_reverts() public {
        address beneficiary = b_dev1;
        uint64 start = uint64(block.timestamp) + 10 days;
        uint64 cliff = 0;
        uint64 duration = 0;
        uint64 slicePeriodSeconds = 1 days;
        uint256 amount = 100_000 ether;
        bool revocable = false;

        vm.expectRevert("Zero Duration");
        vm.prank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );
    }

    function test_createVestingSchedule_zero_slice_duration_reverts() public {
        address beneficiary = b_dev1;
        uint64 start = uint64(block.timestamp) + 10 days;
        uint64 cliff = 0;
        uint64 duration = 100 days;
        uint64 slicePeriodSeconds = 0;
        uint256 amount = 100_000 ether;
        bool revocable = false;

        vm.expectRevert("Zero Slice Period");
        vm.prank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );
    }

    function test_createVestingSchedule_cliff_exceeds_duration_reverts() public {
        address beneficiary = b_dev1;
        uint64 start = uint64(block.timestamp) + 10 days;
        uint64 cliff = 100 days + 1;
        uint64 duration = 100 days;
        uint64 slicePeriodSeconds = 1 days;
        uint256 amount = 100_000 ether;
        bool revocable = false;

        vm.expectRevert("Cliff Exceeds Duration");
        vm.prank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );
    }

    function test_createVestingSchedule_basic_executes() public {
        address beneficiary = b_dev1;
        uint64 start = uint64(block.timestamp) + 10 days;
        uint64 cliff = 5 days;
        uint64 duration = 100 days;
        uint64 slicePeriodSeconds = 1 days;
        uint256 amount = 100_000 ether;
        bool revocable = false;

        bytes32 id = vesting.computeVestingScheduleIdForAddressAndIndex(beneficiary, 0);
        vm.expectEmit(true, true, true, true, address(vesting));
        emit ITokenVestingEvents.VestingScheduleCreated(id, beneficiary, amount);

        vm.prank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        VestingSchedule memory vs = vesting.getVestingSchedule(id);

        assertEq(vs.cliff, start + cliff);
        assertEq(vs.start, start);
        assertEq(vs.duration, duration);
        assertEq(vs.slicePeriodSeconds, slicePeriodSeconds);
        assertEq(vs.amountTotal, amount);
        assertEq(vs.released, 0);
        assertEq(vs.beneficiary, beneficiary);
        assertEq(vs.initialized, true);
        assertEq(vs.revoked, false);
        assertEq(vs.revocable, revocable);

        assertEq(amount, vesting.getVestingSchedulesTotalAmount());
        assertEq(vesting.getVestingIdAtIndex(0), id);
        assertEq(vesting.getVestingSchedulesCountByBeneficiary(beneficiary), 1);

        assertEq(vs.released, 0);
    }

    function test_createVestingSchedule_multiple_executes() public {
        address beneficiary = b_team1;
        uint64 start = uint64(block.timestamp) + 10 days;
        uint64 cliff = 5 days;
        uint64 duration = 100 days;
        uint64 slicePeriodSeconds = 1 days;
        uint256 amount = 100_000 ether;
        bool revocable = false;

        vm.startPrank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        beneficiary = b_team2;
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        beneficiary = b_team3;
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );
        vm.stopPrank();

        assertEq(amount * 3, vesting.getVestingSchedulesTotalAmount());
        assertEq(vesting.getVestingSchedulesCountByBeneficiary(b_team1), 1);
        assertEq(vesting.getVestingSchedulesCountByBeneficiary(b_team2), 1);
        assertEq(vesting.getVestingSchedulesCountByBeneficiary(b_team3), 1);

        vm.prank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        assertEq(amount * 4, vesting.getVestingSchedulesTotalAmount());
        assertEq(4, vesting.getVestingSchedulesCount());
        assertEq(vesting.getVestingSchedulesCountByBeneficiary(b_team1), 1);
        assertEq(vesting.getVestingSchedulesCountByBeneficiary(b_team2), 1);
        assertEq(vesting.getVestingSchedulesCountByBeneficiary(b_team3), 2);
    }

    function test_vesting_operation() public {
        address beneficiary = b_infl1;
        uint64 start = uint64(block.timestamp) + 100;
        uint64 cliff = 0;
        uint64 duration = 1000;
        uint64 slicePeriodSeconds = 1;
        uint256 amount = 100;
        bool revocable = true;

        vm.prank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        // the global count and the per-beneficiary count of schedules is 1
        assertEq(1, vesting.getVestingSchedulesCount());
        assertEq(vesting.getVestingSchedulesCountByBeneficiary(beneficiary), 1);

        // compute the vesting schedule id
        bytes32 id = vesting.computeVestingScheduleIdForAddressAndIndex(beneficiary, 0);

        // nothing to release initially
        assertEq(vesting.computeReleasableAmount(id), 0);

        // set time to half the vesting period
        uint256 jumpTimeTo = start + duration / 2;
        vm.warp(jumpTimeTo);

        // vested amount is half the total amount to vest
        assertEq(vesting.computeReleasableAmount(id), amount / 2);

        // check that only beneficiary can try to release vested tokens
        vm.expectRevert("Not Beneficiary or Releasor");
        vm.prank(defaultAccount);
        vesting.release(id, 100);

        // neither the beneficiary nor the owner can release more than the amount vested
        vm.expectRevert("Insufficient Vested Balance");
        vm.prank(deployer);
        vesting.release(id, 100);

        vm.expectRevert("Insufficient Vested Balance");
        vm.prank(beneficiary);
        vesting.release(id, 100);

        // release 10 tokens and check the Transfer event
        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(address(vesting), beneficiary, 10);

        vm.prank(beneficiary);
        vesting.release(id, 10);

        assertEq(vesting.computeReleasableAmount(id), 40);

        VestingSchedule memory vs = vesting.getVestingSchedule(id);

        // check that the released amount is 10
        assertEq(vs.released, 10);

        // after the vesting period
        uint256 jumpToPostVestingPeriod = start + duration + 1;
        vm.warp(jumpToPostVestingPeriod);

        assertEq(vesting.computeReleasableAmount(id), 90);

        // beneficiary release 45
        vm.prank(beneficiary);
        vesting.release(id, 45);

        // owner release 45
        vm.prank(deployer);
        vesting.release(id, 45);

        // check that the number of released tokens is 100
        VestingSchedule memory vsp = vesting.getVestingSchedule(id);
        assertEq(vsp.released, amount);
        assertEq(token.balanceOf(beneficiary), 100);

        // check that the vested amount is 0
        assertEq(vesting.computeReleasableAmount(id), 0);
    }

    function test_revoke_non_owner_reverts() public {
        bytes32 id = vesting.computeVestingScheduleIdForAddressAndIndex(deployer, 0);
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(defaultAccount);
        vesting.revoke(id);
    }

    function test_revoke_already_revoked_reverts() public {
        address beneficiary = b_infl1;
        uint64 start = uint64(block.timestamp) + 100;
        uint64 cliff = 0;
        uint64 duration = 1000;
        uint64 slicePeriodSeconds = 1;
        uint256 amount = 100;
        bool revocable = true;

        vm.startPrank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        bytes32 id = vesting.computeVestingScheduleIdForAddressAndIndex(beneficiary, 0);

        vesting.revoke(id);

        vm.expectRevert("Vesting Schedule Revoked");
        vesting.revoke(id);
        vm.stopPrank();
    }

    function test_revoke_nonexistent_reverts() public {
        bytes32 id = vesting.computeVestingScheduleIdForAddressAndIndex(deployer, 0);

        vm.expectRevert("Vesting Schedule Not Found");
        vm.prank(deployer);
        vesting.revoke(id);
    }

    function test_revoke_nonrevocable_reverts() public {
        address beneficiary = b_infl1;
        uint64 start = uint64(block.timestamp) + 100;
        uint64 cliff = 0;
        uint64 duration = 1000;
        uint64 slicePeriodSeconds = 1;
        uint256 amount = 100;
        bool revocable = false;

        vm.startPrank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        bytes32 id = vesting.computeVestingScheduleIdForAddressAndIndex(beneficiary, 0);

        vm.expectRevert("Vesting Schedule Not Revocable");
        vesting.revoke(id);
        vm.stopPrank();
    }

    function test_revoke_executes() public {
        address beneficiary = b_infl1;
        uint64 start = uint64(block.timestamp) + 100;
        uint64 cliff = 0;
        uint64 duration = 1000;
        uint64 slicePeriodSeconds = 1;
        uint256 amount = 100_000_000 ether;
        uint256 releaseAmount = amount / 4;
        bool revocable = true;

        vm.startPrank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        vm.stopPrank();

        // jump to half time and release half of the vested tokens
        uint256 jumpTimeTo = start + duration / 2;
        vm.warp(jumpTimeTo);
        bytes32 id = vesting.computeVestingScheduleIdForAddressAndIndex(beneficiary, 0);

        vm.prank(beneficiary);
        vesting.release(id, releaseAmount);

        // now revoke the schedule

        vm.expectEmit(true, true, false, false, address(vesting));
        emit VestingScheduleCancelled(id);
        vm.prank(deployer);
        vesting.revoke(id);

        VestingSchedule memory vs = vesting.getVestingSchedule(id);
        assertEq(vs.revoked, true);
        assertEq(vesting.getVestingSchedulesTotalAmount(), 0);
        assertEq(token.balanceOf(address(vesting)), 375_000_000 ether);
        assertEq(vesting.getWithdrawableAmount(), 375_000_000 ether);
    }

    function test_extend_non_owner_reverts() public {
        bytes32 id = vesting.computeVestingScheduleIdForAddressAndIndex(deployer, 0);
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(defaultAccount);
        vesting.extend(id, 1);
    }

    function test_extend_already_revoked_reverts() public {
        address beneficiary = b_infl1;
        uint64 start = uint64(block.timestamp) + 100;
        uint64 cliff = 0;
        uint64 duration = 1000;
        uint64 slicePeriodSeconds = 1;
        uint256 amount = 100;
        bool revocable = true;

        vm.startPrank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        bytes32 id = vesting.computeVestingScheduleIdForAddressAndIndex(beneficiary, 0);

        vesting.revoke(id);

        vm.expectRevert("Vesting Schedule Revoked");
        vesting.extend(id, 1);
        vm.stopPrank();
    }

    function test_extend_non_revocable_reverts() public {
        address beneficiary = b_infl1;
        uint64 start = uint64(block.timestamp) + 100;
        uint64 cliff = 0;
        uint64 duration = 1000;
        uint64 slicePeriodSeconds = 1;
        uint256 amount = 100;
        bool revocable = false;

        vm.startPrank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        bytes32 id = vesting.computeVestingScheduleIdForAddressAndIndex(beneficiary, 0);

        vm.expectRevert("Vesting Schedule Not Revocable");
        vesting.extend(id, 1);
        vm.stopPrank();
    }

    function test_extend_expired_reverts() public {
        address beneficiary = b_infl1;
        uint64 start = uint64(block.timestamp) + 100;
        uint64 cliff = 0;
        uint64 duration = 1000;
        uint64 slicePeriodSeconds = 1;
        uint256 amount = 100;
        bool revocable = false;

        vm.startPrank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        bytes32 id = vesting.computeVestingScheduleIdForAddressAndIndex(beneficiary, 0);

        vm.expectRevert("Vesting Schedule Not Revocable");
        vesting.extend(id, 1);
        vm.stopPrank();
    }

    function test_extend_nonexistent_reverts() public {
        bytes32 id = vesting.computeVestingScheduleIdForAddressAndIndex(defaultAccount, 0);

        vm.expectRevert("Vesting Schedule Not Found");
        vm.prank(deployer);
        vesting.extend(id, 1);
    }

    function test_extend_zero_extension_reverts() public {
        address beneficiary = b_infl1;
        uint64 start = uint64(block.timestamp) + 100;
        uint64 cliff = 0;
        uint64 duration = 1000;
        uint64 slicePeriodSeconds = 1;
        uint256 amount = 100;
        bool revocable = true;

        vm.startPrank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        bytes32 id = vesting.computeVestingScheduleIdForAddressAndIndex(beneficiary, 0);

        vm.expectRevert("Zero Duration");
        vesting.extend(id, 0);
        vm.stopPrank();
    }

    function test_extend_executes() public {
        address beneficiary = b_infl1;
        uint64 start = uint64(block.timestamp) + 100;
        uint64 cliff = 0;
        uint64 duration = 1000;
        uint64 slicePeriodSeconds = 1;
        uint256 amount = 100;
        bool revocable = true;

        vm.startPrank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        bytes32 id = vesting.computeVestingScheduleIdForAddressAndIndex(beneficiary, 0);
        uint256 jumpTimeTo = start + duration / 2;
        vm.warp(jumpTimeTo);

        assertEq(vesting.computeReleasableAmount(id), 50);

        vm.expectEmit(true, true, true, false, address(vesting));
        emit VestingScheduleExtended(id, uint32(duration));
        vesting.extend(id, uint32(duration));

        // it's now half what it used to be, that is 25% instead of 50%
        // because of the longer schedule
        assertEq(vesting.computeReleasableAmount(id), 25);

        vm.stopPrank();

        VestingSchedule memory vs = vesting.getVestingSchedule(id);
        assertEq(vs.duration, 2000);
    }

    function test_withdraw_non_owner_reverts() public {
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(defaultAccount);
        vesting.withdraw(1);
    }

    function test_withdraw_amount_too_high_reverts() public {
        uint256 excessiveAmount = 1 + token.balanceOf(address(vesting));
        vm.expectRevert("Insufficient Token Balance");
        vm.prank(deployer);
        vesting.withdraw(excessiveAmount);

        address beneficiary = b_infl2;
        uint64 start = uint64(block.timestamp) + 100;
        uint64 cliff = 0;
        uint64 duration = 1000;
        uint64 slicePeriodSeconds = 1;
        uint256 amount = 100_000_000 ether;
        bool revocable = true;

        vm.prank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        vm.expectRevert("Insufficient Token Balance");
        vm.prank(deployer);
        vesting.withdraw(excessiveAmount - amount);

        beneficiary = b_infl1;
        amount = amount / 2;

        vm.prank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        vm.expectRevert("Insufficient Token Balance");
        vm.prank(deployer);
        vesting.withdraw(excessiveAmount - amount * 3);

        assertEq(vesting.getWithdrawableAmount(), token.balanceOf(address(vesting)) - amount * 3);
    }

    function test_withdraw_executes() public {
        uint256 WITHDRAW_AMOUNT = 10;
        vm.expectEmit(true, true, false, false, address(vesting));
        emit AmountWithdrawn(WITHDRAW_AMOUNT);
        vm.prank(deployer);
        vesting.withdraw(WITHDRAW_AMOUNT);

        assertEq(token.balanceOf(address(vesting)), INITIAL_TOKEN_BALANCE - WITHDRAW_AMOUNT);
        assertEq(token.balanceOf(deployer), (TOTAL_SUPPLY / 2) - INITIAL_TOKEN_BALANCE + WITHDRAW_AMOUNT);
    }

    function test_release_revoked_reverts() public {
        address beneficiary = b_infl1;
        uint64 start = uint64(block.timestamp) + 100;
        uint64 cliff = 0;
        uint64 duration = 1000;
        uint64 slicePeriodSeconds = 1;
        uint256 amount = 100;
        bool revocable = true;

        vm.startPrank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        beneficiary = b_infl2;
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        vm.stopPrank();

        bytes32 id1 = vesting.computeVestingScheduleIdForAddressAndIndex(b_infl1, 0);
        bytes32 id2 = vesting.computeVestingScheduleIdForAddressAndIndex(b_infl2, 0);

        uint256 jumpTimeTo = start + duration / 2;
        vm.warp(jumpTimeTo);

        vm.prank(b_infl2);
        vesting.release(id2, 25);

        vm.startPrank(deployer);
        vesting.revoke(id1);
        vesting.revoke(id2);
        vm.stopPrank();

        vm.expectRevert("Vesting Schedule Revoked");
        vm.prank(b_infl1);
        vesting.release(id1, 25);

        vm.expectRevert("Vesting Schedule Revoked");
        vm.prank(b_infl2);
        vesting.release(id2, 25);
    }

    function test_release_non_owner_non_beneficiary_reverts() public {
        address beneficiary = b_infl1;
        uint64 start = uint64(block.timestamp) + 100;
        uint64 cliff = 0;
        uint64 duration = 1000;
        uint64 slicePeriodSeconds = 1;
        uint256 amount = 100;
        bool revocable = true;

        vm.startPrank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        beneficiary = b_infl2;
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        vm.stopPrank();

        bytes32 id1 = vesting.computeVestingScheduleIdForAddressAndIndex(b_infl1, 0);
        bytes32 id2 = vesting.computeVestingScheduleIdForAddressAndIndex(b_infl2, 0);

        uint256 jumpTimeTo = start + duration / 2;
        vm.warp(jumpTimeTo);

        vm.expectRevert("Not Beneficiary or Releasor");
        vm.prank(b_infl2);
        vesting.release(id1, 25);

        vm.expectRevert("Not Beneficiary or Releasor");
        vm.prank(b_infl1);
        vesting.release(id2, 25);
    }

    function test_release_insufficient_vested_balance_reverts() public {
        address beneficiary = b_infl1;
        uint64 start = uint64(block.timestamp) + 100;
        uint64 cliff = 0;
        uint64 duration = 1000;
        uint64 slicePeriodSeconds = 1;
        uint256 amount = 100;
        bool revocable = true;

        vm.startPrank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        vm.stopPrank();

        bytes32 id = vesting.computeVestingScheduleIdForAddressAndIndex(beneficiary, 0);

        uint256 jumpTimeTo = start + duration / 2;
        vm.warp(jumpTimeTo);

        uint256 releasable = vesting.computeReleasableAmount(id);

        vm.expectRevert("Insufficient Vested Balance");
        vm.prank(beneficiary);
        vesting.release(id, releasable + 1);
    }

    function test_release_beneficiary_executes() public {
        address beneficiary = b_infl1;
        uint64 start = uint64(block.timestamp) + 100;
        uint64 cliff = 0;
        uint64 duration = 1000;
        uint64 slicePeriodSeconds = 1;
        uint256 amount = 100;
        bool revocable = true;

        vm.startPrank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        vm.stopPrank();

        bytes32 id = vesting.computeVestingScheduleIdForAddressAndIndex(beneficiary, 0);

        uint256 jumpTimeTo = start + duration / 2;
        vm.warp(jumpTimeTo);

        uint256 releasable = vesting.computeReleasableAmount(id);
        uint256 vsTotalAmountPre = vesting.getVestingSchedulesTotalAmount();

        vm.expectEmit(true, true, true, true, address(vesting));
        emit AmountReleased(id, beneficiary, releasable / 2);
        vm.prank(beneficiary);
        vesting.release(id, releasable / 2);

        vm.expectEmit(true, true, true, true, address(vesting));
        emit AmountReleased(id, beneficiary, releasable / 2);
        vm.prank(beneficiary);
        vesting.release(id, releasable / 2);

        assertEq(vesting.computeReleasableAmount(id), 0);
        assertEq(token.balanceOf(beneficiary), releasable);

        VestingSchedule memory vs = vesting.getVestingSchedule(id);

        assertEq(vs.released, releasable);
        assertEq(vesting.getVestingSchedulesTotalAmount(), vsTotalAmountPre - releasable);
    }

    function test_release_owner_executes() public {
        address beneficiary = b_infl1;
        uint64 start = uint64(block.timestamp) + 100;
        uint64 cliff = 0;
        uint64 duration = 1000;
        uint64 slicePeriodSeconds = 1;
        uint256 amount = 100;
        bool revocable = true;

        vm.startPrank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        vm.stopPrank();

        bytes32 id = vesting.computeVestingScheduleIdForAddressAndIndex(beneficiary, 0);

        uint256 jumpTimeTo = start + duration / 2;
        vm.warp(jumpTimeTo);

        uint256 releasable = vesting.computeReleasableAmount(id);
        uint256 vsTotalAmountPre = vesting.getVestingSchedulesTotalAmount();

        vm.expectEmit(true, true, true, true, address(vesting));
        emit AmountReleased(id, beneficiary, releasable / 2);
        vm.prank(deployer);
        vesting.release(id, releasable / 2);

        vm.expectEmit(true, true, true, true, address(vesting));
        emit AmountReleased(id, beneficiary, releasable / 2);
        vm.prank(deployer);
        vesting.release(id, releasable / 2);

        assertEq(vesting.computeReleasableAmount(id), 0);
        assertEq(token.balanceOf(beneficiary), releasable);

        VestingSchedule memory vs = vesting.getVestingSchedule(id);

        assertEq(vs.released, releasable);
        assertEq(vesting.getVestingSchedulesTotalAmount(), vsTotalAmountPre - releasable);
    }

    //#endregion

    //#region views
    function createArbitrarySchedulesFor(address account, uint8 n) internal {
        address beneficiary = account;
        uint64 start = uint64(block.timestamp) + 100;
        uint64 cliff = 0;
        uint64 duration = 1000;
        uint64 slicePeriodSeconds = 1;
        uint256 amount = 100;
        bool revocable = true;

        vm.startPrank(deployer);
        for (uint8 s = 0; s < n; s++) {
            vesting.createVestingSchedule(
                beneficiary,
                start,
                cliff,
                duration,
                slicePeriodSeconds,
                amount,
                revocable
            );
        }
        vm.stopPrank();
    }

    function test_getVestingSchedulesCountByBeneficiary_executes() public {
        assertEq(vesting.getVestingSchedulesCountByBeneficiary(b_team1), 0);
        assertEq(vesting.getVestingSchedulesCountByBeneficiary(b_team2), 0);
        assertEq(vesting.getVestingSchedulesCountByBeneficiary(deployer), 0);

        createArbitrarySchedulesFor(b_team1, 3);
        createArbitrarySchedulesFor(b_team2, 2);

        assertEq(vesting.getVestingSchedulesCountByBeneficiary(b_team1), 3);
        assertEq(vesting.getVestingSchedulesCountByBeneficiary(b_team2), 2);
        assertEq(vesting.getVestingSchedulesCountByBeneficiary(deployer), 0);
    }

    function test_getVestingIdAtIndex_executes() public {
        createArbitrarySchedulesFor(b_team1, 3);
        createArbitrarySchedulesFor(b_team2, 2);

        bytes32 id0 = vesting.computeVestingScheduleIdForAddressAndIndex(b_team1, 0);
        bytes32 id1 = vesting.computeVestingScheduleIdForAddressAndIndex(b_team1, 1);
        bytes32 id2 = vesting.computeVestingScheduleIdForAddressAndIndex(b_team1, 2);
        bytes32 id3 = vesting.computeVestingScheduleIdForAddressAndIndex(b_team2, 0);
        bytes32 id4 = vesting.computeVestingScheduleIdForAddressAndIndex(b_team2, 1);

        assertEq(vesting.getVestingIdAtIndex(0), id0);
        assertEq(vesting.getVestingIdAtIndex(1), id1);
        assertEq(vesting.getVestingIdAtIndex(2), id2);
        assertEq(vesting.getVestingIdAtIndex(3), id3);
        assertEq(vesting.getVestingIdAtIndex(4), id4);
    }

    function test_getVestingScheduleByAddressAndIndex_executes() public {
        createArbitrarySchedulesFor(b_team1, 3);
        createArbitrarySchedulesFor(b_team2, 2);
        // address beneficiary = account;
        // uint256 start = block.timestamp + 100;
        // uint256 cliff = 0;
        // uint256 duration = 1000;
        // uint256 slicePeriodSeconds = 1;
        // uint256 amount = 100;
        // bool revocable = true;

        bytes32 id = vesting.computeVestingScheduleIdForAddressAndIndex(b_team1, 1);

        vm.prank(deployer);
        vesting.extend(id, 10000);

        VestingSchedule memory vs = vesting.getVestingScheduleByAddressAndIndex(b_team1, 1);

        assertEq(vs.duration, 11000);

        // test getVestingIdAtIndex as well, doh
        VestingSchedule memory vs1 = vesting.getVestingSchedule(vesting.getVestingIdAtIndex(1));
        assertEq(vs1.duration, 11000);

        vm.expectRevert("Index Out of Bounds");
        vesting.getVestingIdAtIndex(5);
    }

    function test_getVestingSchedulesTotalAmount_executes() public {
        createArbitrarySchedulesFor(b_team1, 3);
        createArbitrarySchedulesFor(b_team2, 2);

        assertEq(vesting.getVestingSchedulesTotalAmount(), 500);
    }

    function test_getToken_executes() public {
        assertEq(address(token), vesting.getToken());
    }

    function test_getVestingSchedulesCount_executes() public {
        createArbitrarySchedulesFor(b_team1, 3);
        createArbitrarySchedulesFor(b_team2, 4);
        assertEq(vesting.getVestingSchedulesCount(), 7);
    }

    function test_computeReleasableAmount_cliff_executes() public {
        address beneficiary = b_infl1;
        uint64 start = uint64(block.timestamp) + 100;
        uint64 cliff = 100;
        uint64 duration = 1000;
        uint64 slicePeriodSeconds = 1;
        uint256 amount = 1000;
        bool revocable = true;

        vm.startPrank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        vm.stopPrank();

        bytes32 id = vesting.computeVestingScheduleIdForAddressAndIndex(beneficiary, 0);

        uint256 jumpTimeTo = start + cliff / 2;
        vm.warp(jumpTimeTo);

        assertEq(vesting.computeReleasableAmount(id), 0);

        jumpTimeTo = start + duration / 2;
        vm.warp(jumpTimeTo);

        assertEq(vesting.computeReleasableAmount(id), amount / 2);

        jumpTimeTo = start + duration;
        vm.warp(jumpTimeTo);

        assertEq(vesting.computeReleasableAmount(id), amount);
    }

    function test_computeReleasableAmount_executes() public {
        address beneficiary = b_infl1;
        uint64 start = uint64(block.timestamp) + 100;
        uint64 cliff = 0;
        uint64 duration = 1000;
        uint64 slicePeriodSeconds = 1;
        uint256 amount = 100;
        bool revocable = true;

        vm.startPrank(deployer);
        vesting.createVestingSchedule(
            beneficiary,
            start,
            cliff,
            duration,
            slicePeriodSeconds,
            amount,
            revocable
        );

        vm.stopPrank();

        bytes32 id = vesting.computeVestingScheduleIdForAddressAndIndex(beneficiary, 0);

        uint256 jumpTimeTo = start + duration / 4;
        vm.warp(jumpTimeTo);

        assertEq(vesting.computeReleasableAmount(id), 25);

        jumpTimeTo = start + duration / 2;
        vm.warp(jumpTimeTo);

        assertEq(vesting.computeReleasableAmount(id), 50);

        jumpTimeTo = start + duration / 2 + duration / 4;
        vm.warp(jumpTimeTo);

        assertEq(vesting.computeReleasableAmount(id), 75);

        jumpTimeTo = start + duration;
        vm.warp(jumpTimeTo);

        assertEq(vesting.computeReleasableAmount(id), 100);
    }

    function test_getVestingSchedule_executes() public {
        uint64 start1 = uint64(block.timestamp) + 100;
        uint64 cliff1 = 0;
        uint64 duration1 = 1000;
        uint64 slicePeriodSeconds1 = 1;
        uint256 amount1 = 100;
        bool revocable1 = true;

        vm.startPrank(deployer);
        vesting.createVestingSchedule(
            b_infl1,
            start1,
            cliff1,
            duration1,
            slicePeriodSeconds1,
            amount1,
            revocable1
        );
        vesting.createVestingSchedule(
            b_infl2,
            start1 + 19,
            cliff1 + 19,
            duration1 + 29,
            slicePeriodSeconds1 + 1,
            amount1 * 2,
            !revocable1
        );

        vm.stopPrank();

        bytes32 id1 = vesting.computeVestingScheduleIdForAddressAndIndex(b_infl1, 0);
        bytes32 id2 = vesting.computeVestingScheduleIdForAddressAndIndex(b_infl2, 0);

        VestingSchedule memory vs1 = vesting.getVestingSchedule(id1);
        VestingSchedule memory vs2 = vesting.getVestingSchedule(id2);

        assertEq(vs1.beneficiary, b_infl1);
        assertEq(vs1.start, start1);
        assertEq(vs1.cliff, start1 + cliff1);
        assertEq(vs1.duration, duration1);
        assertEq(vs1.slicePeriodSeconds, slicePeriodSeconds1);
        assertEq(vs1.amountTotal, amount1);
        assertEq(vs1.revocable, revocable1);

        assertEq(vs2.beneficiary, b_infl2);
        assertEq(vs2.start, start1 + 19);
        assertEq(vs2.cliff, start1 + cliff1 + 19 + 19);
        assertEq(vs2.duration, duration1 + 29);
        assertEq(vs2.slicePeriodSeconds, slicePeriodSeconds1 + 1);
        assertEq(vs2.amountTotal, amount1 * 2);
        assertEq(vs2.revocable, !revocable1);
    }

    function test_getWithdrawableAmount_executes() public {
        assertEq(vesting.getWithdrawableAmount(), INITIAL_TOKEN_BALANCE);

        uint64 start1 = uint64(block.timestamp) + 100;
        uint64 cliff1 = 0;
        uint64 duration1 = 1000;
        uint64 slicePeriodSeconds1 = 1;
        uint256 amount1 = INITIAL_TOKEN_BALANCE / 2;
        bool revocable1 = true;

        vm.prank(deployer);
        vesting.createVestingSchedule(
            b_infl1,
            start1,
            cliff1,
            duration1,
            slicePeriodSeconds1,
            amount1,
            revocable1
        );
        assertEq(vesting.getWithdrawableAmount(), INITIAL_TOKEN_BALANCE / 2);
    }

    function test_computeNextVestingScheduleIdForHolder_executes() public {
        uint64 start1 = uint64(block.timestamp) + 100;
        uint64 cliff1 = 0;
        uint64 duration1 = 1000;
        uint64 slicePeriodSeconds1 = 1;
        uint256 amount1 = INITIAL_TOKEN_BALANCE / 2;
        bool revocable1 = true;

        vm.prank(deployer);
        vesting.createVestingSchedule(
            b_infl1,
            start1,
            cliff1,
            duration1,
            slicePeriodSeconds1,
            amount1,
            revocable1
        );
        assertEq(
            vesting.computeNextVestingScheduleIdForHolder(b_infl1),
            vesting.computeVestingScheduleIdForAddressAndIndex(b_infl1, 1)
        );

        assertEq(
            vesting.computeNextVestingScheduleIdForHolder(b_infl2),
            vesting.computeVestingScheduleIdForAddressAndIndex(b_infl2, 0)
        );
    }

    function test_getLastVestingScheduleForHolder_executes() public {
        uint64 start1 = uint64(block.timestamp) + 100;
        uint64 cliff1 = 0;
        uint64 duration1 = 1000;
        uint64 slicePeriodSeconds1 = 1;
        uint256 amount1 = 100;
        bool revocable1 = true;

        vm.startPrank(deployer);
        vesting.createVestingSchedule(
            b_infl1,
            start1,
            cliff1,
            duration1,
            slicePeriodSeconds1,
            amount1,
            revocable1
        );
        vesting.createVestingSchedule(
            b_infl1,
            start1 + 19,
            cliff1 + 19,
            duration1 + 29,
            slicePeriodSeconds1 + 1,
            amount1 * 2,
            !revocable1
        );

        vm.stopPrank();

        VestingSchedule memory vs = vesting.getLastVestingScheduleForHolder(b_infl1);

        assertEq(vs.beneficiary, b_infl1);
        assertEq(vs.start, start1 + 19);
        assertEq(vs.cliff, start1 + cliff1 + 19 + 19);
        assertEq(vs.duration, duration1 + 29);
        assertEq(vs.slicePeriodSeconds, slicePeriodSeconds1 + 1);
        assertEq(vs.amountTotal, amount1 * 2);
        assertEq(vs.revocable, !revocable1);
    }

    function test_computeVestingScheduleIdForAddressAndIndex_executes() public {
        // this obviously works as expected
    }
    //#endregion
}
