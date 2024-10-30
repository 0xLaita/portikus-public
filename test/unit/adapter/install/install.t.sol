// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Tests
import { Adapter_Test } from "../Adapter.t.sol";

// Interfaces
import { IModule } from "@modules/interfaces/IModule.sol";

// Mocks
import { MockModule } from "@mocks/modules/MockModule.sol";

contract Adapter_install is Adapter_Test {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the module is not registered in the Portikus V2 registry
    error ModuleNotRegistered();

    /// @notice Emitted when a selector from a module is already set
    error SelectorAlreadySet(bytes4 selector, address oldModule);

    /// @notice Emitted when caller is not the owner
    error UnauthorizedAccount(address account);

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_install_SuccessfullyInstallsModule() public {
        // Arrange
        address moduleAddress = address(mockModule);

        // Act
        vm.startPrank(users.admin.account);
        adapter.install(moduleAddress);

        // Verify mockFunction
        bool result = MockModule(moduleAddress).mockFunction();
        assertTrue(result, "mockFunction should return true");

        // Verify getOutput
        uint256 input = 42;
        uint256 expectedOutput = input * 2;
        uint256 output = MockModule(moduleAddress).getOutput(input);
        assertEq(output, expectedOutput, "getOutput should return input multiplied by 2");
    }

    function test_install_AfterInstall_CallsThroughAdapter() public {
        // Arrange
        address moduleAddress = address(mockModule);

        // Act
        vm.startPrank(users.admin.account);
        adapter.install(moduleAddress);

        // Act and Assert
        // Call mockFunction through the adapter
        (bool success, bytes memory result) =
            address(adapter).call(abi.encodeWithSelector(MockModule(moduleAddress).mockFunction.selector));
        assertTrue(success, "mockFunction call through adapter should succeed");
        assertEq(abi.decode(result, (bool)), true, "mockFunction call should return true");

        // Call getOutput through the adapter
        uint256 input = 42;
        uint256 expectedOutput = input * 2;
        (success, result) =
            address(adapter).call(abi.encodeWithSelector(MockModule(moduleAddress).getOutput.selector, input));
        assertTrue(success, "getOutput call through adapter should succeed");
        assertEq(abi.decode(result, (uint256)), expectedOutput, "getOutput call should return input multiplied by 2");
    }

    function test_install_RevertsWhen_ModuleNotRegistered() public {
        // Arrange
        address unregisteredModule = address(new MockModule("Unregistered Module", "1.0.0", address(portikusV2)));

        // Act and Assert
        vm.startPrank(users.admin.account);
        vm.expectRevert(ModuleNotRegistered.selector);
        adapter.install(unregisteredModule);
    }

    function test_install_RevertsWhen_ModuleAlreadyInstalled() public {
        // Arrange
        address moduleAddress = address(mockModule);

        // Act
        vm.startPrank(users.admin.account);
        adapter.install(moduleAddress);

        // Act and Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                SelectorAlreadySet.selector, MockModule(moduleAddress).mockFunction.selector, moduleAddress
            )
        );
        adapter.install(moduleAddress);
    }

    function test_install_RevertsWhen_CalledByNonOwner() public {
        // Arrange
        address moduleAddress = address(mockModule);

        // Act and Assert
        vm.startPrank(users.bob.account);
        vm.expectRevert(abi.encodeWithSelector(UnauthorizedAccount.selector, users.bob.account));
        adapter.install(moduleAddress);
    }
}
