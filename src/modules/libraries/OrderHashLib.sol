// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Types
import { Order } from "@types/Order.sol";

/// @title Order Hash Library
/// @dev Library with functions to handle hashing of Order structs
library OrderHashLib {
    /*//////////////////////////////////////////////////////////////
                              TYPESTRINGS
    //////////////////////////////////////////////////////////////*/

    /// @dev The type of the order struct
    bytes internal constant _ORDER_TYPESTRING = // solhint-disable-next-line max-line-length
        "Order(address owner,address beneficiary,address srcToken,address destToken,uint256 srcAmount,uint256 destAmount,uint256 expectedDestAmount,uint256 deadline,uint256 nonce,uint256 partnerAndFee,bytes permit)";

    /*//////////////////////////////////////////////////////////////
                                TYPEHASH
    //////////////////////////////////////////////////////////////*/

    /// @dev The type hash of the order struct
    bytes32 internal constant _ORDER_TYPEHASH = 0x232f6c7c4007c029626b47de38aebf4b64e5aeebdb81418d2b448a50a3a644fa;

    /*//////////////////////////////////////////////////////////////
                                  HASH
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the hash of the provided order
    /// @param order The order to hash
    /// @return The hash of the order
    function hash(Order memory order) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                _ORDER_TYPEHASH,
                order.owner,
                order.beneficiary,
                order.srcToken,
                order.destToken,
                order.srcAmount,
                order.destAmount,
                order.expectedDestAmount,
                order.deadline,
                order.nonce,
                order.partnerAndFee,
                keccak256(order.permit)
            )
        );
    }
}
