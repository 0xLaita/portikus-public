// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Libraries
import { ERC20UtilsLib } from "@modules/libraries/ERC20UtilsLib.sol";

// Test
import { ERC20UtilsLib_Test } from "../ERC20UtilsLib.t.sol";

contract ERC20UtilsLib_transferTo is ERC20UtilsLib_Test {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Error when transfer fails
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using ERC20UtilsLib for address;

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_transferTo_RevertsWhen_InsufficientBalance() public {
        // Arrange
        uint256 transferAmount = 100 ether;

        // Bob has no tokens initially
        vm.startPrank(users.bob.account);

        // Expect the transfer to revert due to insufficient balance
        vm.expectRevert(TransferFailed.selector);

        // Act
        (this).callTransferTo(address(MTK), users.charlie.account, transferAmount);
    }

    function test_transferTo_ERC20() public {
        // Arrange
        // Prank to admin and transfer tokens to address(this)
        vm.startPrank(users.admin.account);
        MTK.transfer(address(this), 1000);

        // Act
        // Check balance of Charlie before transfer
        uint256 balanceBeforeCharlie = MTK.balanceOf(users.charlie.account);

        // Transfer tokens from Alice to Charlie
        (this).callTransferTo(address(MTK), users.charlie.account, 100);

        // Assert
        // Check balance of Charlie after transfer
        uint256 balanceAfterCharlie = MTK.balanceOf(users.charlie.account);
        // Assert that Charlie received 100 tokens
        assertEq(balanceAfterCharlie, balanceBeforeCharlie + 100);
    }

    function test_transferTo_nativeETH() public {
        // Arrange
        address recipient = users.bob.account;
        uint256 amount = 1 ether;

        // Fund the contract with ETH
        vm.deal(address(this), amount);

        // Check balance before transfer
        uint256 balanceBefore = recipient.balance;

        // Act
        // Transfer ETH
        (this).callTransferTo(ETH, recipient, amount);

        // Assert
        // Check balance after transfer
        uint256 balanceAfter = recipient.balance;
        assertEq(balanceAfter, balanceBefore + amount);
    }

    function test_transferTo_nativeETH_RevertsWhen_InsufficientFunds() public {
        // Arrange
        address recipient = users.bob.account;
        uint256 amount = 1_000_000_000_000 ether;

        // Check balance before transfer
        uint256 balanceBefore = recipient.balance;

        // Expect the transfer to revert due to insufficient ETH in the contract
        vm.expectRevert();

        // Act
        // Transfer ETH
        (this).callTransferTo(ETH, recipient, amount);

        // Assert
        // Check balance after transfer
        uint256 balanceAfter = recipient.balance;
        assertEq(balanceAfter, balanceBefore);
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPER
    //////////////////////////////////////////////////////////////*/

    /// @dev Mock to propagate the revert
    function callTransferTo(address destToken, address recipient, uint256 amount) public {
        return ERC20UtilsLib.transferTo(destToken, recipient, amount);
    }
}
