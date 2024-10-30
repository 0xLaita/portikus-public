// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { NonceManagementModule } from "@modules/base/NonceManagementModule.sol";

// Test
import { NonceManagementModule_Test } from "../NonceManagementModule.t.sol";

contract NonceManagementModule_constructor is NonceManagementModule_Test {
    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor() public {
        // Create new NonceManagementModule
        nonceManagementModule = new NonceManagementModule("Mock Module", "1.0.0", address(this));
        // Check constructor
        assertEq(nonceManagementModule.name(), "Mock Module");
        assertEq(nonceManagementModule.version(), "1.0.0");
        assertEq(address(nonceManagementModule.PORTIKUS_V2()), address(this));
    }
}
