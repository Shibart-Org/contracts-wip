// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BUSDMock is ERC20 {
    constructor() ERC20("BUSD Mock", "BUSDm") {}

    function issue(uint256 wad) external {
        _mint(msg.sender, wad);
    }
}
