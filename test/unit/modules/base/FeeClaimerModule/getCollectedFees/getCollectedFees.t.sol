// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Libraries
import { ERC20UtilsLib } from "@modules/libraries/ERC20UtilsLib.sol";

// Test
import { FeeClaimerModule_Test } from "../FeeClaimerModule.t.sol";

contract FeeClaimerModule_getCollectedFees is FeeClaimerModule_Test {
    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getCollectedFees_ReturnsCorrectAmountERC20() public {
        // Arrange
        address partner = users.alice.account;
        address token = address(MTK);
        uint256 amount = 100 ether;

        // Simulate collected fees
        feeClaimerModule.collectFees(partner, token, amount);

        // Act
        uint256 collectedFees = feeClaimerModule.getCollectedFees(partner, token);

        // Assert
        assertEq(collectedFees, amount, "Returned collected fees should match the simulated amount");
    }

    function test_getCollectedFees_ReturnsCorrectAmountETH() public {
        // Arrange
        address partner = users.alice.account;
        address token = ERC20UtilsLib.ETH_ADDRESS;
        uint256 amount = 1 ether;

        // Simulate collected fees
        feeClaimerModule.collectFees(partner, token, amount);

        // Act
        uint256 collectedFees = feeClaimerModule.getCollectedFees(partner, token);

        // Assert
        assertEq(collectedFees, amount, "Returned collected ETH fees should match the simulated amount");
    }

    function test_getCollectedFees_ReturnsZeroForNoFees() public {
        // Arrange
        address partner = users.alice.account;
        address token = address(MTK);

        // Act
        uint256 collectedFees = feeClaimerModule.getCollectedFees(partner, token);

        // Assert
        assertEq(collectedFees, 0, "Should return zero when no fees are collected");
    }
}
