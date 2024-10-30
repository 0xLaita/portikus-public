// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { Adapter } from "@adapter/Adapter.sol";

// Tests
import { Adapter_Test } from "../Adapter.t.sol";

// Test
contract Adapter_owner is Adapter_Test {
    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_owner_ReturnsCorrectOwner() public {
        // Act
        address currentOwner = adapter.owner();

        // Assert
        assertEq(currentOwner, users.admin.account, "Owner should be the admin");
    }

    function test_owner_DeployWithOwner() public {
        // Act
        Adapter newAdapter = new Adapter(users.bob.account);

        // Assert
        assertEq(newAdapter.owner(), users.bob.account, "Owner should be Bob");
    }
}
