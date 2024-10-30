// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Tests
import { Adapter_Test } from "../Adapter.t.sol";

// Interfaces
import { IAdapter } from "@adapter/interfaces/IAdapter.sol";
import { IModule } from "@modules/interfaces/IModule.sol";

// Mocks
import { MockModule } from "@mocks/modules/MockModule.sol";
import { MockModule as MockModule2 } from "@mocks/modules/MockModule2.sol";

contract Adapter_getModules is Adapter_Test {
    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getModules_ReturnsEmptyArrayWhenNoModulesInstalled() public {
        // Act
        IAdapter.Module[] memory modules = adapter.getModules();

        // Assert
        assertEq(modules.length, 0, "Should return an empty array when no modules are installed");
    }

    function test_getModules_ReturnsSingleModuleWhenOneInstalled() public {
        // Arrange
        address moduleAddress = address(mockModule);
        vm.startPrank(users.admin.account);
        adapter.install(moduleAddress);

        // Act
        IAdapter.Module[] memory modules = adapter.getModules();

        // Assert
        assertEq(modules.length, 1, "Should return one module");
        assertEq(modules[0].module, moduleAddress, "Should return the correct module address");
        assertEq(modules[0].selectors.length, 2, "Should return the correct number of selectors");
        assertTrue(
            contains(modules[0].selectors, MockModule(moduleAddress).mockFunction.selector),
            "Should contain mockFunction selector"
        );
        assertTrue(
            contains(modules[0].selectors, MockModule(moduleAddress).getOutput.selector),
            "Should contain getOutput selector"
        );
    }

    function test_getModules_ReturnsMultipleModulesWhenMultipleInstalled() public {
        // Arrange
        address moduleAddress1 = address(mockModule);
        MockModule2 mockModule2 = new MockModule2("Mock Module 2", "1.0.0", address(portikusV2));
        address moduleAddress2 = address(mockModule2);

        // Register and install modules
        vm.startPrank(users.admin.account);
        address[] memory modules = new address[](1);
        modules[0] = moduleAddress2;
        portikusV2.registerModule(modules);
        adapter.install(moduleAddress1);
        adapter.install(moduleAddress2);

        // Act
        IAdapter.Module[] memory installedModules = adapter.getModules();

        // Assert
        assertEq(installedModules.length, 2, "Should return two modules");

        // Check first module
        assertEq(installedModules[0].module, moduleAddress1, "Should return the correct first module address");
        assertEq(
            installedModules[0].selectors.length, 2, "Should return the correct number of selectors for first module"
        );

        // Check second module
        assertEq(installedModules[1].module, moduleAddress2, "Should return the correct second module address");
        assertEq(
            installedModules[1].selectors.length, 2, "Should return the correct number of selectors for second module"
        );
    }

    function test_getModules_CorrectlyReflectsUninstalledModule() public {
        // Arrange
        address moduleAddress1 = address(mockModule);
        MockModule2 mockModule2 = new MockModule2("Mock Module 2", "1.0.0", address(portikusV2));
        address moduleAddress2 = address(mockModule2);

        // Register and install modules
        vm.startPrank(users.admin.account);
        address[] memory modules = new address[](1);
        modules[0] = moduleAddress2;
        portikusV2.registerModule(modules);
        adapter.install(moduleAddress1);
        adapter.install(moduleAddress2);

        // Act
        adapter.uninstall(moduleAddress1);
        IAdapter.Module[] memory remainingModules = adapter.getModules();

        // Assert
        assertEq(remainingModules.length, 1, "Should return one module after uninstallation");
        assertEq(remainingModules[0].module, moduleAddress2, "Should return the correct remaining module address");
    }

    function test_getModules_CorrectlyReflectsAllModulesUninstalled() public {
        // Arrange
        address moduleAddress1 = address(mockModule);
        MockModule2 mockModule2 = new MockModule2("Mock Module 2", "1.0.0", address(portikusV2));
        address moduleAddress2 = address(mockModule2);

        // Register and install modules
        vm.startPrank(users.admin.account);
        address[] memory modules = new address[](1);
        modules[0] = moduleAddress2;
        portikusV2.registerModule(modules);
        adapter.install(moduleAddress1);
        adapter.install(moduleAddress2);

        // Act
        adapter.uninstall(moduleAddress1);
        adapter.uninstall(moduleAddress2);
        IAdapter.Module[] memory remainingModules = adapter.getModules();

        // Assert
        assertEq(remainingModules.length, 0, "Should return empty array after all modules are uninstalled");
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    // Helper function to check if a bytes4 array contains a specific selector
    function contains(bytes4[] memory array, bytes4 searchFor) internal pure returns (bool) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == searchFor) {
                return true;
            }
        }
        return false;
    }
}
