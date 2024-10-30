// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Interfaces
import { IERC1271 } from "@interfaces/util/IERC1271.sol";

/// @title SignatureLib
/// @notice Library with functions to handle signature verification
/// @dev Supports EIP-2098 and ERC-1271 signatures
library SignatureLib {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the signature is invalid
    error InvalidSignature();

    /// @notice Emitted when the signer is invalid
    error InvalidSigner();

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Used to mask the upper bit of a bytes32 value
    bytes32 internal constant UPPER_BIT_MASK = (0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);

    /*//////////////////////////////////////////////////////////////
                                 VERIFY
    //////////////////////////////////////////////////////////////*/

    /// @dev Verifies the signature of the provided data
    /// @notice The signature must be in EIP-2098 format
    /// @param signature The signature to verify
    /// @param hash The hash of the data to verify
    /// @param signer The expected signer of the data
    function verify(bytes memory signature, bytes32 hash, address signer) internal view {
        // Check if signer is an EOA
        // - If signer is an EOA, check EIP-2098 signature format
        // - If signer is a contract, check ERC-1271 signature format
        if (signer.code.length == 0) {
            if (signature.length == 64) {
                // Verify using EIP-2098 signature format
                // - signature is 64 bytes long
                // - r is the first 32 bytes
                // - vs is the last 32 bytes
                // - v is the last byte of vs
                // - s is the first 31 bytes of vs
                (bytes32 r, bytes32 vs) = abi.decode(signature, (bytes32, bytes32));
                bytes32 s = vs & UPPER_BIT_MASK;
                uint8 v = uint8(uint256(vs >> 255)) + 27;
                address actualSigner = ecrecover(hash, v, r, s);
                if (actualSigner == address(0)) revert InvalidSignature();
                if (actualSigner != signer) revert InvalidSigner();
            } else {
                revert InvalidSignature();
            }
        } else {
            // Verify using ERC-1271 signature format
            bytes4 magicValue = IERC1271(signer).isValidSignature(hash, signature);
            if (magicValue != IERC1271(signer).isValidSignature.selector) revert InvalidSignature();
        }
    }
}
