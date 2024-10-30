// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Contracts
import { BaseSettlementModule } from "@modules/settlement/base/BaseSettlementModule.sol";

// Interfaces
import { IFillableDirectSettlementModule } from "@modules/settlement/interfaces/IFillableDirectSettlementModule.sol";
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

/// @title Fillable Direct Settlement Module
/// @notice A module that handles the direct settlement of fillable orders, where the agent's funds are used to
///         partially or fully settle the order. The module verifies the order, transfers the input assets to the agent
///         and the output assets to the beneficiary, while tracking partial fills.
contract FillableDirectSettlementModule is BaseSettlementModule, IFillableDirectSettlementModule {
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

    /// @inheritdoc IFillableDirectSettlementModule
    function directSettleFillable(
        OrderWithSig calldata orderWithSig,
        uint256 fillPercent,
        uint256 amount
    )
        external
        payable
        nonReentrant
        onlyAuthorizedAgent
    {
        // 1. Calculate the fill amount in and out, and expected fill amount out
        uint256 fillAmountIn = (orderWithSig.order.srcAmount * fillPercent) / FillableStorageLib.HUNDRED_PERCENT;
        uint256 fillAmountOut = (orderWithSig.order.destAmount * fillPercent) / FillableStorageLib.HUNDRED_PERCENT;
        uint256 expectedFillAmountOut =
            (orderWithSig.order.expectedDestAmount * fillPercent) / FillableStorageLib.HUNDRED_PERCENT;
        // Make sure both fill amounts are greater than 0
        if (fillAmountIn == 0 || fillAmountOut == 0 || expectedFillAmountOut == 0) {
            revert InvalidFillAmount();
        }
        // 2. Verify the order and transfer the input assets to the agent
        bytes32 orderHash = _pre(orderWithSig, fillAmountIn);
        // 3. Validate msg.value if destination token is ETH
        if (orderWithSig.order.destToken == ERC20UtilsLib.ETH_ADDRESS) {
            if (msg.value != amount) {
                revert InsufficientMsgValue();
            }
        }
        // 4. Transfer the output assets to the beneficiary
        _post(orderWithSig.order, amount, fillAmountIn, fillAmountOut, expectedFillAmountOut, orderHash);
    }

    /// @inheritdoc IFillableDirectSettlementModule
    function directSettleFillableBatch(
        OrderWithSig[] calldata ordersWithSigs,
        uint256[] calldata fillPercents,
        uint256[] calldata amounts
    )
        external
        payable
        nonReentrant
        onlyAuthorizedAgent
    {
        // Init totalETHAmount
        uint256 totalETHAmount;
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
            // 2. Verify the order and transfer the input assets to the agent
            bytes32 orderHash = _pre(ordersWithSigs[i], fillAmountIn);
            // 3. Increase totalETHAmount if destination token is ETH
            if (ordersWithSigs[i].order.destToken == ERC20UtilsLib.ETH_ADDRESS) {
                totalETHAmount += amounts[i];
            }
            // 4. Transfer the output assets to the beneficiary
            _post(ordersWithSigs[i].order, amounts[i], fillAmountIn, fillAmountOut, expectedFillAmountOut, orderHash);
        }
        // Revert in case msg.value was incorrect
        if (msg.value != totalETHAmount) {
            revert InsufficientMsgValue();
        }
    }

    /*//////////////////////////////////////////////////////////////
                             FILLED AMOUNT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFillableDirectSettlementModule
    function directFilledAmount(Order calldata order) external view override returns (uint256 totalFilledAmount) {
        // Hash the order and get the current filled amount
        return _hashTypedDataV4(order.hash()).getFilledAmount();
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Parses and verifies the order data to ensure it can be settled, transfers the input assets to the
    ///         agent and executes permit if needed
    /// @param orderWithSig A struct containing the order and its signature
    /// @param amountIn The amount of the input tokens transferred to the agent
    /// @return orderHash The hash of the order
    function _pre(OrderWithSig calldata orderWithSig, uint256 amountIn) internal returns (bytes32 orderHash) {
        // Check if the deadline has passed
        if (block.timestamp > orderWithSig.order.deadline) {
            revert DeadlineExpired();
        }
        // Verify the order and get the order hash
        orderHash = _verify(orderWithSig);
        // Execute permit function only if order was not partially filled already, because otherwise the permit
        // function would have already been executed
        if (orderHash.getFilledAmount() == 0) {
            // Execute the permit function on the srcToken if the permit length is greater than 0
            orderWithSig.order.srcToken.permit(orderWithSig.order.permit, orderWithSig.order.owner);
        }
        // Transfer the srcToken from the owner to the agent
        orderWithSig.order.srcToken.transferFrom(
            orderWithSig.order.owner, msg.sender, amountIn, orderWithSig.order.permit.length
        );
    }

    /// @notice Verifies the order by checking the nonce and the signature
    /// @param orderWithSig A struct containing the order and its signature
    /// @return orderHash The hash of the order
    function _verify(OrderWithSig memory orderWithSig) internal view returns (bytes32 orderHash) {
        // Check if the nonce has been used, if so, revert
        if (orderWithSig.order.owner.isNonceUsed(orderWithSig.order.nonce)) {
            revert NonceManagerLib.InvalidNonce();
        }
        // Hash the order
        orderHash = _hashTypedDataV4(orderWithSig.order.hash());
        // Verify the order
        orderWithSig.signature.verify(orderHash, orderWithSig.order.owner);
    }

    /// @notice Finalizes the order by processing fees and transferring the output assets to the beneficiary
    /// @param order The order to be settled
    /// @param amountOut The amount of the output tokens offered to settle
    /// @param amountIn The amount of the input tokens transferred to the agent
    /// @param minimumAmountOut (fillAmountOut) The minimum amount of the output tokens
    /// @param expectedAmountOut (expectedFillAmountOut) The expected amount of the output tokens
    /// @param orderHash The hash of the order
    function _post(
        Order memory order,
        uint256 amountOut,
        uint256 amountIn,
        uint256 minimumAmountOut,
        uint256 expectedAmountOut,
        bytes32 orderHash
    )
        internal
    {
        // Initialize the return amount, protocol fee and partner fee
        uint256 returnAmount;
        uint256 protocolFee;
        uint256 partnerFee;
        // If beneficiary is not set, transfer to the owner
        if (order.beneficiary == address(0)) {
            order.beneficiary = order.owner;
        }
        // Check if the amountOut is less than the minimumAmountOut
        if (amountOut < minimumAmountOut) {
            revert InsufficientReturnAmount();
        }
        // If the destToken is ETH, check msg.value and process fees
        // Otherwise, transfer the destToken to this contract, check the balance and process fees
        if (order.destToken == ERC20UtilsLib.ETH_ADDRESS) {
            // Process fees
            (returnAmount, partnerFee, protocolFee) =
                order.partnerAndFee.processFees(ERC20UtilsLib.ETH_ADDRESS, amountOut, expectedAmountOut);
        } else {
            // Transfer the destToken from the agent to this contract
            order.destToken.safeTransferFrom(msg.sender, address(this), amountOut);
            // Process fees
            (returnAmount, partnerFee, protocolFee) =
                order.partnerAndFee.processFees(order.destToken, amountOut, expectedAmountOut);
        }
        // Transfer the output asset to the beneficiary
        order.destToken.transferTo(order.beneficiary, returnAmount);
        // Update the filled amount of the order and emit the OrderPartiallyFilled event or OrderSettled event
        _updateFilledAndEmit(order, orderHash, amountIn, returnAmount, protocolFee, partnerFee);
    }

    /// @notice Updates the filled amount of the order and emits the OrderPartiallyFilled event or OrderSettled event
    ///         based on the total filled amount, if the order is fully filled, updates the nonce as used
    /// @param order The filled order
    /// @param orderHash The hash of the order
    /// @param amountIn The amount of the input asset transferred to the agent
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
        // Emit partially filled event or order settled event if fully filled
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
        moduleSelectors[0] = this.directSettleFillable.selector;
        moduleSelectors[1] = this.directSettleFillableBatch.selector;
        moduleSelectors[2] = this.directFilledAmount.selector;
    }
}
