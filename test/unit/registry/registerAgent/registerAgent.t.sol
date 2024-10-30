// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Test
import { Registry_Test } from "../Registry.t.sol";

contract Registry_registerAgent is Registry_Test {
    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_registerAgent_SuccessfullyRegistersNewAgents() public {
        // Initialize new agents
        address[] memory newAgents = new address[](2);

        // Arrange
        newAgents[0] = users.alice.account;
        newAgents[1] = users.bob.account;

        // Act
        vm.startPrank(users.admin.account);
        registry.registerAgent(newAgents);

        // Assert
        assertTrue(registry.isAgentRegistered(users.alice.account), "Alice should be registered");
        assertTrue(registry.isAgentRegistered(users.bob.account), "Bob should be registered");

        address[] memory registeredAgents = registry.getAgents();
        assertEq(registeredAgents.length, 2, "There should be 2 registered agents");
        assertEq(registeredAgents[0], users.alice.account, "First agent should be Alice");
        assertEq(registeredAgents[1], users.bob.account, "Second agent should be Bob");
    }

    function test_registerAgent_DoesNotRegisterAlreadyRegisteredAgent() public {
        // Initialize new agents
        address[] memory newAgents = new address[](1);

        // Arrange
        newAgents[0] = users.alice.account;

        // Act
        vm.startPrank(users.admin.account);
        registry.registerAgent(newAgents);

        // Try to register the same agent again
        registry.registerAgent(newAgents);

        // Assert
        assertTrue(registry.isAgentRegistered(users.alice.account), "Alice should be registered");

        address[] memory registeredAgents = registry.getAgents();
        assertEq(registeredAgents.length, 1, "There should only be 1 registered agent");
    }

    function test_registerAgent_RevertsWhen_CalledByNonOwner() public {
        // Initialize new agents
        address[] memory newAgents = new address[](1);

        // Arrange
        newAgents[0] = users.alice.account;

        // Act and Assert
        vm.expectRevert();
        vm.startPrank(users.bob.account);
        registry.registerAgent(newAgents);
    }
}
