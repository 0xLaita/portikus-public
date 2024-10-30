// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { IModule } from "@modules/interfaces/IModule.sol";

/// @title Nonce Management Module Interface
/// @notice Interface for a module that allows users to invalidate nonces and query nonce statuses
interface INonceManagementModule is IModule {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a nonce is invalidated
    /// @param owner The address of the nonce owner
    /// @param nonce The invalidated nonce
    event NonceInvalidated(address indexed owner, uint256 nonce);

    /*//////////////////////////////////////////////////////////////
                            NONCE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Invalidates a specific nonce for the caller
    /// @param nonce The nonce to invalidate
    function invalidateNonce(uint256 nonce) external;

    /// @notice Invalidates multiple nonces for the caller
    /// @param nonces The nonces to invalidate
    function invalidateNonces(uint256[] calldata nonces) external;

    /// @notice Checks if a specific nonce is used for a given owner
    /// @param owner The address of the nonce owner
    /// @param nonce The nonce to check
    /// @return used True if the nonce is used, false otherwise
    function isNonceUsed(address owner, uint256 nonce) external view returns (bool used);

    /// @notice Checks if multiple nonces are used for a given owner
    /// @param owner The address of the nonce owner
    /// @param nonces The nonces to check
    /// @return used An array of booleans indicating whether each nonce is used
    function areNoncesUsed(address owner, uint256[] calldata nonces) external view returns (bool[] memory used);
}
