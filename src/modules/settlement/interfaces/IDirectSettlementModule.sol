// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Types
import { OrderWithSig } from "@types/Order.sol";

/// @notice Interface for direct order settlement on a Portikus V2 adapter
interface IDirectSettlementModule {
    /*//////////////////////////////////////////////////////////////
                             ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when msg.value is invalid
    error InsufficientMsgValue();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an order is settled
    /// @param owner The owner of the order
    /// @param beneficiary The beneficiary of the order
    /// @param srcToken The source token of the order
    /// @param destToken The destination token of the order
    /// @param srcAmount The source amount of the order
    /// @param destAmount The destination amount of the order
    /// @param returnAmount The amount of the output tokens returned to the user
    /// @param protocolFee The fee paid to the protocol
    /// @param partnerFee  The fee paid to the partner
    /// @param orderHash The hash of the order
    event OrderSettled(
        address indexed owner,
        address indexed beneficiary,
        address srcToken,
        address destToken,
        uint256 srcAmount,
        uint256 destAmount,
        uint256 returnAmount,
        uint256 protocolFee,
        uint256 partnerFee,
        bytes32 indexed orderHash
    );

    /*//////////////////////////////////////////////////////////////
                                EXTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Settles an order using the callers funds
    /// @param orderWithSig The order and signature to settle
    /// @param amount The amount of the output tokens offered to settle, if this is less than the order's destAmount
    ///               the order will revert
    function directSettle(OrderWithSig calldata orderWithSig, uint256 amount) external payable;

    /// @notice Settles a batch of orders using the callers funds
    /// @param ordersWithSigs The orders and signatures to settle
    /// @param amounts An array of amounts of the output tokens offered to settle, if any of these are less than the
    function directSettleBatch(OrderWithSig[] calldata ordersWithSigs, uint256[] calldata amounts) external payable;
}
