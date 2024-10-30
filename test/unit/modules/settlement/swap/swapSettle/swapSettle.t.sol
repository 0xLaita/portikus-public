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

contract SwapSettlementModule_swapSettle is SwapSettlementModule_Test {
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
        uint256 srcAmount;
        uint256 feeAmount;
        uint256 destAmount;
        Order order;
        OrderWithSig orderWithSig;
        ExecutorData executorData;
    }

    /*//////////////////////////////////////////////////////////////
                               TEST DATA
    //////////////////////////////////////////////////////////////*/

    /// @dev Creates test data for tests, we can't use setup because foundry
    ///     doesn't support copying memory structs to storage atm
    function createTestData() internal returns (TestData memory data) {
        // Setup Base Test
        super.setUp();

        // Prepare test data
        data.srcAmount = 100;
        data.feeAmount = 1;
        data.destAmount = 99;

        // Prank to admin and transfer MTK to alice
        vm.startPrank(users.admin.account);
        address[] memory agents = new address[](1);
        agents[0] = users.charlie.account;
        portikusV2.registerAgent(agents);
        MTK.transfer(users.alice.account, data.srcAmount);
        vm.stopPrank();

        // Prank to alice and approve MTK to module
        vm.startPrank(users.alice.account);
        MTK.approve(address(module), data.srcAmount);

        // Prepare order data
        data.order = Order({
            owner: users.alice.account,
            beneficiary: users.alice.account,
            srcToken: address(MTK),
            destToken: address(DAI),
            srcAmount: data.srcAmount,
            destAmount: data.destAmount - data.feeAmount - 1,
            expectedDestAmount: data.destAmount - data.feeAmount - 1,
            deadline: block.timestamp + 100,
            partnerAndFee: 0,
            nonce: 1,
            permit: ""
        });

        // Arrange valid signature
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        // Set executor data
        data.executorData = ExecutorData(
            StepData(abi.encodeWithSignature("approve(address,uint256)", address(dex), data.srcAmount), address(MTK)),
            StepData(
                abi.encodeWithSignature(
                    "swap(address,address,uint256,uint256,address)",
                    address(MTK),
                    address(DAI),
                    data.srcAmount,
                    data.destAmount,
                    address(executor)
                ),
                address(dex)
            ),
            StepData("", address(0)),
            users.charlie.account,
            address(DAI),
            data.feeAmount
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_swapSettle_Success() public {
        // Setup
        TestData memory data = createTestData();

        // Check initial balance
        uint256 balanceBefore = DAI.balanceOf(users.alice.account);

        // Execute swap as authorized agent (charlie)
        vm.startPrank(users.charlie.account);
        ISwapSettlementModule(module).swapSettle(data.orderWithSig, abi.encode(data.executorData), address(executor));

        // Verify balance change
        uint256 balanceAfter = DAI.balanceOf(users.alice.account);
        assertEq(balanceAfter, balanceBefore + data.destAmount - data.feeAmount - 1);
    }

    function test_swapSettle_SuccessWithBeneficiaryUnset() public {
        TestData memory data = createTestData();

        data.order.beneficiary = address(0);

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        // Check initial balance
        uint256 balanceBefore = DAI.balanceOf(users.alice.account);

        vm.startPrank(users.charlie.account);
        ISwapSettlementModule(module).swapSettle(data.orderWithSig, abi.encode(data.executorData), address(executor));

        uint256 balanceAfter = DAI.balanceOf(users.alice.account);
        assertEq(balanceAfter, balanceBefore + data.destAmount - data.feeAmount - 1);
    }

    function test_swapSettle_SuccessWithETH() public {
        // Setup
        TestData memory data = createTestData();

        // Setup for ETH swap
        data.order.destToken = address(ETH);
        data.executorData.destToken = address(ETH);
        data.executorData.mainCalldata.stepCalldata = abi.encodeWithSignature(
            "swap(address,address,uint256,uint256,address)",
            address(MTK),
            address(0), // ETH
            data.srcAmount,
            data.destAmount,
            address(executor)
        );

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        // Check initial ETH balance
        uint256 balanceBefore = users.alice.account.balance;

        // Execute swap as authorized agent (charlie)
        vm.startPrank(users.charlie.account);
        ISwapSettlementModule(module).swapSettle(data.orderWithSig, abi.encode(data.executorData), address(executor));

        // Verify ETH balance change
        uint256 balanceAfter = users.alice.account.balance;
        assertEq(balanceAfter, balanceBefore + data.destAmount - data.feeAmount);
    }

    function test_swapSettle_RevertsWhen_DeadlineExpired() public {
        // Setup
        TestData memory data = createTestData();

        // Modify order to have an expired deadline
        data.order.deadline = block.timestamp - 100;

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        // Attempt to settle with expired order
        vm.startPrank(users.charlie.account);
        vm.expectRevert(DeadlineExpired.selector);
        ISwapSettlementModule(module).swapSettle(data.orderWithSig, abi.encode(data.executorData), address(executor));
    }

    function test_swapSettle_RevertsWhen_InsufficientReturnAmount() public {
        // Setup
        TestData memory data = createTestData();

        // Modify order to have an unrealistically high destAmount
        data.order.destAmount = data.destAmount + 10_000;

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        // Attempt to settle with insufficient return amount
        vm.startPrank(users.charlie.account);
        vm.expectRevert(InsufficientReturnAmount.selector);
        ISwapSettlementModule(module).swapSettle(data.orderWithSig, abi.encode(data.executorData), address(executor));
    }

    function test_swapSettle_RevertsWhen_UnauthorizedAgent() public {
        // Setup
        TestData memory data = createTestData();

        // Attempt to settle as unauthorized agent (bob)
        vm.startPrank(users.bob.account);
        vm.expectRevert();
        ISwapSettlementModule(module).swapSettle(data.orderWithSig, abi.encode(data.executorData), address(executor));
    }

    function test_swapSettle_RevertsWhen_BeforeStepFailed() public {
        // Setup
        TestData memory data = createTestData();

        // Modify executorData to make beforeStep fail
        data.executorData.beforeCalldata = StepData(abi.encodeWithSignature("revert()"), address(this));

        // Attempt to settle with failing beforeStep
        vm.startPrank(users.charlie.account);
        vm.expectRevert(ExecutionFailed.selector);
        ISwapSettlementModule(module).swapSettle(data.orderWithSig, abi.encode(data.executorData), address(executor));
    }

    function test_swapSettle_RevertsWhen_MainStepFailed() public {
        // Setup
        TestData memory data = createTestData();

        // Modify executorData to make mainStep fail
        data.executorData.mainCalldata = StepData(abi.encodeWithSignature("revert()"), address(this));

        // Attempt to settle with failing mainStep
        vm.startPrank(users.charlie.account);
        vm.expectRevert();
        ISwapSettlementModule(module).swapSettle(data.orderWithSig, abi.encode(data.executorData), address(executor));
    }

    function test_swapSettle_RevertsWhen_AfterStepFailed() public {
        // Setup
        TestData memory data = createTestData();

        // Modify executorData to make afterStep fail
        data.executorData.afterCalldata = StepData(abi.encodeWithSignature("revert()"), address(this));

        // Attempt to settle with failing afterStep
        vm.startPrank(users.charlie.account);
        vm.expectRevert(ExecutionFailed.selector);
        ISwapSettlementModule(module).swapSettle(data.orderWithSig, abi.encode(data.executorData), address(executor));
    }
}
