// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Libraries
import { SafeTransferLib } from "@solady/utils/SafeTransferLib.sol";

/// @title ERC20 Utility Library
/// @dev Library with common functions used by different modules within the Portikus V2 protocol
library ERC20UtilsLib {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the permit execution fails
    error PermitFailed();

    /// @notice Emitted when msg.value is insufficient
    error InsufficientValue();

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev An address used to represent the native token
    address internal constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    /// @dev The address of the Permit2 contract
    address internal constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                TRANSFER
    //////////////////////////////////////////////////////////////*/

    /// @dev Transfer the dest token to the order beneficiary, reducing the amount by 1 wei for gas optimization
    ///      purposes. If the destToken is ETH, it will transfer native ETH to recipient
    /// @param destToken The address of the dest token
    /// @param recipient The address to transfer to
    /// @param amount The amount to transfer
    function transferTo(address destToken, address recipient, uint256 amount) internal {
        // If the destToken is ETH, transfer native ETH
        if (destToken == ETH_ADDRESS) {
            recipient.safeTransferETH(amount);
        } else {
            // Otherwise, transfer the dest token to the recipient, reducing the amount by 1 wei
            // for gas optimization purposes
            destToken.safeTransfer(recipient, amount);
        }
    }

    /// @dev Transfer the src token from the user to a recipient, using permit2 allowance or erc20 allowance based on
    ///      permit length, if the permit length is 192 or 1 it will call transferFrom using permit2
    ///      allowance, otherwise it will call transferFrom using erc20 allowance unless permit length is 96
    /// @param srcToken The address of the src token
    /// @param owner The owner of the token
    /// @param recipient The recipient of the token
    /// @param amount The amount to transfer
    /// @param permitLength The length of the permit
    function transferFrom(
        address srcToken,
        address owner,
        address recipient,
        uint256 amount,
        uint256 permitLength
    )
        internal
    {
        // Skip transferring if the permit length is 96 (permit2TransferFrom)
        if (permitLength == 96) {
            return;
        }
        // If the permit length is 192 or 1 execute permit2TransferFrom to transfer the
        // input assets from the owner to the agent, otherwise execute ERC20 transferFrom
        if (permitLength == 192 || permitLength == 1) {
            // Transfer the input assets from the owner to the recipient using permit2 allowance
            srcToken.permit2TransferFrom(owner, recipient, amount);
        } else {
            // Transfer the input assets from the owner to the recipient using the ERC20 transferFrom function
            srcToken.safeTransferFrom(owner, recipient, amount);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 PERMIT
    //////////////////////////////////////////////////////////////*/

    /// @dev Executes the permit function on the provided token, depending on the permit length,
    ///      it will call the EIP2612 permit (224), DAI-Style permit (256), Permit2 AllowanceTransfer (192)
    ///      or Permit2 Signature (96)
    /// @param token The address of the token
    /// @param data The permit data
    /// @param owner The owner of the token (used for Permit2)
    /// @param deadline The deadline for the permit (used for Permit2)
    /// @param amount The amount to permit (used for Permit2)
    function permit(
        address token,
        bytes calldata data,
        address owner,
        uint256 deadline,
        uint256 amount,
        address recipient
    )
        internal
    {
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            // check the permit length
            switch data.length
            // 0x00 = no permit
            case 0x00 {
                // do nothing
            }
            case 0x01 {
                // 0x01 is used to signify already existing permit2 allowance
            }
            // 32(permit2nonce) + 64(signature) = 96 Permit2 Transfer format
            case 0x60 {
                let x := mload(0x40) // get the free memory pointer
                mstore(x, 0x30f28b7a00000000000000000000000000000000000000000000000000000000) // store the selector
                mstore(add(x, 0x04), token) // store the srcToken
                mstore(add(x, 0x24), amount) // store the amount
                calldatacopy(add(x, 0x44), data.offset, 0x20) // copy the nonce
                mstore(add(x, 0x64), deadline) // store the deadline
                mstore(add(x, 0x84), recipient) // store the recipient address (executor)
                mstore(add(x, 0xa4), amount) // store the amount
                mstore(add(x, 0xc4), owner) // store the owner
                mstore(add(x, 0xe4), 0x100) // store the offset
                mstore(add(x, 0x104), 0x40) // store the length
                calldatacopy(add(x, 0x124), add(data.offset, 0x20), 0x40) // copy the signature
                // Call Permit2 contract and revert on failure
                if iszero(call(gas(), PERMIT2_ADDRESS, 0x00, x, 0x164, 0x00, 0x00)) {
                    mstore(0x00, 0xb78cb0dd00000000000000000000000000000000000000000000000000000000) // store the
                        // selector
                    revert(0x00, 0x04) // Revert with PermitFailed error
                }
            }
            // 32(amount) + 32(nonce) + 32(expiration) + 32(sigDeadline) + 64(signature) = 192 Permit2 allowance format
            case 0xc0 {
                let x := mload(0x40) // get the free memory pointer
                mstore(x, 0x2b67b57000000000000000000000000000000000000000000000000000000000) // store the selector
                mstore(add(x, 0x04), owner) // store the owner address
                mstore(add(x, 0x24), token) // store the token address
                calldatacopy(add(x, 0x44), data.offset, 0x60) // copy amount, nonce, expiration
                mstore(add(x, 0xa4), address()) // store this contract's address as the spender
                calldatacopy(add(x, 0xc4), add(data.offset, 0x60), 0x20) // copy sigDeadline
                mstore(add(x, 0xe4), 0x100) // store the offset for signature
                mstore(add(x, 0x104), 0x40) // store the length of signature
                calldatacopy(add(x, 0x124), add(data.offset, 0x80), 0x40) // copy the signature
                // Call Permit2 contract and revert on failure
                if iszero(call(gas(), PERMIT2_ADDRESS, 0x00, x, 0x164, 0x00, 0x00)) {
                    mstore(0x00, 0xb78cb0dd00000000000000000000000000000000000000000000000000000000) // store the
                        // selector
                    revert(0x00, 0x04) // Revert with PermitFailed error
                }
            }
            // 32 * 7 = 224 EIP2612 Permit
            case 0xe0 {
                let x := mload(0x40) // get the free memory pointer
                mstore(x, 0xd505accf00000000000000000000000000000000000000000000000000000000) // store the selector
                calldatacopy(add(x, 0x04), data.offset, 0xe0) // store the args
                pop(call(gas(), token, 0x00, x, 0xe4, 0x00, 0x20)) // call ERC20 permit, skip checking return data
            }
            // 32 * 8 = 256 DAI-Style Permit
            case 0x100 {
                let x := mload(0x40) // get the free memory pointer
                mstore(x, 0x8fcbaf0c00000000000000000000000000000000000000000000000000000000) // store the selector
                calldatacopy(add(x, 0x04), data.offset, 0x100) // store the args
                pop(call(gas(), token, 0x00, x, 0x104, 0x00, 0x20)) // call ERC20 permit, skip checking return data
            }
            // Otherwise revert
            default {
                mstore(0x00, 0xb78cb0dd00000000000000000000000000000000000000000000000000000000) // store the selector
                revert(0x00, 0x04) // Revert with PermitFailed error
            }
        }
    }

    /// @dev A fillable version of the permit function from this lib, that doesn't support Permit2 SignatureTransfer
    /// @param token The address of the token
    /// @param data The permit data
    /// @param owner The owner of the token (used for Permit2)
    function permit(address token, bytes calldata data, address owner) internal {
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            // check the permit length
            switch data.length
            // 0x00 = no permit
            case 0x00 {
                // do nothing
            }
            case 0x01 {
                // 0x01 is used to signify already existing permit2 allowance
            }
            // 32(amount) + 32(nonce) + 32(expiration) + 32(sigDeadline) + 64(signature) = 192 Permit2 allowance format
            case 0xc0 {
                let x := mload(0x40) // get the free memory pointer
                mstore(x, 0x2b67b57000000000000000000000000000000000000000000000000000000000) // store the selector
                mstore(add(x, 0x04), owner) // store the owner address
                mstore(add(x, 0x24), token) // store the token address
                calldatacopy(add(x, 0x44), data.offset, 0x60) // copy amount, nonce, expiration
                mstore(add(x, 0xa4), address()) // store this contract's address as the spender
                calldatacopy(add(x, 0xc4), add(data.offset, 0x60), 0x20) // copy sigDeadline
                mstore(add(x, 0xe4), 0x100) // store the offset for signature
                mstore(add(x, 0x104), 0x40) // store the length of signature
                calldatacopy(add(x, 0x124), add(data.offset, 0x80), 0x40) // copy the signature
                // Call Permit2 contract and revert on failure
                if iszero(call(gas(), PERMIT2_ADDRESS, 0x00, x, 0x164, 0x00, 0x00)) {
                    mstore(0x00, 0xb78cb0dd00000000000000000000000000000000000000000000000000000000) // store the
                        // selector
                    revert(0x00, 0x04) // Revert with PermitFailed error
                }
            }
            // 32 * 7 = 224 EIP2612 Permit
            case 0xe0 {
                let x := mload(0x40) // get the free memory pointer
                mstore(x, 0xd505accf00000000000000000000000000000000000000000000000000000000) // store the selector
                calldatacopy(add(x, 0x04), data.offset, 0xe0) // store the args
                pop(call(gas(), token, 0x00, x, 0xe4, 0x00, 0x20)) // call ERC20 permit, skip checking return data
            }
            // 32 * 8 = 256 DAI-Style Permit
            case 0x100 {
                let x := mload(0x40) // get the free memory pointer
                mstore(x, 0x8fcbaf0c00000000000000000000000000000000000000000000000000000000) // store the selector
                calldatacopy(add(x, 0x04), data.offset, 0x100) // store the args
                pop(call(gas(), token, 0x00, x, 0x104, 0x00, 0x20)) // call ERC20 permit, skip checking return data
            }
            // Otherwise revert
            default {
                mstore(0x00, 0xb78cb0dd00000000000000000000000000000000000000000000000000000000) // store the selector
                revert(0x00, 0x04) // Revert with PermitFailed error
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                                BALANCE
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the balance of address(this), works for both ETH and ERC20 tokens
    function getBalance(address token) internal view returns (uint256 balanceOf) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            switch eq(token, ETH_ADDRESS)
            // ETH
            case 0x01 { balanceOf := selfbalance() }
            // ERC20
            default {
                let x := mload(0x40) // get the free memory pointer
                mstore(x, 0x70a0823100000000000000000000000000000000000000000000000000000000) // store the selector
                mstore(add(x, 0x04), address()) // store the account
                let success := staticcall(gas(), token, x, 0x24, x, 0x20) // call balanceOf
                if success { balanceOf := mload(x) } // load the balance
            }
        }
    }
}
