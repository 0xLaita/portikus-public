// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Tests
import { Adapter_Test } from "../Adapter.t.sol";

// Interfaces
import { IModule } from "@modules/interfaces/IModule.sol";

// Mocks
import { MockModule } from "@mocks/modules/MockModule.sol";
import { MockModule as MockModule2 } from "@mocks/modules/MockModule2.sol";

contract Adapter_uninstall is Adapter_Test {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when trying to uninstall a module that is not installed
    error ModuleNotInstalled(address module);

    /// @notice Emitted when caller is not the owner
    error UnauthorizedAccount(address account);

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_uninstall_SuccessfullyUninstallsModule() public {
        // Arrange
        address moduleAddress = address(mockModule);
        // First install the module
        vm.startPrank(users.admin.account);
        adapter.install(moduleAddress);

        // Act
        adapter.uninstall(moduleAddress);

        // Act and Assert
        // Call mockFunction through the adapter should revert
        (bool success,) = address(adapter).call(abi.encodeWithSelector(MockModule(moduleAddress).mockFunction.selector));
        assertFalse(success, "mockFunction call through adapter should fail after uninstallation");

        // Call getOutput through the adapter should revert
        uint256 input = 42;
        (success,) = address(adapter).call(abi.encodeWithSelector(MockModule(moduleAddress).getOutput.selector, input));
        assertFalse(success, "getOutput call through adapter should fail after uninstallation");
    }

    function test_uninstall_SuccessfullyUninstallsModule_MultipleInstalled() public {
        // Arrange
        address moduleAddress = address(mockModule);
        // First install the module
        vm.startPrank(users.admin.account);
        adapter.install(moduleAddress);
        // Create and install another module
        MockModule2 mockModule2 = new MockModule2("Mock Module 2", "1.0.0", address(portikusV2));
        address moduleAddress2 = address(mockModule2);
        // Register module
        address[] memory modules = new address[](1);
        modules[0] = moduleAddress2;
        portikusV2.registerModule(modules);
        // Install the second module
        adapter.install(moduleAddress2);

        // Act
        adapter.uninstall(moduleAddress);

        // Act and Assert
        // Call mockFunction through the adapter should revert
        (bool success,) = address(adapter).call(abi.encodeWithSelector(MockModule(moduleAddress).mockFunction.selector));
        assertFalse(success, "mockFunction call through adapter should fail after uninstallation");

        // Call getOutput through the adapter should revert
        uint256 input = 42;
        (success,) = address(adapter).call(abi.encodeWithSelector(MockModule(moduleAddress).getOutput.selector, input));
        assertFalse(success, "getOutput call through adapter should fail after uninstallation");
    }

    function test_uninstall_RevertsWhen_ModuleNotInstalled() public {
        // Arrange
        address moduleAddress = address(mockModule);

        // Act and Assert
        vm.startPrank(users.admin.account);
        vm.expectRevert(abi.encodeWithSelector(ModuleNotInstalled.selector, moduleAddress));
        adapter.uninstall(moduleAddress);
    }

    function test_uninstall_RevertsWhen_CalledByNonOwner() public {
        // Arrange
        address moduleAddress = address(mockModule);

        // First install the module
        vm.startPrank(users.admin.account);
        adapter.install(moduleAddress);

        // Act and Assert
        vm.startPrank(users.bob.account);
        vm.expectRevert(abi.encodeWithSelector(UnauthorizedAccount.selector, users.bob.account));
        adapter.uninstall(moduleAddress);
    }
}
