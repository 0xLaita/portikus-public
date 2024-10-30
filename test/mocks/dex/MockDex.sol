// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockDex {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function swap(
        address srcToken,
        address destToken,
        uint256 srcAmount,
        uint256 destAmount,
        address to
    )
        external
        payable
    {
        require(srcToken != address(0), "MockDEX: srcToken cannot be zero address");

        // Transfer srcToken from msg.sender to this contract
        IERC20(srcToken).transferFrom(msg.sender, address(this), srcAmount);

        if (destToken == address(0)) {
            // Sending ETH
            require(address(this).balance >= destAmount, "MockDEX: Not enough ETH");
            payable(to).transfer(destAmount);
        } else {
            // Sending ERC20 destToken
            require(IERC20(destToken).balanceOf(address(this)) >= destAmount, "MockDEX: Not enough destToken");
            IERC20(destToken).transfer(to, destAmount);
        }
    }

    receive() external payable { }
}
