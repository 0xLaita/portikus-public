// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Test
import { NonceManagementModule_Test } from "../NonceManagementModule.t.sol";

contract NonceManagementModule_selectors is NonceManagementModule_Test {
    /*//////////////////////////////////////////////////////////////
                                   TESTS
    //////////////////////////////////////////////////////////////*/

    function test_selectors_ReturnsCorrectSelectors() public {
        // Act
        bytes4[] memory moduleSelectors = nonceManagementModule.selectors();

        // Assert
        assertEq(moduleSelectors.length, 4, "Should return 4 selectors");
        assertEq(
            moduleSelectors[0],
            nonceManagementModule.invalidateNonce.selector,
            "First selector should be invalidateNonce"
        );
        assertEq(
            moduleSelectors[1],
            nonceManagementModule.invalidateNonces.selector,
            "Second selector should be invalidateNonces"
        );
        assertEq(moduleSelectors[2], nonceManagementModule.isNonceUsed.selector, "Third selector should be isNonceUsed");
        assertEq(
            moduleSelectors[3], nonceManagementModule.areNoncesUsed.selector, "Fourth selector should be areNoncesUsed"
        );
    }
}
