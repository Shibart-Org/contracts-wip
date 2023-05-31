// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WBTCMock is ERC20 {
    constructor() ERC20("Wrapped BTC Mock", "WBTCm") {}

    function issue(uint256 wad) external {
        _mint(msg.sender, wad);
    }

    function decimals() public view virtual override returns (uint8) {
        return 8;
    }
}
