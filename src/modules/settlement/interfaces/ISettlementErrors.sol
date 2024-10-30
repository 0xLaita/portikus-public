// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @notice Interface for errors emitted by Settlement modules
interface ISettlementErrors {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the order received insufficient amount of tokens
    error InsufficientReturnAmount();

    /// @notice Emitted when the order deadline has expired
    error DeadlineExpired();

    /// @notice Emitted when the msg.sender is not an authorized agent
    error UnauthorizedAgent();
}
