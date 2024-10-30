// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Test
import { Registry_Test } from "../Registry.t.sol";

contract Registry_unregisterAgent is Registry_Test {
    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_unregisterAgent_SuccessfullyUnregistersAgent() public {
        // Initialize new agents
        address[] memory newAgents = new address[](1);

        // Arrange
        newAgents[0] = users.alice.account;

        // Register the agent first
        vm.startPrank(users.admin.account);
        registry.registerAgent(newAgents);

        // Act
        registry.unregisterAgent(newAgents);

        // Assert
        assertFalse(registry.isAgentRegistered(users.alice.account), "Alice should be unregistered");

        address[] memory registeredAgents = registry.getAgents();
        assertEq(registeredAgents.length, 0, "There should be no registered agents");
    }

    function test_unregisterAgent_DoesNothingForNonExistentAgent() public {
        // Act and Assert
        // Unregistering a non-existent agent should not revert or change state
        vm.startPrank(users.admin.account);
        // Initialize new agents
        address[] memory newAgents = new address[](1);
        newAgents[0] = users.alice.account;
        registry.unregisterAgent(newAgents);

        assertFalse(registry.isAgentRegistered(users.alice.account), "Alice should remain unregistered");

        address[] memory registeredAgents = registry.getAgents();
        assertEq(registeredAgents.length, 0, "There should be no registered agents");
    }

    function test_unregisterAgent_RevertsWhen_CalledByNonOwner() public {
        // Initialize new agents
        address[] memory newAgents = new address[](1);

        // Arrange
        newAgents[0] = users.alice.account;

        // Register the agent first
        vm.startPrank(users.admin.account);
        registry.registerAgent(newAgents);

        // Act and Assert
        vm.expectRevert();
        vm.startPrank(users.bob.account);
        registry.unregisterAgent(newAgents);
    }
}
