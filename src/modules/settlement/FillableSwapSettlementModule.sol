// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Contracts
import { BaseSettlementModule } from "@modules/settlement/base/BaseSettlementModule.sol";

// Interfaces
import { IFillableSwapSettlementModule } from "@modules/settlement/interfaces/IFillableSwapSettlementModule.sol";
import { IModule } from "@modules/interfaces/IModule.sol";

// Libraries
import { ERC20UtilsLib } from "@modules/libraries/ERC20UtilsLib.sol";
import { FillableOrderHashLib } from "@modules/libraries/FillableOrderHashLib.sol";
import { SignatureLib } from "@modules/libraries/SignatureLib.sol";
import { NonceManagerLib } from "@modules/libraries/NonceManagerLib.sol";
import { FillableStorageLib } from "@modules/libraries/FillableStorageLib.sol";
import { FeeManagerLib } from "@modules/libraries/FeeManagerLib.sol";
import { SafeTransferLib } from "@solady/utils/SafeTransferLib.sol";

// Types
import { Order, OrderWithSig } from "@types/Order.sol";

/// @title Swap Settlement Module
/// @notice A module that handles the swap settlement of fillable orders, which includes pre-execution, execution, and
///         post-execution steps. The module verifies the order, executes the order using the provided data on the
///         executor contract, and finalizes the order by transferring the output assets to the beneficiary.
contract FillableSwapSettlementModule is BaseSettlementModule, IFillableSwapSettlementModule {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using FillableOrderHashLib for Order;
    using SignatureLib for bytes;
    using ERC20UtilsLib for address;
    using NonceManagerLib for address;
    using SafeTransferLib for address;
    using FillableStorageLib for bytes32;
    using FeeManagerLib for uint256;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _version,
        address _portikusV2
    )
        BaseSettlementModule(_name, _version, _portikusV2)
    { }

    /*//////////////////////////////////////////////////////////////
                                 SETTLE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFillableSwapSettlementModule
    function swapSettleFillable(
        OrderWithSig calldata orderWithSig,
        bytes calldata executorData,
        address executor,
        uint256 fillPercent
    )
        external
        nonReentrant
        onlyAuthorizedAgent
    {
        // 1. Calculate the fill amount in and out and expected fill amount out
        uint256 fillAmountIn = (orderWithSig.order.srcAmount * fillPercent) / FillableStorageLib.HUNDRED_PERCENT;
        uint256 fillAmountOut = (orderWithSig.order.destAmount * fillPercent) / FillableStorageLib.HUNDRED_PERCENT;
        uint256 expectedFillAmountOut =
            (orderWithSig.order.expectedDestAmount * fillPercent) / FillableStorageLib.HUNDRED_PERCENT;
        // Make sure both fill amounts are greater than 0
        if (fillAmountIn == 0 || fillAmountOut == 0 || expectedFillAmountOut == 0) {
            revert InvalidFillAmount();
        }
        // 2. Check balance of destToken before settlement
        uint256 balanceBefore = orderWithSig.order.destToken.getBalance();
        // 3. Verify the order and transfer the input assets to the executor contract
        bytes32 orderHash = _pre(orderWithSig, executor, fillAmountIn);
        // 4. Execute the order using the provided data on the executor contract
        _execute(executorData, executor);
        // 5. Transfer the output assets to the beneficiary
        _post(orderWithSig.order, fillAmountOut, expectedFillAmountOut, fillAmountIn, orderHash, balanceBefore);
    }

    /// @inheritdoc IFillableSwapSettlementModule
    function swapSettleFillableBatch(
        OrderWithSig[] calldata ordersWithSigs,
        bytes[] calldata executorData,
        address executor,
        uint256[] calldata fillPercents
    )
        external
        nonReentrant
        onlyAuthorizedAgent
    {
        // Iterate through the orders
        for (uint256 i; i < ordersWithSigs.length; i++) {
            // 1. Calculate the fill amount in and out and expected fill amount out
            uint256 fillAmountIn =
                ordersWithSigs[i].order.srcAmount * fillPercents[i] / FillableStorageLib.HUNDRED_PERCENT;
            uint256 fillAmountOut =
                ordersWithSigs[i].order.destAmount * fillPercents[i] / FillableStorageLib.HUNDRED_PERCENT;
            uint256 expectedFillAmountOut =
                ordersWithSigs[i].order.expectedDestAmount * fillPercents[i] / FillableStorageLib.HUNDRED_PERCENT;
            // Make sure both fill amounts are greater than 0
            if (fillAmountIn == 0 || fillAmountOut == 0 || expectedFillAmountOut == 0) {
                revert InvalidFillAmount();
            }
            // 2. Check balance of destToken before settlement
            uint256 balanceBefore = ordersWithSigs[i].order.destToken.getBalance();
            // 3. Verify the order and transfer the input assets to the executor contract
            bytes32 orderHash = _pre(ordersWithSigs[i], executor, fillAmountIn);
            // 4. Execute the order using the provided data on the executor contract
            _execute(executorData[i], executor);
            // 5. Transfer the output assets to the beneficiary
            _post(ordersWithSigs[i].order, fillAmountOut, expectedFillAmountOut, fillAmountIn, orderHash, balanceBefore);
        }
    }

    /*//////////////////////////////////////////////////////////////
                             FILLED AMOUNT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFillableSwapSettlementModule
    function swapFilledAmount(Order calldata order) external view override returns (uint256 totalFilledAmount) {
        // Hash the order and get the current filled amount
        return _hashTypedDataV4(order.hash()).getFilledAmount();
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Parses and verifies the order data to ensure it can be settled, transfers the input assets to the
    ///         executor contract, and executes permit if needed
    /// @param orderWithSig A struct containing the order and its signature
    /// @param executor The address of the executor contract
    /// @param amountIn The amount of the input asset transferred to the executor contract
    /// @return orderHash The hash of the order
    function _pre(
        OrderWithSig calldata orderWithSig,
        address executor,
        uint256 amountIn
    )
        internal
        returns (bytes32 orderHash)
    {
        // Check if the deadline has passed
        if (block.timestamp > orderWithSig.order.deadline) {
            // Revert if the deadline has passed
            revert DeadlineExpired();
        }
        // Verify the order and update the fillable storage
        orderHash = _verify(orderWithSig);
        // Execute permit function only if order was not partially filled already, because otherwise the permit
        // function would have already been executed
        if (orderHash.getFilledAmount() == 0) {
            // Execute the permit function on the srcToken if the permit length is greater than 0
            orderWithSig.order.srcToken.permit(orderWithSig.order.permit, orderWithSig.order.owner);
        }
        // Transfer the srcToken from the owner to the executor contract
        orderWithSig.order.srcToken.transferFrom(
            orderWithSig.order.owner, executor, amountIn, orderWithSig.order.permit.length
        );
    }

    /// @notice Verifies the order by checking the nonce and the signature
    /// @param orderWithSig A struct containing the order and its signature
    /// @return hash The hash of the order
    function _verify(OrderWithSig memory orderWithSig) internal view returns (bytes32 hash) {
        // Check if the nonce has been used, if so, revert
        if (orderWithSig.order.owner.isNonceUsed(orderWithSig.order.nonce)) {
            revert NonceManagerLib.InvalidNonce();
        }
        // Hash the order
        hash = _hashTypedDataV4(orderWithSig.order.hash());
        // Verify the order
        orderWithSig.signature.verify(hash, orderWithSig.order.owner);
    }

    /// @notice Executes the order using the provided data on the executor contract
    /// @param executorData The data to pass to the executor contract
    /// @param executor The address of the executor contract
    function _execute(bytes calldata executorData, address executor) internal {
        assembly {
            let x := mload(0x40) // get the free memory pointer
            mstore(x, 0x09c5eabe00000000000000000000000000000000000000000000000000000000) // store the selector for
                // execute(bytes)
            mstore(add(x, 0x04), 0x20) // store the offset
            mstore(add(x, 0x24), executorData.length) // store the length
            calldatacopy(add(x, 0x44), executorData.offset, executorData.length) // copy the executor data
            // Call the executor contract with the provided data, revert if the call fails
            if iszero(call(gas(), executor, 0x00, x, add(executorData.length, 0x44), 0x00, 0x00)) {
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }
        }
    }

    /// @notice Finalizes the order by transferring the output assets to the beneficiary
    /// @param order The order to be settled
    /// @param minimumAmountOut (fillAmountOut) The minimum amount of the output asset to be received
    /// @param expectedAmountOut (expectedFillAmountOut) The expected amount of the output asset to be received
    /// @param amountIn The amount of the input asset transferred to the executor contract
    /// @param orderHash The hash of the order
    /// @param balanceBefore The balance of the destToken before the settlement, used to calculate the receivedAmount
    function _post(
        Order memory order,
        uint256 minimumAmountOut,
        uint256 expectedAmountOut,
        uint256 amountIn,
        bytes32 orderHash,
        uint256 balanceBefore
    )
        internal
    {
        // If beneficiary is not set, transfer to the owner
        if (order.beneficiary == address(0)) {
            order.beneficiary = order.owner;
        }
        // Calculate the receivedAmount
        uint256 receivedAmount = order.destToken.getBalance() - balanceBefore;
        // Check if the receivedAmount is less than the minimumAmountOut
        if (receivedAmount < minimumAmountOut) {
            revert InsufficientReturnAmount();
        }
        // Process fees
        (uint256 returnAmount, uint256 partnerFee, uint256 protocolFee) =
            order.partnerAndFee.processFees(order.destToken, receivedAmount, expectedAmountOut);
        // Transfer the output asset to the beneficiary
        order.destToken.transferTo(order.beneficiary, returnAmount);
        // Update the filled amount of the order and emit the OrderPartiallyFilled event or OrderSettled event
        _updateFilledAndEmit(order, orderHash, amountIn, returnAmount, protocolFee, partnerFee);
    }

    /// @notice Updates the filled amount of the order and emits the OrderPartiallyFilled event or OrderSettled event
    ///         based on the total filled amount, if the order is fully filled, updates the nonce as used
    /// @param order The filled order
    /// @param orderHash The hash of the order
    /// @param amountIn The amount of the input asset transferred to the executor contract
    /// @param returnAmount The amount of the output asset returned to the user
    /// @param protocolFee The fee paid to the protocol
    /// @param partnerFee The fee paid to the partner
    function _updateFilledAndEmit(
        Order memory order,
        bytes32 orderHash,
        uint256 amountIn,
        uint256 returnAmount,
        uint256 protocolFee,
        uint256 partnerFee
    )
        internal
    {
        // Update fillable storage
        uint256 totalFilledAmount = orderHash.updateFilled(amountIn);
        // Revert if the totalFilledAmount is greater than the srcAmount
        if (totalFilledAmount > order.srcAmount) {
            revert InvalidFillAmount();
        }
        // Emit partially filled event or order settled event if fully filled;
        else if (totalFilledAmount < order.srcAmount) {
            // Emit the order partially filled event
            emit OrderPartiallyFilled(
                order.owner,
                order.beneficiary,
                order.srcToken,
                order.destToken,
                order.srcAmount,
                order.destAmount,
                returnAmount,
                protocolFee,
                partnerFee,
                totalFilledAmount,
                orderHash
            );
        } else {
            // Set the nonce as used
            order.owner.setNonceUsed(order.nonce);
            // Emit the order settled event
            emit OrderSettled(
                order.owner,
                order.beneficiary,
                order.srcToken,
                order.destToken,
                order.srcAmount,
                order.destAmount,
                returnAmount,
                protocolFee,
                partnerFee,
                orderHash
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                               SELECTORS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IModule
    function selectors() external pure override returns (bytes4[] memory moduleSelectors) {
        moduleSelectors = new bytes4[](3);
        moduleSelectors[0] = this.swapSettleFillable.selector;
        moduleSelectors[1] = this.swapSettleFillableBatch.selector;
        moduleSelectors[2] = this.swapFilledAmount.selector;
    }
}
