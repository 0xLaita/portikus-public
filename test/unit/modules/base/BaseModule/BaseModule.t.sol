// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Mocks
import { MockModule } from "@mocks/modules/MockModule.sol";

// Test
import { Base_Test } from "@test/Base.t.sol";

abstract contract BaseModule_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////
                                VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev MockModule contract
    MockModule public mockModule;

    /*//////////////////////////////////////////////////////////////
                                  SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        // Setup Base Test
        super.setUp();
        // Deploy MockModule
        mockModule = new MockModule("Mock Module", "1.0.0", address(this));
    }
}
