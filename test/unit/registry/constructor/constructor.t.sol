// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { Registry } from "@registry/Registry.sol";

// Test
import { Registry_Test } from "../Registry.t.sol";

contract Registry_constructor is Registry_Test {
    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor() public {
        // Create new Registry
        Registry registry = new Registry(users.bob.account);
        // Check constructor
        assertEq(registry.owner(), users.bob.account);
    }
}
