// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Libraries
import { NonceManagerLib } from "@modules/libraries/NonceManagerLib.sol";

// Test
import { NonceManagerLib_Test } from "../NonceManagerLib.t.sol";

contract NonceManagerLib_setNonceUsed is NonceManagerLib_Test {
    function test_setNonceUsed_SuccessfullyMarksNonce() public {
        // Arrange
        address owner = users.alice.account;
        uint256 nonce = 1;

        // Act
        NonceManagerLib.setNonceUsed(owner, nonce);

        // Assert
        bool isUsed = NonceManagerLib.isNonceUsed(owner, nonce);
        assertTrue(isUsed, "Nonce should be marked as used");
    }

    function test_setNonceUsed_MultipleNoncesSuccessfullyMarked() public {
        // Arrange
        address owner = users.alice.account;
        uint256 nonce1 = 1;
        uint256 nonce2 = 257;

        // Act
        NonceManagerLib.setNonceUsed(owner, nonce1);
        NonceManagerLib.setNonceUsed(owner, nonce2);

        // Assert
        assertTrue(NonceManagerLib.isNonceUsed(owner, nonce1), "Nonce 1 should be marked as used");
        assertTrue(NonceManagerLib.isNonceUsed(owner, nonce2), "Nonce 2 should be marked as used");
    }
}
