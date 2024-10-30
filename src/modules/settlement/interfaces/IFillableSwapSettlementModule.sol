// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Types
import { OrderWithSig, Order } from "@types/Order.sol";

/// @notice Interface for fillable swap order settlement on a Portikus V2 adapter
interface IFillableSwapSettlementModule {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the calculated fill amount is invalid
    error InvalidFillAmount();

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
                                EXTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Settles a fillable order using the provided data as the calldata for the execution
    ///         and the provided executor contract to execute the swap
    /// @param orderWithSig The order and signature to settle
    /// @param executorData The data to pass to the executor contract
    /// @param executor The address of the executor contract
    /// @param fillPercent The percentage of the order to fill
    function swapSettleFillable(
        OrderWithSig calldata orderWithSig,
        bytes calldata executorData,
        address executor,
        uint256 fillPercent
    )
        external;

    /// @notice Settles a batch of fillable orders using the provided data as the calldata for the execution
    ///         and the provided executor contract to execute the swaps
    /// @param ordersWithSigs The orders and signatures to settle
    /// @param executorData An array of data to pass to the executor contract
    /// @param executor The address of the executor contract
    /// @param fillPercents An array of the percentages of the orders to fill
    function swapSettleFillableBatch(
        OrderWithSig[] calldata ordersWithSigs,
        bytes[] calldata executorData,
        address executor,
        uint256[] calldata fillPercents
    )
        external;

    /// @notice Gets the current filled amount of an order
    /// @param order The order to get the filled amount of
    /// @return totalFilledAmount The total amount of the order that has been filled
    function swapFilledAmount(Order calldata order) external view returns (uint256 totalFilledAmount);
}
