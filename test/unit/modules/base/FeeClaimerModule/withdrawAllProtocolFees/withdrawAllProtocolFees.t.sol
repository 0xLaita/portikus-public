// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Libraries
import { ERC20UtilsLib } from "@modules/libraries/ERC20UtilsLib.sol";
import { FeeManagerLib } from "@modules/libraries/FeeManagerLib.sol";

// Test
import { FeeClaimerModule_Test } from "../FeeClaimerModule.t.sol";

contract FeeClaimerModule_withdrawAllProtocolFees is FeeClaimerModule_Test {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event FeesWithdrawn(address indexed partner, address indexed token, uint256 amount, address recipient);

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_withdrawAllProtocolFees_SuccessfulWithdrawalERC20() public {
        // Arrange
        address protocolFeeClaimer = users.bob.account;
        address token = address(MTK);
        uint256 amount = 100 ether;

        // Set protocol fee claimer
        vm.prank(users.admin.account);
        feeClaimerModule.setProtocolFeeClaimer(protocolFeeClaimer);

        // Simulate collected fees
        feeClaimerModule.collectFees(address(0), token, amount);

        // Fund the contract with MTK
        vm.startPrank(users.admin.account);
        MTK.transfer(address(feeClaimerModule), amount);

        // Act
        vm.startPrank(protocolFeeClaimer);
        vm.expectEmit(true, true, false, true);
        emit FeesWithdrawn(address(0), token, amount, protocolFeeClaimer);
        uint256 withdrawnAmount = feeClaimerModule.withdrawAllProtocolFees(token, protocolFeeClaimer);

        // Assert
        assertEq(withdrawnAmount, amount, "Withdrawn amount should match collected fees");
        assertEq(MTK.balanceOf(protocolFeeClaimer), amount, "Protocol fee claimer should receive all collected fees");
        assertEq(
            feeClaimerModule.getCollectedFees(address(0), token), 0, "Collected fees should be zero after withdrawal"
        );
    }

    function test_withdrawAllProtocolFees_SuccessfulWithdrawalETH() public {
        // Arrange
        address protocolFeeClaimer = users.bob.account;
        address token = ERC20UtilsLib.ETH_ADDRESS;
        uint256 amount = 1 ether;

        // Set protocol fee claimer
        vm.prank(users.admin.account);
        feeClaimerModule.setProtocolFeeClaimer(protocolFeeClaimer);

        // Simulate collected fees
        feeClaimerModule.collectFees(address(0), token, amount);

        // Fund the contract with ETH
        vm.deal(address(feeClaimerModule), amount);

        // Act
        vm.startPrank(protocolFeeClaimer);
        uint256 balanceBefore = protocolFeeClaimer.balance;
        vm.expectEmit(true, true, false, true);
        emit FeesWithdrawn(address(0), token, amount, protocolFeeClaimer);
        uint256 withdrawnAmount = feeClaimerModule.withdrawAllProtocolFees(token, protocolFeeClaimer);

        // Assert
        assertEq(withdrawnAmount, amount, "Withdrawn amount should match collected fees");
        assertEq(
            protocolFeeClaimer.balance - balanceBefore,
            amount,
            "Protocol fee claimer should receive all collected ETH fees"
        );
        assertEq(
            feeClaimerModule.getCollectedFees(address(0), token), 0, "Collected fees should be zero after withdrawal"
        );
    }

    function test_withdrawAllProtocolFees_NoFeesCollected() public {
        // Arrange
        address protocolFeeClaimer = users.bob.account;
        address token = address(MTK);

        // Set protocol fee claimer
        vm.prank(users.admin.account);
        feeClaimerModule.setProtocolFeeClaimer(protocolFeeClaimer);

        // Act
        vm.startPrank(protocolFeeClaimer);
        uint256 withdrawnAmount = feeClaimerModule.withdrawAllProtocolFees(token, protocolFeeClaimer);

        // Assert
        assertEq(withdrawnAmount, 0, "Withdrawn amount should be zero when no fees are collected");
        assertEq(MTK.balanceOf(protocolFeeClaimer), 0, "Protocol fee claimer should not receive any tokens");
    }

    function test_withdrawAllProtocolFees_RevertUnauthorized() public {
        // Arrange
        address unauthorizedAccount = users.alice.account;
        address token = address(MTK);

        // Act & Assert
        vm.startPrank(unauthorizedAccount);
        vm.expectRevert(abi.encodeWithSelector(FeeManagerLib.UnauthorizedAccount.selector, unauthorizedAccount));
        feeClaimerModule.withdrawAllProtocolFees(token, unauthorizedAccount);
    }
}
