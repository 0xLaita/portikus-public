// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @notice Interface for errors emitted by Portikus adapters
interface IErrors {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a module is not found for the provided selector
    error ModuleNotFound();

    /// @notice Emitted when trying to install a module that is not registered in the Portikus registry
    error ModuleNotRegistered();
}
