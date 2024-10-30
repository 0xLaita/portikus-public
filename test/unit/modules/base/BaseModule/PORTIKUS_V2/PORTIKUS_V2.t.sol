// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Mocks
import { MockModule } from "@mocks/modules/MockModule.sol";

// Test
import { BaseModule_Test } from "../BaseModule.t.sol";

contract BaseModule_PORTIKUS_V2 is BaseModule_Test {
    function test_PORTIKUS_V2() public {
        // Check PORTIKUS_V2
        assertEq(address(mockModule.PORTIKUS_V2()), address(this));
    }
}
