// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Libraries
import { NonceManagerLib } from "@modules/libraries/NonceManagerLib.sol";

// Test
import { NonceManagementModule_Test } from "../NonceManagementModule.t.sol";

contract NonceManagementModule_isNonceUsed is NonceManagementModule_Test {
    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isNonceUsed_ReturnsTrueWhenNonceIsUsed() public {
        // Arrange
        address user = users.alice.account;
        uint256 nonce = 123;
        vm.startPrank(user);
        nonceManagementModule.invalidateNonce(nonce);

        // Act
        bool isUsed = nonceManagementModule.isNonceUsed(user, nonce);

        // Assert
        assertTrue(isUsed, "Nonce should be marked as used");
    }

    function test_isNonceUsed_ReturnsFalseWhenNonceIsNotUsed() public {
        // Arrange
        address user = users.alice.account;
        uint256 nonce = 123;

        // Act
        bool isUsed = nonceManagementModule.isNonceUsed(user, nonce);

        // Assert
        assertFalse(isUsed, "Nonce should not be marked as used");
    }
}
