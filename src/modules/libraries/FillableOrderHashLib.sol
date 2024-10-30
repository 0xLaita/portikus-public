// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Types
import { Order } from "@types/Order.sol";

/// @title Fillable Order Hash Library
/// @dev Library with functions to handle hashing of FillableOrder structs
library FillableOrderHashLib {
    /*//////////////////////////////////////////////////////////////
                              TYPESTRINGS
    //////////////////////////////////////////////////////////////*/

    /// @dev The type of the fillable order struct
    bytes internal constant _FILLABLE_ORDER_TYPESTRING = // solhint-disable-next-line max-line-length
        "FillableOrder(address owner,address beneficiary,address srcToken,address destToken,uint256 srcAmount,uint256 destAmount,uint256 expectedDestAmount,uint256 deadline,uint256 nonce,uint256 partnerAndFee,bytes permit)";

    /*//////////////////////////////////////////////////////////////
                                TYPEHASH
    //////////////////////////////////////////////////////////////*/

    /// @dev The type hash of the fillable order struct
    bytes32 internal constant _FILLABLE_ORDER_TYPEHASH =
        0xe04ecb09e1ce24b3c3dcd0be44a59388efb42929225376031666661ab6196311;

    /*//////////////////////////////////////////////////////////////
                                  HASH
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the hash of the provided order
    /// @param order The order to hash
    /// @return The hash of the order
    function hash(Order memory order) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                _FILLABLE_ORDER_TYPEHASH,
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
