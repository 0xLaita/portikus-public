// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { FillableSwapSettlementModule } from "@modules/settlement/FillableSwapSettlementModule.sol";

// Test
import { FillableSwapSettlementModule_Test } from "../FillableSwapSettlementModule.t.sol";

contract FillableSwapSettlementModule_constructor is FillableSwapSettlementModule_Test {
    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor() public {
        // Create new FillableSwapSettlementModule
        FillableSwapSettlementModule newModule =
            new FillableSwapSettlementModule("Fillable Swap Module 2", "2.0.0", address(this));

        // Check constructor
        assertEq(newModule.name(), "Fillable Swap Module 2");
        assertEq(newModule.version(), "2.0.0");
        assertEq(address(newModule.PORTIKUS_V2()), address(this));
    }
}
