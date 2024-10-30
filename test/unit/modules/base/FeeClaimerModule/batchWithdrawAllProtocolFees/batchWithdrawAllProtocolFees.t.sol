// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Libraries
import { ERC20UtilsLib } from "@modules/libraries/ERC20UtilsLib.sol";
import { FeeManagerLib } from "@modules/libraries/FeeManagerLib.sol";

// Test
import { FeeClaimerModule_Test } from "../FeeClaimerModule.t.sol";

contract FeeClaimerModule_batchWithdrawAllProtocolFees is FeeClaimerModule_Test {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event FeesWithdrawn(address indexed partner, address indexed token, uint256 amount, address recipient);

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_batchWithdrawAllProtocolFees_SuccessfulWithdrawal() public {
        // Arrange
        address protocolFeeClaimer = users.bob.account;
        address[] memory tokens = new address[](3);
        tokens[0] = address(MTK);
        tokens[1] = address(USDT);
        tokens[2] = ERC20UtilsLib.ETH_ADDRESS;
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100 ether;
        amounts[1] = 200 ether;
        amounts[2] = 1 ether;

        // Set protocol fee claimer
        vm.prank(users.admin.account);
        feeClaimerModule.setProtocolFeeClaimer(protocolFeeClaimer);

        // Simulate collected fees
        for (uint256 i = 0; i < tokens.length; i++) {
            feeClaimerModule.collectFees(address(0), tokens[i], amounts[i]);
        }

        // Fund the contract with tokens and ETH
        vm.deal(address(feeClaimerModule), amounts[2]);
        vm.startPrank(users.admin.account);
        MTK.transfer(address(feeClaimerModule), amounts[0]);
        USDT.transfer(address(feeClaimerModule), amounts[1]);
        vm.stopPrank();

        // Act
        vm.startPrank(protocolFeeClaimer);
        uint256 ethBalanceBefore = protocolFeeClaimer.balance;
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.expectEmit(true, true, false, true);
            emit FeesWithdrawn(address(0), tokens[i], amounts[i], protocolFeeClaimer);
        }
        feeClaimerModule.batchWithdrawAllProtocolFees(tokens, protocolFeeClaimer);

        // Assert
        assertEq(
            MTK.balanceOf(protocolFeeClaimer),
            amounts[0],
            "Protocol fee claimer should receive the correct amount of MTK"
        );
        assertEq(
            USDT.balanceOf(protocolFeeClaimer),
            amounts[1],
            "Protocol fee claimer should receive the correct amount of USDT"
        );
        assertEq(
            protocolFeeClaimer.balance - ethBalanceBefore,
            amounts[2],
            "Protocol fee claimer should receive the correct amount of ETH"
        );
        for (uint256 i = 0; i < tokens.length; i++) {
            assertEq(
                feeClaimerModule.getCollectedFees(address(0), tokens[i]),
                0,
                "Collected fees should be zero after withdrawal"
            );
        }
    }

    function test_batchWithdrawAllProtocolFees_EmptyArray() public {
        // Arrange
        address protocolFeeClaimer = users.bob.account;
        address[] memory tokens = new address[](0);

        // Set protocol fee claimer
        vm.prank(users.admin.account);
        feeClaimerModule.setProtocolFeeClaimer(protocolFeeClaimer);

        // Act & Assert
        vm.startPrank(protocolFeeClaimer);
        feeClaimerModule.batchWithdrawAllProtocolFees(tokens, protocolFeeClaimer);
        // No assertions needed, just checking that it doesn't revert
    }

    function test_batchWithdrawAllProtocolFees_RevertUnauthorized() public {
        // Arrange
        address unauthorizedAccount = users.alice.account;
        address[] memory tokens = new address[](1);
        tokens[0] = address(MTK);

        // Act & Assert
        vm.startPrank(unauthorizedAccount);
        vm.expectRevert(abi.encodeWithSelector(FeeManagerLib.UnauthorizedAccount.selector, unauthorizedAccount));
        feeClaimerModule.batchWithdrawAllProtocolFees(tokens, unauthorizedAccount);
    }

    function test_batchWithdrawAllProtocolFees_MixedTokenTypes() public {
        // Arrange
        address protocolFeeClaimer = users.bob.account;
        address[] memory tokens = new address[](3);
        tokens[0] = address(MTK);
        tokens[1] = ERC20UtilsLib.ETH_ADDRESS;
        tokens[2] = address(USDT);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100 ether;
        amounts[1] = 1 ether;
        amounts[2] = 200 ether;

        // Set protocol fee claimer
        vm.prank(users.admin.account);
        feeClaimerModule.setProtocolFeeClaimer(protocolFeeClaimer);

        // Simulate collected fees
        for (uint256 i = 0; i < tokens.length; i++) {
            feeClaimerModule.collectFees(address(0), tokens[i], amounts[i]);
        }

        // Fund the contract with tokens and ETH
        vm.deal(address(feeClaimerModule), amounts[1]);
        vm.startPrank(users.admin.account);
        MTK.transfer(address(feeClaimerModule), amounts[0]);
        USDT.transfer(address(feeClaimerModule), amounts[2]);
        vm.stopPrank();

        // Act
        vm.startPrank(protocolFeeClaimer);
        uint256 ethBalanceBefore = protocolFeeClaimer.balance;
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.expectEmit(true, true, false, true);
            emit FeesWithdrawn(address(0), tokens[i], amounts[i], protocolFeeClaimer);
        }
        feeClaimerModule.batchWithdrawAllProtocolFees(tokens, protocolFeeClaimer);

        // Assert
        assertEq(
            MTK.balanceOf(protocolFeeClaimer),
            amounts[0],
            "Protocol fee claimer should receive the correct amount of MTK"
        );
        assertEq(
            protocolFeeClaimer.balance - ethBalanceBefore,
            amounts[1],
            "Protocol fee claimer should receive the correct amount of ETH"
        );
        assertEq(
            USDT.balanceOf(protocolFeeClaimer),
            amounts[2],
            "Protocol fee claimer should receive the correct amount of USDT"
        );
        for (uint256 i = 0; i < tokens.length; i++) {
            assertEq(
                feeClaimerModule.getCollectedFees(address(0), tokens[i]),
                0,
                "Collected fees should be zero after withdrawal"
            );
        }
    }
}
