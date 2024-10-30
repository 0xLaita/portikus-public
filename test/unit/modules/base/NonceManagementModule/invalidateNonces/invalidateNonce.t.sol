// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Libraries
import { NonceManagerLib } from "@modules/libraries/NonceManagerLib.sol";

// Test
import { NonceManagementModule_Test } from "../NonceManagementModule.t.sol";

contract NonceManagementModule_invalidateNonces is NonceManagementModule_Test {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event NonceInvalidated(address indexed user, uint256 nonce);

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_invalidateNonces_MarksMultipleNoncesAsUsed() public {
        // Arrange
        address user = users.alice.account;
        uint256[] memory nonces = new uint256[](3);
        nonces[0] = 123;
        nonces[1] = 456;
        nonces[2] = 789;
        vm.startPrank(user);

        // Act
        for (uint256 i = 0; i < nonces.length; i++) {
            vm.expectEmit(true, false, false, true);
            emit NonceInvalidated(user, nonces[i]);
        }
        nonceManagementModule.invalidateNonces(nonces);

        // Assert
        for (uint256 i = 0; i < nonces.length; i++) {
            assertTrue(nonceManagementModule.isNonceUsed(user, nonces[i]), "Nonce should be marked as used");
        }
    }

    function test_invalidateNonces_EmptyArray() public {
        // Arrange
        address user = users.alice.account;
        uint256[] memory nonces = new uint256[](0);
        vm.startPrank(user);

        // Act & Assert
        nonceManagementModule.invalidateNonces(nonces);
        // No assertions needed, just checking that it doesn't revert
    }
}
