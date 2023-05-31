// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDTMock is ERC20 {
    constructor() ERC20("Tether USD Mock", "USDTm") {}

    function issue(uint256 wad) external {
        _mint(msg.sender, wad);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}
