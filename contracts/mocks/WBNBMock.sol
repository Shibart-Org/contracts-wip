// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WBNBMock is ERC20 {
    constructor() ERC20("WBNB Mock", "WBNBm") {}

    function issue(uint256 wad) external {
        _mint(msg.sender, wad);
    }
}
