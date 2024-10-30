// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title IModule
/// @notice Core interfaces that all modules must implement to be compatible with the Portikus protocol
interface IModule {
    /*//////////////////////////////////////////////////////////////
                                METADATA
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the name of the module
    function name() external view returns (string memory);

    /// @notice Returns the version of the module
    function version() external view returns (string memory);

    /*//////////////////////////////////////////////////////////////
                               SELECTORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Used by the executor to determine which functions should be installed
    /// @dev The implementation should not include any of the function selectors defined in the IModule interface itself
    /// @return moduleSelectors An array of function selectors that the module implements
    function selectors() external pure returns (bytes4[] memory moduleSelectors);
}
