// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Adapter } from "@adapter/Adapter.sol";

// Test
import { Factory_Test } from "../Factory.t.sol";

// Interfaces
import { IFactory } from "@interfaces/portikus/IFactory.sol";

contract Factory_create is Factory_Test {
    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_create_ReturnsCorrectAdapterAddress() public {
        // Arrange
        bytes32 salt = keccak256(abi.encodePacked("salt"));
        address expectedOwner = users.alice.account;

        // Act
        address adapter = factory.create(salt, expectedOwner);

        // Assert
        assertTrue(adapter != address(0), "Adapter address should not be zero");
        assertEq(Ownable(adapter).owner(), expectedOwner, "Adapter owner should match the expected owner");
    }

    function test_create_EmitsAdapterCreatedEvent() public {
        // Arrange
        bytes32 salt = keccak256(abi.encodePacked("salt"));
        address expectedOwner = users.bob.account;

        // Predict the address
        bytes memory bytecode = abi.encodePacked(type(Adapter).creationCode, abi.encode(expectedOwner));
        address expectedAdapter = address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(factory), salt, keccak256(bytecode)))))
        );

        // Expect the event
        vm.expectEmit(true, true, true, true);
        emit IFactory.AdapterCreated(expectedAdapter, address(this), expectedOwner);

        // Act
        address adapter = factory.create(salt, expectedOwner);

        // Assert
        assertTrue(adapter.code.length > 0);
    }

    function test_create_RevertsWhen_ContractAlreadyDeployed() public {
        // Arrange
        bytes32 salt = keccak256(abi.encodePacked("salt"));
        address expectedOwner = users.alice.account;

        // Deploy the first contract successfully
        address adapter1 = factory.create(salt, expectedOwner);
        assertTrue(adapter1.code.length > 0);

        // Act and Assert
        // Expect a revert with AdapterCreationFailed() if we try to deploy again with the same salt
        vm.expectRevert(IFactory.AdapterCreationFailed.selector);

        // Attempt to deploy another contract with the same salt
        factory.create(salt, expectedOwner);
    }

    function test_create_RevertsWhen_NotEnoughGas() public {
        // Arrange
        bytes32 salt = keccak256(abi.encodePacked("salt"));
        address expectedOwner = users.bob.account;

        // Act and Assert
        // Expect a revert due to insufficient gas
        vm.expectRevert();

        // Call the create function with very low gas
        factory.create{ gas: 1000 }(salt, expectedOwner); // Intentionally low gas to simulate out-of-gas
    }

    function test_create_DeploysDeterministicAddress() public {
        // Arrange
        bytes32 salt = keccak256(abi.encodePacked("salt"));
        address expectedOwner = users.charlie.account;

        // Calculate expected address using create2
        bytes memory bytecode = abi.encodePacked(type(Adapter).creationCode, abi.encode(expectedOwner));
        address expectedAdapter = address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(factory), salt, keccak256(bytecode)))))
        );

        // Act
        address adapter = factory.create(salt, expectedOwner);

        // Assert
        assertEq(adapter, expectedAdapter, "Adapter should be deployed at the deterministic address");
    }

    function test_create_RevertsWhen_OwnerIsZeroAddress() public {
        // Arrange
        bytes32 salt = keccak256(abi.encodePacked("salt"));
        address zeroAddress = address(0);

        // Act and Assert
        // Expect a revert with InvalidOwner() if the owner address is zero
        vm.expectRevert(IFactory.InvalidOwner.selector);

        // Attempt to deploy with zero address as the owner
        factory.create(salt, zeroAddress);
    }
}
