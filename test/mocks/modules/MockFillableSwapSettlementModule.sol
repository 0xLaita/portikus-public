// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { FillableSwapSettlementModule } from "@modules/settlement/FillableSwapSettlementModule.sol";

/// @title Mocked Swap Settlement Module with an additional receive function
contract MockFillableSwapSettlementModule is FillableSwapSettlementModule {
    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param _name The name of the module
    /// @param _version The version of the module
    /// @param _portikusV2 The PortikusV2 contract address
    constructor(
        string memory _name,
        string memory _version,
        address _portikusV2
    )
        FillableSwapSettlementModule(_name, _version, _portikusV2)
    { }

    /*//////////////////////////////////////////////////////////////
                                RECEIVE
    //////////////////////////////////////////////////////////////*/

    /// @notice Receive function to accept ETH
    receive() external payable { }
}
