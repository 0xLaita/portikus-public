// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title Nonce Manager Library
/// @notice A library for managing nonces within adapter modules inside the PortikusV2 protocol
library NonceManagerLib {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the nonce of an order is invalid
    error InvalidNonce();

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice keccak256(abi.encode(uint256(keccak256("NonceManagerLib.nonces")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 internal constant NONCES_SLOT = 0xa5ab6f25bd0bb74bb114be2bb23f43ddf211bb478345ba2988a2675c2e318300;

    /// @custom:storage-location erc7201:NonceManagerLib.nonces
    /// @notice The structure that defines the storage layout containing nonces,
    /// storage collisions are avoided following the ERC-7201 standard
    /// @param nonces A mapping of nonces for each user to an indexed bitmap, where each bit represents a nonce.
    ///        A bitmap is used to allow unordered nonce consumption, and reduces the gas cost of managing nonces.
    ///        - owner: This represents the user for whom we are managing nonces.
    ///                 Each user (address) has its own separate set of nonces.
    ///        - index: The index of the nonce bitmap, each index corresponds to a batch of 256 nonces.
    ///                 The index is calculated by dividing the nonce by 256 (nonce / 256).
    ///        - nonce: Each bit in the 256-bit word represents a single nonce.
    ///                 A bit value of 1 means the nonce is used, and 0 means it is unused.
    struct NonceStorage {
        mapping(address owner => mapping(uint256 index => uint256 nonce)) nonces;
    }

    /// @notice Get the pointer to the nonces storage slot
    /// @return ns The pointer to the nonces storage slot
    function noncesStorage() internal pure returns (NonceStorage storage ns) {
        bytes32 slot = NONCES_SLOT;
        assembly {
            ns.slot := slot
        }
    }

    /*//////////////////////////////////////////////////////////////
                                  SET
    //////////////////////////////////////////////////////////////*/

    /// @notice Marks a specific nonce as used
    /// @param owner The address of the nonce owner
    /// @param nonce The specific nonce to mark as used
    function setNonceUsed(address owner, uint256 nonce) internal {
        // Calculate the index of the bitmap
        uint256 nonceIndex = nonce / 256;
        // Calculate the bit position within the bitmap
        uint256 bitPosition = nonce % 256;
        // Set the specific bit to mark the nonce as used
        noncesStorage().nonces[owner][nonceIndex] |= (1 << bitPosition);
    }

    /// @notice Attempts to use a specified nonce, reverts if the nonce is already used
    /// @param owner The address of the user
    /// @param nonce The specific nonce to use
    function useNonce(address owner, uint256 nonce) internal {
        // Calculate the index of the bitmap
        uint256 nonceIndex = nonce / 256;
        // Calculate the bit position within the bitmap
        uint256 bitPosition = nonce % 256;
        // Set bit value
        uint256 bitValue = 1 << bitPosition;
        // Update the nonce at the specific index by toggling the bit
        uint256 newNonce = noncesStorage().nonces[owner][nonceIndex] ^= bitValue;
        // Check if the new nonce bit is set
        if (newNonce & bitValue == 0) {
            // Revert if the nonce is already used
            revert InvalidNonce();
        }
    }

    /// @notice Invalidate a specific nonce for the msg.sender
    /// @param nonce The specific nonce to invalidate
    function invalidateNonce(uint256 nonce) internal {
        // Mark the nonce as used for the msg.sender
        setNonceUsed(msg.sender, nonce);
    }

    /*//////////////////////////////////////////////////////////////
                                  GET
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks if a specific nonce is used
    /// @param owner The address of the nonce owner
    /// @param nonce The specific nonce to check
    /// @return True if the nonce is used, false otherwise
    function isNonceUsed(address owner, uint256 nonce) internal view returns (bool) {
        // Calculate the index of the bitmap
        uint256 nonceIndex = nonce / 256;
        // Calculate the bit position within the bitmap
        uint256 bitPosition = nonce % 256;
        // Check if the specific bit is set
        return noncesStorage().nonces[owner][nonceIndex] & (1 << bitPosition) != 0;
    }
}
