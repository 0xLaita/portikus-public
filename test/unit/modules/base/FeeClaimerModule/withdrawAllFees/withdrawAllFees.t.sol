// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Libraries
import { ERC20UtilsLib } from "@modules/libraries/ERC20UtilsLib.sol";

// Test
import { FeeClaimerModule_Test } from "../FeeClaimerModule.t.sol";

contract FeeClaimerModule_withdrawAllFees is FeeClaimerModule_Test {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event FeesWithdrawn(address indexed partner, address indexed token, uint256 amount, address recipient);

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_withdrawAllFees_SuccessfulWithdrawalERC20() public {
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
        uint256 withdrawnAmount = feeClaimerModule.withdrawAllFees(token, partner);

        // Assert
        assertEq(withdrawnAmount, amount, "Withdrawn amount should match collected fees");
        assertEq(MTK.balanceOf(partner), amount, "Partner should receive all collected fees");
        assertEq(feeClaimerModule.getCollectedFees(token, partner), 0, "Collected fees should be zero after withdrawal");
    }

    function test_withdrawAllFees_SuccessfulWithdrawalETH() public {
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
        uint256 withdrawnAmount = feeClaimerModule.withdrawAllFees(token, partner);

        // Assert
        assertEq(withdrawnAmount, amount, "Withdrawn amount should match collected fees");
        assertEq(partner.balance - balanceBefore, amount, "Partner should receive all collected ETH fees");
        assertEq(feeClaimerModule.getCollectedFees(token, partner), 0, "Collected fees should be zero after withdrawal");
    }

    function test_withdrawAllFees_NoFeesCollected() public {
        // Arrange
        address partner = users.alice.account;
        address token = address(MTK);
        vm.startPrank(partner);

        // Act
        uint256 withdrawnAmount = feeClaimerModule.withdrawAllFees(token, partner);

        // Assert
        assertEq(withdrawnAmount, 0, "Withdrawn amount should be zero when no fees are collected");
        assertEq(MTK.balanceOf(partner), 0, "Partner should not receive any tokens");
    }
}
