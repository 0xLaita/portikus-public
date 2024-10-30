// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Libraries
import { ERC20UtilsLib } from "@modules/libraries/ERC20UtilsLib.sol";
import { FeeManagerLib } from "@modules/libraries/FeeManagerLib.sol";

// Test
import { FeeClaimerModule_Test } from "../FeeClaimerModule.t.sol";

contract FeeClaimerModule_withdrawProtocolFees is FeeClaimerModule_Test {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event FeesWithdrawn(address indexed partner, address indexed token, uint256 amount, address recipient);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error InsufficientFees();

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_withdrawProtocolFees_SuccessfulWithdrawalERC20() public {
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
        feeClaimerModule.withdrawProtocolFees(token, amount, protocolFeeClaimer);

        // Assert
        assertEq(MTK.balanceOf(protocolFeeClaimer), amount, "Protocol fee claimer should receive the withdrawn amount");
        assertEq(
            feeClaimerModule.getCollectedFees(address(feeClaimerModule), token),
            0,
            "Collected fees should be zero after withdrawal"
        );
    }

    function test_withdrawProtocolFees_SuccessfulWithdrawalETH() public {
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
        feeClaimerModule.withdrawProtocolFees(token, amount, protocolFeeClaimer);

        // Assert
        assertEq(
            protocolFeeClaimer.balance - balanceBefore,
            amount,
            "Protocol fee claimer should receive the withdrawn ETH amount"
        );
        assertEq(
            feeClaimerModule.getCollectedFees(address(feeClaimerModule), token),
            0,
            "Collected fees should be zero after withdrawal"
        );
    }

    function test_withdrawProtocolFees_RevertUnauthorized() public {
        // Arrange
        address unauthorizedAccount = users.alice.account;
        address token = address(MTK);
        uint256 amount = 100 ether;

        // Act & Assert
        vm.startPrank(unauthorizedAccount);
        vm.expectRevert(abi.encodeWithSelector(FeeManagerLib.UnauthorizedAccount.selector, unauthorizedAccount));
        feeClaimerModule.withdrawProtocolFees(token, amount, unauthorizedAccount);
    }

    function test_withdrawProtocolFees_RevertInsufficientBalance() public {
        // Arrange
        address protocolFeeClaimer = users.bob.account;
        address token = address(MTK);
        uint256 collectedAmount = 100 ether;
        uint256 withdrawAmount = 200 ether;

        // Set protocol fee claimer
        vm.prank(users.admin.account);
        feeClaimerModule.setProtocolFeeClaimer(protocolFeeClaimer);

        // Simulate collected fees
        feeClaimerModule.collectFees(address(feeClaimerModule), token, collectedAmount);

        // Act & Assert
        vm.startPrank(protocolFeeClaimer);
        vm.expectRevert(InsufficientFees.selector);
        feeClaimerModule.withdrawProtocolFees(token, withdrawAmount, protocolFeeClaimer);
    }
}
