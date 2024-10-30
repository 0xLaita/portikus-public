// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Libraries
import { ERC20UtilsLib } from "@modules/libraries/ERC20UtilsLib.sol";

// Test
import { ERC20UtilsLib_Test } from "../ERC20UtilsLib.t.sol";

contract ERC20UtilsLib_getBalance is ERC20UtilsLib_Test {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using ERC20UtilsLib for address;

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getBalance_ReturnsCorrectETHBalance() public {
        // Arrange
        address account = address(this);
        uint256 balance = 1 ether;
        vm.deal(account, balance);

        // Prank to account
        vm.startPrank(account);

        // Act
        uint256 returnedBalance = ETH.getBalance();

        // Assert
        assertEq(returnedBalance, balance, "Returned balance should match the actual ETH balance");
    }

    function test_getBalance_ReturnsCorrectERC20Balance() public {
        // Arrange
        address account = address(this);
        uint256 balance = 100;
        vm.startPrank(users.admin.account);
        MTK.transfer(account, balance);

        // Act
        uint256 returnedBalance = address(MTK).getBalance();

        // Assert
        assertEq(returnedBalance, balance, "Returned balance should match the actual ERC20 balance");
    }
}
