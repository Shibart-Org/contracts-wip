// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "./IShibartEvents.sol";

interface IShibart is IShibartEvents {
    function distributionSupply() external view returns (uint256);

    function setPulseRaiser(address raiser_) external;

    // function distribute(address account, uint256 amount) external;
}
