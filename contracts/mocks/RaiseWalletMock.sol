// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RaiseWalletMock is Ownable {
    function withdrawToken(address token_) external onlyOwner {
        IERC20(token_).transfer(msg.sender, IERC20(token_).balanceOf(address(this)));
    }

    function withdrawNative() external onlyOwner {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");

        require(success);
    }
}