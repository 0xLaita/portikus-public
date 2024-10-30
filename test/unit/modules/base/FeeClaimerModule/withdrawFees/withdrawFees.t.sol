// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Libraries
import { ERC20UtilsLib } from "@modules/libraries/ERC20UtilsLib.sol";

// Test
import { FeeClaimerModule_Test } from "../FeeClaimerModule.t.sol";

contract FeeClaimerModule_withdrawFees is FeeClaimerModule_Test {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error InsufficientFees();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event FeesWithdrawn(address indexed partner, address indexed token, uint256 amount, address recipient);

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_withdrawFees_SuccessfulWithdrawalERC20() public {
        // Arrange
        address partner = users.alice.account;
        address token = address(MTK);
        uint256 amount = 100 ether;

        // Simulate collected fees
        feeClaimerModule.collectFees(partner, token, amount);

        // Fund the contract with MTK
        vm.startPrank(users.admin.account);
        MTK.transfer(address(feeClaimerModule), amount);

        // Act
        vm.startPrank(partner);
        vm.expectEmit(true, true, false, true);
        emit FeesWithdrawn(partner, token, amount, partner);
        feeClaimerModule.withdrawFees(token, amount, partner);

        // Assert
        assertEq(MTK.balanceOf(partner), amount, "Partner should receive the withdrawn amount");
        assertEq(feeClaimerModule.getCollectedFees(token, partner), 0, "Collected fees should be zero after withdrawal");
    }

    function test_withdrawFees_SuccessfulWithdrawalETH() public {
        // Arrange
        address partner = users.alice.account;
        address token = ERC20UtilsLib.ETH_ADDRESS;
        uint256 amount = 1 ether;
        vm.startPrank(partner);

        // Simulate collected fees
        feeClaimerModule.collectFees(partner, token, amount);

        // Fund the contract with ETH
        vm.deal(address(feeClaimerModule), amount);

        // Act
        uint256 balanceBefore = partner.balance;
        vm.expectEmit(true, true, false, true);
        emit FeesWithdrawn(partner, token, amount, partner);
        feeClaimerModule.withdrawFees(token, amount, partner);

        // Assert
        assertEq(partner.balance - balanceBefore, amount, "Partner should receive the withdrawn ETH amount");
        assertEq(feeClaimerModule.getCollectedFees(token, partner), 0, "Collected fees should be zero after withdrawal");
    }

    function test_withdrawFees_SuccessfulWithdrawalETH_RecipientZero() public {
        // Arrange
        address partner = users.alice.account;
        address token = ERC20UtilsLib.ETH_ADDRESS;
        uint256 amount = 1 ether;
        vm.startPrank(partner);

        // Simulate collected fees
        feeClaimerModule.collectFees(partner, token, amount);

        // Fund the contract with ETH
        vm.deal(address(feeClaimerModule), amount);

        // Act
        uint256 balanceBefore = partner.balance;
        vm.expectEmit(true, true, false, true);
        emit FeesWithdrawn(partner, token, amount, partner);
        feeClaimerModule.withdrawFees(token, amount, address(0));

        // Assert
        assertEq(partner.balance - balanceBefore, amount, "Partner should receive the withdrawn ETH amount");
        assertEq(feeClaimerModule.getCollectedFees(token, partner), 0, "Collected fees should be zero after withdrawal");
    }

    function test_withdrawFees_InsufficientFeesERC20() public {
        // Arrange
        address partner = users.alice.account;
        address token = address(MTK);
        uint256 amount = 100 ether;
        vm.startPrank(partner);

        // Act & Assert
        vm.expectRevert(InsufficientFees.selector);
        feeClaimerModule.withdrawFees(token, amount, partner);
    }

    function test_withdrawFees_InsufficientFeesETH() public {
        // Arrange
        address partner = users.alice.account;
        address token = ERC20UtilsLib.ETH_ADDRESS;
        uint256 amount = 1 ether;
        vm.startPrank(partner);

        // Act & Assert
        vm.expectRevert(InsufficientFees.selector);
        feeClaimerModule.withdrawFees(token, amount, partner);
    }
}
