// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { IModule } from "@modules/interfaces/IModule.sol";

/// @title Fee Claimer Module Interface
/// @notice Interface for the Fee Claimer Module, which allows partners to claim their collected fees
interface IFeeClaimerModule is IModule {
    /*//////////////////////////////////////////////////////////////
                              PARTNER FEES
    //////////////////////////////////////////////////////////////*/

    /// @notice Allows a partner to withdraw a specific amount of their collected fees for a token
    /// @param token The address of the token to withdraw
    /// @param amount The amount of fees to withdraw
    /// @param recipient The address to send the fees to
    function withdrawFees(address token, uint256 amount, address recipient) external;

    /// @notice Allows a partner to withdraw all their collected fees for a specific token
    /// @param token The address of the token to withdraw (use address(0) for ETH)
    /// @param recipient The address to send the fees to
    /// @return amount The amount of fees withdrawn
    function withdrawAllFees(address token, address recipient) external returns (uint256 amount);

    /// @notice Allows a partner to withdraw all fees for multiple tokens in a single transaction
    /// @param tokens An array of token addresses to withdraw
    /// @param recipient The address to send the fees to
    function batchWithdrawAllFees(address[] calldata tokens, address recipient) external;

    /// @notice Gets the amount of collected fees for a partner and token
    /// @param partner The address of the partner
    /// @param token The address of the token
    /// @return The amount of collected fees
    function getCollectedFees(address partner, address token) external view returns (uint256);

    /// @notice Gets collected fees for a partner for specified tokens
    /// @param partner The address of the partner
    /// @param tokens An array of token addresses to check
    /// @return amounts An array of collected fee amounts corresponding to the input tokens
    function batchGetCollectedFees(
        address partner,
        address[] calldata tokens
    )
        external
        view
        returns (uint256[] memory amounts);

    /*//////////////////////////////////////////////////////////////
                             PROTOCOL FEES
    //////////////////////////////////////////////////////////////*/

    /// @notice Allows the protocol fee claimer to withdraw a specific amount of collected protocol fees for a token
    /// @param token The address of the token to withdraw
    /// @param amount The amount of fees to withdraw
    /// @param recipient The address to send the fees to
    function withdrawProtocolFees(address token, uint256 amount, address recipient) external;

    /// @notice Allows the protocol fee claimer to withdraw all collected protocol fees for a specific token
    /// @param token The address of the token to withdraw
    /// @param recipient The address to send the fees to
    /// @return amount The amount of fees withdrawn
    function withdrawAllProtocolFees(address token, address recipient) external returns (uint256 amount);

    /// @notice Allows the protocol fee claimer to withdraw all collected protocol fees for multiple tokens in a single
    /// transaction
    /// @param tokens An array of token addresses to withdraw
    /// @param recipient The address to send the fees to
    function batchWithdrawAllProtocolFees(address[] calldata tokens, address recipient) external;

    /*//////////////////////////////////////////////////////////////
                              FEE CLAIMER
    //////////////////////////////////////////////////////////////*/

    /// @notice Allows the owner to set the protocol fee claimer
    /// @param protocolFeeClaimer The address of the protocol fee claimer
    function setProtocolFeeClaimer(address protocolFeeClaimer) external;

    /// @notice Gets the address of the protocol fee claimer
    /// @return The address of the protocol fee claimer
    function getProtocolFeeClaimer() external view returns (address);
}
