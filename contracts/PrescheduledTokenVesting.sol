// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "./TokenVesting.sol";

contract PrescheduledTokenVesting is TokenVesting {
    constructor(address token_) TokenVesting(token_) {
        // TODO: add initial vesting schedules for team etc.
        // Use this snipped as the template:
        // _createVestingSchedule(
        //     VestingScheduleConfig({
        //         beneficiary: <account>,
        //         start: <timestamp>,
        //         cliff: <seconds>,
        //         duration: <seconds>,
        //         slicePeriodSeconds: <seconds>,
        //         amountTotal: <wei>,
        //         revocable: <bool>
        //     })
        // );
    }
}