// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Test
import { Registry_Test } from "../Registry.t.sol";

contract Registry_unregisterModule is Registry_Test {
    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_unregisterModule_SuccessfullyUnregistersModule() public {
        // Initialize new modules
        address[] memory newModules = new address[](1);

        // Arrange
        newModules[0] = users.charlie.account;

        // Register the module first
        vm.startPrank(users.admin.account);
        registry.registerModule(newModules);

        // Act
        registry.unregisterModule(newModules);

        // Assert
        assertFalse(registry.isModuleRegistered(users.charlie.account), "Charlie should be unregistered");

        address[] memory registeredModules = registry.getModules();
        assertEq(registeredModules.length, 0, "There should be no registered modules");
    }

    function test_unregisterModule_DoesNothingForNonExistentModule() public {
        // Act and Assert
        // Unregistering a non-existent module should not revert or change state
        vm.startPrank(users.admin.account);
        // Initialize new modules
        address[] memory newModules = new address[](1);
        newModules[0] = users.charlie.account;
        registry.unregisterModule(newModules);

        assertFalse(registry.isModuleRegistered(users.charlie.account), "Charlie should remain unregistered");

        address[] memory registeredModules = registry.getModules();
        assertEq(registeredModules.length, 0, "There should be no registered modules");
    }

    function test_unregisterModule_RevertsWhen_CalledByNonOwner() public {
        // Initialize new modules
        address[] memory newModules = new address[](1);

        // Arrange
        newModules[0] = users.charlie.account;

        // Register the module first
        vm.startPrank(users.admin.account);
        registry.registerModule(newModules);

        // Act and Assert
        vm.expectRevert();
        vm.startPrank(users.bob.account);
        registry.unregisterModule(newModules);
    }
}
