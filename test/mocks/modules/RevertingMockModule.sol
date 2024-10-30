// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { BaseModule } from "@modules/base/BaseModule.sol";

/// @title Mock Module
/// @notice Mock module for testing purposes
contract RevertingMockModule is BaseModule {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error MockFunctionRevert();

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

    /// @notice Mock function that reverts
    function mockFunction() external pure returns (bool) {
        revert MockFunctionRevert();
    }

    /*//////////////////////////////////////////////////////////////
                                SELECTORS
    //////////////////////////////////////////////////////////////*/

    function selectors() external pure override returns (bytes4[] memory moduleSelectors) {
        moduleSelectors = new bytes4[](1);
        moduleSelectors[0] = this.mockFunction.selector;
    }
}
