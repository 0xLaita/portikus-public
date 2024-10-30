// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Interfaces
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IDirectSettlementModule } from "@modules/settlement/interfaces/IDirectSettlementModule.sol";
import { IFeeClaimerModule } from "@modules/interfaces/IFeeClaimerModule.sol";

// Libraries
import { ERC20UtilsLib } from "@modules/libraries/ERC20UtilsLib.sol";
import { OrderHashLib } from "@modules/libraries/OrderHashLib.sol";

// Test
import { SettlementModule_Integration_Test } from "../../SettlementModule.t.sol";

// Types
import { Order, OrderWithSig } from "@types/Order.sol";

// Utilities
import { EIP2098Lib } from "test/utils/EIP2098Lib.sol";

contract DirectSettlementModule_fees is SettlementModule_Integration_Test {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using OrderHashLib for Order;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event FeesWithdrawn(address indexed partner, address indexed token, uint256 amount, address recipient);
    event OrderSettled(
        address indexed owner,
        address indexed beneficiary,
        address srcToken,
        address destToken,
        uint256 srcAmount,
        uint256 destAmount,
        uint256 returnAmount,
        uint256 protocolFee,
        uint256 partnerFee,
        bytes32 indexed orderHash
    );

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct TestData {
        uint256 srcAmount;
        uint256 destAmount;
        uint256 fee;
        Order order;
        OrderWithSig orderWithSig;
    }

    /*//////////////////////////////////////////////////////////////
                              SINGLE TEST
    //////////////////////////////////////////////////////////////*/

    /// @dev Creates test data for tests
    function createTestData(
        uint256 feeInBps,
        address srcToken,
        address destToken,
        uint256 nonce
    )
        internal
        returns (TestData memory data)
    {
        data.srcAmount = 100 ether;
        data.destAmount = 99 ether;
        data.fee = feeInBps;

        vm.startPrank(users.admin.account);
        address[] memory agents = new address[](1);
        agents[0] = users.charlie.account;
        portikusV2.registerAgent(agents);
        if (srcToken != ERC20UtilsLib.ETH_ADDRESS) {
            IERC20(srcToken).transfer(users.alice.account, data.srcAmount);
        } else {
            vm.deal(users.alice.account, data.srcAmount);
        }
        if (destToken != ERC20UtilsLib.ETH_ADDRESS) {
            IERC20(destToken).transfer(users.charlie.account, data.destAmount * 2);
        } else {
            vm.deal(users.charlie.account, data.destAmount * 2);
        }
        vm.stopPrank();

        if (srcToken != ERC20UtilsLib.ETH_ADDRESS) {
            vm.prank(users.alice.account);
            IERC20(srcToken).approve(address(adapter), type(uint256).max);
        }

        if (destToken != ERC20UtilsLib.ETH_ADDRESS) {
            vm.prank(users.charlie.account);
            IERC20(destToken).approve(address(adapter), type(uint256).max);
        }

        data.order = Order({
            owner: users.alice.account,
            beneficiary: users.alice.account,
            srcToken: srcToken,
            destToken: destToken,
            srcAmount: data.srcAmount,
            destAmount: data.destAmount,
            expectedDestAmount: data.destAmount,
            deadline: block.timestamp + 100,
            partnerAndFee: (uint256(uint160(address(users.bob.account))) << 96) | data.fee,
            nonce: nonce,
            permit: ""
        });

        data.orderWithSig = signOrder(data.order);
    }

    /*//////////////////////////////////////////////////////////////
                               BATCH TEST
    //////////////////////////////////////////////////////////////*/

    /// @dev Creates test data for batch settlement tests
    function createBatchTestData(
        uint256[] memory feePercentages,
        address[] memory destTokens
    )
        internal
        returns (TestData[] memory batchData, uint256[] memory destAmounts)
    {
        uint256 numOrders = feePercentages.length;
        batchData = new TestData[](numOrders);
        destAmounts = new uint256[](numOrders);

        for (uint256 i = 0; i < numOrders; i++) {
            batchData[i] = createTestData(feePercentages[i], address(MTK), destTokens[i], i + 1);
            destAmounts[i] = batchData[i].destAmount;
        }
    }

    /*//////////////////////////////////////////////////////////////
                              SINGLE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_settleOrderWithFees() public {
        TestData memory data = createTestData(100, address(MTK), address(DAI), 1); // 1% fee
        uint256 expectedFee = (data.destAmount * data.fee) / 10_000;

        vm.expectEmit(true, true, false, true);
        emit OrderSettled(
            data.order.owner,
            data.order.beneficiary,
            data.order.srcToken,
            data.order.destToken,
            data.order.srcAmount,
            data.order.destAmount,
            data.destAmount - expectedFee,
            0,
            expectedFee,
            _hashTypedDataV4(data.order.hash())
        );
        vm.prank(users.charlie.account);
        IDirectSettlementModule(address(adapter)).directSettle(data.orderWithSig, data.destAmount);

        uint256 collectedFees = IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        assertEq(collectedFees, expectedFee, "Collected fees should match expected fee");
    }

    function test_withdrawSpecificAmount() public {
        TestData memory data = createTestData(100, address(MTK), address(DAI), 1); // 1% fee
        uint256 expectedFee = (data.destAmount * data.fee) / 10_000;

        vm.prank(users.charlie.account);
        IDirectSettlementModule(address(adapter)).directSettle(data.orderWithSig, data.destAmount);

        uint256 withdrawAmount = expectedFee / 2;
        vm.startPrank(users.bob.account);
        vm.expectEmit(true, true, false, true);
        emit FeesWithdrawn(users.bob.account, address(DAI), withdrawAmount, users.bob.account);
        IFeeClaimerModule(address(adapter)).withdrawFees(address(DAI), withdrawAmount, users.bob.account);

        uint256 remainingFees = IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        assertEq(
            remainingFees, expectedFee - withdrawAmount, "Remaining fees should be correct after partial withdrawal"
        );
    }

    function test_queryCollectedFees() public {
        TestData memory data1 = createTestData(100, address(MTK), address(DAI), 1); // 1% fee
        TestData memory data2 = createTestData(200, address(DAI), address(MTK), 2); // 2% fee

        vm.startPrank(users.charlie.account);
        IDirectSettlementModule(address(adapter)).directSettle(data1.orderWithSig, data1.destAmount);
        IDirectSettlementModule(address(adapter)).directSettle(data2.orderWithSig, data2.destAmount);
        vm.stopPrank();

        uint256 expectedFee1 = (data1.destAmount * data1.fee) / 10_000;
        uint256 expectedFee2 = (data2.destAmount * data2.fee) / 10_000;

        assertEq(
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI)),
            expectedFee1,
            "Collected DAI fees should be correct"
        );
        assertEq(
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(MTK)),
            expectedFee2,
            "Collected MTK fees should be correct"
        );

        address[] memory tokens = new address[](2);
        tokens[0] = address(DAI);
        tokens[1] = address(MTK);

        uint256[] memory collectedFees =
            IFeeClaimerModule(address(adapter)).batchGetCollectedFees(users.bob.account, tokens);
        assertEq(collectedFees[0], expectedFee1, "Batch collected DAI fees should be correct");
        assertEq(collectedFees[1], expectedFee2, "Batch collected MTK fees should be correct");
    }

    function test_withdrawAllFees() public {
        TestData memory data = createTestData(100, address(MTK), address(DAI), 1); // 1% fee
        uint256 expectedFee = (data.destAmount * data.fee) / 10_000;

        vm.prank(users.charlie.account);
        IDirectSettlementModule(address(adapter)).directSettle(data.orderWithSig, data.destAmount);

        vm.startPrank(users.bob.account);
        vm.expectEmit(true, true, false, true);
        emit FeesWithdrawn(users.bob.account, address(DAI), expectedFee, users.bob.account);
        uint256 withdrawnAmount = IFeeClaimerModule(address(adapter)).withdrawAllFees(address(DAI), users.bob.account);

        assertEq(withdrawnAmount, expectedFee, "Withdrawn amount should match collected fees");
        assertEq(DAI.balanceOf(users.bob.account), expectedFee, "Partner should receive all collected fees");
        assertEq(
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI)),
            0,
            "Collected fees should be zero after withdrawal"
        );
    }

    function test_batchWithdrawAllFees() public {
        TestData memory data1 = createTestData(100, address(MTK), address(DAI), 1); // 1% fee
        TestData memory data2 = createTestData(200, address(DAI), address(MTK), 2); // 2% fee

        uint256 expectedFee1 = (data1.destAmount * data1.fee) / 10_000;
        uint256 expectedFee2 = (data2.destAmount * data2.fee) / 10_000;

        vm.startPrank(users.charlie.account);
        IDirectSettlementModule(address(adapter)).directSettle(data1.orderWithSig, data1.destAmount);
        IDirectSettlementModule(address(adapter)).directSettle(data2.orderWithSig, data2.destAmount);
        vm.stopPrank();

        address[] memory tokens = new address[](2);
        tokens[0] = address(DAI);
        tokens[1] = address(MTK);

        vm.startPrank(users.bob.account);
        vm.expectEmit(true, true, false, true);
        emit FeesWithdrawn(users.bob.account, address(DAI), expectedFee1, users.bob.account);
        vm.expectEmit(true, true, false, true);
        emit FeesWithdrawn(users.bob.account, address(MTK), expectedFee2, users.bob.account);
        IFeeClaimerModule(address(adapter)).batchWithdrawAllFees(tokens, users.bob.account);

        assertEq(DAI.balanceOf(users.bob.account), expectedFee1, "Partner should receive all collected DAI fees");
        assertEq(MTK.balanceOf(users.bob.account), expectedFee2, "Partner should receive all collected MTK fees");
        assertEq(
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI)),
            0,
            "Collected DAI fees should be zero after withdrawal"
        );
        assertEq(
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(MTK)),
            0,
            "Collected MTK fees should be zero after withdrawal"
        );
    }

    function test_settleOrdersWithDifferentFeePercentages() public {
        TestData memory data1 = createTestData(100, address(MTK), address(DAI), 1); // 1% fee
        TestData memory data2 = createTestData(200, address(MTK), address(DAI), 2); // 2% fee
        TestData memory data3 = createTestData(0, address(MTK), address(DAI), 3); // 0% fee

        vm.startPrank(users.charlie.account);
        IDirectSettlementModule(address(adapter)).directSettle(data1.orderWithSig, data1.destAmount);
        IDirectSettlementModule(address(adapter)).directSettle(data2.orderWithSig, data2.destAmount);
        IDirectSettlementModule(address(adapter)).directSettle(data3.orderWithSig, data3.destAmount);
        vm.stopPrank();

        uint256 expectedFee1 = (data1.destAmount * data1.fee) / 10_000;
        uint256 expectedFee2 = (data2.destAmount * data2.fee) / 10_000;
        uint256 expectedFee3 = 0;

        uint256 totalCollectedFees =
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        assertEq(
            totalCollectedFees, expectedFee1 + expectedFee2 + expectedFee3, "Total collected fees should be correct"
        );
    }

    function test_settleOrdersWithDifferentTokens() public {
        TestData memory dataDAI = createTestData(100, address(MTK), address(DAI), 1); // 1% fee
        TestData memory dataWETH = createTestData(100, address(MTK), address(WETH), 2); // 1% fee
        TestData memory dataETH = createTestData(100, address(MTK), ERC20UtilsLib.ETH_ADDRESS, 3); // 1% fee

        vm.startPrank(users.charlie.account);
        IDirectSettlementModule(address(adapter)).directSettle(dataDAI.orderWithSig, dataDAI.destAmount);
        IDirectSettlementModule(address(adapter)).directSettle(dataWETH.orderWithSig, dataWETH.destAmount);
        IDirectSettlementModule(address(adapter)).directSettle{ value: dataETH.destAmount }(
            dataETH.orderWithSig, dataETH.destAmount
        );
        vm.stopPrank();

        uint256 expectedFee = (dataDAI.destAmount * dataDAI.fee) / 10_000;

        assertEq(
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI)),
            expectedFee,
            "Collected DAI fees should be correct"
        );
        assertEq(
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(WETH)),
            expectedFee,
            "Collected WETH fees should be correct"
        );
        assertEq(
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, ERC20UtilsLib.ETH_ADDRESS),
            expectedFee,
            "Collected ETH fees should be correct"
        );
    }

    function test_revertWhenWithdrawingMoreThanCollected() public {
        TestData memory data = createTestData(100, address(MTK), address(DAI), 1); // 1% fee
        uint256 expectedFee = (data.destAmount * data.fee) / 10_000;

        vm.prank(users.charlie.account);
        IDirectSettlementModule(address(adapter)).directSettle(data.orderWithSig, data.destAmount);

        vm.expectRevert();
        vm.prank(users.bob.account);
        IFeeClaimerModule(address(adapter)).withdrawFees(address(DAI), expectedFee + 1, users.bob.account);
    }

    function test_withdrawAllFees_SuccessfulWithdrawalERC20() public {
        TestData memory data = createTestData(100, address(MTK), address(DAI), 1); // 1% fee
        uint256 expectedFee = (data.destAmount * data.fee) / 10_000; // Convert bps to actual fee

        vm.prank(users.charlie.account);
        IDirectSettlementModule(address(adapter)).directSettle(data.orderWithSig, data.destAmount);

        vm.startPrank(users.bob.account);
        vm.expectEmit(true, true, false, true);
        emit FeesWithdrawn(users.bob.account, address(DAI), expectedFee, users.bob.account);
        uint256 withdrawnAmount = IFeeClaimerModule(address(adapter)).withdrawAllFees(address(DAI), users.bob.account);

        assertEq(withdrawnAmount, expectedFee, "Withdrawn amount should match collected fees");
        assertEq(DAI.balanceOf(users.bob.account), expectedFee, "Partner should receive all collected fees");
        assertEq(
            IFeeClaimerModule(address(adapter)).getCollectedFees(address(DAI), users.bob.account),
            0,
            "Collected fees should be zero after withdrawal"
        );
    }

    function test_withdrawAllFees_SuccessfulWithdrawalETH() public {
        TestData memory data = createTestData(100, address(MTK), ERC20UtilsLib.ETH_ADDRESS, 1); // 1% fee
        uint256 expectedFee = (data.destAmount * data.fee) / 10_000; // Convert bps to actual fee

        vm.prank(users.charlie.account);
        IDirectSettlementModule(address(adapter)).directSettle{ value: data.destAmount }(
            data.orderWithSig, data.destAmount
        );

        vm.startPrank(users.bob.account);
        uint256 balanceBefore = users.bob.account.balance;
        vm.expectEmit(true, true, false, true);
        emit FeesWithdrawn(users.bob.account, ERC20UtilsLib.ETH_ADDRESS, expectedFee, users.bob.account);
        uint256 withdrawnAmount =
            IFeeClaimerModule(address(adapter)).withdrawAllFees(ERC20UtilsLib.ETH_ADDRESS, users.bob.account);

        assertEq(withdrawnAmount, expectedFee, "Withdrawn amount should match collected fees");
        assertEq(
            users.bob.account.balance - balanceBefore, expectedFee, "Partner should receive all collected ETH fees"
        );
        assertEq(
            IFeeClaimerModule(address(adapter)).getCollectedFees(ERC20UtilsLib.ETH_ADDRESS, users.bob.account),
            0,
            "Collected fees should be zero after withdrawal"
        );
    }

    function test_withdrawAllFees_NoFeesCollected() public {
        address partner = users.bob.account;
        address token = address(MTK);
        vm.startPrank(partner);

        uint256 withdrawnAmount = IFeeClaimerModule(address(adapter)).withdrawAllFees(token, partner);

        assertEq(withdrawnAmount, 0, "Withdrawn amount should be zero when no fees are collected");
        assertEq(MTK.balanceOf(partner), 0, "Partner should not receive any tokens");
    }

    function test_withdrawAllFees_MultipleOrdersAndWithdrawals() public {
        TestData memory data1 = createTestData(100, address(MTK), address(DAI), 1); // 1% fee
        TestData memory data2 = createTestData(200, address(DAI), address(MTK), 2); // 2% fee

        uint256 expectedFee1 = (data1.destAmount * data1.fee) / 10_000;
        uint256 expectedFee2 = (data2.destAmount * data2.fee) / 10_000;

        vm.startPrank(users.charlie.account);
        IDirectSettlementModule(address(adapter)).directSettle(data1.orderWithSig, data1.destAmount);
        IDirectSettlementModule(address(adapter)).directSettle(data2.orderWithSig, data2.destAmount);
        vm.stopPrank();

        vm.startPrank(users.bob.account);
        vm.expectEmit(true, true, false, true);
        emit FeesWithdrawn(users.bob.account, address(DAI), expectedFee1, users.bob.account);
        uint256 withdrawnDAI = IFeeClaimerModule(address(adapter)).withdrawAllFees(address(DAI), users.bob.account);
        assertEq(withdrawnDAI, expectedFee1, "Withdrawn DAI amount should match collected fees");
        assertEq(DAI.balanceOf(users.bob.account), expectedFee1, "Partner should receive all collected DAI fees");

        vm.expectEmit(true, true, false, true);
        emit FeesWithdrawn(users.bob.account, address(MTK), expectedFee2, users.bob.account);
        uint256 withdrawnMTK = IFeeClaimerModule(address(adapter)).withdrawAllFees(address(MTK), users.bob.account);
        assertEq(withdrawnMTK, expectedFee2, "Withdrawn MTK amount should match collected fees");
        assertEq(MTK.balanceOf(users.bob.account), expectedFee2, "Partner should receive all collected MTK fees");

        assertEq(
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI)),
            0,
            "Collected DAI fees should be zero after withdrawal"
        );
        assertEq(
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(MTK)),
            0,
            "Collected MTK fees should be zero after withdrawal"
        );
    }

    /*//////////////////////////////////////////////////////////////
                        BATCH SETTLEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_directSettleBatch_WithFees() public {
        uint256[] memory feePercentages = new uint256[](3);
        feePercentages[0] = 100; // 1%
        feePercentages[1] = 200; // 2%
        feePercentages[2] = 50; // 0.5%

        address[] memory destTokens = new address[](3);
        destTokens[0] = address(DAI);
        destTokens[1] = address(WETH);
        destTokens[2] = ERC20UtilsLib.ETH_ADDRESS;

        (TestData[] memory batchData, uint256[] memory destAmounts) = createBatchTestData(feePercentages, destTokens);

        OrderWithSig[] memory ordersWithSigs = new OrderWithSig[](3);
        for (uint256 i = 0; i < 3; i++) {
            ordersWithSigs[i] = batchData[i].orderWithSig;
        }

        uint256 totalETHValue = destAmounts[2]; // For the ETH order

        vm.startPrank(users.charlie.account);
        IDirectSettlementModule(address(adapter)).directSettleBatch{ value: totalETHValue }(ordersWithSigs, destAmounts);
        vm.stopPrank();

        for (uint256 i = 0; i < 3; i++) {
            uint256 expectedFee = (batchData[i].destAmount * batchData[i].fee) / 10_000;
            uint256 collectedFees =
                IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, destTokens[i]);
            assertEq(
                collectedFees,
                expectedFee,
                string(abi.encodePacked("Collected fees for order ", i, " should match expected fee"))
            );
        }
    }

    function test_directSettleBatch_WithDifferentFeePercentages() public {
        uint256[] memory feePercentages = new uint256[](3);
        feePercentages[0] = 100; // 1%
        feePercentages[1] = 0; // 0%
        feePercentages[2] = 200; // 2%

        address[] memory destTokens = new address[](3);
        destTokens[0] = address(DAI);
        destTokens[1] = address(DAI);
        destTokens[2] = address(DAI);

        (TestData[] memory batchData, uint256[] memory destAmounts) = createBatchTestData(feePercentages, destTokens);

        OrderWithSig[] memory ordersWithSigs = new OrderWithSig[](3);
        for (uint256 i = 0; i < 3; i++) {
            ordersWithSigs[i] = batchData[i].orderWithSig;
        }

        vm.startPrank(users.charlie.account);
        IDirectSettlementModule(address(adapter)).directSettleBatch(ordersWithSigs, destAmounts);
        vm.stopPrank();

        uint256 totalCollectedFees =
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        uint256 expectedTotalFees = 0;
        for (uint256 i = 0; i < 3; i++) {
            expectedTotalFees += (batchData[i].destAmount * batchData[i].fee) / 10_000;
        }
        assertEq(totalCollectedFees, expectedTotalFees, "Total collected fees should match expected fees");
    }

    function test_directSettleBatch_WithDifferentTokens() public {
        uint256[] memory feePercentages = new uint256[](3);
        feePercentages[0] = 100; // 1%
        feePercentages[1] = 100; // 1%
        feePercentages[2] = 100; // 1%

        address[] memory destTokens = new address[](3);
        destTokens[0] = address(DAI);
        destTokens[1] = address(WETH);
        destTokens[2] = ERC20UtilsLib.ETH_ADDRESS;

        (TestData[] memory batchData, uint256[] memory destAmounts) = createBatchTestData(feePercentages, destTokens);

        OrderWithSig[] memory ordersWithSigs = new OrderWithSig[](3);
        for (uint256 i = 0; i < 3; i++) {
            ordersWithSigs[i] = batchData[i].orderWithSig;
        }

        uint256 totalETHValue = destAmounts[2]; // For the ETH order

        vm.startPrank(users.charlie.account);
        IDirectSettlementModule(address(adapter)).directSettleBatch{ value: totalETHValue }(ordersWithSigs, destAmounts);
        vm.stopPrank();

        for (uint256 i = 0; i < 3; i++) {
            uint256 expectedFee = (batchData[i].destAmount * batchData[i].fee) / 10_000;
            uint256 collectedFees =
                IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, destTokens[i]);
            assertEq(
                collectedFees,
                expectedFee,
                string(abi.encodePacked("Collected fees for token ", i, " should match expected fee"))
            );
        }
    }

    function test_directSettleBatch_EmitCorrectEvents() public {
        uint256[] memory feePercentages = new uint256[](2);
        feePercentages[0] = 100; // 1%
        feePercentages[1] = 200; // 2%

        address[] memory destTokens = new address[](2);
        destTokens[0] = address(DAI);
        destTokens[1] = address(WETH);

        (TestData[] memory batchData, uint256[] memory destAmounts) = createBatchTestData(feePercentages, destTokens);

        OrderWithSig[] memory ordersWithSigs = new OrderWithSig[](2);
        for (uint256 i = 0; i < 2; i++) {
            ordersWithSigs[i] = batchData[i].orderWithSig;
        }

        vm.startPrank(users.charlie.account);
        for (uint256 i = 0; i < 2; i++) {
            uint256 expectedFee = (batchData[i].destAmount * batchData[i].fee) / 10_000;
            vm.expectEmit(true, true, true, true);
            emit OrderSettled(
                batchData[i].order.owner,
                batchData[i].order.beneficiary,
                batchData[i].order.srcToken,
                batchData[i].order.destToken,
                batchData[i].order.srcAmount,
                batchData[i].order.destAmount,
                batchData[i].destAmount - expectedFee,
                0,
                expectedFee,
                _hashTypedDataV4(batchData[i].order.hash())
            );
        }
        IDirectSettlementModule(address(adapter)).directSettleBatch(ordersWithSigs, destAmounts);
        vm.stopPrank();
    }

    function test_directSettleBatch_UpdateCollectedFeesCorrectly() public {
        uint256[] memory feePercentages = new uint256[](3);
        feePercentages[0] = 100; // 1%
        feePercentages[1] = 200; // 2%
        feePercentages[2] = 150; // 1.5%

        address[] memory destTokens = new address[](3);
        destTokens[0] = address(DAI);
        destTokens[1] = address(DAI);
        destTokens[2] = address(DAI);

        (TestData[] memory batchData, uint256[] memory destAmounts) = createBatchTestData(feePercentages, destTokens);

        OrderWithSig[] memory ordersWithSigs = new OrderWithSig[](3);
        for (uint256 i = 0; i < 3; i++) {
            ordersWithSigs[i] = batchData[i].orderWithSig;
        }

        vm.startPrank(users.charlie.account);
        IDirectSettlementModule(address(adapter)).directSettleBatch(ordersWithSigs, destAmounts);
        vm.stopPrank();

        uint256 totalExpectedFees = 0;
        for (uint256 i = 0; i < 3; i++) {
            totalExpectedFees += (batchData[i].destAmount * batchData[i].fee) / 10_000;
        }

        uint256 collectedFees = IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        assertEq(collectedFees, totalExpectedFees, "Total collected fees should match sum of all expected fees");
    }

    function test_directSettle_OrderWithSurplus() public {
        TestData memory data = createTestData(100, address(MTK), address(DAI), 1); // 1% fee
        data.order.expectedDestAmount = data.order.destAmount * 110 / 100; // Set expected amount 10% higher
        data.orderWithSig = signOrder(data.order);

        uint256 actualAmount = data.order.expectedDestAmount * 105 / 100; // Actual amount 5% higher than
            // expectedDestAmount
        uint256 surplus = actualAmount - data.order.expectedDestAmount;
        uint256 expectedProtocolFee = surplus / 2;
        uint256 expectedPartnerFee = (actualAmount - expectedProtocolFee) * data.fee / 10_000;

        vm.expectEmit(true, true, false, true);
        emit OrderSettled(
            data.order.owner,
            data.order.beneficiary,
            data.order.srcToken,
            data.order.destToken,
            data.order.srcAmount,
            data.order.destAmount,
            actualAmount - expectedProtocolFee - expectedPartnerFee,
            expectedProtocolFee,
            expectedPartnerFee,
            _hashTypedDataV4(data.order.hash())
        );

        vm.prank(users.charlie.account);
        IDirectSettlementModule(address(adapter)).directSettle(data.orderWithSig, actualAmount);

        uint256 collectedPartnerFees =
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        assertEq(collectedPartnerFees, expectedPartnerFee, "Collected partner fees should match expected");
    }

    function test_directSettle_settleOrderWithoutSurplus() public {
        TestData memory data = createTestData(100, address(MTK), address(DAI), 1); // 1% fee
        data.order.expectedDestAmount = data.order.destAmount * 110 / 100; // Set expected amount 10% higher
        data.orderWithSig = signOrder(data.order);

        uint256 actualAmount = data.order.expectedDestAmount; // Actual amount equal to expectedDestAmount (no surplus)
        uint256 expectedPartnerFee = actualAmount * data.fee / 10_000;

        vm.expectEmit(true, true, false, true);
        emit OrderSettled(
            data.order.owner,
            data.order.beneficiary,
            data.order.srcToken,
            data.order.destToken,
            data.order.srcAmount,
            data.order.destAmount,
            actualAmount - expectedPartnerFee,
            0,
            expectedPartnerFee,
            _hashTypedDataV4(data.order.hash())
        );

        vm.prank(users.charlie.account);
        IDirectSettlementModule(address(adapter)).directSettle(data.orderWithSig, actualAmount);

        uint256 collectedPartnerFees =
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        assertEq(collectedPartnerFees, expectedPartnerFee, "Collected partner fees should match expected");
    }

    function test_directSettle_OrderBatchWithMixedSurplus() public {
        uint256[] memory feePercentages = new uint256[](3);
        feePercentages[0] = 100; // 1%
        feePercentages[1] = 200; // 2%
        feePercentages[2] = 150; // 1.5%

        address[] memory destTokens = new address[](3);
        destTokens[0] = address(DAI);
        destTokens[1] = address(DAI);
        destTokens[2] = address(DAI);

        (TestData[] memory batchData, uint256[] memory destAmounts) = createBatchTestData(feePercentages, destTokens);

        // Modify expected and actual amounts
        batchData[0].order.expectedDestAmount = batchData[0].order.destAmount * 110 / 100; // 10% higher
        destAmounts[0] = batchData[0].order.expectedDestAmount * 105 / 100; // 5% surplus over expectedDestAmount

        batchData[1].order.expectedDestAmount = batchData[1].order.destAmount * 105 / 100; // 5% higher
        destAmounts[1] = batchData[1].order.expectedDestAmount; // No surplus

        batchData[2].order.expectedDestAmount = batchData[2].order.destAmount * 110 / 100; // 10% higher
        destAmounts[2] = batchData[2].order.expectedDestAmount * 115 / 100; // 15% surplus over expectedDestAmount

        OrderWithSig[] memory ordersWithSigs = new OrderWithSig[](3);
        for (uint256 i = 0; i < 3; i++) {
            ordersWithSigs[i] = signOrder(batchData[i].order);
        }

        vm.prank(users.charlie.account);
        IDirectSettlementModule(address(adapter)).directSettleBatch(ordersWithSigs, destAmounts);

        uint256 totalCollectedFees =
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));

        uint256 expectedTotalFees = 0;
        for (uint256 i = 0; i < 3; i++) {
            uint256 surplus = destAmounts[i] > batchData[i].order.expectedDestAmount
                ? destAmounts[i] - batchData[i].order.expectedDestAmount
                : 0;
            uint256 protocolFee = surplus / 2;
            uint256 partnerFee = (destAmounts[i] - protocolFee) * batchData[i].fee / 10_000;
            expectedTotalFees += partnerFee;
        }

        assertEq(totalCollectedFees, expectedTotalFees, "Total collected fees should match expected fees");
    }

    /*//////////////////////////////////////////////////////////////
                               INVARIANT
    //////////////////////////////////////////////////////////////*/

    function invariant_totalFeesNeverExceedActualAmount() public {
        TestData memory data = createTestData(200, address(MTK), address(DAI), 1); // 2% fee
        data.order.expectedDestAmount = data.order.destAmount * 120 / 100; // Set expected amount 20% higher
        data.orderWithSig = signOrder(data.order);

        uint256 actualAmount = data.order.expectedDestAmount * 110 / 100; // 10% higher than expected, but still lower
            // than original expected

        vm.prank(users.charlie.account);
        IDirectSettlementModule(address(adapter)).directSettle(data.orderWithSig, actualAmount);

        uint256 partnerFees = IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        uint256 protocolFees = IFeeClaimerModule(address(adapter)).getCollectedFees(address(0), address(DAI));

        assert(partnerFees + protocolFees <= actualAmount);
    }

    function invariant_partnerFeesNeverExceedSpecifiedPercentage() public {
        TestData memory data = createTestData(200, address(MTK), address(DAI), 1); // 2% fee
        data.orderWithSig = signOrder(data.order);

        vm.prank(users.charlie.account);
        IDirectSettlementModule(address(adapter)).directSettle(data.orderWithSig, data.destAmount);

        uint256 partnerFees = IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        uint256 maxAllowedFees = (data.destAmount * 200) / 10_000; // 2% of destAmount

        assert(partnerFees <= maxAllowedFees);
    }

    function invariant_protocolFeesOnlyCollectedWithSurplus() public {
        TestData memory data = createTestData(100, address(MTK), address(DAI), 1); // 1% fee
        data.order.expectedDestAmount = data.order.destAmount;
        data.orderWithSig = signOrder(data.order);

        vm.prank(users.charlie.account);
        IDirectSettlementModule(address(adapter)).directSettle(data.orderWithSig, data.destAmount);

        uint256 protocolFees = IFeeClaimerModule(address(adapter)).getCollectedFees(address(0), address(DAI));

        assert(protocolFees == 0);
    }

    function invariant_surplusIsDistributedCorrectly() public {
        TestData memory data = createTestData(100, address(MTK), address(DAI), 1); // 1% fee
        data.order.expectedDestAmount = data.order.destAmount * 110 / 100; // Set expected amount 10% higher
        data.orderWithSig = signOrder(data.order);

        uint256 actualAmount = data.order.expectedDestAmount * 105 / 100; // 5% surplus

        vm.prank(users.charlie.account);
        IDirectSettlementModule(address(adapter)).directSettle(data.orderWithSig, actualAmount);

        uint256 surplus = actualAmount - data.order.expectedDestAmount;
        uint256 expectedProtocolFee = surplus / 2;
        uint256 expectedPartnerFee = (actualAmount - expectedProtocolFee) * data.fee / 10_000;

        uint256 partnerFees = IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        uint256 protocolFees = IFeeClaimerModule(address(adapter)).getCollectedFees(address(0), address(DAI));

        assert(partnerFees == expectedPartnerFee);
        assert(protocolFees == expectedProtocolFee);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Signs the order
    function signOrder(Order memory order) internal view returns (OrderWithSig memory) {
        bytes32 hash = _hashTypedDataV4(order.hash());
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        return OrderWithSig({ order: order, signature: sig });
    }
}
