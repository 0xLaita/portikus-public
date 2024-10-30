// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Libraries
import { ERC20UtilsLib } from "@modules/libraries/ERC20UtilsLib.sol";

// Test
import { FeeClaimerModule_Test } from "../FeeClaimerModule.t.sol";

contract FeeClaimerModule_batchWithdrawAllFees is FeeClaimerModule_Test {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event FeesWithdrawn(address indexed partner, address indexed token, uint256 amount, address recipient);

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_batchWithdrawAllFees_SuccessfulWithdrawal() public {
        // Arrange
        address partner = users.alice.account;
        address[] memory tokens = new address[](3);
        tokens[0] = address(MTK);
        tokens[1] = address(USDT);
        tokens[2] = ERC20UtilsLib.ETH_ADDRESS;
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100 ether;
        amounts[1] = 200 ether;
        amounts[2] = 1 ether;

        // Simulate collected fees
        for (uint256 i = 0; i < tokens.length; i++) {
            feeClaimerModule.collectFees(partner, tokens[i], amounts[i]);
        }

        // Fund the contract with ETH
        vm.deal(address(feeClaimerModule), amounts[2]);

        // Fund the contract with USDT and MTK
        vm.startPrank(users.admin.account);
        MTK.transfer(address(feeClaimerModule), amounts[0]);
        USDT.transfer(address(feeClaimerModule), amounts[1]);

        // Act
        vm.startPrank(partner);
        uint256 ethBalanceBefore = partner.balance;
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.expectEmit(true, true, false, true);
            emit FeesWithdrawn(partner, tokens[i], amounts[i], partner);
        }
        feeClaimerModule.batchWithdrawAllFees(tokens, partner);

        // Assert
        assertEq(MTK.balanceOf(partner), amounts[0], "Partner should receive the correct amount for MTK");
        assertEq(USDT.balanceOf(partner), amounts[1], "Partner should receive the correct amount for USDT");
        assertEq(partner.balance - ethBalanceBefore, amounts[2], "Partner should receive the correct amount of ETH");
        for (uint256 i = 0; i < tokens.length; i++) {
            assertEq(
                feeClaimerModule.getCollectedFees(tokens[i], partner),
                0,
                "Collected fees should be zero after withdrawal"
            );
        }
    }

    function test_batchWithdrawAllFees_EmptyArray() public {
        // Arrange
        address partner = users.alice.account;
        address[] memory tokens = new address[](0);
        vm.startPrank(partner);

        // Act & Assert
        feeClaimerModule.batchWithdrawAllFees(tokens, partner);
        // No assertions needed, just checking that it doesn't revert
    }
}
