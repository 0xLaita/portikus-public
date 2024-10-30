// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { MockFeeClaimerModule } from "@mocks/modules/MockFeeClaimerModule.sol";

// Test
import { Base_Test } from "@test/Base.t.sol";

abstract contract FeeClaimerModule_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////
                                VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev FeeClaimerModule contract
    MockFeeClaimerModule public feeClaimerModule;

    /*//////////////////////////////////////////////////////////////
                                  SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        // Setup Base Test
        super.setUp();
        // Deploy FeeClaimerModule
        feeClaimerModule = new MockFeeClaimerModule("Fee Module", "1.0.0", address(this), users.admin.account);
    }
}
