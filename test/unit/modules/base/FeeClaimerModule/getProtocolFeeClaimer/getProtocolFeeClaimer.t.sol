// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Test
import { FeeClaimerModule_Test } from "../FeeClaimerModule.t.sol";

contract FeeClaimerModule_getProtocolFeeClaimer is FeeClaimerModule_Test {
    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getProtocolFeeClaimer_InitialValue() public {
        // Act
        address initialFeeClaimer = feeClaimerModule.getProtocolFeeClaimer();

        // Assert
        assertEq(initialFeeClaimer, address(0), "Initial protocol fee claimer should be zero address");
    }

    function test_getProtocolFeeClaimer_AfterUpdate() public {
        // Arrange
        address newFeeClaimer = users.alice.account;

        // Act
        vm.prank(users.admin.account);
        feeClaimerModule.setProtocolFeeClaimer(newFeeClaimer);
        address updatedFeeClaimer = feeClaimerModule.getProtocolFeeClaimer();

        // Assert
        assertEq(updatedFeeClaimer, newFeeClaimer, "Updated protocol fee claimer should match the new address");
    }

    function test_getProtocolFeeClaimer_MultipleUpdates() public {
        // Arrange
        address firstFeeClaimer = users.alice.account;
        address secondFeeClaimer = users.bob.account;

        // Act
        vm.startPrank(users.admin.account);
        feeClaimerModule.setProtocolFeeClaimer(firstFeeClaimer);
        feeClaimerModule.setProtocolFeeClaimer(secondFeeClaimer);
        vm.stopPrank();
        address finalFeeClaimer = feeClaimerModule.getProtocolFeeClaimer();

        // Assert
        assertEq(finalFeeClaimer, secondFeeClaimer, "Final protocol fee claimer should match the last updated address");
    }
}
