// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Interfaces
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IFillableSwapSettlementModule } from "@modules/settlement/interfaces/IFillableSwapSettlementModule.sol";

// Libraries
import { FillableOrderHashLib } from "@modules/libraries/FillableOrderHashLib.sol";
import { FillableStorageLib } from "@modules/libraries/FillableStorageLib.sol";
import { NonceManagerLib } from "@modules/libraries/NonceManagerLib.sol";
import { ERC20UtilsLib } from "@modules/libraries/ERC20UtilsLib.sol";

// Tests
import { FillableSwapSettlementModule_Test } from "../FillableSwapSettlementModule.t.sol";

// Types
import { Order, OrderWithSig } from "@types/Order.sol";
import { ExecutorData, StepData } from "@executors/example/ThreeStepExecutor.sol";

// Utilities
import { EIP2098Lib } from "test/utils/EIP2098Lib.sol";

contract FillableSwapSettlementModule_swapSettleFillableBatch is FillableSwapSettlementModule_Test {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using FillableOrderHashLib for Order;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error DeadlineExpired();
    error InsufficientReturnAmount();
    error ExecutionFailed();
    error InvalidFillAmount();

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct TestData {
        uint256 numOrders;
        OrderWithSig[] ordersWithSigs;
        bytes[] executorDataArray;
        uint256[] fillPercents;
    }

    /*//////////////////////////////////////////////////////////////
                               TEST DATA
    //////////////////////////////////////////////////////////////*/

    /// @dev Creates test data for tests, we can't use setup because foundry
    ///     doesn't support copying memory structs to storage atm
    function createTestData() internal returns (TestData memory data) {
        // Setup Base Test
        super.setUp();

        // Initialize test data
        data.numOrders = 3;
        data.ordersWithSigs = new OrderWithSig[](data.numOrders);
        data.executorDataArray = new bytes[](data.numOrders);
        data.fillPercents = new uint256[](data.numOrders);

        // Register charlie as an authorized agent
        vm.startPrank(users.admin.account);
        address[] memory agents = new address[](1);
        agents[0] = users.charlie.account;
        portikusV2.registerAgent(agents);

        for (uint256 i = 0; i < data.numOrders; i++) {
            // Set up amounts for each order
            uint256 srcAmount = 10 ether * (i + 1);
            uint256 feeAmount = 1 ether;
            uint256 destAmount = 9 ether * (i + 1);

            // Transfer MTK to alice and approve module
            vm.startPrank(users.admin.account);
            MTK.transfer(users.alice.account, srcAmount);
            vm.startPrank(users.alice.account);
            MTK.approve(address(module), type(uint256).max);

            // Create order
            Order memory order = Order({
                owner: users.alice.account,
                beneficiary: users.alice.account,
                srcToken: address(MTK),
                destToken: address(DAI),
                srcAmount: srcAmount,
                destAmount: destAmount - feeAmount - 2,
                expectedDestAmount: destAmount - feeAmount - 2,
                deadline: block.timestamp + 100,
                partnerAndFee: 0,
                nonce: i + 1,
                permit: ""
            });

            // Sign order
            bytes32 hash = _hashTypedDataV4(order.hash());
            uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
            bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
            data.ordersWithSigs[i] = OrderWithSig({ order: order, signature: sig });

            // Create executor data
            ExecutorData memory executorData = ExecutorData(
                StepData(abi.encodeWithSignature("approve(address,uint256)", address(dex), srcAmount), address(MTK)),
                StepData(
                    abi.encodeWithSignature(
                        "swap(address,address,uint256,uint256,address)",
                        address(MTK),
                        address(DAI),
                        srcAmount,
                        destAmount,
                        address(executor)
                    ),
                    address(dex)
                ),
                StepData("", address(0)),
                users.charlie.account,
                address(DAI),
                feeAmount
            );
            data.executorDataArray[i] = abi.encode(executorData);
            data.fillPercents[i] = FillableStorageLib.HUNDRED_PERCENT;
        }
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_swapSettleFillableBatch_Success() public {
        // Setup
        TestData memory data = createTestData();

        // Check initial balance
        uint256 balanceBefore = DAI.balanceOf(users.alice.account);

        // Execute batch swap as authorized agent (charlie)
        vm.startPrank(users.charlie.account);
        IFillableSwapSettlementModule(module).swapSettleFillableBatch(
            data.ordersWithSigs, data.executorDataArray, address(executor), data.fillPercents
        );

        // Verify balance change
        uint256 balanceAfter = DAI.balanceOf(users.alice.account);

        // Calculate and assert expected total destination amount
        uint256 expectedTotalDestAmount = 0;
        for (uint256 i = 0; i < data.numOrders; i++) {
            expectedTotalDestAmount += data.ordersWithSigs[i].order.destAmount;
        }
        assertGte(balanceAfter, balanceBefore + expectedTotalDestAmount);
    }

    function test_swapSettleFillableBatch_SuccessWithETH() public {
        // Setup
        TestData memory data = createTestData();

        // Modify orders and executor data for ETH as destination
        for (uint256 i = 0; i < data.numOrders; i++) {
            data.ordersWithSigs[i].order.destToken = ERC20UtilsLib.ETH_ADDRESS;
            data.ordersWithSigs[i].order.destAmount = data.ordersWithSigs[i].order.destAmount - 20 - 1 ether;
            // Adjust destAmount
            ExecutorData memory executorData = abi.decode(data.executorDataArray[i], (ExecutorData));
            executorData.destToken = ERC20UtilsLib.ETH_ADDRESS;
            executorData.mainCalldata.stepCalldata = abi.encodeWithSignature(
                "swap(address,address,uint256,uint256,address)",
                address(MTK),
                address(0), // ETH
                data.ordersWithSigs[i].order.srcAmount,
                data.ordersWithSigs[i].order.destAmount + 20 + 1 ether,
                address(executor)
            );
            data.executorDataArray[i] = abi.encode(executorData);

            // Re-sign the modified order
            bytes32 hash = _hashTypedDataV4(data.ordersWithSigs[i].order.hash());
            uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
            bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
            data.ordersWithSigs[i].signature = sig;
        }

        // Check initial ETH balance
        uint256 balanceBefore = users.alice.account.balance;

        // Execute batch swap as authorized agent (charlie)
        vm.startPrank(users.charlie.account);
        IFillableSwapSettlementModule(module).swapSettleFillableBatch(
            data.ordersWithSigs, data.executorDataArray, address(executor), data.fillPercents
        );

        // Verify ETH balance change
        uint256 balanceAfter = users.alice.account.balance;

        // Calculate and assert expected total destination amount
        uint256 expectedTotalDestAmount = 0;
        for (uint256 i = 0; i < data.numOrders; i++) {
            expectedTotalDestAmount += data.ordersWithSigs[i].order.destAmount;
        }
        assertGte(balanceAfter, balanceBefore + expectedTotalDestAmount);
    }

    function test_swapSettleFillableBatch_RevertsWhen_FillAmountOutIsZero() public {
        TestData memory data = createTestData();

        // Modify one order's destAmount to be very small
        data.ordersWithSigs[0].order.destAmount = 9999; // Just below 10000 to ensure zero result with integer division

        // Set a fillPercent that results in zero expected amount for the first order
        data.fillPercents[0] = 1;

        // Calculate expected fill amount
        uint256 expectedFillAmount =
            (data.ordersWithSigs[0].order.destAmount * data.fillPercents[0]) / FillableStorageLib.HUNDRED_PERCENT;

        // Ensure the expected fill amount is zero
        assertEq(expectedFillAmount, 0, "Expected fill amount should be zero");

        // Update executor data for the first order
        ExecutorData memory executorData = abi.decode(data.executorDataArray[0], (ExecutorData));
        executorData.mainCalldata.stepCalldata = abi.encodeWithSignature(
            "swap(address,address,uint256,uint256,address)",
            address(MTK),
            address(DAI),
            (data.ordersWithSigs[0].order.srcAmount * 9999) / FillableStorageLib.HUNDRED_PERCENT,
            (data.ordersWithSigs[0].order.srcAmount * 9999) / FillableStorageLib.HUNDRED_PERCENT,
            address(executor)
        );
        data.executorDataArray[0] = abi.encode(executorData);

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.ordersWithSigs[0].order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.ordersWithSigs[0].signature = sig;

        vm.startPrank(users.charlie.account);
        vm.expectRevert(InvalidFillAmount.selector);
        IFillableSwapSettlementModule(module).swapSettleFillableBatch(
            data.ordersWithSigs, data.executorDataArray, address(executor), data.fillPercents
        );
    }

    function test_swapSettleFillableBatch_RevertsWhen_FillAmountInIsZero() public {
        TestData memory data = createTestData();

        // Set a fillPercent that results in zero expected amount for the first order
        data.fillPercents[0] = 0;

        // Calculate expected fill amount
        uint256 expectedFillAmount =
            (data.ordersWithSigs[0].order.destAmount * data.fillPercents[0]) / FillableStorageLib.HUNDRED_PERCENT;

        // Ensure the expected fill amount is zero
        assertEq(expectedFillAmount, 0, "Expected fill amount should be zero");

        // Update executor data for the first order
        ExecutorData memory executorData = abi.decode(data.executorDataArray[0], (ExecutorData));
        executorData.mainCalldata.stepCalldata = abi.encodeWithSignature(
            "swap(address,address,uint256,uint256,address)", address(MTK), address(DAI), 0, 0, address(executor)
        );
        data.executorDataArray[0] = abi.encode(executorData);

        vm.startPrank(users.charlie.account);
        vm.expectRevert(InvalidFillAmount.selector);
        IFillableSwapSettlementModule(module).swapSettleFillableBatch(
            data.ordersWithSigs, data.executorDataArray, address(executor), data.fillPercents
        );
    }

    function test_swapSettleFillableBatch_RevertsWhen_DeadlineExpired() public {
        // Setup
        TestData memory data = createTestData();

        // Modify orders to have expired deadlines
        for (uint256 i = 0; i < data.numOrders; i++) {
            data.ordersWithSigs[i].order.deadline = block.timestamp - 100; // Expired deadline

            // Re-sign the modified order
            bytes32 hash = _hashTypedDataV4(data.ordersWithSigs[i].order.hash());
            uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
            bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
            data.ordersWithSigs[i].signature = sig;
        }

        // Attempt to settle batch with expired orders
        vm.startPrank(users.charlie.account);
        vm.expectRevert(DeadlineExpired.selector);
        IFillableSwapSettlementModule(module).swapSettleFillableBatch(
            data.ordersWithSigs, data.executorDataArray, address(executor), data.fillPercents
        );
    }

    function test_swapSettleFillableBatch_RevertsWhen_InsufficientReturnAmount() public {
        // Setup
        TestData memory data = createTestData();

        // Modify orders to have unrealistically high destAmount
        for (uint256 i = 0; i < data.numOrders; i++) {
            data.ordersWithSigs[i].order.destAmount += 100_000 ether; // Insufficient return amount

            // Re-sign the modified order
            bytes32 hash = _hashTypedDataV4(data.ordersWithSigs[i].order.hash());
            uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
            bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
            data.ordersWithSigs[i].signature = sig;
        }

        // Attempt to settle batch with insufficient return amounts
        vm.startPrank(users.charlie.account);
        vm.expectRevert(InsufficientReturnAmount.selector);
        IFillableSwapSettlementModule(module).swapSettleFillableBatch(
            data.ordersWithSigs, data.executorDataArray, address(executor), data.fillPercents
        );
    }

    function test_swapSettleFillableBatch_RevertsWhen_UnauthorizedAgent() public {
        // Setup
        TestData memory data = createTestData();

        // Attempt to settle as unauthorized agent (bob)
        vm.startPrank(users.bob.account);
        vm.expectRevert();
        IFillableSwapSettlementModule(module).swapSettleFillableBatch(
            data.ordersWithSigs, data.executorDataArray, address(executor), data.fillPercents
        );
    }
}
