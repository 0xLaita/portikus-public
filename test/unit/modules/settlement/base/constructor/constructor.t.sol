// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Mocks
import { MockSettlementModule } from "@mocks/modules/MockSettlementModule.sol";

// Test
import { BaseSettlementModule_Test } from "../BaseSettlementModule.t.sol";

contract BaseSSettlementModule_constructor is BaseSettlementModule_Test {
    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor() public {
        // Create new MockModule
        MockSettlementModule mockModule = new MockSettlementModule("Mock Module 2", "2.0.0", address(this));
        // Check constructor
        assertEq(mockModule.name(), "Mock Module 2");
        assertEq(mockModule.version(), "2.0.0");
        assertEq(address(mockModule.PORTIKUS_V2()), address(this));
    }
}
