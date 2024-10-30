// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { FillableDirectSettlementModule } from "@modules/settlement/FillableDirectSettlementModule.sol";

// Test
import { FillableDirectSettlementModule_Test } from "../FillableDirectSettlementModule.t.sol";

contract FillableDirectSettlementModule_constructor is FillableDirectSettlementModule_Test {
    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor() public {
        // Create new FillableDirectSettlementModule
        FillableDirectSettlementModule newModule =
            new FillableDirectSettlementModule("Fillable Direct Module 2", "2.0.0", address(this));

        // Check constructor
        assertEq(newModule.name(), "Fillable Direct Module 2");
        assertEq(newModule.version(), "2.0.0");
        assertEq(address(newModule.PORTIKUS_V2()), address(this));
    }
}
