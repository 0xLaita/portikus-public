// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Libraries
import { FillableOrderHashLib } from "@modules/libraries/FillableOrderHashLib.sol";

// Test
import { HashLib_Test } from "../HashLib.t.sol";

// Types
import { Order } from "@types/Order.sol";

contract FillableOrderHashLib_hash is HashLib_Test {
    /*//////////////////////////////////////////////////////////////
                                  TESTS
    //////////////////////////////////////////////////////////////*/

    function test_hash_FillableOrder_CorrectHash() public {
        // Arrange order
        Order memory order = Order({
            owner: address(this),
            beneficiary: address(this),
            srcToken: address(WETH),
            destToken: address(MTK),
            srcAmount: 100,
            destAmount: 100,
            expectedDestAmount: 100,
            deadline: block.timestamp + 100,
            nonce: 1,
            partnerAndFee: 0,
            permit: bytes(hex"1234")
        });

        // Expected hash
        bytes32 expectedHash = keccak256(
            abi.encode(
                FillableOrderHashLib._FILLABLE_ORDER_TYPEHASH,
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

        // Act
        bytes32 orderHash = FillableOrderHashLib.hash(order);

        // Assert
        assertEq(orderHash, expectedHash, "Hash should match the expected value");
    }
}