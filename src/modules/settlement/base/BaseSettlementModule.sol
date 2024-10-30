// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Contracts
import { EIP712 } from "@modules/util/EIP712.sol";
import { BaseModule } from "@modules/base/BaseModule.sol";

// Interfaces
import { ISettlementErrors } from "@modules/settlement/interfaces/ISettlementErrors.sol";
import { IRegistry } from "@interfaces/portikus/IRegistry.sol";

/// @title Base Settlement Module
/// @notice An abstract base module for settlement facets, implementing common errors,
/// EIP712 and authorization checks for agents
abstract contract BaseSettlementModule is BaseModule, EIP712, ISettlementErrors {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param _name The name of the module
    /// @param _version The version of the module
    constructor(
        string memory _name,
        string memory _version,
        address _portikusV2
    )
        BaseModule(_name, _version, _portikusV2)
    { }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks if the msg.sender is an authorized agent in the Portikus V2 registry
    modifier onlyAuthorizedAgent() {
        if (!IRegistry(PORTIKUS_V2).isAgentRegistered(msg.sender)) {
            revert UnauthorizedAgent();
        }
        _;
    }
}
