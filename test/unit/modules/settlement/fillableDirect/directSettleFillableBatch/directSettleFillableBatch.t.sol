// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Interfaces
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IFillableDirectSettlementModule } from "@modules/settlement/interfaces/IFillableDirectSettlementModule.sol";

// Libraries
import { FillableOrderHashLib } from "@modules/libraries/FillableOrderHashLib.sol";
import { FillableStorageLib } from "@modules/libraries/FillableStorageLib.sol";
import { NonceManagerLib } from "@modules/libraries/NonceManagerLib.sol";
import { ERC20UtilsLib } from "@modules/libraries/ERC20UtilsLib.sol";

// Tests
import { FillableDirectSettlementModule_Test } from "../FillableDirectSettlementModule.t.sol";

// Types
import { Order, OrderWithSig } from "@types/Order.sol";

// Utilities
import { EIP2098Lib } from "test/utils/EIP2098Lib.sol";

contract FillableDirectSettlementModule_directSettleFillableBatch is FillableDirectSettlementModule_Test {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using FillableOrderHashLib for Order;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error DeadlineExpired();
    error InsufficientReturnAmount();
    error InvalidFillAmount();
    error InsufficientMsgValue();

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct TestData {
        uint256[] srcAmounts;
        uint256[] destAmounts;
        Order[] orders;
        OrderWithSig[] ordersWithSigs;
    }

    /*//////////////////////////////////////////////////////////////
                               TEST DATA
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates and returns test data for the test cases
    function createTestData(uint256 numOrders, bool includeETH) internal returns (TestData memory data) {
        // Setup base test
        super.setUp();

        data.srcAmounts = new uint256[](numOrders);
        data.destAmounts = new uint256[](numOrders);
        data.orders = new Order[](numOrders);
        data.ordersWithSigs = new OrderWithSig[](numOrders);

        for (uint256 i = 0; i < numOrders; i++) {
            data.srcAmounts[i] = 100 ether + i * 10 ether;
            data.destAmounts[i] = 99 ether + i * 10 ether;

            // Transfer tokens to test accounts
            vm.startPrank(users.admin.account);
            MTK.transfer(users.alice.account, data.srcAmounts[i]);
            if (includeETH && i == numOrders - 1) {
                vm.deal(users.charlie.account, data.destAmounts[i]);
            } else {
                DAI.transfer(users.charlie.account, data.destAmounts[i]);
            }
            vm.stopPrank();

            // Approve module to spend Alice's tokens
            vm.startPrank(users.alice.account);
            MTK.approve(address(module), type(uint256).max);
            vm.stopPrank();

            // Create order data
            data.orders[i] = Order({
                owner: users.alice.account,
                beneficiary: users.alice.account,
                srcToken: address(MTK),
                destToken: includeETH && i == numOrders - 1 ? ERC20UtilsLib.ETH_ADDRESS : address(DAI),
                srcAmount: data.srcAmounts[i],
                destAmount: data.destAmounts[i],
                expectedDestAmount: data.destAmounts[i],
                deadline: block.timestamp + 100,
                partnerAndFee: 0,
                nonce: i + 1,
                permit: ""
            });

            // Sign the order
            bytes32 hash = _hashTypedDataV4(data.orders[i].hash());
            uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
            bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
            data.ordersWithSigs[i] = OrderWithSig({ order: data.orders[i], signature: sig });
        }

        // Approve module to spend agent's (charlie's) tokens
        vm.startPrank(users.charlie.account);
        DAI.approve(address(module), type(uint256).max);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test successful fillable direct settlement batch with ERC20 tokens
    function test_directSettleFillableBatch_Success() public {
        TestData memory data = createTestData(3, false);

        uint256 balanceBefore = DAI.balanceOf(users.alice.account);
        uint256 totalDestAmount = 0;
        for (uint256 i = 0; i < data.destAmounts.length; i++) {
            totalDestAmount += data.destAmounts[i];
        }

        uint256[] memory fillPercents = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        for (uint256 i = 0; i < fillPercents.length; i++) {
            fillPercents[i] = FillableStorageLib.HUNDRED_PERCENT;
            amounts[i] = data.destAmounts[i];
        }

        vm.startPrank(users.charlie.account);
        IFillableDirectSettlementModule(module).directSettleFillableBatch(data.ordersWithSigs, fillPercents, amounts);

        uint256 balanceAfter = DAI.balanceOf(users.alice.account);
        assertEq(balanceAfter, balanceBefore + totalDestAmount);
    }

    /// @notice Test successful partial fillable direct settlement batch
    function test_directSettleFillableBatch_SuccessPartialFill() public {
        TestData memory data = createTestData(3, false);

        uint256 balanceBefore = DAI.balanceOf(users.alice.account);
        uint256 expectedTotalFillAmount = 0;

        uint256[] memory fillPercents = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        fillPercents[0] = 5000; // 50%
        fillPercents[1] = 7500; // 75%
        fillPercents[2] = 2500; // 25%

        for (uint256 i = 0; i < data.destAmounts.length; i++) {
            amounts[i] = data.destAmounts[i] * fillPercents[i] / FillableStorageLib.HUNDRED_PERCENT;
            expectedTotalFillAmount += amounts[i];
        }

        vm.startPrank(users.charlie.account);
        IFillableDirectSettlementModule(module).directSettleFillableBatch(data.ordersWithSigs, fillPercents, amounts);

        uint256 balanceAfter = DAI.balanceOf(users.alice.account);
        assertEq(balanceAfter, balanceBefore + expectedTotalFillAmount);
    }

    /// @notice Test revert when one order in batch has expired deadline
    function test_directSettleFillableBatch_RevertsWhen_OneDeadlineExpired() public {
        TestData memory data = createTestData(3, false);

        data.orders[1].deadline = block.timestamp - 100;

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.orders[1].hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.ordersWithSigs[1] = OrderWithSig({ order: data.orders[1], signature: sig });

        uint256[] memory fillPercents = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        for (uint256 i = 0; i < fillPercents.length; i++) {
            fillPercents[i] = FillableStorageLib.HUNDRED_PERCENT;
            amounts[i] = data.destAmounts[i];
        }

        vm.startPrank(users.charlie.account);
        vm.expectRevert(DeadlineExpired.selector);
        IFillableDirectSettlementModule(module).directSettleFillableBatch(data.ordersWithSigs, fillPercents, amounts);
    }

    /// @notice Test revert when called by an unauthorized agent
    function test_directSettleFillableBatch_RevertsWhen_UnauthorizedAgent() public {
        TestData memory data = createTestData(3, false);

        uint256[] memory fillPercents = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        for (uint256 i = 0; i < fillPercents.length; i++) {
            fillPercents[i] = FillableStorageLib.HUNDRED_PERCENT;
            amounts[i] = data.destAmounts[i];
        }

        vm.startPrank(users.bob.account);
        vm.expectRevert();
        IFillableDirectSettlementModule(module).directSettleFillableBatch(data.ordersWithSigs, fillPercents, amounts);
    }

    /// @notice Test successful fillable direct settlement batch with mixed ERC20 and ETH
    function test_directSettleFillableBatch_SuccessMixedERC20AndETH() public {
        TestData memory data = createTestData(3, true);

        uint256 balanceBeforeERC20 = DAI.balanceOf(users.alice.account);
        uint256 balanceBeforeETH = users.alice.account.balance;
        uint256 totalDestAmountERC20 = data.destAmounts[0] + data.destAmounts[1];
        uint256 totalDestAmountETH = data.destAmounts[2];

        uint256[] memory fillPercents = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        for (uint256 i = 0; i < fillPercents.length; i++) {
            fillPercents[i] = FillableStorageLib.HUNDRED_PERCENT;
            amounts[i] = data.destAmounts[i];
        }

        vm.startPrank(users.charlie.account);
        IFillableDirectSettlementModule(module).directSettleFillableBatch{ value: totalDestAmountETH }(
            data.ordersWithSigs, fillPercents, amounts
        );

        uint256 balanceAfterERC20 = DAI.balanceOf(users.alice.account);
        uint256 balanceAfterETH = users.alice.account.balance;
        assertEq(
            balanceAfterERC20, balanceBeforeERC20 + totalDestAmountERC20, "ERC20 balance should increase correctly"
        );
        assertEq(balanceAfterETH, balanceBeforeETH + totalDestAmountETH, "ETH balance should increase correctly");
    }

    /// @notice Test revert when insufficient ETH is sent for mixed ERC20 and ETH batch
    function test_directSettleFillableBatch_RevertsWhen_InsufficientETHSent() public {
        TestData memory data = createTestData(3, true);

        uint256[] memory fillPercents = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        for (uint256 i = 0; i < fillPercents.length; i++) {
            fillPercents[i] = FillableStorageLib.HUNDRED_PERCENT;
            amounts[i] = data.destAmounts[i];
        }

        vm.startPrank(users.charlie.account);
        vm.expectRevert(InsufficientMsgValue.selector);
        vm.deal(address(module), 1 ether); // // Send ETH to module so it has enough for internal transfers
        IFillableDirectSettlementModule(module).directSettleFillableBatch{ value: data.destAmounts[2] - 1 }(
            data.ordersWithSigs, fillPercents, amounts
        );
    }

    /// @notice Test partial fill for mixed ERC20 and ETH batch
    function test_directSettleFillableBatch_PartialFillMixedERC20AndETH() public {
        TestData memory data = createTestData(3, true);

        uint256 balanceBeforeERC20 = DAI.balanceOf(users.alice.account);
        uint256 balanceBeforeETH = users.alice.account.balance;

        uint256[] memory fillPercents = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        fillPercents[0] = 5000; // 50%
        fillPercents[1] = 7500; // 75%
        fillPercents[2] = 2500; // 25% (ETH)

        uint256 expectedFillAmountERC20 = 0;
        uint256 expectedFillAmountETH = 0;

        for (uint256 i = 0; i < data.destAmounts.length; i++) {
            amounts[i] = data.destAmounts[i] * fillPercents[i] / FillableStorageLib.HUNDRED_PERCENT;
            if (i < 2) {
                expectedFillAmountERC20 += amounts[i];
            } else {
                expectedFillAmountETH = amounts[i];
            }
        }

        vm.startPrank(users.charlie.account);
        IFillableDirectSettlementModule(module).directSettleFillableBatch{ value: expectedFillAmountETH }(
            data.ordersWithSigs, fillPercents, amounts
        );

        uint256 balanceAfterERC20 = DAI.balanceOf(users.alice.account);
        uint256 balanceAfterETH = users.alice.account.balance;
        assertEq(
            balanceAfterERC20, balanceBeforeERC20 + expectedFillAmountERC20, "ERC20 balance should increase correctly"
        );
        assertEq(balanceAfterETH, balanceBeforeETH + expectedFillAmountETH, "ETH balance should increase correctly");
    }

    /// @notice Test successful fillable direct settlement batch with ETH as destination token for all orders
    function test_directSettleFillableBatch_SuccessWithETH() public {
        TestData memory data = createTestData(3, false); // Set to false as we'll manually set all to ETH
        uint256 totalEthAmount = 0;

        for (uint256 i = 0; i < data.orders.length; i++) {
            data.orders[i].destToken = ERC20UtilsLib.ETH_ADDRESS;
            totalEthAmount += data.destAmounts[i];

            // Re-sign the modified order
            bytes32 hash = _hashTypedDataV4(data.orders[i].hash());
            uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
            bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
            data.ordersWithSigs[i] = OrderWithSig({ order: data.orders[i], signature: sig });
        }

        // Transfer ETH to Charlie
        vm.deal(users.charlie.account, totalEthAmount);

        uint256 balanceBefore = users.alice.account.balance;

        uint256[] memory fillPercents = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        for (uint256 i = 0; i < fillPercents.length; i++) {
            fillPercents[i] = FillableStorageLib.HUNDRED_PERCENT;
            amounts[i] = data.destAmounts[i];
        }

        vm.startPrank(users.charlie.account);
        IFillableDirectSettlementModule(module).directSettleFillableBatch{ value: totalEthAmount }(
            data.ordersWithSigs, fillPercents, amounts
        );

        uint256 balanceAfter = users.alice.account.balance;
        assertEq(balanceAfter, balanceBefore + totalEthAmount, "ETH balance should increase by the total amount");
        assertEq(DAI.balanceOf(users.alice.account), 0, "DAI balance should remain unchanged");
    }

    /// @notice Test revert when msg.value is insufficient for ETH destination in batch
    function test_directSettleFillableBatch_RevertsWhen_InsufficientMsgValue() public {
        TestData memory data = createTestData(3, true);
        data.orders[1].destToken = ERC20UtilsLib.ETH_ADDRESS;

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.orders[1].hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.ordersWithSigs[1] = OrderWithSig({ order: data.orders[1], signature: sig });

        uint256 ethAmount = data.destAmounts[1] + data.destAmounts[2];

        uint256[] memory fillPercents = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        for (uint256 i = 0; i < fillPercents.length; i++) {
            fillPercents[i] = FillableStorageLib.HUNDRED_PERCENT;
            amounts[i] = data.destAmounts[i];
        }

        vm.deal(users.charlie.account, ethAmount - 1); // Send less than required
        vm.deal(address(module), 1 ether); // Send ETH to module so it has enough for internal transfers
        vm.startPrank(users.charlie.account);
        vm.expectRevert(InsufficientMsgValue.selector);
        IFillableDirectSettlementModule(module).directSettleFillableBatch{ value: ethAmount - 1 }(
            data.ordersWithSigs, fillPercents, amounts
        );
    }

    /// @notice Test revert when fillAmountOut is zero for any order in the batch
    function test_directSettleFillableBatch_RevertsWhen_FillAmountOutIsZero() public {
        TestData memory data = createTestData(3, false);

        // Modify one order's destAmount to be very small
        data.orders[1].destAmount = 9999; // Just below 10000 to ensure zero result with integer division

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.orders[1].hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.ordersWithSigs[1] = OrderWithSig({ order: data.orders[1], signature: sig });

        uint256[] memory fillPercents = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        fillPercents[0] = FillableStorageLib.HUNDRED_PERCENT;
        fillPercents[1] = 1; // This will result in zero fillAmountOut for the second order
        fillPercents[2] = FillableStorageLib.HUNDRED_PERCENT;

        for (uint256 i = 0; i < data.destAmounts.length; i++) {
            amounts[i] = data.destAmounts[i] * fillPercents[i] / FillableStorageLib.HUNDRED_PERCENT;
        }

        vm.startPrank(users.charlie.account);
        vm.expectRevert(InvalidFillAmount.selector);
        IFillableDirectSettlementModule(module).directSettleFillableBatch(data.ordersWithSigs, fillPercents, amounts);
    }

    /// @notice Test revert when fillAmountIn is zero for any order in the batch
    function test_directSettleFillableBatch_RevertsWhen_FillAmountInIsZero() public {
        TestData memory data = createTestData(3, false);

        uint256[] memory fillPercents = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        fillPercents[0] = FillableStorageLib.HUNDRED_PERCENT;
        fillPercents[1] = 0; // This will result in zero fillAmountIn for the second order
        fillPercents[2] = FillableStorageLib.HUNDRED_PERCENT;

        for (uint256 i = 0; i < data.destAmounts.length; i++) {
            amounts[i] = data.destAmounts[i] * fillPercents[i] / FillableStorageLib.HUNDRED_PERCENT;
        }

        vm.startPrank(users.charlie.account);
        vm.expectRevert(InvalidFillAmount.selector);
        IFillableDirectSettlementModule(module).directSettleFillableBatch(data.ordersWithSigs, fillPercents, amounts);
    }

    /// @notice Test revert when amount is less than fillAmountOut for any order in the batch
    function test_directSettleFillableBatch_RevertsWhen_InsufficientAmount() public {
        TestData memory data = createTestData(3, false);

        uint256[] memory fillPercents = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        for (uint256 i = 0; i < fillPercents.length; i++) {
            fillPercents[i] = FillableStorageLib.HUNDRED_PERCENT;
            amounts[i] = data.destAmounts[i];
        }
        amounts[1] = amounts[1] - 1; // Make one amount insufficient

        vm.startPrank(users.charlie.account);
        vm.expectRevert(InsufficientReturnAmount.selector);
        IFillableDirectSettlementModule(module).directSettleFillableBatch(data.ordersWithSigs, fillPercents, amounts);
    }

    /// @notice Test revert when fillPercents and amounts arrays have different lengths
    function test_directSettleFillableBatch_RevertsWhen_ArrayLengthMismatch() public {
        TestData memory data = createTestData(3, false);

        uint256[] memory fillPercents = new uint256[](3);
        uint256[] memory amounts = new uint256[](2); // Mismatch in length
        for (uint256 i = 0; i < fillPercents.length; i++) {
            fillPercents[i] = FillableStorageLib.HUNDRED_PERCENT;
            if (i < 2) {
                amounts[i] = data.destAmounts[i];
            }
        }

        vm.startPrank(users.charlie.account);
        vm.expectRevert();
        IFillableDirectSettlementModule(module).directSettleFillableBatch(data.ordersWithSigs, fillPercents, amounts);
    }

    /// @notice Test successful fillable direct settlement batch with varying fill percents
    function test_directSettleFillableBatch_SuccessVaryingFillPercents() public {
        TestData memory data = createTestData(3, false);

        uint256 balanceBefore = DAI.balanceOf(users.alice.account);
        uint256 expectedTotalFillAmount = 0;

        uint256[] memory fillPercents = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        fillPercents[0] = 10_000; // 100%
        fillPercents[1] = 5000; // 50%
        fillPercents[2] = 7500; // 75%

        for (uint256 i = 0; i < data.destAmounts.length; i++) {
            amounts[i] = data.destAmounts[i] * fillPercents[i] / FillableStorageLib.HUNDRED_PERCENT;
            expectedTotalFillAmount += amounts[i];
        }

        vm.startPrank(users.charlie.account);
        IFillableDirectSettlementModule(module).directSettleFillableBatch(data.ordersWithSigs, fillPercents, amounts);

        uint256 balanceAfter = DAI.balanceOf(users.alice.account);
        assertEq(balanceAfter, balanceBefore + expectedTotalFillAmount);
    }
}
