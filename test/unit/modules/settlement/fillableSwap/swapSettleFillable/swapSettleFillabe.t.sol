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

contract FillableSwapSettlementModule_swapSettleFillable is FillableSwapSettlementModule_Test {
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

    function createTestData() internal returns (TestData memory data) {
        // Setup Base Test
        super.setUp();

        // Prepare test data
        data.srcAmount = 100 ether;
        data.feeAmount = 1 ether;
        data.destAmount = 99 ether;

        // Prank to admin and transfer MTK to alice
        vm.startPrank(users.admin.account);
        address[] memory agents = new address[](1);
        agents[0] = users.charlie.account;
        portikusV2.registerAgent(agents);
        MTK.transfer(users.alice.account, data.srcAmount);
        vm.stopPrank();

        // Prank to alice and approve MTK to module
        vm.startPrank(users.alice.account);
        MTK.approve(address(module), type(uint256).max);
        vm.stopPrank();

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

    function test_swapSettleFillable_Success() public {
        TestData memory data = createTestData();

        uint256 balanceBefore = DAI.balanceOf(users.alice.account);

        vm.startPrank(users.charlie.account);
        IFillableSwapSettlementModule(module).swapSettleFillable(
            data.orderWithSig, abi.encode(data.executorData), address(executor), FillableStorageLib.HUNDRED_PERCENT
        );

        uint256 balanceAfter = DAI.balanceOf(users.alice.account);
        assertEq(balanceAfter, balanceBefore + data.destAmount - data.feeAmount - 1);
    }

    function test_swapSettleFillable_Success_BeneficiaryUnset() public {
        TestData memory data = createTestData();

        // Unset beneficiary
        data.order.beneficiary = address(0);

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        uint256 balanceBefore = DAI.balanceOf(users.alice.account);

        vm.startPrank(users.charlie.account);
        IFillableSwapSettlementModule(module).swapSettleFillable(
            data.orderWithSig, abi.encode(data.executorData), address(executor), FillableStorageLib.HUNDRED_PERCENT
        );

        uint256 balanceAfter = DAI.balanceOf(users.alice.account);
        assertEq(balanceAfter, balanceBefore + data.destAmount - data.feeAmount - 1);
    }

    function test_swapSettleFillable_SuccessPartialFill() public {
        TestData memory data = createTestData();

        uint256 fillPercent = 3600; // 36%
        uint256 expectedFillAmount = (data.destAmount) * 4000 / FillableStorageLib.HUNDRED_PERCENT;
        uint256 balanceBefore = DAI.balanceOf(users.alice.account);

        // Update executor data to return half of the expected amount
        data.executorData.mainCalldata.stepCalldata = abi.encodeWithSignature(
            "swap(address,address,uint256,uint256,address)",
            address(MTK),
            address(DAI),
            36_000_000_000_000_000_000,
            expectedFillAmount,
            address(executor)
        );

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        vm.startPrank(users.charlie.account);
        IFillableSwapSettlementModule(module).swapSettleFillable(
            data.orderWithSig, abi.encode(data.executorData), address(executor), fillPercent
        );

        uint256 balanceAfter = DAI.balanceOf(users.alice.account);
        assertEq(balanceAfter, balanceBefore + 36_939_999_999_999_999_999);
    }

    function test_swapSettleFillable_RevertsWhen_FillAmountOutIsZero() public {
        TestData memory data = createTestData();

        // Modify the order's destAmount to be very small
        data.order.destAmount = 9999; // Just below 10000 to ensure zero result with integer division

        // Set a fillPercent that results in zero expected amount
        uint256 fillPercent = 1;

        // Calculate expected fill amount
        uint256 expectedFillAmount = (data.order.destAmount * fillPercent) / FillableStorageLib.HUNDRED_PERCENT;

        // Ensure the expected fill amount is zero
        assertEq(expectedFillAmount, 0, "Expected fill amount should be zero");

        // Send MTK to executor
        vm.startPrank(users.admin.account);
        MTK.transfer(address(executor), data.srcAmount);

        // Update executor data to match the modified destAmount and fillPercent
        data.executorData.mainCalldata.stepCalldata = abi.encodeWithSignature(
            "swap(address,address,uint256,uint256,address)",
            address(MTK),
            address(DAI),
            (data.srcAmount * 9999) / FillableStorageLib.HUNDRED_PERCENT,
            (data.srcAmount * 9999) / FillableStorageLib.HUNDRED_PERCENT,
            address(executor)
        );

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        vm.startPrank(users.charlie.account);
        vm.expectRevert(InvalidFillAmount.selector);
        IFillableSwapSettlementModule(module).swapSettleFillable(
            data.orderWithSig, abi.encode(data.executorData), address(executor), fillPercent
        );
    }

    function test_swapSettleFillable_RevertsWhen_FillAmountInIsZero() public {
        TestData memory data = createTestData();

        // Set a fillPercent that results in zero expected amount
        uint256 fillPercent = 0;

        // Calculate expected fill amount
        uint256 expectedFillAmount = (data.order.destAmount * fillPercent) / FillableStorageLib.HUNDRED_PERCENT;

        // Ensure the expected fill amount is zero
        assertEq(expectedFillAmount, 0, "Expected fill amount should be zero");

        // Send MTK to executor
        vm.startPrank(users.admin.account);
        MTK.transfer(address(executor), data.srcAmount);

        // Update executor data to match the modified destAmount and fillPercent
        data.executorData.mainCalldata.stepCalldata = abi.encodeWithSignature(
            "swap(address,address,uint256,uint256,address)", address(MTK), address(DAI), 0, 0, address(executor)
        );

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        vm.startPrank(users.charlie.account);
        vm.expectRevert(InvalidFillAmount.selector);
        IFillableSwapSettlementModule(module).swapSettleFillable(
            data.orderWithSig, abi.encode(data.executorData), address(executor), fillPercent
        );
    }

    function test_swapSettleFillable_SuccessWithETH() public {
        TestData memory data = createTestData();
        data.order.destToken = ERC20UtilsLib.ETH_ADDRESS;
        data.order.destAmount = 1 ether;
        data.order.expectedDestAmount = 1 ether;
        data.executorData.destToken = ERC20UtilsLib.ETH_ADDRESS;
        data.executorData.mainCalldata.stepCalldata = abi.encodeWithSignature(
            "swap(address,address,uint256,uint256,address)",
            address(MTK),
            address(0),
            data.srcAmount,
            data.destAmount,
            address(executor)
        );

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        uint256 balanceBefore = users.alice.account.balance;

        vm.startPrank(users.charlie.account);
        IFillableSwapSettlementModule(module).swapSettleFillable(
            data.orderWithSig, abi.encode(data.executorData), address(executor), FillableStorageLib.HUNDRED_PERCENT
        );

        uint256 balanceAfter = users.alice.account.balance;
        assertEq(
            balanceAfter,
            balanceBefore + data.destAmount - data.feeAmount - 48_500_000_000_000_000_000, // protocol takes 50% of
                // surplus
            "ETH balance should increase by expected amount"
        );
    }

    function test_swapSettleFillable_RevertsWhen_Overfill() public {
        TestData memory data = createTestData();

        uint256 fillPercent = 3600; // 36%
        uint256 expectedFillAmount = (data.destAmount) * 4000 / FillableStorageLib.HUNDRED_PERCENT;
        // Set destAmount to be low
        data.order.destAmount = 1 ether;

        // Update executor data to return half of the expected amount
        data.executorData.mainCalldata.stepCalldata = abi.encodeWithSignature(
            "swap(address,address,uint256,uint256,address)",
            address(MTK),
            address(DAI),
            36_000_000_000_000_000_000,
            expectedFillAmount,
            address(executor)
        );

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        vm.startPrank(users.charlie.account);
        IFillableSwapSettlementModule(module).swapSettleFillable(
            data.orderWithSig, abi.encode(data.executorData), address(executor), fillPercent
        );

        // Give alice more MTK
        vm.startPrank(users.admin.account);
        MTK.transfer(users.alice.account, 100 ether);

        // Prank to charlie
        vm.startPrank(users.charlie.account);

        // Attempt to overfill
        vm.expectRevert(InvalidFillAmount.selector);
        IFillableSwapSettlementModule(module).swapSettleFillable(
            data.orderWithSig, abi.encode(data.executorData), address(executor), FillableStorageLib.HUNDRED_PERCENT
        );
    }

    function test_swapSettleFillable_RevertsWhen_DeadlineExpired() public {
        TestData memory data = createTestData();

        data.order.deadline = block.timestamp - 100;

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        vm.startPrank(users.charlie.account);
        vm.expectRevert(DeadlineExpired.selector);
        IFillableSwapSettlementModule(module).swapSettleFillable(
            data.orderWithSig, abi.encode(data.executorData), address(executor), FillableStorageLib.HUNDRED_PERCENT
        );
    }

    function test_swapSettleFillable_RevertsWhen_UnauthorizedAgent() public {
        TestData memory data = createTestData();

        vm.startPrank(users.bob.account);
        vm.expectRevert();
        IFillableSwapSettlementModule(module).swapSettleFillable(
            data.orderWithSig, abi.encode(data.executorData), address(executor), FillableStorageLib.HUNDRED_PERCENT
        );
    }

    function test_swapSettleFillable_RevertsWhen_OrderAlreadyFilled() public {
        TestData memory data = createTestData();

        vm.startPrank(users.charlie.account);
        IFillableSwapSettlementModule(module).swapSettleFillable(
            data.orderWithSig, abi.encode(data.executorData), address(executor), FillableStorageLib.HUNDRED_PERCENT
        );

        vm.expectRevert(NonceManagerLib.InvalidNonce.selector);
        IFillableSwapSettlementModule(module).swapSettleFillable(
            data.orderWithSig, abi.encode(data.executorData), address(executor), FillableStorageLib.HUNDRED_PERCENT
        );
    }

    function test_swapSettleFillable_RevertsWhen_InsufficientReturnAmount() public {
        TestData memory data = createTestData();

        // Modify executorData to return less than expected
        data.executorData.mainCalldata.stepCalldata = abi.encodeWithSignature(
            "swap(address,address,uint256,uint256,address)",
            address(MTK),
            address(DAI),
            data.srcAmount,
            data.destAmount / 2, // Return half of the expected amount
            address(executor)
        );

        vm.startPrank(users.charlie.account);
        vm.expectRevert(InsufficientReturnAmount.selector);
        IFillableSwapSettlementModule(module).swapSettleFillable(
            data.orderWithSig, abi.encode(data.executorData), address(executor), FillableStorageLib.HUNDRED_PERCENT
        );
    }

    function test_swapSettleFillable_RevertsWhen_ExecutionFailed() public {
        TestData memory data = createTestData();

        // Modify executorData to make execution fail
        data.executorData.mainCalldata = StepData(abi.encodeWithSignature("revert()"), address(this));

        vm.startPrank(users.charlie.account);
        vm.expectRevert();
        IFillableSwapSettlementModule(module).swapSettleFillable(
            data.orderWithSig, abi.encode(data.executorData), address(executor), FillableStorageLib.HUNDRED_PERCENT
        );
    }
}
