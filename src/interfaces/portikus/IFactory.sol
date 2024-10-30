// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @notice Interface for the Portikus V2 factory
interface IFactory {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the CREATE2 deployment of an Adapter contract fails
    error AdapterCreationFailed();

    /// @notice Emits an error when passed owner is the zero address
    error InvalidOwner();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new Adapter contract is deployed
    event AdapterCreated(address indexed adapter, address indexed creator, address indexed owner);

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys a new base Adapter contract with CREATE2 using the provided salt
    /// @param _salt The salt to use for CREATE2
    /// @param _owner The owner of the deployed Adapter contract, defaults to the caller if not provided
    /// @return The address of the deployed Adapter contract
    function create(bytes32 _salt, address _owner) external returns (address);
}
