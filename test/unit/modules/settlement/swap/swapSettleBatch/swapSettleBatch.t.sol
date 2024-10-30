// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Interfaces
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISwapSettlementModule } from "@modules/settlement/interfaces/ISwapSettlementModule.sol";

// Libraries
import { OrderHashLib } from "@modules/libraries/OrderHashLib.sol";

// Tests
import { SwapSettlementModule_Test } from "../SwapSettlementModule.t.sol";

// Types
import { Order, OrderWithSig } from "@types/Order.sol";
import { ExecutorData, StepData } from "@executors/example/ThreeStepExecutor.sol";

// Utilities
import { EIP2098Lib } from "test/utils/EIP2098Lib.sol";

contract SwapSettlementModule_swapSettleBatch is SwapSettlementModule_Test {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using OrderHashLib for Order;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error DeadlineExpired();
    error InsufficientReturnAmount();
    error ExecutionFailed();

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct TestData {
        uint256 numOrders;
        OrderWithSig[] ordersWithSigs;
        bytes[] executorDataArray;
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

        // Register charlie as an authorized agent
        vm.startPrank(users.admin.account);
        address[] memory agents = new address[](1);
        agents[0] = users.charlie.account;
        portikusV2.registerAgent(agents);

        for (uint256 i = 0; i < data.numOrders; i++) {
            // Set up amounts for each order
            uint256 srcAmount = 100 * (i + 1);
            uint256 feeAmount = 1;
            uint256 destAmount = 99 * (i + 1);

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
        }
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_swapSettleBatch_Success() public {
        // Setup
        TestData memory data = createTestData();

        // Check initial balance
        uint256 balanceBefore = DAI.balanceOf(users.alice.account);

        // Execute batch swap as authorized agent (charlie)
        vm.startPrank(users.charlie.account);
        ISwapSettlementModule(module).swapSettleBatch(data.ordersWithSigs, data.executorDataArray, address(executor));

        // Verify balance change
        uint256 balanceAfter = DAI.balanceOf(users.alice.account);

        // Calculate and assert expected total destination amount
        uint256 expectedTotalDestAmount = 0;
        for (uint256 i = 0; i < data.numOrders; i++) {
            expectedTotalDestAmount += data.ordersWithSigs[i].order.destAmount;
        }
        assertGte(balanceAfter, balanceBefore + expectedTotalDestAmount);
    }

    function test_swapSettleBatch_SuccessWithETH() public {
        // Setup
        TestData memory data = createTestData();

        // Modify orders and executor data for ETH as destination
        for (uint256 i = 0; i < data.numOrders; i++) {
            data.ordersWithSigs[i].order.destToken = address(ETH);
            data.ordersWithSigs[i].order.destAmount = data.ordersWithSigs[i].order.destAmount - 20; // Adjust destAmount
            ExecutorData memory executorData = abi.decode(data.executorDataArray[i], (ExecutorData));
            executorData.destToken = address(ETH);
            executorData.mainCalldata.stepCalldata = abi.encodeWithSignature(
                "swap(address,address,uint256,uint256,address)",
                address(MTK),
                address(0), // ETH
                data.ordersWithSigs[i].order.srcAmount,
                data.ordersWithSigs[i].order.destAmount + 20,
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
        ISwapSettlementModule(module).swapSettleBatch(data.ordersWithSigs, data.executorDataArray, address(executor));

        // Verify ETH balance change
        uint256 balanceAfter = users.alice.account.balance;

        // Calculate and assert expected total destination amount
        uint256 expectedTotalDestAmount = 0;
        for (uint256 i = 0; i < data.numOrders; i++) {
            expectedTotalDestAmount += data.ordersWithSigs[i].order.destAmount;
        }
        assertGte(balanceAfter, balanceBefore + expectedTotalDestAmount);
    }

    function test_swapSettleBatch_RevertsWhen_DeadlineExpired() public {
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
        ISwapSettlementModule(module).swapSettleBatch(data.ordersWithSigs, data.executorDataArray, address(executor));
    }

    function test_swapSettleBatch_RevertsWhen_InsufficientReturnAmount() public {
        // Setup
        TestData memory data = createTestData();

        // Modify orders to have unrealistically high destAmount
        for (uint256 i = 0; i < data.numOrders; i++) {
            data.ordersWithSigs[i].order.destAmount += 100_000; // Insufficient return amount

            // Re-sign the modified order
            bytes32 hash = _hashTypedDataV4(data.ordersWithSigs[i].order.hash());
            uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
            bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
            data.ordersWithSigs[i].signature = sig;
        }

        // Attempt to settle batch with insufficient return amounts
        vm.startPrank(users.charlie.account);
        vm.expectRevert(InsufficientReturnAmount.selector);
        ISwapSettlementModule(module).swapSettleBatch(data.ordersWithSigs, data.executorDataArray, address(executor));
    }

    function test_swapSettleBatch_RevertsWhen_UnauthorizedAgent() public {
        // Setup
        TestData memory data = createTestData();

        // Attempt to settle as unauthorized agent (bob)
        vm.startPrank(users.bob.account);
        vm.expectRevert();
        ISwapSettlementModule(module).swapSettleBatch(data.ordersWithSigs, data.executorDataArray, address(executor));
    }
}
