// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Contracts
import { EIP712 } from "@modules/util/EIP712.sol";

// Interfaces
import { IRegistry } from "@interfaces/portikus/IRegistry.sol";
import { IAdapter } from "@adapter/interfaces/IAdapter.sol";
import { IERC173 } from "@adapter/interfaces/IERC173.sol";

// Libraries
import { ModuleManagerLib } from "@modules/libraries/ModuleManagerLib.sol";

//
//      ____  ____  ____  ____________ ____  _______    ___    ____  ___    ____  ________________
//     / __ \/ __ \/ __ \/_  __/  _/ //_/ / / / ___/   /   |  / __ \/   |  / __ \/_  __/ ____/ __ \
//    / /_/ / / / / /_/ / / /  / // ,< / / / /\__ \   / /| | / / / / /| | / /_/ / / / / __/ / /_/ /
//   / ____/ /_/ / _, _/ / / _/ // /| / /_/ /___/ /  / ___ |/ /_/ / ___ |/ ____/ / / / /___/ _, _/
//  /_/    \____/_/ |_| /_/ /___/_/ |_\____//____/  /_/  |_/_____/_/  |_/_/     /_/ /_____/_/ |_|
//
//
/// @title Adapter
/// @notice The base PortikusV2 adapter contract containing core functionality for managing modules,
///         executing module functions and implementing the EIP712 standard for typed structured data hashing
/// @author Laita Labs
contract Adapter is IAdapter, EIP712 {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using ModuleManagerLib for address;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The address of the PortikusV2 contract
    address internal immutable PORTIKUS_V2;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param _owner The owner of the adapter, an owner has the ability to install
    ///        and uninstall modules to the adapter contract
    constructor(address _owner) {
        /// The PortikusV2 address is the factory contract that deploys this adapter
        PORTIKUS_V2 = msg.sender;
        /// Set the owner of the adapter
        _owner.setOwner();
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verifies that the caller is the owner of the adapter,
    ///         reverts if the caller is not the owner with UnauthorizedAccount(msg.sender)
    modifier onlyOwner() {
        ModuleManagerLib.isOwner();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               OWNERSHIP
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC173
    function owner() external view override returns (address) {
        return ModuleManagerLib.owner();
    }

    /// @inheritdoc IERC173
    function transferOwnership(address _newOwner) external override onlyOwner {
        // Transfer ownership of the adapter
        _newOwner.setOwner();
    }

    /*//////////////////////////////////////////////////////////////
                            INSTALL MODULES
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAdapter
    function install(address module) external onlyOwner {
        // Make sure the module is registered in the Portikus V2 registry
        if (!IRegistry(PORTIKUS_V2).isModuleRegistered(address(module))) {
            revert ModuleNotRegistered();
        }
        // Add the module and all of its function selectors to the adapter
        module.install();
    }

    /*//////////////////////////////////////////////////////////////
                           UNINSTALL MODULES
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAdapter
    function uninstall(address module) external onlyOwner {
        // Remove the module and all of its function selectors from the adapter
        module.uninstall();
    }

    /*//////////////////////////////////////////////////////////////
                         GET INSTALLED MODULES
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAdapter
    function getModules() external view returns (Module[] memory) {
        return ModuleManagerLib.getModules();
    }

    /*//////////////////////////////////////////////////////////////
                                FALLBACK
    //////////////////////////////////////////////////////////////*/

    /// @notice Loads a module for the given function selector:
    ///         1. Load the module address from the ModuleManagerLib storage
    ///         2. If the module address is not set, revert
    ///         3. If the module is not registered, revert
    ///         4. If the module address is set and registered, delegatecall the module address with the given calldata
    fallback() external payable {
        ModuleManagerLib.ModuleStorage storage ms = ModuleManagerLib.modulesStorage();
        // Get the module address from the selector
        address module = ms.selectorToModule[msg.sig].moduleAddress;
        address portikus = PORTIKUS_V2; // inline assembly cannot access immutable constants
        assembly {
            // If the module address is not set, revert
            if iszero(module) {
                mstore(0, 0x7252c08c) // error ModuleNotFound()
                revert(0x1c, 0x04)
            }
            // Load free memory pointer
            let x := mload(0x40)
            // Copy signature
            mstore(x, 0x1c5ebe2f) // `isModuleRegistered(address)`
            // Copy module address
            mstore(add(x, 0x20), module)
            // Read the registry, reverting upon module being not registered
            if iszero(
                and( // The arguments of `and` are evaluated from right to left
                    eq(mload(x), 0x01), // Returned `true`
                    staticcall(gas(), portikus, add(x, 0x1c), 0x24, x, 0x20)
                )
            ) {
                mstore(0x00, 0x9c4aee9e) // `ModuleNotRegistered()`
                revert(0x1c, 0x04)
            }
            // Copy calldata to free memory
            calldatacopy(x, 0x00, calldatasize())
            // Delegatecall to the module address with the given calldata
            let result := delegatecall(gas(), module, x, calldatasize(), 0x00, 0x00)
            // Get the size of the returned data
            let size := returndatasize()
            // Copy the returned data to free memory
            returndatacopy(x, 0x00, size)
            // If the delegatecall was not successful, revert with the returned data
            if iszero(result) { revert(x, size) }
            // Return the returned data
            return(x, size)
        }
    }

    /// @notice Allows the adapter to receive ether
    receive() external payable { }
}
