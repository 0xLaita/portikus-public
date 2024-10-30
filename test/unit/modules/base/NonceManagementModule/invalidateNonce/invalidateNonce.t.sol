// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Libraries
import { NonceManagerLib } from "@modules/libraries/NonceManagerLib.sol";

// Test
import { NonceManagementModule_Test } from "../NonceManagementModule.t.sol";

contract NonceManagementModule_invalidateNonce is NonceManagementModule_Test {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event NonceInvalidated(address indexed user, uint256 nonce);

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_invalidateNonce_MarksNonceAsUsed() public {
        // Arrange
        address user = users.alice.account;
        uint256 nonce = 123;
        vm.startPrank(user);

        // Act
        vm.expectEmit(true, false, false, true);
        emit NonceInvalidated(user, nonce);
        nonceManagementModule.invalidateNonce(nonce);

        // Assert
        assertTrue(nonceManagementModule.isNonceUsed(user, nonce), "Nonce should be marked as used");
    }

    function testFuzz_invalidateNonce(uint256 nonce) public {
        // Arrange
        address user = users.alice.account;
        vm.startPrank(user);

        // Act
        vm.expectEmit(true, false, false, true);
        emit NonceInvalidated(user, nonce);
        nonceManagementModule.invalidateNonce(nonce);

        // Assert
        assertTrue(nonceManagementModule.isNonceUsed(user, nonce), "Nonce should be marked as used");
    }

    function test_invalidateNonce_Idempotent() public {
        // Arrange
        address user = users.alice.account;
        uint256 nonce = 123;
        vm.startPrank(user);

        // Act
        nonceManagementModule.invalidateNonce(nonce);
        nonceManagementModule.invalidateNonce(nonce);

        // Assert
        assertTrue(nonceManagementModule.isNonceUsed(user, nonce), "Nonce should still be marked as used");
    }
}
