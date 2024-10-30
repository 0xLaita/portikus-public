// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Mocks
import { MockModule } from "@mocks/modules/MockModule.sol";

// Test
import { BaseModule_Test } from "../BaseModule.t.sol";

contract BaseModule_selectors is BaseModule_Test {
    function test_selectors() public {
        // Get module selectors
        bytes4[2] memory moduleSelectors;
        moduleSelectors[0] = MockModule.mockFunction.selector;
        moduleSelectors[1] = MockModule.getOutput.selector;
        // Check selectors
        assertEq(mockModule.selectors()[0], moduleSelectors[0]);
        assertEq(mockModule.selectors()[1], moduleSelectors[1]);
    }
}
