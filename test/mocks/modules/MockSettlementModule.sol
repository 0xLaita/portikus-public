// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { BaseSettlementModule } from "@modules/settlement/base/BaseSettlementModule.sol";

/// @title Mock Module
/// @notice Mock module for testing purposes
contract MockSettlementModule is BaseSettlementModule {
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
        BaseSettlementModule(_name, _version, _portikusV2)
    { }

    /*//////////////////////////////////////////////////////////////
                             MOCK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Mock function for testing purposes
    function mockFunction() external pure returns (bool) {
        return true;
    }

    /// @notice Mock get output based on input
    function getOutput(uint256 input) external pure returns (uint256) {
        return input * 2;
    }

    /// @notice Mock function using onlyAuthorizedAgent modifier for testing purposes
    function mockFunctionWithModifier() external onlyAuthorizedAgent returns (uint256) {
        return 1;
    }

    /*//////////////////////////////////////////////////////////////
                                SELECTORS
    //////////////////////////////////////////////////////////////*/

    function selectors() external pure override returns (bytes4[] memory moduleSelectors) {
        moduleSelectors = new bytes4[](2);
        moduleSelectors[0] = this.mockFunction.selector;
        moduleSelectors[1] = this.getOutput.selector;
    }
}
