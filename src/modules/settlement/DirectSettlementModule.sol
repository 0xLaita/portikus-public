// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Contracts
import { BaseSettlementModule } from "@modules/settlement/base/BaseSettlementModule.sol";

// Interfaces
import { IDirectSettlementModule } from "@modules/settlement/interfaces/IDirectSettlementModule.sol";
import { IModule } from "@modules/interfaces/IModule.sol";

// Libraries
import { ERC20UtilsLib } from "@modules/libraries/ERC20UtilsLib.sol";
import { OrderHashLib } from "@modules/libraries/OrderHashLib.sol";
import { SignatureLib } from "@modules/libraries/SignatureLib.sol";
import { NonceManagerLib } from "@modules/libraries/NonceManagerLib.sol";
import { FeeManagerLib } from "@modules/libraries/FeeManagerLib.sol";
import { SafeTransferLib } from "@solady/utils/SafeTransferLib.sol";

// Types
import { Order, OrderWithSig } from "@types/Order.sol";

/// @title Direct Settlement Module
/// @notice A module that handles the direct settlement of orders, where the agent's funds are used to settle the
///         order. The module verifies the order, transfers the input assets to the agent and the output assets to the
///         beneficiary.
contract DirectSettlementModule is BaseSettlementModule, IDirectSettlementModule {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using OrderHashLib for Order;
    using SignatureLib for bytes;
    using ERC20UtilsLib for address;
    using NonceManagerLib for address;
    using SafeTransferLib for address;
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

    /// @inheritdoc IDirectSettlementModule
    function directSettle(
        OrderWithSig calldata orderWithSig,
        uint256 amount
    )
        external
        payable
        nonReentrant
        onlyAuthorizedAgent
    {
        // 1. Verify the order and transfer the input assets to the agent
        bytes32 orderHash = _pre(orderWithSig);
        // 2. Validate msg.value if destination token is ETH
        if (orderWithSig.order.destToken == ERC20UtilsLib.ETH_ADDRESS) {
            if (msg.value != amount) {
                revert InsufficientMsgValue();
            }
        }
        // 3. Transfer the output assets to the beneficiary
        _post(orderWithSig.order, amount, orderHash);
    }

    /// @inheritdoc IDirectSettlementModule
    function directSettleBatch(
        OrderWithSig[] calldata ordersWithSigs,
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
            // 1. Verify the order and transfer the input assets to the agent
            bytes32 orderHash = _pre(ordersWithSigs[i]);
            // 2. Increase totalETHAmount if destination token is ETH
            if (ordersWithSigs[i].order.destToken == ERC20UtilsLib.ETH_ADDRESS) {
                totalETHAmount += amounts[i];
            }
            // 3. Transfer the output assets to the beneficiary
            _post(ordersWithSigs[i].order, amounts[i], orderHash);
        }
        // Revert in case msg.value was incorrect
        if (msg.value != totalETHAmount) {
            revert InsufficientMsgValue();
        }
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Parses and verifies the order data to ensure it can be settled, transfers the input assets to the
    ///         agent and executes permit if needed
    /// @param orderWithSig A struct containing the order and its signature
    /// @return orderHash The hash of the order
    function _pre(OrderWithSig calldata orderWithSig) internal returns (bytes32 orderHash) {
        // Verify the order
        orderHash = _verify(orderWithSig);
        // Check if the deadline has passed
        if (block.timestamp > orderWithSig.order.deadline) {
            // Revert if the deadline has passed
            revert DeadlineExpired();
        }
        // Execute the permit function on the srcToken if the permit length is greater than 0
        orderWithSig.order.srcToken.permit(
            orderWithSig.order.permit,
            orderWithSig.order.owner,
            orderWithSig.order.deadline,
            orderWithSig.order.srcAmount,
            msg.sender
        );
        // Transfer the srcToken from the owner to the agent
        orderWithSig.order.srcToken.transferFrom(
            orderWithSig.order.owner, msg.sender, orderWithSig.order.srcAmount, orderWithSig.order.permit.length
        );
    }

    /// @notice Verifies the order by checking the nonce and the signature
    /// @param orderWithSig A struct containing the order and its signature
    /// @return orderHash The hash of the order
    function _verify(OrderWithSig memory orderWithSig) internal returns (bytes32 orderHash) {
        // Check if the nonce has been used and increment the nonce
        orderWithSig.order.owner.useNonce(orderWithSig.order.nonce);
        // Hash the order
        orderHash = _hashTypedDataV4(orderWithSig.order.hash());
        // Verify the order
        orderWithSig.signature.verify(orderHash, orderWithSig.order.owner);
    }

    /// @notice Finalizes the order by processing fees and transferring the output assets to the beneficiary
    /// @param order The order to be settled
    /// @param amount The amount of the output tokens offered to settle
    /// @param orderHash The hash of the order
    function _post(Order memory order, uint256 amount, bytes32 orderHash) internal {
        // Init returnAmount, protocolFee and partnerFee
        uint256 returnAmount;
        uint256 protocolFee;
        uint256 partnerFee;
        // If beneficiary is not set, transfer to the owner
        address beneficiary;
        if (order.beneficiary == address(0)) {
            beneficiary = order.owner;
        } else {
            beneficiary = order.beneficiary;
        }
        // Revert if the amount is less than the destAmount
        if (amount < order.destAmount) {
            revert InsufficientReturnAmount();
        }
        // Receive the output assets and process fees
        if (order.destToken == ERC20UtilsLib.ETH_ADDRESS) {
            // Process fees
            (returnAmount, partnerFee, protocolFee) =
                order.partnerAndFee.processFees(ERC20UtilsLib.ETH_ADDRESS, amount, order.expectedDestAmount);
        } else {
            // Transfer the destToken from the agent to the this contract
            order.destToken.safeTransferFrom(msg.sender, address(this), amount);
            // Process fees
            (returnAmount, partnerFee, protocolFee) =
                order.partnerAndFee.processFees(order.destToken, amount, order.expectedDestAmount);
        }
        // Transfer the output asset to the beneficiary
        order.destToken.transferTo(beneficiary, returnAmount);
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

    /*//////////////////////////////////////////////////////////////
                               SELECTORS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IModule
    function selectors() external pure override returns (bytes4[] memory moduleSelectors) {
        moduleSelectors = new bytes4[](2);
        moduleSelectors[0] = this.directSettle.selector;
        moduleSelectors[1] = this.directSettleBatch.selector;
    }
}
