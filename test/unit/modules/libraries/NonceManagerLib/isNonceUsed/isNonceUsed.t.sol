// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Libraries
import { NonceManagerLib } from "@modules/libraries/NonceManagerLib.sol";

// Test
import { NonceManagerLib_Test } from "../NonceManagerLib.t.sol";

contract NonceManagerLib_isNonceUsed is NonceManagerLib_Test {
    function test_isNonceUsed_ReturnsTrueWhenNonceIsUsed() public {
        // Arrange
        address owner = users.alice.account;
        uint256 nonce = 1;

        // Act
        NonceManagerLib.setNonceUsed(owner, nonce);

        // Assert
        bool isUsed = NonceManagerLib.isNonceUsed(owner, nonce);
        assertTrue(isUsed, "Nonce should be marked as used");
    }

    function test_isNonceUsed_ReturnsFalseWhenNonceIsNotUsed() public {
        // Arrange
        address owner = users.alice.account;
        uint256 nonce = 1;

        // Act & Assert
        bool isUsed = NonceManagerLib.isNonceUsed(owner, nonce);
        assertFalse(isUsed, "Nonce should not be marked as used");
    }
}
