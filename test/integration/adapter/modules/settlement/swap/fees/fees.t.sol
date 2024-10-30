// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Interfaces
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISwapSettlementModule } from "@modules/settlement/interfaces/ISwapSettlementModule.sol";
import { IFeeClaimerModule } from "@modules/interfaces/IFeeClaimerModule.sol";

// Libraries
import { ERC20UtilsLib } from "@modules/libraries/ERC20UtilsLib.sol";
import { OrderHashLib } from "@modules/libraries/OrderHashLib.sol";

// Test
import { SettlementModule_Integration_Test } from "../../SettlementModule.t.sol";

// Types
import { Order, OrderWithSig } from "@types/Order.sol";
import { ExecutorData, StepData } from "@executors/example/ThreeStepExecutor.sol";

// Utilities
import { EIP2098Lib } from "test/utils/EIP2098Lib.sol";

contract SwapSettlementModule_fees is SettlementModule_Integration_Test {
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
        uint256 partnerFee;
        uint256 executorFee;
        Order order;
        OrderWithSig orderWithSig;
        ExecutorData executorData;
    }

    /*//////////////////////////////////////////////////////////////
                               TEST DATA
    //////////////////////////////////////////////////////////////*/

    /// @dev Creates test data for tests
    function createTestData(
        uint256 partnerFeeInBps,
        uint256 executorFeeInBps,
        address srcToken,
        address destToken,
        uint256 nonce
    )
        internal
        returns (TestData memory data)
    {
        data.srcAmount = 1_000_000;
        data.destAmount = 990_000;
        data.partnerFee = partnerFeeInBps;
        data.executorFee = (data.destAmount * executorFeeInBps) / 10_000;

        vm.startPrank(users.admin.account);
        address[] memory agents = new address[](1);
        agents[0] = users.charlie.account;
        portikusV2.registerAgent(agents);
        if (srcToken != ERC20UtilsLib.ETH_ADDRESS) {
            IERC20(srcToken).transfer(users.alice.account, data.srcAmount);
        } else {
            vm.deal(users.alice.account, data.srcAmount);
        }
        vm.stopPrank();

        if (srcToken != ERC20UtilsLib.ETH_ADDRESS) {
            vm.prank(users.alice.account);
            IERC20(srcToken).approve(address(adapter), type(uint256).max);
        }

        data.order = Order({
            owner: users.alice.account,
            beneficiary: users.alice.account,
            srcToken: srcToken,
            destToken: destToken,
            srcAmount: data.srcAmount,
            destAmount: data.destAmount - data.executorFee - 1,
            expectedDestAmount: data.destAmount,
            deadline: block.timestamp + 100,
            partnerAndFee: (uint256(uint160(address(users.bob.account))) << 96) | data.partnerFee,
            nonce: nonce,
            permit: ""
        });

        data.orderWithSig = signOrder(data.order);

        data.executorData = ExecutorData(
            StepData(abi.encodeWithSignature("approve(address,uint256)", address(dex), data.srcAmount), srcToken),
            StepData(
                abi.encodeWithSignature(
                    "swap(address,address,uint256,uint256,address)",
                    srcToken,
                    destToken,
                    data.srcAmount,
                    data.destAmount,
                    address(executor)
                ),
                address(dex)
            ),
            StepData("", address(0)),
            users.charlie.account,
            destToken,
            data.executorFee
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_swapSettle_WithFees() public {
        // Arrange
        TestData memory data = createTestData(100, 50, address(MTK), address(DAI), 1); // 1% partner fee, 0.5% executor
            // fee
        uint256 expectedPartnerFee = ((data.destAmount - data.executorFee) * data.partnerFee) / 10_000;

        // Act & Assert
        vm.expectEmit(true, true, true, true);
        emit OrderSettled(
            data.order.owner,
            data.order.beneficiary,
            data.order.srcToken,
            data.order.destToken,
            data.order.srcAmount,
            data.order.destAmount,
            data.destAmount - data.executorFee - expectedPartnerFee - 1,
            0,
            expectedPartnerFee,
            _hashTypedDataV4(data.order.hash())
        );

        vm.prank(users.charlie.account);
        ISwapSettlementModule(address(adapter)).swapSettle(
            data.orderWithSig, abi.encode(data.executorData), address(executor)
        );

        uint256 collectedFees = IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        assertEq(collectedFees, expectedPartnerFee, "Collected fees should match expected partner fee");

        uint256 aliceBalance = DAI.balanceOf(users.alice.account);
        assertEq(
            aliceBalance,
            data.destAmount - data.executorFee - expectedPartnerFee - 1,
            "Alice should receive correct amount after fees"
        );

        uint256 charlieBalance = DAI.balanceOf(users.charlie.account);
        assertEq(charlieBalance, data.executorFee, "Charlie should receive executor fee");
    }

    function test_swapSettleBatch_WithFees() public {
        // Arrange
        uint256[] memory partnerFeePercentages = new uint256[](3);
        partnerFeePercentages[0] = 100; // 1%
        partnerFeePercentages[1] = 200; // 2%
        partnerFeePercentages[2] = 50; // 0.5%

        uint256[] memory executorFeePercentages = new uint256[](3);
        executorFeePercentages[0] = 50; // 0.5%
        executorFeePercentages[1] = 75; // 0.75%
        executorFeePercentages[2] = 25; // 0.25%

        address[] memory destTokens = new address[](3);
        destTokens[0] = address(DAI);
        destTokens[1] = address(WETH);
        destTokens[2] = address(MTK);

        OrderWithSig[] memory ordersWithSigs = new OrderWithSig[](3);
        bytes[] memory executorDataArray = new bytes[](3);
        uint256[] memory expectedPartnerFees = new uint256[](3);
        uint256[] memory expectedExecutorFees = new uint256[](3);

        for (uint256 i = 0; i < 3; i++) {
            TestData memory data =
                createTestData(partnerFeePercentages[i], executorFeePercentages[i], address(MTK), destTokens[i], i + 1);
            ordersWithSigs[i] = data.orderWithSig;
            executorDataArray[i] = abi.encode(data.executorData);
            expectedPartnerFees[i] = ((data.destAmount - data.executorFee) * data.partnerFee) / 10_000;
            expectedExecutorFees[i] = data.executorFee;
        }

        // Act
        vm.prank(users.charlie.account);
        ISwapSettlementModule(address(adapter)).swapSettleBatch(ordersWithSigs, executorDataArray, address(executor));

        // Assert
        for (uint256 i = 0; i < 3; i++) {
            uint256 collectedFees =
                IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, destTokens[i]);
            assertEq(
                collectedFees,
                expectedPartnerFees[i],
                string(abi.encodePacked("Collected fees for order ", i, " should match expected partner fee"))
            );
        }

        assertEq(
            DAI.balanceOf(users.charlie.account),
            expectedExecutorFees[0],
            "Charlie should receive correct DAI executor fee"
        );
        assertEq(
            WETH.balanceOf(users.charlie.account),
            expectedExecutorFees[1],
            "Charlie should receive correct WETH executor fee"
        );
        assertEq(
            MTK.balanceOf(users.charlie.account),
            expectedExecutorFees[2],
            "Charlie should receive correct MTK executor fee"
        );
    }

    function test_withdrawSpecificAmount() public {
        // Arrange
        TestData memory data = createTestData(100, 50, address(MTK), address(DAI), 1); // 1% partner fee, 0.5% executor
            // fee
        uint256 expectedPartnerFee = ((data.destAmount - data.executorFee) * data.partnerFee) / 10_000;

        vm.prank(users.charlie.account);
        ISwapSettlementModule(address(adapter)).swapSettle(
            data.orderWithSig, abi.encode(data.executorData), address(executor)
        );

        uint256 withdrawAmount = expectedPartnerFee / 2;

        // Act
        vm.startPrank(users.bob.account);
        vm.expectEmit(true, true, false, true);
        emit FeesWithdrawn(users.bob.account, address(DAI), withdrawAmount, users.bob.account);
        IFeeClaimerModule(address(adapter)).withdrawFees(address(DAI), withdrawAmount, users.bob.account);

        // Assert
        uint256 remainingFees = IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        assertEq(
            remainingFees,
            expectedPartnerFee - withdrawAmount,
            "Remaining fees should be correct after partial withdrawal"
        );
    }

    function test_withdrawAllFees() public {
        // Arrange
        TestData memory data = createTestData(100, 50, address(MTK), address(DAI), 1); // 1% partner fee, 0.5% executor
            // fee
        uint256 expectedPartnerFee = ((data.destAmount - data.executorFee) * data.partnerFee) / 10_000;

        vm.prank(users.charlie.account);
        ISwapSettlementModule(address(adapter)).swapSettle(
            data.orderWithSig, abi.encode(data.executorData), address(executor)
        );

        // Act
        vm.startPrank(users.bob.account);
        vm.expectEmit(true, true, false, true);
        emit FeesWithdrawn(users.bob.account, address(DAI), expectedPartnerFee, users.bob.account);
        uint256 withdrawnAmount = IFeeClaimerModule(address(adapter)).withdrawAllFees(address(DAI), users.bob.account);

        // Assert
        assertEq(withdrawnAmount, expectedPartnerFee, "Withdrawn amount should match collected fees");
        assertEq(DAI.balanceOf(users.bob.account), expectedPartnerFee, "Partner should receive all collected fees");
        assertEq(
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI)),
            0,
            "Collected fees should be zero after withdrawal"
        );
    }

    function test_batchWithdrawAllFees() public {
        // Arrange
        TestData memory data1 = createTestData(100, 50, address(MTK), address(DAI), 1); // 1% partner fee, 0.5% executor
            // fee
        TestData memory data2 = createTestData(200, 75, address(DAI), address(WETH), 2); // 2% partner fee, 0.75%
            // executor fee

        vm.startPrank(users.charlie.account);
        ISwapSettlementModule(address(adapter)).swapSettle(
            data1.orderWithSig, abi.encode(data1.executorData), address(executor)
        );
        ISwapSettlementModule(address(adapter)).swapSettle(
            data2.orderWithSig, abi.encode(data2.executorData), address(executor)
        );
        vm.stopPrank();

        uint256 expectedFee1 = ((data1.destAmount - data1.executorFee) * data1.partnerFee) / 10_000;
        uint256 expectedFee2 = ((data2.destAmount - data2.executorFee) * data2.partnerFee) / 10_000;

        address[] memory tokens = new address[](2);
        tokens[0] = address(DAI);
        tokens[1] = address(WETH);

        // Act
        vm.startPrank(users.bob.account);
        vm.expectEmit(true, true, false, true);
        emit FeesWithdrawn(users.bob.account, address(DAI), expectedFee1, users.bob.account);
        vm.expectEmit(true, true, false, true);
        emit FeesWithdrawn(users.bob.account, address(WETH), expectedFee2, users.bob.account);
        IFeeClaimerModule(address(adapter)).batchWithdrawAllFees(tokens, users.bob.account);

        // Assert
        assertEq(DAI.balanceOf(users.bob.account), expectedFee1, "Partner should receive all collected DAI fees");
        assertEq(WETH.balanceOf(users.bob.account), expectedFee2, "Partner should receive all collected WETH fees");
        assertEq(
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI)),
            0,
            "Collected DAI fees should be zero after withdrawal"
        );
        assertEq(
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(WETH)),
            0,
            "Collected WETH fees should be zero after withdrawal"
        );
    }

    function test_settleOrdersWithDifferentFeePercentages() public {
        // Arrange
        TestData memory data1 = createTestData(100, 50, address(MTK), address(DAI), 1); // 1% partner fee, 0.5% executor
            // fee
        TestData memory data2 = createTestData(200, 75, address(MTK), address(DAI), 2); // 2% partner fee, 0.75%
            // executor fee
        TestData memory data3 = createTestData(0, 25, address(MTK), address(DAI), 3); // 0% partner fee, 0.25% executor
            // fee

        // Act
        vm.startPrank(users.charlie.account);
        ISwapSettlementModule(address(adapter)).swapSettle(
            data1.orderWithSig, abi.encode(data1.executorData), address(executor)
        );
        ISwapSettlementModule(address(adapter)).swapSettle(
            data2.orderWithSig, abi.encode(data2.executorData), address(executor)
        );
        ISwapSettlementModule(address(adapter)).swapSettle(
            data3.orderWithSig, abi.encode(data3.executorData), address(executor)
        );
        vm.stopPrank();

        // Assert
        uint256 expectedFee1 = ((data1.destAmount - data1.executorFee) * data1.partnerFee) / 10_000;
        uint256 expectedFee2 = ((data2.destAmount - data2.executorFee) * data2.partnerFee) / 10_000;
        uint256 expectedFee3 = 0;

        uint256 totalCollectedFees =
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        assertEq(
            totalCollectedFees,
            expectedFee1 + expectedFee2 + expectedFee3,
            "Total collected partner fees should be correct"
        );

        uint256 totalExecutorFees = DAI.balanceOf(users.charlie.account);
        assertEq(
            totalExecutorFees,
            data1.executorFee + data2.executorFee + data3.executorFee,
            "Total executor fees should be correct"
        );
    }

    function test_settleOrdersWithDifferentTokens() public {
        // Arrange
        TestData memory dataDAI = createTestData(100, 50, address(MTK), address(DAI), 1); // 1% partner fee, 0.5%
            // executor fee
        TestData memory dataWETH = createTestData(100, 50, address(MTK), address(WETH), 2); // 1% partner fee, 0.5%
            // executor fee

        // Act
        vm.startPrank(users.charlie.account);
        ISwapSettlementModule(address(adapter)).swapSettle(
            dataDAI.orderWithSig, abi.encode(dataDAI.executorData), address(executor)
        );
        ISwapSettlementModule(address(adapter)).swapSettle(
            dataWETH.orderWithSig, abi.encode(dataWETH.executorData), address(executor)
        );

        vm.stopPrank();

        // Assert
        uint256 expectedPartnerFeeDAI = ((dataDAI.destAmount - dataDAI.executorFee) * dataDAI.partnerFee) / 10_000;
        uint256 expectedPartnerFeeWETH = ((dataWETH.destAmount - dataWETH.executorFee) * dataWETH.partnerFee) / 10_000;

        assertEq(
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI)),
            expectedPartnerFeeDAI,
            "Collected DAI partner fees should be correct"
        );
        assertEq(
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(WETH)),
            expectedPartnerFeeWETH,
            "Collected WETH partner fees should be correct"
        );

        assertEq(
            DAI.balanceOf(users.charlie.account), dataDAI.executorFee, "Charlie should receive correct DAI executor fee"
        );
        assertEq(
            WETH.balanceOf(users.charlie.account),
            dataWETH.executorFee,
            "Charlie should receive correct WETH executor fee"
        );
    }

    function test_revertWhenWithdrawingMoreThanCollected() public {
        // Arrange
        TestData memory data = createTestData(100, 50, address(MTK), address(DAI), 1); // 1% partner fee, 0.5% executor
            // fee
        uint256 expectedPartnerFee = ((data.destAmount - data.executorFee) * data.partnerFee) / 10_000;

        vm.prank(users.charlie.account);
        ISwapSettlementModule(address(adapter)).swapSettle(
            data.orderWithSig, abi.encode(data.executorData), address(executor)
        );

        // Act & Assert
        vm.expectRevert();
        vm.prank(users.bob.account);
        IFeeClaimerModule(address(adapter)).withdrawFees(address(DAI), expectedPartnerFee + 1, users.bob.account);
    }

    function test_queryCollectedFees() public {
        // Arrange
        TestData memory data1 = createTestData(100, 50, address(MTK), address(DAI), 1); // 1% partner fee, 0.5% executor
            // fee
        TestData memory data2 = createTestData(200, 75, address(DAI), address(MTK), 2); // 2% partner fee, 0.75%
            // executor fee

        vm.startPrank(users.charlie.account);
        ISwapSettlementModule(address(adapter)).swapSettle(
            data1.orderWithSig, abi.encode(data1.executorData), address(executor)
        );
        ISwapSettlementModule(address(adapter)).swapSettle(
            data2.orderWithSig, abi.encode(data2.executorData), address(executor)
        );
        vm.stopPrank();

        uint256 expectedFee1 = ((data1.destAmount - data1.executorFee) * data1.partnerFee) / 10_000;
        uint256 expectedFee2 = ((data2.destAmount - data2.executorFee) * data2.partnerFee) / 10_000;

        // Act & Assert
        assertEq(
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI)),
            expectedFee1,
            "Collected DAI partner fees should be correct"
        );
        assertEq(
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(MTK)),
            expectedFee2,
            "Collected MTK partner fees should be correct"
        );

        address[] memory tokens = new address[](2);
        tokens[0] = address(DAI);
        tokens[1] = address(MTK);

        uint256[] memory collectedFees =
            IFeeClaimerModule(address(adapter)).batchGetCollectedFees(users.bob.account, tokens);
        assertEq(collectedFees[0], expectedFee1, "Batch collected DAI partner fees should be correct");
        assertEq(collectedFees[1], expectedFee2, "Batch collected MTK partner fees should be correct");
    }

    function test_swapSettle_WithZeroFees() public {
        // Arrange
        TestData memory data = createTestData(0, 0, address(MTK), address(DAI), 1); // 0% partner fee, 0% executor fee

        // Act
        vm.prank(users.charlie.account);
        ISwapSettlementModule(address(adapter)).swapSettle(
            data.orderWithSig, abi.encode(data.executorData), address(executor)
        );

        // Assert
        uint256 collectedFees = IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        assertEq(collectedFees, 0, "Collected partner fees should be zero for 0% fee");

        uint256 executorBalance = DAI.balanceOf(users.charlie.account);
        assertEq(executorBalance, 0, "Executor should receive no fee for 0% fee");
    }

    function test_swapSettle_WithSurplus() public {
        // Arrange
        TestData memory data = createTestData(100, 50, address(MTK), address(DAI), 1); // 1% partner fee, 0.5% executor
            // fee
        data.order.expectedDestAmount = data.order.destAmount * 110 / 100; // Set expected amount 10% higher
        data.orderWithSig = signOrder(data.order);

        uint256 actualAmount = data.order.expectedDestAmount * 105 / 100; // Actual amount 5% higher than
        // expectedDestAmount
        uint256 surplus = actualAmount - data.executorFee - 1 - data.order.expectedDestAmount;
        uint256 expectedProtocolFee = (surplus * 5000) / 10_000;
        uint256 expectedPartnerFee =
            ((actualAmount - data.executorFee - 1 - expectedProtocolFee) * data.partnerFee) / 10_000;

        // Modify executorData to return the actual amount
        data.executorData.mainCalldata.stepCalldata = abi.encodeWithSignature(
            "swap(address,address,uint256,uint256,address)",
            data.order.srcToken,
            data.order.destToken,
            data.order.srcAmount,
            actualAmount,
            address(executor)
        );

        // Act & Assert
        vm.expectEmit(true, true, true, true);
        emit OrderSettled(
            data.order.owner,
            data.order.beneficiary,
            data.order.srcToken,
            data.order.destToken,
            data.order.srcAmount,
            data.order.destAmount,
            actualAmount - expectedProtocolFee - expectedPartnerFee - data.executorFee - 1,
            expectedProtocolFee,
            expectedPartnerFee,
            _hashTypedDataV4(data.order.hash())
        );

        vm.prank(users.charlie.account);
        ISwapSettlementModule(address(adapter)).swapSettle(
            data.orderWithSig, abi.encode(data.executorData), address(executor)
        );

        uint256 collectedPartnerFees =
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        assertEq(collectedPartnerFees, expectedPartnerFee, "Collected partner fees should match expected");
    }

    function test_swapSettle_WithoutSurplus() public {
        // Arrange
        TestData memory data = createTestData(100, 50, address(MTK), address(DAI), 1); // 1% partner fee, 0.5% executor
            // fee
        data.order.expectedDestAmount = data.order.destAmount * 110 / 100; // Set expected amount 10% higher
        data.orderWithSig = signOrder(data.order);

        uint256 actualAmount = data.order.expectedDestAmount; // Actual amount equal to expectedDestAmount (no surplus)
        uint256 expectedPartnerFee = (actualAmount - data.executorFee) * data.partnerFee / 10_000;

        // Modify executorData to return the actual amount
        data.executorData.mainCalldata.stepCalldata = abi.encodeWithSignature(
            "swap(address,address,uint256,uint256,address)",
            data.order.srcToken,
            data.order.destToken,
            data.order.srcAmount,
            actualAmount,
            address(executor)
        );

        // Act & Assert
        vm.expectEmit(true, true, true, true);
        emit OrderSettled(
            data.order.owner,
            data.order.beneficiary,
            data.order.srcToken,
            data.order.destToken,
            data.order.srcAmount,
            data.order.destAmount,
            actualAmount - expectedPartnerFee - data.executorFee - 1,
            0,
            expectedPartnerFee,
            _hashTypedDataV4(data.order.hash())
        );

        vm.prank(users.charlie.account);
        ISwapSettlementModule(address(adapter)).swapSettle(
            data.orderWithSig, abi.encode(data.executorData), address(executor)
        );

        uint256 collectedPartnerFees =
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        assertEq(collectedPartnerFees, expectedPartnerFee, "Collected partner fees should match expected");
    }

    function test_swapSettleBatch_WithMixedSurplus() public {
        // Arrange
        uint256[] memory partnerFeePercentages = new uint256[](3);
        partnerFeePercentages[0] = 100; // 1%
        partnerFeePercentages[1] = 200; // 2%
        partnerFeePercentages[2] = 150; // 1.5%

        uint256[] memory executorFeePercentages = new uint256[](3);
        executorFeePercentages[0] = 50; // 0.5%
        executorFeePercentages[1] = 75; // 0.75%
        executorFeePercentages[2] = 25; // 0.25%

        address[] memory destTokens = new address[](3);
        destTokens[0] = address(DAI);
        destTokens[1] = address(DAI);
        destTokens[2] = address(DAI);

        OrderWithSig[] memory ordersWithSigs = new OrderWithSig[](3);
        bytes[] memory executorDataArray = new bytes[](3);
        uint256 totalExpectedPartnerFees = 0;
        uint256 totalExpectedProtocolFees = 0;

        for (uint256 i = 0; i < 3; i++) {
            TestData memory data =
                createTestData(partnerFeePercentages[i], executorFeePercentages[i], address(MTK), destTokens[i], i + 1);
            data.order.expectedDestAmount = data.order.destAmount * 110 / 100; // Set expected amount 10% higher
            ordersWithSigs[i] = signOrder(data.order);

            uint256 actualAmount;
            if (i == 0) actualAmount = data.order.expectedDestAmount * 105 / 100; // 5% surplus

            else if (i == 1) actualAmount = data.order.expectedDestAmount; // No surplus

            else actualAmount = data.order.expectedDestAmount * 115 / 100; // 15% surplus

            data.executorData.mainCalldata.stepCalldata = abi.encodeWithSignature(
                "swap(address,address,uint256,uint256,address)",
                data.order.srcToken,
                data.order.destToken,
                data.order.srcAmount,
                actualAmount,
                address(executor)
            );
            executorDataArray[i] = abi.encode(data.executorData);

            uint256 surplus = actualAmount > data.order.expectedDestAmount
                ? actualAmount - data.executorFee - (i > 0 ? 0 : 1) - data.order.expectedDestAmount
                : 0;
            uint256 protocolFee = (surplus * 5000) / 10_000;
            uint256 partnerFee =
                ((actualAmount - protocolFee - data.executorFee - (i > 0 ? 0 : 1)) * data.partnerFee) / 10_000;

            totalExpectedPartnerFees += partnerFee;
            totalExpectedProtocolFees += protocolFee;
        }

        // Record the initial protocol fees
        uint256 initialProtocolFees = IFeeClaimerModule(address(adapter)).getCollectedFees(address(0), address(DAI));

        // Act
        vm.prank(users.charlie.account);
        ISwapSettlementModule(address(adapter)).swapSettleBatch(ordersWithSigs, executorDataArray, address(executor));

        // Assert
        uint256 collectedPartnerFees =
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        assertEq(collectedPartnerFees, totalExpectedPartnerFees, "Total collected partner fees should match expected");

        uint256 collectedProtocolFees =
            IFeeClaimerModule(address(adapter)).getCollectedFees(address(0), address(DAI)) - initialProtocolFees;
        assertEq(
            collectedProtocolFees, totalExpectedProtocolFees, "Total collected protocol fees should match expected"
        );
    }

    /*//////////////////////////////////////////////////////////////
                               INVARIANT
    //////////////////////////////////////////////////////////////*/

    function invariant_totalFeesNeverExceedActualAmount() public {
        TestData memory data = createTestData(200, 100, address(MTK), address(DAI), 1); // 2% partner fee, 1% executor
            // fee
        data.order.expectedDestAmount = data.order.destAmount * 120 / 100; // Set expected amount 20% higher
        data.orderWithSig = signOrder(data.order);

        uint256 actualAmount = data.order.expectedDestAmount * 110 / 100; // 10% higher than expected, but still lower
            // than original expected

        data.executorData.mainCalldata.stepCalldata = abi.encodeWithSignature(
            "swap(address,address,uint256,uint256,address)",
            data.order.srcToken,
            data.order.destToken,
            data.order.srcAmount,
            actualAmount,
            address(executor)
        );

        vm.prank(users.charlie.account);
        ISwapSettlementModule(address(adapter)).swapSettle(
            data.orderWithSig, abi.encode(data.executorData), address(executor)
        );

        uint256 partnerFees = IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        uint256 protocolFees = IFeeClaimerModule(address(adapter)).getCollectedFees(address(0), address(DAI));
        uint256 executorFees = data.executorFee;

        assert(partnerFees + protocolFees + executorFees <= actualAmount);
    }

    function invariant_partnerFeesNeverExceedSpecifiedPercentage() public {
        TestData memory data = createTestData(200, 100, address(MTK), address(DAI), 1); // 2% partner fee, 1% executor
            // fee
        data.orderWithSig = signOrder(data.order);

        vm.prank(users.charlie.account);
        ISwapSettlementModule(address(adapter)).swapSettle(
            data.orderWithSig, abi.encode(data.executorData), address(executor)
        );

        uint256 partnerFees = IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        uint256 maxAllowedFees = (data.destAmount * 200) / 10_000; // 2% of destAmount

        assert(partnerFees <= maxAllowedFees);
    }

    function invariant_protocolFeesOnlyCollectedWithSurplus() public {
        TestData memory data = createTestData(100, 50, address(MTK), address(DAI), 1); // 1% partner fee, 0.5% executor
            // fee
        data.order.expectedDestAmount = data.order.destAmount;
        data.orderWithSig = signOrder(data.order);

        vm.prank(users.charlie.account);
        ISwapSettlementModule(address(adapter)).swapSettle(
            data.orderWithSig, abi.encode(data.executorData), address(executor)
        );

        uint256 protocolFees = IFeeClaimerModule(address(adapter)).getCollectedFees(address(0), address(DAI));

        assert(protocolFees == 0);
    }

    function invariant_executorFeesNeverExceedSpecifiedAmount() public {
        TestData memory data = createTestData(100, 50, address(MTK), address(DAI), 1); // 1% partner fee, 0.5% executor
            // fee
        data.orderWithSig = signOrder(data.order);

        uint256 charlieBalanceBefore = DAI.balanceOf(users.charlie.account);

        vm.prank(users.charlie.account);
        ISwapSettlementModule(address(adapter)).swapSettle(
            data.orderWithSig, abi.encode(data.executorData), address(executor)
        );

        uint256 charlieBalanceAfter = DAI.balanceOf(users.charlie.account);
        uint256 actualExecutorFee = charlieBalanceAfter - charlieBalanceBefore;

        assert(actualExecutorFee <= data.executorFee);
    }

    function invariant_surplusIsDistributedCorrectly() public {
        TestData memory data = createTestData(100, 50, address(MTK), address(DAI), 1); // 1% partner fee, 0.5% executor
            // fee
        data.order.expectedDestAmount = data.order.destAmount * 110 / 100; // Set expected amount 10% higher
        data.orderWithSig = signOrder(data.order);

        uint256 actualAmount = data.order.expectedDestAmount * 105 / 100; // 5% surplus

        data.executorData.mainCalldata.stepCalldata = abi.encodeWithSignature(
            "swap(address,address,uint256,uint256,address)",
            data.order.srcToken,
            data.order.destToken,
            data.order.srcAmount,
            actualAmount,
            address(executor)
        );

        vm.prank(users.charlie.account);
        ISwapSettlementModule(address(adapter)).swapSettle(
            data.orderWithSig, abi.encode(data.executorData), address(executor)
        );

        uint256 surplus = actualAmount - data.executorFee - 1 - data.order.expectedDestAmount;
        uint256 expectedProtocolFee = (surplus * 5000) / 10_000;
        uint256 expectedPartnerFee =
            ((actualAmount - data.executorFee - 1 - expectedProtocolFee) * data.partnerFee) / 10_000;

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
