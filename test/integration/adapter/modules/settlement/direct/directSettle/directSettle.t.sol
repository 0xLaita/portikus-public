// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Interfaces
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IDirectSettlementModule } from "@modules/settlement/interfaces/IDirectSettlementModule.sol";

// Libraries
import { OrderHashLib } from "@modules/libraries/OrderHashLib.sol";

// Tests
import { SettlementModule_Integration_Test } from "../../SettlementModule.t.sol";

// Types
import { Order, OrderWithSig } from "@types/Order.sol";

// Utilities
import { EIP2098Lib } from "test/utils/EIP2098Lib.sol";

contract DirectSettlementModule_Integration_directSettle is SettlementModule_Integration_Test {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using OrderHashLib for Order;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error DeadlineExpired();
    error InsufficientReturnAmount();

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

    /// @dev Creates test data for tests
    function createTestData() internal returns (TestData memory data) {
        // Setup Base Test
        super.setUp();

        // Prepare test data
        data.srcAmount = 100;
        data.destAmount = 99;

        // Prank to admin and transfer MTK to alice and DAI to charlie
        vm.startPrank(users.admin.account);
        address[] memory agents = new address[](1);
        agents[0] = users.charlie.account;
        portikusV2.registerAgent(agents);
        MTK.transfer(users.alice.account, data.srcAmount);
        DAI.transfer(users.charlie.account, data.destAmount);
        vm.stopPrank();

        // Prank to alice and approve MTK to adapter
        vm.startPrank(users.alice.account);
        MTK.approve(address(adapter), data.srcAmount);
        vm.stopPrank();

        // Prank to charlie and approve DAI to adapter
        vm.startPrank(users.charlie.account);
        DAI.approve(address(adapter), data.destAmount);
        vm.stopPrank();

        // Prepare order data
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

        // Arrange valid signature
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_directSettle_Success() public {
        // Setup
        TestData memory data = createTestData();

        // Check initial balances
        uint256 aliceInitialMTK = MTK.balanceOf(users.alice.account);
        uint256 aliceInitialDAI = DAI.balanceOf(users.alice.account);
        uint256 charlieInitialDAI = DAI.balanceOf(users.charlie.account);

        // Execute direct settlement as authorized agent (charlie)
        vm.startPrank(users.charlie.account);
        IDirectSettlementModule(address(adapter)).directSettle(data.orderWithSig, data.destAmount);

        // Verify balance changes
        assertEq(MTK.balanceOf(users.alice.account), aliceInitialMTK - data.srcAmount);
        assertEq(DAI.balanceOf(users.alice.account), aliceInitialDAI + data.destAmount);
        assertEq(DAI.balanceOf(users.charlie.account), charlieInitialDAI - data.destAmount);
    }

    function test_directSettle_SuccessWithETH() public {
        // Setup
        TestData memory data = createTestData();

        // Setup for ETH swap
        data.order.destToken = address(ETH);
        data.order.destAmount = data.destAmount - 2; // Adjust for potential rounding

        // Re-sign the modified order
        bytes32 hash = _hashTypedDataV4(data.order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        data.orderWithSig = OrderWithSig({ order: data.order, signature: sig });

        // Check initial balances
        uint256 aliceInitialMTK = MTK.balanceOf(users.alice.account);
        uint256 aliceInitialETH = users.alice.account.balance;
        uint256 charlieInitialETH = users.charlie.account.balance;

        // Execute direct settlement as authorized agent (charlie)
        vm.startPrank(users.charlie.account);
        IDirectSettlementModule(address(adapter)).directSettle{ value: data.order.destAmount }(
            data.orderWithSig, data.order.destAmount
        );

        // Verify balance changes
        assertEq(MTK.balanceOf(users.alice.account), aliceInitialMTK - data.srcAmount);
        assertEq(users.alice.account.balance, aliceInitialETH + data.order.destAmount);
        assertEq(users.charlie.account.balance, charlieInitialETH - data.order.destAmount);
    }

    function test_directSettle_RevertsWhen_DeadlineExpired() public {
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
        IDirectSettlementModule(address(adapter)).directSettle(data.orderWithSig, data.destAmount);
    }

    function test_directSettle_RevertsWhen_InsufficientReturnAmount() public {
        // Setup
        TestData memory data = createTestData();

        // Attempt to settle with insufficient return amount
        vm.startPrank(users.charlie.account);
        vm.expectRevert(InsufficientReturnAmount.selector);
        IDirectSettlementModule(address(adapter)).directSettle(data.orderWithSig, data.destAmount - 1);
    }

    function test_directSettle_RevertsWhen_UnauthorizedAgent() public {
        // Setup
        TestData memory data = createTestData();

        // Attempt to settle as unauthorized agent (bob)
        vm.startPrank(users.bob.account);
        vm.expectRevert();
        IDirectSettlementModule(address(adapter)).directSettle(data.orderWithSig, data.destAmount);
    }

    function test_directSettle_RevertsWhen_SrcTokenTransferFails() public {
        // Setup
        TestData memory data = createTestData();

        // Remove approval for srcToken
        vm.startPrank(users.alice.account);
        MTK.approve(address(adapter), 0);
        vm.stopPrank();

        // Attempt to settle with insufficient approval
        vm.startPrank(users.charlie.account);
        vm.expectRevert();
        IDirectSettlementModule(address(adapter)).directSettle(data.orderWithSig, data.destAmount);
    }

    function test_directSettle_RevertsWhen_DestTokenTransferFails() public {
        // Setup
        TestData memory data = createTestData();

        // Remove approval for destToken
        vm.startPrank(users.charlie.account);
        DAI.approve(address(adapter), 0);

        // Attempt to settle with insufficient approval
        vm.expectRevert();
        IDirectSettlementModule(address(adapter)).directSettle(data.orderWithSig, data.destAmount);
    }
}
