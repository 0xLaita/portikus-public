// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Test
import { Registry_Test } from "../Registry.t.sol";

contract Registry_getAgents is Registry_Test {
    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getAgents_ReturnsRegisteredAgents() public {
        // Initialize new agents
        address[] memory newAgents = new address[](2);

        // Arrange
        newAgents[0] = users.alice.account;
        newAgents[1] = users.bob.account;

        vm.startPrank(users.admin.account);
        registry.registerAgent(newAgents);

        // Act
        address[] memory registeredAgents = registry.getAgents();

        // Assert
        assertEq(registeredAgents.length, 2, "There should be 2 registered agents");
        assertEq(registeredAgents[0], users.alice.account, "First agent should be Alice");
        assertEq(registeredAgents[1], users.bob.account, "Second agent should be Bob");
    }
}
