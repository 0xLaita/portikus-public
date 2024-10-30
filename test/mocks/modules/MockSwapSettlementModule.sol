// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { SwapSettlementModule } from "@modules/settlement/SwapSettlementModule.sol";

/// @title Mocked Swap Settlement Module with an additional receive function
contract MockSwapSettlementModule is SwapSettlementModule {
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
        SwapSettlementModule(_name, _version, _portikusV2)
    { }

    /*//////////////////////////////////////////////////////////////
                                RECEIVE
    //////////////////////////////////////////////////////////////*/

    /// @notice Receive function to accept ETH
    receive() external payable { }
}
