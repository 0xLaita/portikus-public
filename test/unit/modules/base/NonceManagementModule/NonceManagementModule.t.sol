// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { NonceManagementModule } from "@modules/base/NonceManagementModule.sol";

// Test
import { Base_Test } from "@test/Base.t.sol";

abstract contract NonceManagementModule_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////
                                VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev NonceManagementModule contract
    NonceManagementModule public nonceManagementModule;

    /*//////////////////////////////////////////////////////////////
                                  SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        // Setup Base Test
        super.setUp();
        // Deploy NonceManagementModule
        nonceManagementModule = new NonceManagementModule("Mock Module", "1.0.0", address(this));
    }
}
