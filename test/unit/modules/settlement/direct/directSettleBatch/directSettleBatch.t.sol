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

contract DirectSettlementModule_directSettleBatch is DirectSettlementModule_Test {
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
        uint256[] srcAmounts;
        uint256[] destAmounts;
        Order[] orders;
        OrderWithSig[] ordersWithSigs;
    }

    /*//////////////////////////////////////////////////////////////
                               TEST DATA
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates and returns test data for batch settlement tests
    function createTestData(uint256 numOrders) internal returns (TestData memory data) {
        super.setUp();

        data.srcAmounts = new uint256[](numOrders);
        data.destAmounts = new uint256[](numOrders);
        data.orders = new Order[](numOrders);
        data.ordersWithSigs = new OrderWithSig[](numOrders);

        for (uint256 i = 0; i < numOrders; i++) {
            data.srcAmounts[i] = 100 * (i + 1);
            data.destAmounts[i] = 99 * (i + 1);

            // Transfer tokens to test accounts
            vm.startPrank(users.admin.account);
            MTK.transfer(users.alice.account, data.srcAmounts[i]);
            DAI.transfer(users.charlie.account, data.destAmounts[i]);
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
                destToken: address(DAI),
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

    /// @notice Test successful batch settlement with ERC20 tokens
    function test_directSettleBatch_Success() public {
        uint256 numOrders = 3;
        TestData memory data = createTestData(numOrders);

        uint256 balanceBefore = DAI.balanceOf(users.alice.account);

        vm.startPrank(users.charlie.account);
        IDirectSettlementModule(module).directSettleBatch(data.ordersWithSigs, data.destAmounts);

        uint256 balanceAfter = DAI.balanceOf(users.alice.account);
        uint256 expectedTotalDestAmount = 0;
        for (uint256 i = 0; i < numOrders; i++) {
            expectedTotalDestAmount += data.destAmounts[i];
        }
        assertEq(balanceAfter, balanceBefore + expectedTotalDestAmount);
    }

    /// @notice Test successful batch settlement with mixed ERC20 and ETH orders
    function test_directSettleBatch_SuccessWithMixedTokens() public {
        uint256 numOrders = 3;
        TestData memory data = createTestData(numOrders);

        // Change the second order to ETH
        data.orders[1].destToken = address(ETH);
        bytes32 hash = _hashTypedDataV4(data.orders[1].hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.ordersWithSigs[1] = OrderWithSig({ order: data.orders[1], signature: sig });

        uint256 daiBalanceBefore = DAI.balanceOf(users.alice.account);
        uint256 ethBalanceBefore = users.alice.account.balance;

        vm.startPrank(users.charlie.account);
        IDirectSettlementModule(module).directSettleBatch{ value: data.destAmounts[1] }(
            data.ordersWithSigs, data.destAmounts
        );

        uint256 daiBalanceAfter = DAI.balanceOf(users.alice.account);
        uint256 ethBalanceAfter = users.alice.account.balance;

        assertEq(daiBalanceAfter, daiBalanceBefore + data.destAmounts[0] + data.destAmounts[2]);
        assertEq(ethBalanceAfter, ethBalanceBefore + data.destAmounts[1]);
    }

    /// @notice Test revert when one order in batch has expired deadline
    function test_directSettleBatch_RevertsWhen_OneDeadlineExpired() public {
        uint256 numOrders = 3;
        TestData memory data = createTestData(numOrders);

        // Expire the second order's deadline
        data.orders[1].deadline = block.timestamp - 100;
        bytes32 hash = _hashTypedDataV4(data.orders[1].hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.ordersWithSigs[1] = OrderWithSig({ order: data.orders[1], signature: sig });

        vm.startPrank(users.charlie.account);
        vm.expectRevert(DeadlineExpired.selector);
        IDirectSettlementModule(module).directSettleBatch(data.ordersWithSigs, data.destAmounts);
    }

    /// @notice Test revert when one order in batch has insufficient return amount
    function test_directSettleBatch_RevertsWhen_OneInsufficientReturnAmount() public {
        uint256 numOrders = 3;
        TestData memory data = createTestData(numOrders);

        // Reduce the second order's destAmount
        data.destAmounts[1] = data.destAmounts[1] - 1;

        vm.startPrank(users.charlie.account);
        vm.expectRevert(InsufficientReturnAmount.selector);
        IDirectSettlementModule(module).directSettleBatch(data.ordersWithSigs, data.destAmounts);
    }

    /// @notice Test revert when agent sends insufficient ETH value
    function test_directSettleBatch_RevertsWhen_InsufficientMsgValue() public {
        uint256 numOrders = 3;
        TestData memory data = createTestData(numOrders);

        // Change the second order to ETH
        data.orders[1].destToken = address(ETH);
        bytes32 hash = _hashTypedDataV4(data.orders[1].hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.ordersWithSigs[1] = OrderWithSig({ order: data.orders[1], signature: sig });

        // ETH amount needed to settle the orders
        uint256 ethAmount = data.destAmounts[1];

        vm.deal(address(module), 1 ether); // send ETH to module for internal transfers
        vm.startPrank(users.charlie.account);
        vm.expectRevert(InsufficientMsgValue.selector);
        IDirectSettlementModule(module).directSettleBatch{ value: ethAmount - 1 }(data.ordersWithSigs, data.destAmounts);
    }

    /// @notice Test revert when called by an unauthorized agent
    function test_directSettleBatch_RevertsWhen_UnauthorizedAgent() public {
        uint256 numOrders = 3;
        TestData memory data = createTestData(numOrders);

        vm.startPrank(users.bob.account);
        vm.expectRevert();
        IDirectSettlementModule(module).directSettleBatch(data.ordersWithSigs, data.destAmounts);
    }

    /// @notice Test revert when one source token transfer fails
    function test_directSettleBatch_RevertsWhen_OneSrcTokenTransferFails() public {
        uint256 numOrders = 3;
        TestData memory data = createTestData(numOrders);

        vm.startPrank(users.alice.account);
        MTK.approve(address(module), 0); // Remove approval
        vm.stopPrank();

        vm.startPrank(users.charlie.account);
        vm.expectRevert();
        IDirectSettlementModule(module).directSettleBatch(data.ordersWithSigs, data.destAmounts);
    }

    /// @notice Test revert when one destination token transfer fails
    function test_directSettleBatch_RevertsWhen_OneDestTokenTransferFails() public {
        uint256 numOrders = 3;
        TestData memory data = createTestData(numOrders);

        vm.startPrank(users.charlie.account);
        DAI.approve(address(module), data.destAmounts[0] + data.destAmounts[1]); // Approve less than required
        vm.expectRevert();
        IDirectSettlementModule(module).directSettleBatch(data.ordersWithSigs, data.destAmounts);
    }
}
