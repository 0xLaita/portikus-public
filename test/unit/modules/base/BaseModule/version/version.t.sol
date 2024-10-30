// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Mocks
import { MockModule } from "@mocks/modules/MockModule.sol";

// Test
import { BaseModule_Test } from "../BaseModule.t.sol";

contract BaseModule_version is BaseModule_Test {
    function test_version() public {
        // Check version
        assertEq(mockModule.version(), "1.0.0");
    }
}
