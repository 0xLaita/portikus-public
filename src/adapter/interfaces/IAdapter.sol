// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Interfaces
import { IErrors } from "./IErrors.sol";
import { IERC173 } from "./IERC173.sol";

/// @notice Interface for Portikus V2 adapters
interface IAdapter is IErrors, IERC173 {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The module struct contains the address of the module and its selectors
    struct Module {
        address module;
        bytes4[] selectors;
    }

    /*//////////////////////////////////////////////////////////////
                                INSTALL
    //////////////////////////////////////////////////////////////*/

    /// @notice Add a new module to the adapter, the module must be registered in the Portikus registry
    /// @param module The address of the module to install
    function install(address module) external;

    /*//////////////////////////////////////////////////////////////
                               UNINSTALL
    //////////////////////////////////////////////////////////////*/

    /// @notice Remove a previously installed module from the adapter
    /// @param module The address of the module to uninstall
    function uninstall(address module) external;

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets all installed modules and their selectors
    /// @return modules The installed modules and their selectors
    function getModules() external view returns (Module[] memory modules);
}
