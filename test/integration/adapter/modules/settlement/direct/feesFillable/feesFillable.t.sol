// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Interfaces
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IFillableDirectSettlementModule } from "@modules/settlement/interfaces/IFillableDirectSettlementModule.sol";
import { IFeeClaimerModule } from "@modules/interfaces/IFeeClaimerModule.sol";

// Libraries
import { FillableOrderHashLib } from "@modules/libraries/FillableOrderHashLib.sol";
import { FillableStorageLib } from "@modules/libraries/FillableStorageLib.sol";
import { ERC20UtilsLib } from "@modules/libraries/ERC20UtilsLib.sol";

// Test
import { SettlementModule_Integration_Test } from "../../SettlementModule.t.sol";

// Types
import { Order, OrderWithSig } from "@types/Order.sol";

// Utilities
import { EIP2098Lib } from "test/utils/EIP2098Lib.sol";

contract FillableDirectSettlementModule_feesFillable is SettlementModule_Integration_Test {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using FillableOrderHashLib for Order;

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
        Order order;
        OrderWithSig orderWithSig;
    }

    /*//////////////////////////////////////////////////////////////
                               TEST DATA
    //////////////////////////////////////////////////////////////*/

    /// @dev Creates test data for tests
    function createTestData(
        uint256 partnerFeeInBps,
        address srcToken,
        address destToken,
        uint256 nonce
    )
        internal
        returns (TestData memory data)
    {
        data.srcAmount = 100 ether;
        data.destAmount = 99 ether;
        data.partnerFee = partnerFeeInBps;

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
            partnerAndFee: (uint256(uint160(address(users.bob.account))) << 96) | data.partnerFee,
            nonce: nonce,
            permit: ""
        });

        data.orderWithSig = signOrder(data.order);
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_directSettleFillable_WithFees() public {
        TestData memory data = createTestData(100, address(MTK), address(DAI), 1); // 1% partner fee
        uint256 expectedPartnerFee = (data.destAmount * data.partnerFee) / 10_000;

        vm.expectEmit(true, true, true, true);
        emit OrderSettled(
            data.order.owner,
            data.order.beneficiary,
            data.order.srcToken,
            data.order.destToken,
            data.order.srcAmount,
            data.order.destAmount,
            data.destAmount - expectedPartnerFee,
            0,
            expectedPartnerFee,
            _hashTypedDataV4(data.order.hash())
        );

        vm.prank(users.charlie.account);
        IFillableDirectSettlementModule(address(adapter)).directSettleFillable(
            data.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, data.destAmount
        );

        uint256 collectedFees = IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        assertEq(collectedFees, expectedPartnerFee, "Collected fees should match expected partner fee");
    }

    function test_directSettleFillableBatch_WithFees() public {
        uint256[] memory partnerFeePercentages = new uint256[](3);
        partnerFeePercentages[0] = 100; // 1%
        partnerFeePercentages[1] = 200; // 2%
        partnerFeePercentages[2] = 50; // 0.5%

        address[] memory destTokens = new address[](3);
        destTokens[0] = address(DAI);
        destTokens[1] = address(WETH);
        destTokens[2] = ERC20UtilsLib.ETH_ADDRESS;

        OrderWithSig[] memory ordersWithSigs = new OrderWithSig[](3);
        uint256[] memory fillPercents = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        uint256[] memory expectedPartnerFees = new uint256[](3);

        for (uint256 i = 0; i < 3; i++) {
            TestData memory data = createTestData(partnerFeePercentages[i], address(MTK), destTokens[i], i + 1);
            ordersWithSigs[i] = data.orderWithSig;
            fillPercents[i] = FillableStorageLib.HUNDRED_PERCENT;
            amounts[i] = data.destAmount;
            expectedPartnerFees[i] = (data.destAmount * data.partnerFee) / 10_000;
        }

        uint256 totalEthValue = amounts[2]; // For the ETH order

        vm.prank(users.charlie.account);
        IFillableDirectSettlementModule(address(adapter)).directSettleFillableBatch{ value: totalEthValue }(
            ordersWithSigs, fillPercents, amounts
        );

        for (uint256 i = 0; i < 3; i++) {
            uint256 collectedFees =
                IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, destTokens[i]);
            assertEq(
                collectedFees,
                expectedPartnerFees[i],
                string(abi.encodePacked("Collected fees for order ", i, " should match expected partner fee"))
            );
        }
    }

    function test_withdrawSpecificAmount() public {
        TestData memory data = createTestData(100, address(MTK), address(DAI), 1); // 1% partner fee
        uint256 expectedPartnerFee = (data.destAmount * data.partnerFee) / 10_000;

        vm.prank(users.charlie.account);
        IFillableDirectSettlementModule(address(adapter)).directSettleFillable(
            data.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, data.destAmount
        );

        uint256 withdrawAmount = expectedPartnerFee / 2;

        vm.startPrank(users.bob.account);
        vm.expectEmit(true, true, false, true);
        emit FeesWithdrawn(users.bob.account, address(DAI), withdrawAmount, users.bob.account);
        IFeeClaimerModule(address(adapter)).withdrawFees(address(DAI), withdrawAmount, users.bob.account);

        uint256 remainingFees = IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        assertEq(
            remainingFees,
            expectedPartnerFee - withdrawAmount,
            "Remaining fees should be correct after partial withdrawal"
        );
    }

    function test_withdrawAllFees() public {
        TestData memory data = createTestData(100, address(MTK), address(DAI), 1); // 1% partner fee
        uint256 expectedPartnerFee = (data.destAmount * data.partnerFee) / 10_000;

        vm.prank(users.charlie.account);
        IFillableDirectSettlementModule(address(adapter)).directSettleFillable(
            data.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, data.destAmount
        );

        vm.startPrank(users.bob.account);
        vm.expectEmit(true, true, false, true);
        emit FeesWithdrawn(users.bob.account, address(DAI), expectedPartnerFee, users.bob.account);
        uint256 withdrawnAmount = IFeeClaimerModule(address(adapter)).withdrawAllFees(address(DAI), users.bob.account);

        assertEq(withdrawnAmount, expectedPartnerFee, "Withdrawn amount should match collected fees");
        assertEq(DAI.balanceOf(users.bob.account), expectedPartnerFee, "Partner should receive all collected fees");
        assertEq(
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI)),
            0,
            "Collected fees should be zero after withdrawal"
        );
    }

    function test_batchWithdrawAllFees() public {
        TestData memory data1 = createTestData(100, address(MTK), address(DAI), 1); // 1% partner fee
        TestData memory data2 = createTestData(200, address(DAI), address(WETH), 2); // 2% partner fee

        vm.startPrank(users.charlie.account);
        IFillableDirectSettlementModule(address(adapter)).directSettleFillable(
            data1.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, data1.destAmount
        );
        IFillableDirectSettlementModule(address(adapter)).directSettleFillable(
            data2.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, data2.destAmount
        );
        vm.stopPrank();

        uint256 expectedFee1 = (data1.destAmount * data1.partnerFee) / 10_000;
        uint256 expectedFee2 = (data2.destAmount * data2.partnerFee) / 10_000;

        address[] memory tokens = new address[](2);
        tokens[0] = address(DAI);
        tokens[1] = address(WETH);

        vm.startPrank(users.bob.account);
        vm.expectEmit(true, true, false, true);
        emit FeesWithdrawn(users.bob.account, address(DAI), expectedFee1, users.bob.account);
        vm.expectEmit(true, true, false, true);
        emit FeesWithdrawn(users.bob.account, address(WETH), expectedFee2, users.bob.account);
        IFeeClaimerModule(address(adapter)).batchWithdrawAllFees(tokens, users.bob.account);

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
        TestData memory data1 = createTestData(100, address(MTK), address(DAI), 1); // 1% partner fee
        TestData memory data2 = createTestData(200, address(MTK), address(DAI), 2); // 2% partner fee
        TestData memory data3 = createTestData(0, address(MTK), address(DAI), 3); // 0% partner fee

        vm.startPrank(users.charlie.account);
        IFillableDirectSettlementModule(address(adapter)).directSettleFillable(
            data1.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, data1.destAmount
        );
        IFillableDirectSettlementModule(address(adapter)).directSettleFillable(
            data2.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, data2.destAmount
        );
        IFillableDirectSettlementModule(address(adapter)).directSettleFillable(
            data3.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, data3.destAmount
        );
        vm.stopPrank();

        uint256 expectedFee1 = (data1.destAmount * data1.partnerFee) / 10_000;
        uint256 expectedFee2 = (data2.destAmount * data2.partnerFee) / 10_000;
        uint256 expectedFee3 = 0;

        uint256 totalCollectedFees =
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        assertEq(
            totalCollectedFees,
            expectedFee1 + expectedFee2 + expectedFee3,
            "Total collected partner fees should be correct"
        );
    }

    function test_settleOrdersWithDifferentTokens() public {
        TestData memory dataDAI = createTestData(100, address(MTK), address(DAI), 1); // 1% partner fee
        TestData memory dataWETH = createTestData(100, address(MTK), address(WETH), 2); // 1% partner fee
        TestData memory dataETH = createTestData(100, address(MTK), ERC20UtilsLib.ETH_ADDRESS, 3); // 1% partner fee

        vm.startPrank(users.charlie.account);
        IFillableDirectSettlementModule(address(adapter)).directSettleFillable(
            dataDAI.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, dataDAI.destAmount
        );
        IFillableDirectSettlementModule(address(adapter)).directSettleFillable(
            dataWETH.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, dataWETH.destAmount
        );
        IFillableDirectSettlementModule(address(adapter)).directSettleFillable{ value: dataETH.destAmount }(
            dataETH.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, dataETH.destAmount
        );
        vm.stopPrank();

        uint256 expectedFee = (dataDAI.destAmount * dataDAI.partnerFee) / 10_000;

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
        TestData memory data = createTestData(100, address(MTK), address(DAI), 1); // 1% partner fee
        uint256 expectedPartnerFee = (data.destAmount * data.partnerFee) / 10_000;

        vm.prank(users.charlie.account);
        IFillableDirectSettlementModule(address(adapter)).directSettleFillable(
            data.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, data.destAmount
        );

        vm.expectRevert();
        vm.prank(users.bob.account);
        IFeeClaimerModule(address(adapter)).withdrawFees(address(DAI), expectedPartnerFee + 1, users.bob.account);
    }

    function test_queryCollectedFees() public {
        TestData memory data1 = createTestData(100, address(MTK), address(DAI), 1); // 1% partner fee
        TestData memory data2 = createTestData(200, address(DAI), address(MTK), 2); // 2% partner fee

        vm.startPrank(users.charlie.account);
        IFillableDirectSettlementModule(address(adapter)).directSettleFillable(
            data1.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, data1.destAmount
        );
        IFillableDirectSettlementModule(address(adapter)).directSettleFillable(
            data2.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, data2.destAmount
        );
        vm.stopPrank();

        uint256 expectedFee1 = (data1.destAmount * data1.partnerFee) / 10_000;
        uint256 expectedFee2 = (data2.destAmount * data2.partnerFee) / 10_000;

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

    function test_directSettleFillable_WithZeroFees() public {
        TestData memory data = createTestData(0, address(MTK), address(DAI), 1); // 0% partner fee

        vm.prank(users.charlie.account);
        IFillableDirectSettlementModule(address(adapter)).directSettleFillable(
            data.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, data.destAmount
        );

        uint256 collectedFees = IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        assertEq(collectedFees, 0, "Collected partner fees should be zero for 0% fee");
    }

    function test_directSettleFillable_PartialFillWithFees() public {
        TestData memory data = createTestData(100, address(MTK), address(DAI), 1); // 1% partner fee
        uint256 fillPercent = 5000; // 50%
        uint256 expectedFillAmount = data.destAmount * fillPercent / FillableStorageLib.HUNDRED_PERCENT;
        uint256 expectedPartnerFee = (expectedFillAmount * data.partnerFee) / 10_000;

        vm.prank(users.charlie.account);
        IFillableDirectSettlementModule(address(adapter)).directSettleFillable(
            data.orderWithSig, fillPercent, expectedFillAmount
        );

        uint256 collectedFees = IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        assertEq(collectedFees, expectedPartnerFee, "Collected fees should match expected partner fee for partial fill");
    }

    function test_directSettleFillable_WithSurplus() public {
        TestData memory data = createTestData(100, address(MTK), address(DAI), 1); // 1% partner fee
        data.order.expectedDestAmount = data.order.destAmount * 110 / 100; // Set expected amount 10% higher
        data.orderWithSig = signOrder(data.order);

        uint256 actualAmount = data.order.expectedDestAmount * 105 / 100; // Actual amount 5% higher than
            // expectedDestAmount
        uint256 surplus = actualAmount - data.order.expectedDestAmount;
        uint256 expectedProtocolFee = surplus / 2;
        uint256 expectedPartnerFee = (actualAmount - expectedProtocolFee) * data.partnerFee / 10_000;

        vm.expectEmit(true, true, true, true);
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
        IFillableDirectSettlementModule(address(adapter)).directSettleFillable(
            data.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, actualAmount
        );

        uint256 collectedPartnerFees =
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        assertEq(collectedPartnerFees, expectedPartnerFee, "Collected partner fees should match expected");
    }

    function test_directSettleFillable_WithoutSurplus() public {
        TestData memory data = createTestData(100, address(MTK), address(DAI), 1); // 1% partner fee
        data.order.expectedDestAmount = data.order.destAmount * 110 / 100; // Set expected amount 10% higher
        data.orderWithSig = signOrder(data.order);

        uint256 actualAmount = data.order.expectedDestAmount; // Actual amount equal to expectedDestAmount (no surplus)
        uint256 expectedPartnerFee = actualAmount * data.partnerFee / 10_000;

        vm.expectEmit(true, true, true, true);
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
        IFillableDirectSettlementModule(address(adapter)).directSettleFillable(
            data.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, actualAmount
        );

        uint256 collectedPartnerFees =
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        assertEq(collectedPartnerFees, expectedPartnerFee, "Collected partner fees should match expected");
    }

    function test_directSettleFillableBatch_WithMixedSurplus() public {
        uint256[] memory partnerFeePercentages = new uint256[](3);
        partnerFeePercentages[0] = 100; // 1%
        partnerFeePercentages[1] = 200; // 2%
        partnerFeePercentages[2] = 150; // 1.5%

        address[] memory destTokens = new address[](3);
        destTokens[0] = address(DAI);
        destTokens[1] = address(DAI);
        destTokens[2] = address(DAI);

        OrderWithSig[] memory ordersWithSigs = new OrderWithSig[](3);
        uint256[] memory fillPercents = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);

        for (uint256 i = 0; i < 3; i++) {
            TestData memory data = createTestData(partnerFeePercentages[i], address(MTK), destTokens[i], i + 1);
            data.order.expectedDestAmount = data.order.destAmount * 110 / 100; // Set expected amount 10% higher
            ordersWithSigs[i] = signOrder(data.order);
            fillPercents[i] = FillableStorageLib.HUNDRED_PERCENT;
        }

        // Set different scenarios for each order
        amounts[0] = ordersWithSigs[0].order.expectedDestAmount * 105 / 100; // 5% surplus
        amounts[1] = ordersWithSigs[1].order.expectedDestAmount; // No surplus
        amounts[2] = ordersWithSigs[2].order.expectedDestAmount * 115 / 100; // 15% surplus

        vm.prank(users.charlie.account);
        IFillableDirectSettlementModule(address(adapter)).directSettleFillableBatch(
            ordersWithSigs, fillPercents, amounts
        );

        uint256 totalCollectedFees =
            IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));

        uint256 expectedTotalFees = 0;
        for (uint256 i = 0; i < 3; i++) {
            uint256 surplus = amounts[i] > ordersWithSigs[i].order.expectedDestAmount
                ? amounts[i] - ordersWithSigs[i].order.expectedDestAmount
                : 0;
            uint256 protocolFee = surplus / 2;
            uint256 partnerFee = (amounts[i] - protocolFee) * partnerFeePercentages[i] / 10_000;
            expectedTotalFees += partnerFee;
        }

        assertEq(totalCollectedFees, expectedTotalFees, "Total collected fees should match expected fees");
    }

    function test_directSettleFillable_PartialFillWithSurplus() public {
        TestData memory data = createTestData(100, address(MTK), address(DAI), 1); // 1% partner fee
        data.order.expectedDestAmount = data.order.destAmount * 110 / 100; // Set expected amount 10% higher
        data.orderWithSig = signOrder(data.order);

        uint256 fillPercent = 5000; // 50%
        uint256 expectedFillAmount = data.order.expectedDestAmount * fillPercent / FillableStorageLib.HUNDRED_PERCENT;
        uint256 actualAmount = expectedFillAmount * 105 / 100; // 5% surplus on the filled amount

        uint256 surplus = actualAmount - expectedFillAmount;
        uint256 expectedProtocolFee = surplus / 2;
        uint256 expectedPartnerFee = (actualAmount - expectedProtocolFee) * data.partnerFee / 10_000;

        vm.prank(users.charlie.account);
        IFillableDirectSettlementModule(address(adapter)).directSettleFillable(
            data.orderWithSig, fillPercent, actualAmount
        );

        uint256 collectedFees = IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        assertEq(
            collectedFees,
            expectedPartnerFee,
            "Collected fees should match expected partner fee for partial fill with surplus"
        );
    }

    /*//////////////////////////////////////////////////////////////
                               INVARIANT
    //////////////////////////////////////////////////////////////*/

    function invariant_totalFeesNeverExceedActualAmount() public {
        TestData memory data = createTestData(200, address(MTK), address(DAI), 1); // 2% partner fee
        data.order.expectedDestAmount = data.order.destAmount * 120 / 100; // Set expected amount 20% higher
        data.orderWithSig = signOrder(data.order);

        uint256 actualAmount = data.order.expectedDestAmount * 110 / 100; // 10% higher than expected, but still lower
            // than original expected

        vm.prank(users.charlie.account);
        IFillableDirectSettlementModule(address(adapter)).directSettleFillable(
            data.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, actualAmount
        );

        uint256 partnerFees = IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        uint256 protocolFees = IFeeClaimerModule(address(adapter)).getCollectedFees(address(0), address(DAI));

        assert(partnerFees + protocolFees <= actualAmount);
    }

    function invariant_partnerFeesNeverExceedSpecifiedPercentage() public {
        TestData memory data = createTestData(200, address(MTK), address(DAI), 1); // 2% partner fee
        data.orderWithSig = signOrder(data.order);

        vm.prank(users.charlie.account);
        IFillableDirectSettlementModule(address(adapter)).directSettleFillable(
            data.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, data.destAmount
        );

        uint256 partnerFees = IFeeClaimerModule(address(adapter)).getCollectedFees(users.bob.account, address(DAI));
        uint256 maxAllowedFees = (data.destAmount * 200) / 10_000; // 2% of destAmount

        assert(partnerFees <= maxAllowedFees);
    }

    function invariant_protocolFeesOnlyCollectedWithSurplus() public {
        TestData memory data = createTestData(100, address(MTK), address(DAI), 1); // 1% partner fee
        data.order.expectedDestAmount = data.order.destAmount;
        data.orderWithSig = signOrder(data.order);

        vm.prank(users.charlie.account);
        IFillableDirectSettlementModule(address(adapter)).directSettleFillable(
            data.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, data.destAmount
        );

        uint256 protocolFees = IFeeClaimerModule(address(adapter)).getCollectedFees(address(0), address(DAI));

        assert(protocolFees == 0);
    }

    function invariant_filledAmountNeverExceedsOrderAmount() public {
        TestData memory data = createTestData(100, address(MTK), address(DAI), 1);
        data.orderWithSig = signOrder(data.order);

        vm.prank(users.charlie.account);
        IFillableDirectSettlementModule(address(adapter)).directSettleFillable(
            data.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, data.destAmount
        );

        uint256 filledAmount = IFillableDirectSettlementModule(address(adapter)).directFilledAmount(data.order);

        assert(filledAmount <= data.order.srcAmount);
    }

    function invariant_surplusIsDistributedCorrectly() public {
        TestData memory data = createTestData(100, address(MTK), address(DAI), 1); // 1% partner fee
        data.order.expectedDestAmount = data.order.destAmount * 110 / 100; // Set expected amount 10% higher
        data.orderWithSig = signOrder(data.order);

        uint256 actualAmount = data.order.expectedDestAmount * 105 / 100; // 5% surplus

        vm.prank(users.charlie.account);
        IFillableDirectSettlementModule(address(adapter)).directSettleFillable(
            data.orderWithSig, FillableStorageLib.HUNDRED_PERCENT, actualAmount
        );

        uint256 surplus = actualAmount - data.order.expectedDestAmount;
        uint256 expectedProtocolFee = surplus / 2;
        uint256 expectedPartnerFee = (actualAmount - expectedProtocolFee) * data.partnerFee / 10_000;

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
