// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Interfaces
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IFillableDirectSettlementModule } from "@modules/settlement/interfaces/IFillableDirectSettlementModule.sol";

// Libraries
import { FillableOrderHashLib } from "@modules/libraries/FillableOrderHashLib.sol";
import { FillableStorageLib } from "@modules/libraries/FillableStorageLib.sol";

// Tests
import { FillableDirectSettlementModule_Test } from "../FillableDirectSettlementModule.t.sol";

// Types
import { Order, OrderWithSig } from "@types/Order.sol";

// Utilities
import { EIP2098Lib } from "test/utils/EIP2098Lib.sol";

contract FillableDirectSettlementModule_directFilledAmount is FillableDirectSettlementModule_Test {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using FillableOrderHashLib for Order;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct TestData {
        uint256 srcAmount;
        uint256 destAmount;
        Order order;
        OrderWithSig orderWithSig;
    }

    /*//////////////////////////////////////////////////////////////
                               TEST DATA
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates and returns test data for the test cases
    function createTestData() internal returns (TestData memory data) {
        // Setup base test
        super.setUp();

        // Set test amounts
        data.srcAmount = 100 ether;
        data.destAmount = 99 ether;

        // Transfer tokens to test accounts
        vm.startPrank(users.admin.account);
        MTK.transfer(users.alice.account, data.srcAmount);
        DAI.transfer(users.charlie.account, data.destAmount);
        vm.stopPrank();

        // Approve module to spend Alice's tokens
        vm.startPrank(users.alice.account);
        MTK.approve(address(module), type(uint256).max);
        vm.stopPrank();

        // Approve module to spend agent's (charlie's) tokens
        vm.startPrank(users.charlie.account);
        DAI.approve(address(module), type(uint256).max);
        vm.stopPrank();

        // Create order data
        data.order = Order({
            owner: users.alice.account,
            beneficiary: users.alice.account,
            srcToken: address(MTK),
            destToken: address(DAI),
            srcAmount: data.srcAmount,
            destAmount: data.destAmount,
            expectedDestAmount: data.destAmount,
            deadline: block.timestamp + 100,
            partnerAndFee: 0,
            nonce: 1,
            permit: ""
        });

        // Sign the order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test directFilledAmount for an unfilled order
    function test_directFilledAmount_Unfilled() public {
        TestData memory data = createTestData();

        uint256 filledAmount = IFillableDirectSettlementModule(module).directFilledAmount(data.order);
        assertEq(filledAmount, 0, "Unfilled order should return zero filled amount");
    }

    /// @notice Test directFilledAmount for a partially filled order
    function test_directFilledAmount_PartiallyFilled() public {
        TestData memory data = createTestData();

        uint256 fillPercent = 5000; // 50%
        uint256 expectedFillAmount = data.srcAmount * fillPercent / FillableStorageLib.HUNDRED_PERCENT;

        vm.startPrank(users.charlie.account);
        IFillableDirectSettlementModule(module).directSettleFillable(
            data.orderWithSig, fillPercent, data.orderWithSig.order.destAmount / 2
        );

        uint256 filledAmount = IFillableDirectSettlementModule(module).directFilledAmount(data.order);
        assertEq(filledAmount, expectedFillAmount, "Partially filled order should return correct filled amount");
    }

    /// @notice Test directFilledAmount for a fully filled order
    function test_directFilledAmount_FullyFilled() public {
        TestData memory data = createTestData();

        vm.startPrank(users.charlie.account);
        IFillableDirectSettlementModule(module).directSettleFillable(
            data.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, data.orderWithSig.order.destAmount
        );

        uint256 filledAmount = IFillableDirectSettlementModule(module).directFilledAmount(data.order);
        assertEq(filledAmount, data.srcAmount, "Fully filled order should return total dest amount");
    }
}
