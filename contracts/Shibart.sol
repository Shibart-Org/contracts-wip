// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./interfaces/IShibart.sol";

contract Shibart is ERC20, Ownable, IShibart {
    address public raiser;
    uint256 public supplyCap;

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
        require(raiser_ != address(0), "Zero Raiser Address");
        require(raiser == address(0), "Already Set");
        raiser = raiser_;
        emit PulseRaiserSet(raiser);
    }

    function distribute(address account, uint256 amount) external {
        _onlyPulseRaiser();
        require(account != address(0), "Zero Account");
        require(amount > 0, "Zero Amount");
        require(totalSupply() + amount <= supplyCap, "Supply Cap Exceeded");
        emit Distributed(account, amount);
        _mint(account, amount);
    }

    function _onlyPulseRaiser() internal view {
        require(msg.sender == raiser, "UNAUTHORIZED");
    }
}
