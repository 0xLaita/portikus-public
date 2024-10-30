// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Tests
import { Adapter_Test } from "../Adapter.t.sol";

// Interfaces
import { IModule } from "@modules/interfaces/IModule.sol";

// Mocks
import { MockModule } from "@mocks/modules/MockModule.sol";
import { RevertingMockModule } from "@mocks/modules/RevertingMockModule.sol";

contract Adapter_fallback is Adapter_Test {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the module is not found for a given function selector
    error ModuleNotFound();

    /// @notice The revert reason for the mock function
    error MockFunctionRevert();

    /// @notice Emitted when trying to install a module that is not registered in the Portikus registry
    error ModuleNotRegistered();

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_fallback_SuccessfullyDelegatesToModule() public {
        // Arrange
        address moduleAddress = address(mockModule);

        // Install the module
        vm.startPrank(users.admin.account);
        adapter.install(moduleAddress);

        // Act
        (bool success, bytes memory result) =
            address(adapter).call(abi.encodeWithSelector(MockModule(moduleAddress).mockFunction.selector));

        // Assert
        assertTrue(success, "Call through fallback should succeed");
        assertEq(abi.decode(result, (bool)), true, "mockFunction should return true");
    }

    function test_fallback_RevertsWhen_ModuleNotFound() public {
        // Act and Assert
        vm.startPrank(users.admin.account);
        vm.expectRevert(ModuleNotFound.selector);
        (bool success,) =
            address(adapter).call{ value: 0 }(abi.encodeWithSelector(bytes4(keccak256("nonExistentFunction()"))));
        assertTrue(success);
    }

    function test_fallback_RevertsWhen_DelegateCallFails() public {
        // Arrange
        // Create a module that will always revert
        address moduleAddress = address(new RevertingMockModule("RevertingMockModule", "1.0.0", address(portikusV2)));
        // Register the module
        vm.startPrank(users.admin.account);
        address[] memory modules = new address[](1);
        modules[0] = moduleAddress;
        portikusV2.registerModule(modules);

        // Act
        vm.startPrank(users.admin.account);
        adapter.install(moduleAddress);

        // Act and Assert
        vm.expectRevert(MockFunctionRevert.selector);
        // solhint-disable-next-line return-value
        (bool success,) = address(adapter).call{ value: 0 }(
            abi.encodeWithSelector(RevertingMockModule(moduleAddress).mockFunction.selector)
        );
        assertTrue(success);
    }

    function test_fallback_RevertsWhen_ModuleNotRegistered() public {
        // Arrange
        address moduleAddress = address(mockModule);

        // Install the module
        vm.startPrank(users.admin.account);
        adapter.install(moduleAddress);

        // Unregister the module
        vm.startPrank(users.admin.account);
        address[] memory modules = new address[](1);
        modules[0] = moduleAddress;
        portikusV2.unregisterModule(modules);

        // Act and Assert
        vm.expectRevert(ModuleNotRegistered.selector);

        (bool success,) = address(adapter).call(abi.encodeWithSelector(MockModule(moduleAddress).mockFunction.selector));

        assertTrue(success);
    }
}
