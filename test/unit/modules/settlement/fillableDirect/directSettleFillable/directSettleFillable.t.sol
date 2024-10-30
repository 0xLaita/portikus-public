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

contract FillableDirectSettlementModule_directSettleFillable is FillableDirectSettlementModule_Test {
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

    /// @notice Test successful fillable direct settlement with ERC20 tokens
    function test_directSettleFillable_Success() public {
        TestData memory data = createTestData();

        uint256 balanceBefore = DAI.balanceOf(users.alice.account);

        vm.startPrank(users.charlie.account);
        IFillableDirectSettlementModule(module).directSettleFillable(
            data.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, data.destAmount
        );

        uint256 balanceAfter = DAI.balanceOf(users.alice.account);
        assertEq(balanceAfter, balanceBefore + data.destAmount);
    }

    /// @notice Test fillable direct with unset beneficiary
    function test_directSettleFillable_BeneficiaryUnset() public {
        TestData memory data = createTestData();

        data.order.beneficiary = address(0);

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        vm.startPrank(users.charlie.account);
        IFillableDirectSettlementModule(module).directSettleFillable(
            data.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, data.destAmount
        );

        uint256 balanceAfter = DAI.balanceOf(users.alice.account);
        assertEq(balanceAfter, data.destAmount);
    }

    /// @notice Test revert when fill amount is zero due to rounding
    function test_directSettleFillable_RevertsWhen_FillAmountIsZero() public {
        TestData memory data = createTestData();

        // Modify the order's destAmount to be very small
        data.order.destAmount = 9999; // Just below 10000 to ensure zero result with integer division

        // Set a fillPercent that results in zero expected amount
        uint256 fillPercent = 1;

        // Calculate expected fill amount
        uint256 expectedFillAmount = (data.order.destAmount * fillPercent) / FillableStorageLib.HUNDRED_PERCENT;

        // Ensure the expected fill amount is zero
        assertEq(expectedFillAmount, 0, "Expected fill amount should be zero");

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        vm.startPrank(users.charlie.account);
        vm.expectRevert(InvalidFillAmount.selector);
        IFillableDirectSettlementModule(module).directSettleFillable(data.orderWithSig, fillPercent, expectedFillAmount);
    }

    /// @notice Test revert when fill amount in is zero due to rounding
    function test_directSettleFillable_RevertsWhen_FillAmountInIsZero() public {
        TestData memory data = createTestData();

        // Modify the order's srcAmount to be very small
        data.order.srcAmount = 9999; // Just below 10000 to ensure zero result with integer division

        // Set a fillPercent that results in zero expected amount
        uint256 fillPercent = 1;

        // Calculate expected fill amount
        uint256 expectedFillAmount = (data.order.destAmount * fillPercent) / FillableStorageLib.HUNDRED_PERCENT;

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        vm.startPrank(users.charlie.account);
        vm.expectRevert(InvalidFillAmount.selector);
        IFillableDirectSettlementModule(module).directSettleFillable(data.orderWithSig, fillPercent, expectedFillAmount);
    }

    /// @notice Test successful partial fillable direct settlement
    function test_directSettleFillable_SuccessPartialFill() public {
        TestData memory data = createTestData();

        uint256 fillPercent = 5000; // 50%
        uint256 expectedFillAmount = data.destAmount * fillPercent / FillableStorageLib.HUNDRED_PERCENT;
        uint256 balanceBefore = DAI.balanceOf(users.alice.account);

        vm.startPrank(users.charlie.account);
        IFillableDirectSettlementModule(module).directSettleFillable(data.orderWithSig, fillPercent, expectedFillAmount);

        uint256 balanceAfter = DAI.balanceOf(users.alice.account);
        assertEq(balanceAfter, balanceBefore + expectedFillAmount);
    }

    /// @notice Test successful fillable direct settlement of a partially filled order
    function test_directSettleFillable_SuccessPartialThenFull() public {
        TestData memory data = createTestData();

        uint256 firstFillPercent = 3000; // 30%
        uint256 secondFillPercent = 7000; // 70%

        uint256 firstExpectedFillAmount = data.destAmount * firstFillPercent / FillableStorageLib.HUNDRED_PERCENT;
        uint256 secondExpectedFillAmount = data.destAmount * secondFillPercent / FillableStorageLib.HUNDRED_PERCENT;

        vm.startPrank(users.charlie.account);
        IFillableDirectSettlementModule(module).directSettleFillable(
            data.orderWithSig, firstFillPercent, firstExpectedFillAmount
        );

        uint256 balanceAfterFirst = DAI.balanceOf(users.alice.account);
        assertEq(balanceAfterFirst, firstExpectedFillAmount);

        IFillableDirectSettlementModule(module).directSettleFillable(
            data.orderWithSig, secondFillPercent, secondExpectedFillAmount
        );

        uint256 balanceAfterSecond = DAI.balanceOf(users.alice.account);
        assertEq(balanceAfterSecond, firstExpectedFillAmount + secondExpectedFillAmount);
    }

    function test_directSettleFillable_RevertsWhen_Overfill() public {
        TestData memory data = createTestData();

        uint256 firstFillPercent = 3000; // 30%
        uint256 secondFillPercent = 8000; // 70%

        uint256 firstExpectedFillAmount = data.destAmount * firstFillPercent / FillableStorageLib.HUNDRED_PERCENT;
        uint256 secondExpectedFillAmount = data.destAmount * secondFillPercent / FillableStorageLib.HUNDRED_PERCENT;

        vm.startPrank(users.charlie.account);
        IFillableDirectSettlementModule(module).directSettleFillable(
            data.orderWithSig, firstFillPercent, firstExpectedFillAmount
        );

        uint256 balanceAfterFirst = DAI.balanceOf(users.alice.account);
        assertEq(balanceAfterFirst, firstExpectedFillAmount);

        // Give Alice more MTK
        vm.startPrank(users.admin.account);
        MTK.transfer(users.alice.account, 100 ether);

        // Prank to charlie
        vm.startPrank(users.charlie.account);

        // Expect revert when trying to overfill
        vm.expectRevert(InvalidFillAmount.selector);

        IFillableDirectSettlementModule(module).directSettleFillable(
            data.orderWithSig, secondFillPercent, secondExpectedFillAmount
        );
    }

    /// @notice Test revert when order deadline has expired
    function test_directSettleFillable_RevertsWhen_DeadlineExpired() public {
        TestData memory data = createTestData();

        data.order.deadline = block.timestamp - 100;

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        vm.startPrank(users.charlie.account);
        vm.expectRevert(DeadlineExpired.selector);
        IFillableDirectSettlementModule(module).directSettleFillable(
            data.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, data.destAmount
        );
    }

    /// @notice Test revert when called by an unauthorized agent
    function test_directSettleFillable_RevertsWhen_UnauthorizedAgent() public {
        TestData memory data = createTestData();

        vm.startPrank(users.bob.account);
        vm.expectRevert();
        IFillableDirectSettlementModule(module).directSettleFillable(
            data.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, data.destAmount
        );
    }

    /// @notice Test revert when trying to fill a fully filled order
    function test_directSettleFillable_RevertsWhen_OrderAlreadyFilled() public {
        TestData memory data = createTestData();

        vm.startPrank(users.charlie.account);
        IFillableDirectSettlementModule(module).directSettleFillable(
            data.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, data.destAmount
        );

        vm.expectRevert(NonceManagerLib.InvalidNonce.selector);
        IFillableDirectSettlementModule(module).directSettleFillable(
            data.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, data.destAmount
        );
    }

    /// @notice Test successful fillable direct settlement with ETH as destination token
    function test_directSettleFillable_SuccessWithETH() public {
        TestData memory data = createTestData();
        data.order.destToken = ERC20UtilsLib.ETH_ADDRESS;
        data.order.destAmount = 1 ether; // Set a smaller amount for easier testing

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        uint256 balanceBefore = users.alice.account.balance;

        vm.startPrank(users.charlie.account);
        IFillableDirectSettlementModule(module).directSettleFillable{ value: 1 ether }(
            data.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, 1 ether
        );

        uint256 balanceAfter = users.alice.account.balance;
        assertEq(balanceAfter, balanceBefore + 1 ether, "ETH balance should increase by 1 ether");
    }

    /// @notice Test revert when msg.value is less than amountOut for ETH destination
    function test_directSettleFillable_RevertsWhen_InsufficientMsgValue() public {
        TestData memory data = createTestData();
        data.order.destToken = ERC20UtilsLib.ETH_ADDRESS;
        data.order.destAmount = 1 ether;

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        vm.startPrank(users.charlie.account);
        vm.expectRevert(InsufficientMsgValue.selector);
        IFillableDirectSettlementModule(module).directSettleFillable{ value: 0.5 ether }(
            data.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, 1 ether
        );
    }

    /// @notice Test revert when the passed amount is less than the destAmount
    function test_directSettleFillable_RevertsWhen_AmountLessThanDestAmount() public {
        TestData memory data = createTestData();
        data.order.destToken = ERC20UtilsLib.ETH_ADDRESS;
        data.order.destAmount = 1 ether;

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        vm.startPrank(users.charlie.account);
        vm.expectRevert(InsufficientMsgValue.selector);
        IFillableDirectSettlementModule(module).directSettleFillable{ value: 1 ether }(
            data.orderWithSig,
            FillableStorageLib.HUNDRED_PERCENT,
            0.01 ether // Less than destAmount
        );
    }

    /// @notice Test partial fill with ETH as destination token
    function test_directSettleFillable_PartialFillWithETH() public {
        TestData memory data = createTestData();
        data.order.destToken = ERC20UtilsLib.ETH_ADDRESS;
        data.order.destAmount = 1 ether;

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        uint256 balanceBefore = users.alice.account.balance;
        uint256 fillPercent = 5000; // 50%
        uint256 expectedFillAmount = 0.5 ether;

        vm.startPrank(users.charlie.account);
        IFillableDirectSettlementModule(module).directSettleFillable{ value: 0.5 ether }(
            data.orderWithSig, fillPercent, expectedFillAmount
        );

        uint256 balanceAfter = users.alice.account.balance;
        assertEq(balanceAfter, balanceBefore + 0.5 ether, "ETH balance should increase by 0.5 ether");
    }
}
