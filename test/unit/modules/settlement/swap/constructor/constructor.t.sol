// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { SwapSettlementModule } from "@modules/settlement/SwapSettlementModule.sol";

// Test
import { SwapSettlementModule_Test } from "../SwapSettlementModule.t.sol";

contract SwapSettlementModule_constructor is SwapSettlementModule_Test {
    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor() public {
        // Create new MockModule
        SwapSettlementModule mockModule = new SwapSettlementModule("Mock Module 2", "2.0.0", address(this));
        // Check constructor
        assertEq(mockModule.name(), "Mock Module 2");
        assertEq(mockModule.version(), "2.0.0");
        assertEq(address(mockModule.PORTIKUS_V2()), address(this));
    }
}
