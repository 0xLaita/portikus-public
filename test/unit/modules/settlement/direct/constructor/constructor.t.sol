// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { DirectSettlementModule } from "@modules/settlement/DirectSettlementModule.sol";

// Test
import { DirectSettlementModule_Test } from "../DirectSettlementModule.t.sol";

contract DirectSettlementModule_constructor is DirectSettlementModule_Test {
    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor() public {
        // Create new DirectSettlementModule
        DirectSettlementModule newModule = new DirectSettlementModule("Direct Module 2", "2.0.0", address(this));

        // Check constructor
        assertEq(newModule.name(), "Direct Module 2");
        assertEq(newModule.version(), "2.0.0");
        assertEq(address(newModule.PORTIKUS_V2()), address(this));
    }
}
