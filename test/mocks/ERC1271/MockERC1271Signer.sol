// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Interfaces
import { IERC1271 } from "@interfaces/util/IERC1271.sol";

contract MockERC1271Signer is IERC1271 {
    bytes4 internal constant MAGICVALUE = 0x1626ba7e;
    bytes4 internal constant INVALIDVALUE = 0xffffffff;

    /// @dev Returns the magic value if the signature is valid
    function isValidSignature(bytes32 hash, bytes memory) public pure override returns (bytes4 magicValue) {
        // Simplified logic: consider signature valid if it equals the hash
        if (hash == bytes32(0x8f54f1c2d0eb5771cd5bf67a6689fcd6eed9444d91a39e5ef32a9b4ae5ca14ff)) {
            return MAGICVALUE;
        } else {
            return INVALIDVALUE;
        }
    }

    /// @dev Simplified sign function to create a valid signature
    function sign(bytes32 hash) public pure returns (bytes memory) {
        // Return a dummy signature that would be considered valid by isValidSignature
        return abi.encodePacked(hash);
    }

    /// @dev Function to create an invalid signature
    function invalidSign() public pure returns (bytes memory) {
        // Return a dummy invalid signature
        return abi.encodePacked(bytes32(0x00));
    }
}
