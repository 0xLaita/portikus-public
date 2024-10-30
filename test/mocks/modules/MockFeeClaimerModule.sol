// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { FeeClaimerModule } from "@modules/base/FeeClaimerModule.sol";

// Libraries
import { FeeManagerLib } from "@modules/libraries/FeeManagerLib.sol";
import { ModuleManagerLib } from "@modules/libraries/ModuleManagerLib.sol";

/// @title Mock Module
/// @notice Mock module for testing purposes
contract MockFeeClaimerModule is FeeClaimerModule {
    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param _name The name of the module
    /// @param _version The version of the module
    constructor(
        string memory _name,
        string memory _version,
        address _portikusV2,
        address owner
    )
        FeeClaimerModule(_name, _version, _portikusV2)
    {
        ModuleManagerLib.setOwner(owner);
    }

    /*//////////////////////////////////////////////////////////////
                                RECEIVE
    //////////////////////////////////////////////////////////////*/

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                                COLLECT
    //////////////////////////////////////////////////////////////*/

    // Mock function to collect fees
    function collectFees(address partner, address token, uint256 amount) external {
        FeeManagerLib.collectFees(partner, token, amount);
    }
}
