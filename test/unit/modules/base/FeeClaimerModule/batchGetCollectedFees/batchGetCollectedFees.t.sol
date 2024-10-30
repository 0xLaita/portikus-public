// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Libraries
import { ERC20UtilsLib } from "@modules/libraries/ERC20UtilsLib.sol";

// Test
import { FeeClaimerModule_Test } from "../FeeClaimerModule.t.sol";

contract FeeClaimerModule_batchGetCollectedFees is FeeClaimerModule_Test {
    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_batchGetCollectedFees_ReturnsCorrectAmounts() public {
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

        // Act
        uint256[] memory collectedFees = feeClaimerModule.batchGetCollectedFees(partner, tokens);

        // Assert
        assertEq(collectedFees.length, tokens.length, "Returned array length should match input tokens length");
        for (uint256 i = 0; i < tokens.length; i++) {
            assertEq(collectedFees[i], amounts[i], "Collected fees should match simulated amounts for each token");
        }
    }

    function test_batchGetCollectedFees_EmptyArray() public {
        // Arrange
        address partner = users.alice.account;
        address[] memory tokens = new address[](0);

        // Act
        uint256[] memory collectedFees = feeClaimerModule.batchGetCollectedFees(partner, tokens);

        // Assert
        assertEq(collectedFees.length, 0, "Should return an empty array for empty input");
    }
}
