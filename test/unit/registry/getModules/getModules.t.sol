// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Test
import { Registry_Test } from "../Registry.t.sol";

contract Registry_getModules is Registry_Test {
    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getModules_ReturnsRegisteredModules() public {
        // Initialize new modules
        address[] memory newModules = new address[](2);

        // Arrange
        newModules[0] = users.charlie.account;
        newModules[1] = users.bob.account;

        vm.startPrank(users.admin.account);
        registry.registerModule(newModules);

        // Act
        address[] memory registeredModules = registry.getModules();

        // Assert
        assertEq(registeredModules.length, 2, "There should be 2 registered modules");
        assertEq(registeredModules[0], users.charlie.account, "First module should be Charlie");
        assertEq(registeredModules[1], users.bob.account, "Second module should be Bob");
    }
}
