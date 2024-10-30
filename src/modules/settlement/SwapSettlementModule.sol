// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Contracts
import { BaseSettlementModule } from "@modules/settlement/base/BaseSettlementModule.sol";

// Interfaces
import { ISwapSettlementModule } from "@modules/settlement/interfaces/ISwapSettlementModule.sol";
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

/// @title Swap Settlement Module
/// @notice A module that handles the swap settlement of orders, which includes pre-execution, execution, and
///         post-execution steps. The module verifies the order, executes the order using the provided data on the
///         executor contract, and finalizes the order by transferring the output assets to the beneficiary.
contract SwapSettlementModule is BaseSettlementModule, ISwapSettlementModule {
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

    /// @inheritdoc ISwapSettlementModule
    function swapSettle(
        OrderWithSig calldata orderWithSig,
        bytes calldata executorData,
        address executor
    )
        external
        nonReentrant
        onlyAuthorizedAgent
    {
        // 1. Check balance of destToken before settlement
        uint256 balanceBefore = orderWithSig.order.destToken.getBalance();
        // 2. Verify the order and transfer the input assets to the executor contract
        bytes32 orderHash = _pre(orderWithSig, executor);
        // 3. Execute the order using the provided data on the executor contract
        _execute(executorData, executor);
        // 4. Transfer the output assets to the beneficiary
        _post(orderWithSig.order, orderHash, balanceBefore);
    }

    /// @inheritdoc ISwapSettlementModule
    function swapSettleBatch(
        OrderWithSig[] calldata ordersWithSigs,
        bytes[] calldata executorData,
        address executor
    )
        external
        nonReentrant
        onlyAuthorizedAgent
    {
        // Iterate through the orders
        for (uint256 i; i < ordersWithSigs.length; i++) {
            // 1. Check balance of destToken before settlement
            uint256 balanceBefore = ordersWithSigs[i].order.destToken.getBalance();
            // 2. Verify the order and transfer the input assets to the executor contract
            bytes32 orderHash = _pre(ordersWithSigs[i], executor);
            // 3. Execute the order using the provided data on the executor contract
            _execute(executorData[i], executor);
            // 4. Transfer the output assets to the beneficiary
            _post(ordersWithSigs[i].order, orderHash, balanceBefore);
        }
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Parses and verifies the order data to ensure it can be settled, transfers the input assets to the
    ///         executor contract, and executes permit if needed
    /// @param orderWithSig A struct containing the order and its signature
    /// @param executor The address of the executor contract
    /// @return orderHash The hash of the order
    function _pre(OrderWithSig calldata orderWithSig, address executor) internal returns (bytes32 orderHash) {
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
            executor
        );
        // Transfer the srcToken from the owner to the executor contract
        orderWithSig.order.srcToken.transferFrom(
            orderWithSig.order.owner, executor, orderWithSig.order.srcAmount, orderWithSig.order.permit.length
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

    /// @notice Finalizes the order by processing fees and transferring the output assets to the beneficiary
    /// @param order The order to be settled
    /// @param orderHash The hash of the order
    /// @param balanceBefore The balance of the destToken before settlement
    function _post(Order memory order, bytes32 orderHash, uint256 balanceBefore) internal {
        // Calculate the receivedAmount
        uint256 receivedAmount = order.destToken.getBalance() - balanceBefore;
        // Check if the receivedAmount is less than the destAmount
        if (receivedAmount < order.destAmount) {
            revert InsufficientReturnAmount();
        }
        // If beneficiary is not set, transfer to the owner
        address beneficiary;
        if (order.beneficiary == address(0)) {
            beneficiary = order.owner;
        } else {
            beneficiary = order.beneficiary;
        }
        // Process fees
        (uint256 returnAmount, uint256 partnerFee, uint256 protocolFee) =
            order.partnerAndFee.processFees(order.destToken, receivedAmount, order.expectedDestAmount);
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
        moduleSelectors[0] = this.swapSettle.selector;
        moduleSelectors[1] = this.swapSettleBatch.selector;
    }
}
