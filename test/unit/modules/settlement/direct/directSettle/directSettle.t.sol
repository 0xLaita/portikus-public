// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Interfaces
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IDirectSettlementModule } from "@modules/settlement/interfaces/IDirectSettlementModule.sol";

// Libraries
import { OrderHashLib } from "@modules/libraries/OrderHashLib.sol";

// Tests
import { DirectSettlementModule_Test } from "../DirectSettlementModule.t.sol";

// Types
import { Order, OrderWithSig } from "@types/Order.sol";

// Utilities
import { EIP2098Lib } from "test/utils/EIP2098Lib.sol";

contract DirectSettlementModule_directSettle is DirectSettlementModule_Test {
    using OrderHashLib for Order;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error DeadlineExpired();
    error InsufficientReturnAmount();
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
        data.srcAmount = 100;
        data.destAmount = 99;

        // Transfer tokens to test accounts
        vm.startPrank(users.admin.account);
        MTK.transfer(users.alice.account, data.srcAmount);
        DAI.transfer(users.charlie.account, data.destAmount);
        vm.stopPrank();

        // Approve module to spend Alice's tokens
        vm.startPrank(users.alice.account);
        MTK.approve(address(module), data.srcAmount);
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

    /// @notice Test successful direct settlement with ERC20 tokens
    function test_directSettle_Success() public {
        TestData memory data = createTestData();

        uint256 balanceBefore = DAI.balanceOf(users.alice.account);

        vm.startPrank(users.charlie.account);
        IDirectSettlementModule(module).directSettle(data.orderWithSig, data.destAmount);

        uint256 balanceAfter = DAI.balanceOf(users.alice.account);
        assertEq(balanceAfter, balanceBefore + data.destAmount);
    }

    function test_directSettle_SuccessWithBeneficiaryUnset() public {
        TestData memory data = createTestData();

        data.order.beneficiary = address(0);

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        // Check balances before
        uint256 balanceBefore = DAI.balanceOf(users.alice.account);

        vm.startPrank(users.charlie.account);
        IDirectSettlementModule(module).directSettle(data.orderWithSig, data.destAmount);

        uint256 balanceAfter = DAI.balanceOf(users.alice.account);
        assertEq(balanceAfter, balanceBefore + data.destAmount);
    }

    /// @notice Test successful direct settlement with ETH as destination
    function test_directSettle_SuccessWithETH() public {
        TestData memory data = createTestData();

        data.order.destToken = address(ETH);

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        uint256 balanceBefore = users.alice.account.balance;

        vm.startPrank(users.charlie.account);
        IDirectSettlementModule(module).directSettle{ value: data.destAmount }(data.orderWithSig, data.destAmount);

        uint256 balanceAfter = users.alice.account.balance;
        assertEq(balanceAfter, balanceBefore + data.destAmount);
    }

    /// @notice Test revert when order deadline has expired
    function test_directSettle_RevertsWhen_DeadlineExpired() public {
        TestData memory data = createTestData();

        data.order.deadline = block.timestamp - 100;

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        vm.startPrank(users.charlie.account);
        vm.expectRevert(DeadlineExpired.selector);
        IDirectSettlementModule(module).directSettle(data.orderWithSig, data.destAmount);
    }

    /// @notice Test revert when settled amount is less than order's destAmount
    function test_directSettle_RevertsWhen_InsufficientReturnAmount() public {
        TestData memory data = createTestData();

        vm.startPrank(users.charlie.account);
        vm.expectRevert(InsufficientReturnAmount.selector);
        IDirectSettlementModule(module).directSettle(data.orderWithSig, data.destAmount - 1);
    }

    /// @notice Test revert when called by an unauthorized agent
    function test_directSettle_RevertsWhen_UnauthorizedAgent() public {
        TestData memory data = createTestData();

        vm.startPrank(users.bob.account);
        vm.expectRevert();
        IDirectSettlementModule(module).directSettle(data.orderWithSig, data.destAmount);
    }

    /// @notice Test revert when source token transfer fails
    function test_directSettle_RevertsWhen_SrcTokenTransferFails() public {
        TestData memory data = createTestData();

        vm.startPrank(users.alice.account);
        MTK.approve(address(module), 0); // Remove approval
        vm.stopPrank();

        vm.startPrank(users.charlie.account);
        vm.expectRevert();
        IDirectSettlementModule(module).directSettle(data.orderWithSig, data.destAmount);
    }

    /// @notice Test revert when destination token transfer fails
    function test_directSettle_RevertsWhen_DestTokenTransferFails() public {
        TestData memory data = createTestData();

        vm.startPrank(users.charlie.account);
        DAI.approve(address(module), 0); // Remove approval
        vm.expectRevert();
        IDirectSettlementModule(module).directSettle(data.orderWithSig, data.destAmount);
    }

    /// @notice Test revert when agent has insufficient msg.value
    function test_directSettle_RevertsWhen_InsufficientMsgValue() public {
        TestData memory data = createTestData();
        data.order.destToken = address(ETH);

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        vm.startPrank(users.charlie.account);
        vm.expectRevert(InsufficientMsgValue.selector);
        IDirectSettlementModule(module).directSettle(data.orderWithSig, data.destAmount);
    }
}
