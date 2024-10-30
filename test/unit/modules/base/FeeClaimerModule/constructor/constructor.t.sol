// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Mocks
import { MockFeeClaimerModule } from "@mocks/modules/MockFeeClaimerModule.sol";

// Test
import { FeeClaimerModule_Test } from "../FeeClaimerModule.t.sol";

contract FeeClaimerModule_constructor is FeeClaimerModule_Test {
    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor() public {
        // Create new MockModule
        feeClaimerModule = new MockFeeClaimerModule("Mock Module 2", "2.0.0", address(this), users.admin.account);
        // Check constructor
        assertEq(feeClaimerModule.name(), "Mock Module 2");
        assertEq(feeClaimerModule.version(), "2.0.0");
        assertEq(address(feeClaimerModule.PORTIKUS_V2()), address(this));
    }
}
