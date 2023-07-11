// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./interfaces/IShibart.sol";

contract Shibart is ERC20, Ownable, IShibart {
    uint256 public supplyCap;
    bool distributionSupplyMinted;

    constructor(
        address premintTo_,
        uint256 supplyCap_
    ) ERC20("Shibart", "$ART") {
        require(supplyCap_ > 0, "Zero Supply Cap");
        supplyCap = supplyCap_;
        address premintSupplyDestination = (premintTo_ == address(0))
            ? msg.sender
            : premintTo_;

        _mint(premintSupplyDestination, supplyCap_ / 2);
    }

    function distributionSupply() external view returns (uint256) {
        return supplyCap / 2;
    }

    function setPulseRaiser(address raiser_) external {
        _checkOwner();
        require(!distributionSupplyMinted, "Supply Already Minted");
        require(raiser_ != address(0), "Zero Raiser Address");
        distributionSupplyMinted = true;
        _mint(raiser_, supplyCap / 2);
        emit PulseRaiserSet(raiser_, supplyCap / 2);
    }
}
