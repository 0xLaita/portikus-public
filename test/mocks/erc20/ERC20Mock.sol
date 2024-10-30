// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Dependencies
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/token/ERC20/extensions/ERC20Permit.sol";

contract ERC20Mock is ERC20, ERC20Permit {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) ERC20Permit(name_) {
        // mint maximum uint256 to the contract creator
        _mint(msg.sender, type(uint256).max);
    }
}
