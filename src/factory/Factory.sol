// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Contracts
import { Adapter } from "@adapter/Adapter.sol";

// Interfaces
import { IFactory } from "@interfaces/portikus/IFactory.sol";

/// @title Factory
/// @notice A factory for creating modular executor contracts, it uses create2 to deploy new executor contracts based on
///         a provided salt, allowing for deterministic deployment of executor contracts
contract Factory is IFactory {
    /*//////////////////////////////////////////////////////////////
                                CONSTANT
    //////////////////////////////////////////////////////////////*/

    /// @notice The bytecode of the Adapter contract
    bytes internal constant ADAPTER_BYTECODE = type(Adapter).creationCode;

    /*//////////////////////////////////////////////////////////////
                                  CREATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFactory
    function create(bytes32 _salt, address _owner) external override returns (address adapter) {
        // If the owner is not provided, revert with InvalidOwner()
        if (_owner == address(0)) {
            revert InvalidOwner();
        }
        // Append the owner to the bytecode
        bytes memory data = abi.encodePacked(ADAPTER_BYTECODE, abi.encode(_owner));
        assembly {
            // Deploy the contract using create2
            adapter := create2(0, add(data, 0x20), mload(data), _salt)
            // Revert if the deployment failed
            if iszero(extcodesize(adapter)) {
                mstore(0x0, 0xbe696958) // error AdapterCreationFailed()
                revert(0x1c, 0x04)
            }
        }
        // Emit an event for the created adapter
        emit AdapterCreated(adapter, msg.sender, _owner);
    }
}
