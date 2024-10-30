// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Interfaces
import { IModule } from "@modules/interfaces/IModule.sol";
import { IAdapter } from "@adapter/interfaces/IAdapter.sol";

/// @title Module Manager Library
/// @notice A library for managing modules in an adapter contract, heavily inspired by the Diamond Proxy (ERC-2535)
/// @author Laita Labs
library ModuleManagerLib {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a selector from a module is already set
    error SelectorAlreadySet(bytes4 selector, address oldModule);

    /// @notice Emitted when trying to uninstall a module that is not installed
    error ModuleNotInstalled(address module);

    /// @notice Emitted when caller is not the owner
    error UnauthorizedAccount(address account);

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a module is installed
    event ModuleInstalled(address indexed module);

    /// @notice Emitted when a module is uninstalled
    event ModuleUninstalled(address indexed module);

    /// @notice Emitted when the adapter ownership is transferred
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice keccak256(abi.encode(uint256(keccak256("ModuleManagerLib.modules")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 internal constant MODULES_SLOT = 0xcd83f9e468adb540d21d5a132f84948f7344c9d0a65c67a05f93f89a07b57200;

    /// @dev A struct to store a module's address data
    /// @param moduleAddress The address of the module
    /// @param functionSelectorPosition The position of the module's function selectors in the
    ///        ModuleToSelectors.selectors array
    struct ModuleToFacet {
        address moduleAddress;
        uint32 functionSelectorPosition;
    }

    /// @dev A struct to store a module's function selectors data
    /// @param selectors The function selectors of the module
    /// @param moduleAddressPosition The position of the module in the ModuleStorage.modules array
    struct ModuleToSelectors {
        bytes4[] selectors;
        uint32 moduleAddressPosition;
    }

    /// @custom:storage-location erc7201:ModuleManagerLib.modules
    /// @notice The structure that defines the storage layout containing all module data, storage collisions are avoided
    ///         following the ERC-7201 standard
    /// @param moduleToSelectors A mapping of module addresses to their function selectors
    /// @param selectorToModule A mapping of function selectors to their module addresses
    /// @param modules An array of all module addresses
    /// @param owner The adapter owner
    struct ModuleStorage {
        mapping(address => ModuleToSelectors) moduleToSelectors;
        mapping(bytes4 => ModuleToFacet) selectorToModule;
        address[] modules;
        address owner;
    }

    /// @notice Get the storage slot for the ModuleStorage struct
    /// @return ms The ModuleStorage struct storage pointer
    function modulesStorage() internal pure returns (ModuleStorage storage ms) {
        bytes32 storagePointer = MODULES_SLOT;
        assembly {
            ms.slot := storagePointer
        }
    }

    /*//////////////////////////////////////////////////////////////
                                INSTALL
    //////////////////////////////////////////////////////////////*/

    /// @notice Install a module in the adapter, adding all of its function selectors
    /// @param module The address of the module to install
    function install(address module) internal {
        // Get adapter module storage
        ModuleStorage storage ms = modulesStorage();
        // Get module function selectors
        bytes4[] memory selectors = IModule(module).selectors();

        // Add module to modules
        ms.modules.push(module);

        // Set selectors in moduleToSelectors
        ms.moduleToSelectors[module].selectors = selectors;

        // Set module address position in moduleToSelectors
        ms.moduleToSelectors[module].moduleAddressPosition = uint32(ms.modules.length - 1);

        // Set module in selectorToModule
        for (uint32 i = 0; i < selectors.length; i++) {
            address oldModule = ms.selectorToModule[selectors[i]].moduleAddress;
            // If a selector is already set, revert as it would cause a conflict
            if (oldModule != address(0)) {
                // If a selector is already set the owner should uninstall the old module first
                revert SelectorAlreadySet(selectors[i], oldModule);
            }
            ms.selectorToModule[selectors[i]].functionSelectorPosition = i;
            ms.selectorToModule[selectors[i]].moduleAddress = module;
        }
        // emit the module installed event
        emit ModuleInstalled(module);
    }

    /*//////////////////////////////////////////////////////////////
                               UNINSTALL
    //////////////////////////////////////////////////////////////*/

    /// @notice Remove a module from the adapter, removing all of its function selectors
    /// @param module The address of the module to uninstall
    function uninstall(address module) internal {
        // Get adapter module storage
        ModuleStorage storage ms = modulesStorage();
        // Get module function selectors
        bytes4[] memory selectors = ms.moduleToSelectors[module].selectors;

        // Check if the module is actually installed
        if (selectors.length == 0) {
            revert ModuleNotInstalled(module);
        }

        // Get the module position in modules
        uint32 modulePosition = ms.moduleToSelectors[module].moduleAddressPosition;
        // Get the last module position in modules
        uint32 lastModulePosition = uint32(ms.modules.length - 1);
        // If the module is not the last module, swap the module with the last module
        if (modulePosition != lastModulePosition) {
            address lastModule = ms.modules[lastModulePosition];
            ms.modules[modulePosition] = lastModule;
            ms.moduleToSelectors[lastModule].moduleAddressPosition = modulePosition;
        }
        // Remove the last module
        ms.modules.pop();

        // Remove module from moduleToSelectors
        delete ms.moduleToSelectors[module];

        // Remove module from selectorToModule
        for (uint256 i = 0; i < selectors.length; i++) {
            delete ms.selectorToModule[selectors[i]];
        }
        // emit the module uninstalled event
        emit ModuleUninstalled(module);
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get all installed modules and their selectors
    /// @return modules The installed modules and their selectors
    function getModules() external view returns (IAdapter.Module[] memory modules) {
        // Get adapter module storage
        ModuleStorage storage ms = modulesStorage();
        uint256 length = ms.modules.length;
        modules = new IAdapter.Module[](length);
        for (uint256 i = 0; i < length; i++) {
            address module = ms.modules[i];
            bytes4[] memory selectors = ms.moduleToSelectors[module].selectors;
            modules[i] = IAdapter.Module(module, selectors);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 OWNER
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the owner of the adapter
    /// @return owner The owner of the adapter
    function owner() internal view returns (address) {
        // Get adapter module storage
        ModuleStorage storage ms = modulesStorage();
        return ms.owner;
    }

    /// @notice Set the owner of the adapter
    /// @param _owner The new owner of the adapter
    function setOwner(address _owner) internal {
        // Get adapter module storage
        ModuleStorage storage ms = modulesStorage();
        // Cache the old owner
        address oldOwner = ms.owner;
        // Set the new owner
        ms.owner = _owner;
        // Emit the OwnershipTransferred event
        emit OwnershipTransferred(oldOwner, _owner);
    }

    /// @notice Check if the caller is the owner of the adapter, revert if not
    function isOwner() internal view {
        // Get adapter module storage
        ModuleStorage storage ms = modulesStorage();
        if (msg.sender != ms.owner) {
            revert UnauthorizedAccount(msg.sender);
        }
    }
}
