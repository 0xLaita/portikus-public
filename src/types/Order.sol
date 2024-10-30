// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @dev Order data structure containing the order details to be settled,
///      the order is signed by the owner to be executed by an agent
///      on behalf of the owner, executing the swap and transferring the
///      dest token to the beneficiary
struct Order {
    /// @dev The address of the order owner
    address owner;
    /// @dev The address of the order beneficiary
    address beneficiary;
    /// @dev The address of the src token
    address srcToken;
    /// @dev The address of the dest token
    address destToken;
    /// @dev The amount of src token to swap
    uint256 srcAmount;
    /// @dev The minimum amount of dest token to receive
    uint256 destAmount;
    /// @dev The expected amount of dest token to receive
    uint256 expectedDestAmount;
    /// @dev The deadline for the order
    uint256 deadline;
    /// @dev The nonce of the order
    uint256 nonce;
    /// @dev Encoded partner address, fee bps, and flags for the order
    ///      partnerAndFee = (partner << 96) | (partnerTakesSurplus << 8) | fee in bps (max fee is 2%)
    uint256 partnerAndFee;
    /// @dev Optional permit signature for the src token
    bytes permit;
}

/// @dev Order with signature
struct OrderWithSig {
    /// @dev The order data
    Order order;
    /// @dev The signature of the order
    bytes signature;
}
