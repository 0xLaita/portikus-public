// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Libraries
import { NonceManagerLib } from "@modules/libraries/NonceManagerLib.sol";

// Test
import { NonceManagerLib_Test } from "../NonceManagerLib.t.sol";

contract NonceManagerLib_useNonce is NonceManagerLib_Test {
    function test_useNonce_SuccessfullyUsesNonce() public {
        // Arrange
        address owner = users.alice.account;
        uint256 nonce = 1;

        // Act
        NonceManagerLib.useNonce(owner, nonce);

        // Assert
        bool isUsed = NonceManagerLib.isNonceUsed(owner, nonce);
        assertTrue(isUsed, "Nonce should be marked as used");
    }

    function test_useNonce_RevertsWhen_NonceAlreadyUsed() public {
        // Arrange
        address owner = users.alice.account;
        uint256 nonce = 1;

        // Act
        NonceManagerLib.setNonceUsed(owner, nonce);

        // Assert
        vm.expectRevert(NonceManagerLib.InvalidNonce.selector);
        NonceManagerLib.useNonce(owner, nonce);
    }
}
