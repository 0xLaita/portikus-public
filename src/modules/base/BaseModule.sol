// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Contracts
import { ReentrancyGuardTransient as ReentrancyGuard } from "@openzeppelin/utils/ReentrancyGuardTransient.sol";

// Interfaces
import { IModule } from "@modules/interfaces/IModule.sol";

// Libraries
import { ShortStrings, ShortString } from "@openzeppelin/contracts/utils/ShortStrings.sol";

/// @title Base Module
/// @notice An abstract base module to be inherited by all modules in the Portikus V2 protocol
abstract contract BaseModule is ReentrancyGuard, IModule {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using ShortStrings for string;
    using ShortStrings for ShortString;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The name and version of the module
    ShortString private immutable NAME;
    ShortString private immutable VERSION;
    /// @notice The address of the Portikus V2 contract
    address public immutable PORTIKUS_V2;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param _name The name of the module
    /// @param _version The version of the module
    constructor(string memory _name, string memory _version, address _portikusV2) {
        NAME = _name.toShortString();
        VERSION = _version.toShortString();
        PORTIKUS_V2 = _portikusV2;
    }

    /*//////////////////////////////////////////////////////////////
                                METADATA
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IModule
    function name() external view virtual override returns (string memory) {
        return NAME.toString();
    }

    /// @inheritdoc IModule
    function version() external view virtual override returns (string memory) {
        return VERSION.toString();
    }

    /*//////////////////////////////////////////////////////////////
                                SELECTORS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IModule
    function selectors() external pure virtual override returns (bytes4[] memory moduleSelectors);
}
