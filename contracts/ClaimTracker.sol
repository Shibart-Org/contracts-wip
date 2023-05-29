// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

contract ClaimTracker {
    mapping(uint256 => uint256) public claimedBitMap;

    function _attempSetClaimed(uint256 index_) internal returns (bool) {
        uint256 mask = (1 << index_);
        uint256 word = index_ / 256;
        bool isClaimed = claimedBitMap[word] & mask == mask;
        if (isClaimed) return false;
        claimedBitMap[word] = claimedBitMap[word] | mask;
        return true;
    }
}

