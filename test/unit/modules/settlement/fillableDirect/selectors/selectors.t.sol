// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Mocks
import { MockModule } from "@mocks/modules/MockModule.sol";

// Contracts
import { FillableDirectSettlementModule } from "@modules/settlement/FillableDirectSettlementModule.sol";

// Test
import { FillableDirectSettlementModule_Test } from "../FillableDirectSettlementModule.t.sol";

contract FillableDirectSettlementModule_selectors is FillableDirectSettlementModule_Test {
    function test_selectors() public {
        // Get module selectors
        bytes4[3] memory moduleSelectors;
        moduleSelectors[0] = FillableDirectSettlementModule.directSettleFillable.selector;
        moduleSelectors[1] = FillableDirectSettlementModule.directSettleFillableBatch.selector;
        moduleSelectors[2] = FillableDirectSettlementModule.directFilledAmount.selector;
        // Check selectors
        assertEq(module.selectors()[0], moduleSelectors[0]);
        assertEq(module.selectors()[1], moduleSelectors[1]);
        assertEq(module.selectors()[2], moduleSelectors[2]);
    }
}
