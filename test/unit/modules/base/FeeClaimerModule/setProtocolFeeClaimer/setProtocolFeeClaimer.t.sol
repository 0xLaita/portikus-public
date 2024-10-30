// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Test
import { FeeClaimerModule_Test } from "../FeeClaimerModule.t.sol";

// Libraries
import { ModuleManagerLib } from "@modules/libraries/ModuleManagerLib.sol";

contract FeeClaimerModule_setProtocolFeeClaimer is FeeClaimerModule_Test {
    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setProtocolFeeClaimer_SuccessfulUpdate() public {
        // Arrange
        address newFeeClaimer = users.alice.account;

        // Act
        vm.prank(users.admin.account);
        feeClaimerModule.setProtocolFeeClaimer(newFeeClaimer);

        // Assert
        assertEq(feeClaimerModule.getProtocolFeeClaimer(), newFeeClaimer, "Protocol fee claimer should be updated");
    }

    function test_setProtocolFeeClaimer_RevertUnauthorized() public {
        // Arrange
        address unauthorizedAccount = users.bob.account;
        address newFeeClaimer = users.alice.account;

        // Act & Assert
        vm.prank(unauthorizedAccount);
        vm.expectRevert(abi.encodeWithSelector(ModuleManagerLib.UnauthorizedAccount.selector, unauthorizedAccount));
        feeClaimerModule.setProtocolFeeClaimer(newFeeClaimer);
    }

    function test_setProtocolFeeClaimer_UpdateToZeroAddress() public {
        // Arrange
        address zeroAddress = address(0);

        // Act
        vm.prank(users.admin.account);
        feeClaimerModule.setProtocolFeeClaimer(zeroAddress);

        // Assert
        assertEq(
            feeClaimerModule.getProtocolFeeClaimer(), zeroAddress, "Protocol fee claimer should be set to zero address"
        );
    }
}
