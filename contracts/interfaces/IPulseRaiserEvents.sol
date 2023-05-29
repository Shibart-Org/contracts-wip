// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface IPulseRaiserEvents {
    event PriceBaseModified(uint8 indexed day, uint16 indexed base);
    event PriceBasesBatchModified();
    event PointsGained(address indexed account, uint256 indexed pointAmount);
    event TotalPointsAllocated(
        uint256 indexed pointsTotal,
        uint256 indexed tokenPerPoint
    );

    event ClaimsEnabled();
}
