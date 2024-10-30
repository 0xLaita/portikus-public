// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { BaseModule } from "@modules/base/BaseModule.sol";

/// @title Mock Module
/// @notice Mock module for testing purposes
contract MockModule is BaseModule {
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
                             MOCK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Mock function for testing purposes
    function mockFunction2() external pure returns (bool) {
        return true;
    }

    /// @notice Mock get output based on input
    function getOutput2(uint256 input) external pure returns (uint256) {
        return input * 2;
    }

    /*//////////////////////////////////////////////////////////////
                                SELECTORS
    //////////////////////////////////////////////////////////////*/

    function selectors() external pure override returns (bytes4[] memory moduleSelectors) {
        moduleSelectors = new bytes4[](2);
        moduleSelectors[0] = this.mockFunction2.selector;
        moduleSelectors[1] = this.getOutput2.selector;
    }
}
