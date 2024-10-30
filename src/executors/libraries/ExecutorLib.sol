// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Interfaces
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Libraries
import { SafeTransferLib } from "@solady/utils/SafeTransferLib.sol";

/// @title ExecutorLib
/// @dev Library with functions that can be reused by Executor contracts
library ExecutorLib {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Native ETH address
    address internal constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Executor data struct, containing all data required to execute a swap
    struct ExecutorData {
        // The address of the src token
        address srcToken;
        // The address of the dest token
        address destToken;
        // The amount of fee to be paid for the swap
        uint256 feeAmount;
        // The calldata to execute the swap
        bytes calldataToExecute;
        // The address to execute the swap
        address executionAddress;
        // The address to receive the fee, if not set the tx.origin will receive the fee
        address feeRecipient;
    }

    /*//////////////////////////////////////////////////////////////
                                  FEES
    //////////////////////////////////////////////////////////////*/

    /// @dev Transfers ERC20 or native ETH fees to the fee recipient, transfer native ETH or ERC20 to recipient
    /// @param recipient The address to transfer the funds to
    /// @param feeRecipient The address to transfer the fees to
    /// @param destToken The address of the dest token
    /// @param feeAmount The amount of fee to transfer
    function transferFeesAndETH(
        address recipient,
        address feeRecipient,
        address destToken,
        uint256 feeAmount
    )
        internal
    {
        // If the fee recipient is not set, set it to tx.origin
        feeRecipient = feeRecipient == address(0) ? tx.origin : feeRecipient;
        // If the destToken is ETH, transfer fee amount to the owner,
        // and the remaining balance to the PortikusV1 contract. Otherwise,
        // ERC20 transfer the fee amount to the owner
        if (destToken == ETH_ADDRESS) {
            // Transfer the fee amount  to the fee recipient
            feeRecipient.safeTransferETH(feeAmount);
            // Transfer the remaining balance to the PortikusV1 contract
            recipient.safeTransferETH(address(this).balance);
        } else {
            // Transfer the fee amount to the fee recipient or tx.origin if not set
            destToken.safeTransfer(feeRecipient, feeAmount);
            // Transfer the remaining balance to the recipient, deducting 1 wei for gas optimization
            destToken.safeTransfer(recipient, IERC20(destToken).balanceOf(address(this)) - 1);
        }
    }
}
