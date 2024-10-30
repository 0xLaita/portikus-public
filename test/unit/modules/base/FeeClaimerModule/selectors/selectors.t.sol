// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Interfaces
import { IFeeClaimerModule } from "@modules/interfaces/IFeeClaimerModule.sol";

// Mocks
import { MockFeeClaimerModule } from "@mocks/modules/MockFeeClaimerModule.sol";

// Test
import { FeeClaimerModule_Test } from "../FeeClaimerModule.t.sol";

contract FeeClaimerModule_selectors is FeeClaimerModule_Test {
    function test_selectors() public {
        // Get module selectors
        bytes4[10] memory moduleSelectors;
        moduleSelectors[0] = IFeeClaimerModule.withdrawFees.selector;
        moduleSelectors[1] = IFeeClaimerModule.withdrawAllFees.selector;
        moduleSelectors[2] = IFeeClaimerModule.batchWithdrawAllFees.selector;
        moduleSelectors[3] = IFeeClaimerModule.getCollectedFees.selector;
        moduleSelectors[4] = IFeeClaimerModule.batchGetCollectedFees.selector;
        moduleSelectors[5] = IFeeClaimerModule.withdrawProtocolFees.selector;
        moduleSelectors[6] = IFeeClaimerModule.withdrawAllProtocolFees.selector;
        moduleSelectors[7] = IFeeClaimerModule.batchWithdrawAllProtocolFees.selector;
        moduleSelectors[8] = IFeeClaimerModule.setProtocolFeeClaimer.selector;
        moduleSelectors[9] = IFeeClaimerModule.getProtocolFeeClaimer.selector;
        // Check selectors
        assertEq(feeClaimerModule.selectors()[0], moduleSelectors[0]);
        assertEq(feeClaimerModule.selectors()[1], moduleSelectors[1]);
        assertEq(feeClaimerModule.selectors()[2], moduleSelectors[2]);
        assertEq(feeClaimerModule.selectors()[3], moduleSelectors[3]);
        assertEq(feeClaimerModule.selectors()[4], moduleSelectors[4]);
        assertEq(feeClaimerModule.selectors()[5], moduleSelectors[5]);
        assertEq(feeClaimerModule.selectors()[6], moduleSelectors[6]);
        assertEq(feeClaimerModule.selectors()[7], moduleSelectors[7]);
        assertEq(feeClaimerModule.selectors()[8], moduleSelectors[8]);
        assertEq(feeClaimerModule.selectors()[9], moduleSelectors[9]);
    }
}
