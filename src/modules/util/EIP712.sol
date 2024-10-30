// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Dependencies
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// Interfaces
import { IEIP712 } from "@interfaces/util/IEIP712.sol";

/// @title EIP712
/// @notice Implements EIP712 domain separator and hashing functionality
/// @dev This contract is a modified version of the OpenZeppelin EIP712 contract
/// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/EIP712.sol
contract EIP712 is IEIP712 {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // The raw EIP712 domain separator type string
    bytes private constant TYPE_HASH_RAW =
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)";

    // Raw name
    string private constant NAME_RAW = "Portikus";

    // Raw version
    string private constant VERSION_RAW = "2.0.0";

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLE
    //////////////////////////////////////////////////////////////*/

    // Hash of the EIP712 Domain Separator data
    bytes32 private immutable HASHED_NAME;
    bytes32 private immutable HASHED_VERSION;
    bytes32 private immutable TYPE_HASH;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the EIP712 domain separator fields
    constructor() {
        HASHED_NAME = keccak256(bytes(NAME_RAW));
        HASHED_VERSION = keccak256(bytes(VERSION_RAW));
        TYPE_HASH = keccak256(abi.encodePacked(TYPE_HASH_RAW));
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the domain separator for the current chain
    function _domainSeparatorV4() internal view returns (bytes32) {
        // Uses address(this) as the verifyingContract is the adapter that installed a module
        return keccak256(abi.encode(TYPE_HASH, HASHED_NAME, HASHED_VERSION, block.chainid, address(this)));
    }

    /// @notice Hashes the EIP712 Domain Separator and the struct hash
    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(_domainSeparatorV4(), structHash);
    }

    /*//////////////////////////////////////////////////////////////
                                EXTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IEIP712
    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return _domainSeparatorV4();
    }
}
