// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface IShibartEvents {
    event PulseRaiserSet(address indexed raiser);
    event Distributed(address indexed account, uint256 indexed amount);
}
