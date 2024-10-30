// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Types
import { OrderWithSig } from "@types/Order.sol";

/// @notice Interface for swap order settlement on a Portikus V2 adapter
interface ISwapSettlementModule {
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

    /// @notice Settles an order using the provided data as the calldata for the execution
    ///         and the provided executor contract to execute the swap
    /// @param orderWithSig The order and signature to settle
    /// @param executorData The data to pass to the executor contract
    /// @param executor The address of the executor contract
    function swapSettle(OrderWithSig calldata orderWithSig, bytes calldata executorData, address executor) external;

    /// @notice Settles a batch of orders using the provided data as the calldata for the execution
    ///         and the provided executor contract to execute the swaps
    /// @param ordersWithSigs The orders and signatures to settle
    /// @param executorData An array of data to pass to the executor contract
    /// @param executor The address of the executor contract
    function swapSettleBatch(
        OrderWithSig[] calldata ordersWithSigs,
        bytes[] calldata executorData,
        address executor
    )
        external;
}
