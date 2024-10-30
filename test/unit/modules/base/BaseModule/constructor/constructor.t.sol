// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Mocks
import { MockModule } from "@mocks/modules/MockModule.sol";

// Test
import { BaseModule_Test } from "../BaseModule.t.sol";

contract BaseModule_constructor is BaseModule_Test {
    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor() public {
        // Create new MockModule
        mockModule = new MockModule("Mock Module 2", "2.0.0", address(this));
        // Check constructor
        assertEq(mockModule.name(), "Mock Module 2");
        assertEq(mockModule.version(), "2.0.0");
        assertEq(address(mockModule.PORTIKUS_V2()), address(this));
    }
}
