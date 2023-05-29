// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface IGenerationToken {
    function distributionSupply() external view returns (uint256);

    function distribute(address account, uint256 amount) external;
}