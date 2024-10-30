// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { Registry } from "@registry/Registry.sol";

// Test
import { Base_Test } from "@test/Base.t.sol";

abstract contract Registry_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev Registry contract
    Registry public registry;

    /*//////////////////////////////////////////////////////////////
                                  SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        // Setup Base Test
        super.setUp();
        // Deploy registry
        registry = new Registry(users.admin.account);
    }
}
