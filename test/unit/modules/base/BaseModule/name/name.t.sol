// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Mocks
import { MockModule } from "@mocks/modules/MockModule.sol";

// Test
import { BaseModule_Test } from "../BaseModule.t.sol";

contract BaseModule_name is BaseModule_Test {
    function test_name() public {
        // Check name
        assertEq(mockModule.name(), "Mock Module");
    }
}
