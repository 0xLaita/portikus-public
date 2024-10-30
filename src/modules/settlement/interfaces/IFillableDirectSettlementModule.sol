// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Order, OrderWithSig } from "@types/Order.sol";

/// @notice Interface for fillable direct order settlement on a Portikus V2 adapter
interface IFillableDirectSettlementModule {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the calculated fill amount is invalid
    error InvalidFillAmount();

    /// @notice Thrown when msg.value is invalid
    error InsufficientMsgValue();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an order is partially filled
    /// @param owner The owner of the order
    /// @param beneficiary The beneficiary of the order
    /// @param srcToken The source token of the order
    /// @param destToken The destination token of the order
    /// @param srcAmount The total source amount of the order
    /// @param destAmount The total destination amount of the order
    /// @param returnAmount The amount of the output tokens returned to the user
    /// @param protocolFee The fee paid to the protocol
    /// @param partnerFee  The fee paid to the partner
    /// @param totalFilledAmount The total amount filled so far
    /// @param orderHash The hash of the order
    event OrderPartiallyFilled(
        address indexed owner,
        address indexed beneficiary,
        address srcToken,
        address destToken,
        uint256 srcAmount,
        uint256 destAmount,
        uint256 returnAmount,
        uint256 protocolFee,
        uint256 partnerFee,
        uint256 totalFilledAmount,
        bytes32 indexed orderHash
    );

    /// @notice Emitted when an order is fully settled
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
                                 SETTLE
    //////////////////////////////////////////////////////////////*/

    /// @notice Settles a single fillable direct order
    /// @param orderWithSig The order with signature to be settled
    /// @param fillPercent The percentage of the order to fill, in basis points
    /// @param amount The amount of the output tokens offered to settle
    function directSettleFillable(
        OrderWithSig calldata orderWithSig,
        uint256 fillPercent,
        uint256 amount
    )
        external
        payable;

    /// @notice Settles multiple fillable direct orders
    /// @param ordersWithSigs The orders with signatures to be settled
    /// @param fillPercents The percentages of the orders to fill, in basis points
    /// @param amounts The amounts of the output tokens offered to settle
    function directSettleFillableBatch(
        OrderWithSig[] calldata ordersWithSigs,
        uint256[] calldata fillPercents,
        uint256[] calldata amounts
    )
        external
        payable;

    /*//////////////////////////////////////////////////////////////
                             FILLED AMOUNT
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the total filled amount for an order
    /// @param order The order to check
    /// @return totalFilledAmount The total filled amount for the order
    function directFilledAmount(Order calldata order) external view returns (uint256 totalFilledAmount);
}
