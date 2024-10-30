// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Libraries
import { NonceManagerLib } from "@modules/libraries/NonceManagerLib.sol";

// Test
import { NonceManagementModule_Test } from "../NonceManagementModule.t.sol";

contract NonceManagementModule_areNoncesUsed is NonceManagementModule_Test {
    function test_areNoncesUsed_ReturnsCorrectStatusForMultipleNonces() public {
        // Arrange
        address user = users.alice.account;
        uint256[] memory nonces = new uint256[](3);
        nonces[0] = 123;
        nonces[1] = 456;
        nonces[2] = 789;
        vm.startPrank(user);
        nonceManagementModule.invalidateNonce(nonces[1]);

        // Act
        bool[] memory used = nonceManagementModule.areNoncesUsed(user, nonces);

        // Assert
        assertFalse(used[0], "First nonce should not be used");
        assertTrue(used[1], "Second nonce should be used");
        assertFalse(used[2], "Third nonce should not be used");
    }

    function test_areNoncesUsed_EmptyArray() public {
        // Arrange
        address user = users.alice.account;
        uint256[] memory nonces = new uint256[](0);

        // Act
        bool[] memory used = nonceManagementModule.areNoncesUsed(user, nonces);

        // Assert
        assertEq(used.length, 0, "Result array should be empty");
    }
}
