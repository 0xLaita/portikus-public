// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Test
import { Registry_Test } from "../Registry.t.sol";

contract Registry_registerModule is Registry_Test {
    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_registerModule_SuccessfullyRegistersNewModules() public {
        // Initialize new modules
        address[] memory newModules = new address[](2);

        // Arrange
        newModules[0] = users.charlie.account;
        newModules[1] = users.bob.account;

        // Act
        vm.startPrank(users.admin.account);
        registry.registerModule(newModules);

        // Assert
        assertTrue(registry.isModuleRegistered(users.charlie.account), "Charlie should be registered");
        assertTrue(registry.isModuleRegistered(users.bob.account), "Bob should be registered");

        address[] memory registeredModules = registry.getModules();
        assertEq(registeredModules.length, 2, "There should be 2 registered modules");
        assertEq(registeredModules[0], users.charlie.account, "First module should be Charlie");
        assertEq(registeredModules[1], users.bob.account, "Second module should be Bob");
    }

    function test_registerModule_DoesNotRegisterAlreadyRegisteredModule() public {
        // Initialize new modules
        address[] memory newModules = new address[](1);

        // Arrange
        newModules[0] = users.charlie.account;

        // Act
        vm.startPrank(users.admin.account);
        registry.registerModule(newModules);

        // Try to register the same module again
        registry.registerModule(newModules);

        // Assert
        assertTrue(registry.isModuleRegistered(users.charlie.account), "Charlie should be registered");

        address[] memory registeredModules = registry.getModules();
        assertEq(registeredModules.length, 1, "There should only be 1 registered module");
    }

    function test_registerModule_RevertsWhen_CalledByNonOwner() public {
        // Initialize new modules
        address[] memory newModules = new address[](1);

        // Arrange
        newModules[0] = users.charlie.account;

        // Act and Assert
        vm.expectRevert();
        vm.startPrank(users.bob.account);
        registry.registerModule(newModules);
    }
}
