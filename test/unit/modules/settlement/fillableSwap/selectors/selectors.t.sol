// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Mocks
import { MockModule } from "@mocks/modules/MockModule.sol";

// Contracts
import { FillableSwapSettlementModule } from "@modules/settlement/FillableSwapSettlementModule.sol";

// Test
import { FillableSwapSettlementModule_Test } from "../FillableSwapSettlementModule.t.sol";

contract FillableSwapSettlementModule_selectors is FillableSwapSettlementModule_Test {
    function test_selectors() public {
        // Get module selectors
        bytes4[3] memory moduleSelectors;
        moduleSelectors[0] = FillableSwapSettlementModule.swapSettleFillable.selector;
        moduleSelectors[1] = FillableSwapSettlementModule.swapSettleFillableBatch.selector;
        moduleSelectors[2] = FillableSwapSettlementModule.swapFilledAmount.selector;
        // Check selectors
        assertEq(module.selectors()[0], moduleSelectors[0]);
        assertEq(module.selectors()[1], moduleSelectors[1]);
        assertEq(module.selectors()[2], moduleSelectors[2]);
    }
}
