// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Libraries
import { FeeManagerLib } from "@modules/libraries/FeeManagerLib.sol";
import { ERC20UtilsLib } from "@modules/libraries/ERC20UtilsLib.sol";

// Test
import { FeeManagerLib_Test } from "../FeeManagerLib.t.sol";

contract FeeManagerLib_processFees is FeeManagerLib_Test {
    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_processFees_NoSurplusWithPartner() public {
        uint256 partnerAndFee = (uint256(uint160(address(users.alice.account))) << 96) | 100; // 1% fee
        address token = address(MTK);
        uint256 receivedAmount = 1000 ether;
        uint256 expectedAmount = 1000 ether;

        (uint256 returnAmount, uint256 partnerFee, uint256 protocolFee) =
            FeeManagerLib.processFees(partnerAndFee, token, receivedAmount, expectedAmount);

        assertEq(returnAmount, 990 ether, "Return amount should be 99% of received amount");
        assertEq(partnerFee, 10 ether, "Partner fee should be 1% of received amount");
        assertEq(protocolFee, 0, "Protocol fee should be 0 when there's no surplus");
        assertEq(
            FeeManagerLib.getCollectedFees(token, users.alice.account),
            10 ether,
            "Collected fees for partner should be correct"
        );
    }

    function test_processFees_SurplusWithPartner_FixedFee() public {
        uint256 partnerAndFee = (uint256(uint160(address(users.alice.account))) << 96) | 100; // 1% fee
        address token = address(MTK);
        uint256 receivedAmount = 1100 ether;
        uint256 expectedAmount = 1000 ether;

        (uint256 returnAmount, uint256 partnerFee, uint256 protocolFee) =
            FeeManagerLib.processFees(partnerAndFee, token, receivedAmount, expectedAmount);

        assertEq(returnAmount, 1039.5 ether, "Return amount should be correct after fees");
        assertEq(partnerFee, 10.5 ether, "Partner fee should be 1% of amount after protocol fee");
        assertEq(protocolFee, 50 ether, "Protocol fee should be 50% of surplus");
        assertEq(
            FeeManagerLib.getCollectedFees(token, users.alice.account),
            10.5 ether,
            "Collected fees for partner should be correct"
        );
        assertEq(
            FeeManagerLib.getCollectedFees(token, address(0)), 50 ether, "Collected fees for protocol should be correct"
        );
    }

    function test_processFees_SurplusWithPartner_TakesSurplus() public {
        uint256 partnerAndFee = (uint256(uint160(address(users.alice.account))) << 96) | (1 << 8); // Partner takes
            // surplus, no fixed fee
        address token = address(MTK);
        uint256 receivedAmount = 1100 ether;
        uint256 expectedAmount = 1000 ether;

        (uint256 returnAmount, uint256 partnerFee, uint256 protocolFee) =
            FeeManagerLib.processFees(partnerAndFee, token, receivedAmount, expectedAmount);

        assertEq(returnAmount, 1000 ether, "Return amount should be equal to expected amount");
        assertEq(partnerFee, 50 ether, "Partner fee should be 50% of surplus");
        assertEq(protocolFee, 50 ether, "Protocol fee should be 50% of surplus");
        assertEq(
            FeeManagerLib.getCollectedFees(token, users.alice.account),
            50 ether,
            "Collected fees for partner should be correct"
        );
        assertEq(
            FeeManagerLib.getCollectedFees(token, address(0)), 50 ether, "Collected fees for protocol should be correct"
        );
    }

    function test_processFees_NoPartner() public {
        uint256 partnerAndFee = 0; // No partner, 0% fee
        address token = address(MTK);
        uint256 receivedAmount = 1000 ether;
        uint256 expectedAmount = 1000 ether;

        (uint256 returnAmount, uint256 partnerFee, uint256 protocolFee) =
            FeeManagerLib.processFees(partnerAndFee, token, receivedAmount, expectedAmount);

        assertEq(returnAmount, 1000 ether, "Return amount should be equal to received amount");
        assertEq(partnerFee, 0, "Partner fee should be 0 when there's no partner");
        assertEq(protocolFee, 0, "Protocol fee should be 0 when there's no surplus");
    }

    function test_processFees_SurplusNoPartner() public {
        uint256 partnerAndFee = 0; // No partner, 0% fee
        address token = address(MTK);
        uint256 receivedAmount = 1100 ether;
        uint256 expectedAmount = 1000 ether;

        (uint256 returnAmount, uint256 partnerFee, uint256 protocolFee) =
            FeeManagerLib.processFees(partnerAndFee, token, receivedAmount, expectedAmount);

        assertEq(returnAmount, 1050 ether, "Return amount should be received amount minus protocol fee");
        assertEq(partnerFee, 0, "Partner fee should be 0 when there's no partner");
        assertEq(protocolFee, 50 ether, "Protocol fee should be 50% of surplus");
        assertEq(
            FeeManagerLib.getCollectedFees(token, address(0)), 50 ether, "Collected fees for protocol should be correct"
        );
    }

    function test_processFees_ExactAmount() public {
        uint256 partnerAndFee = (uint256(uint160(address(users.alice.account))) << 96) | 100; // 1% fee
        address token = address(MTK);
        uint256 receivedAmount = 1000 ether;
        uint256 expectedAmount = 1000 ether;

        (uint256 returnAmount, uint256 partnerFee, uint256 protocolFee) =
            FeeManagerLib.processFees(partnerAndFee, token, receivedAmount, expectedAmount);

        assertEq(returnAmount, 990 ether, "Return amount should be 99% of received amount");
        assertEq(partnerFee, 10 ether, "Partner fee should be 1% of received amount");
        assertEq(protocolFee, 0, "Protocol fee should be 0 when there's no surplus");
    }

    function test_processFees_SmallAmounts() public {
        uint256 partnerAndFee = (uint256(uint160(address(users.alice.account))) << 96) | 100; // 1% fee
        address token = address(MTK);
        uint256 receivedAmount = 100;
        uint256 expectedAmount = 90;

        (uint256 returnAmount, uint256 partnerFee, uint256 protocolFee) =
            FeeManagerLib.processFees(partnerAndFee, token, receivedAmount, expectedAmount);

        assertEq(returnAmount, 95, "Return amount should be correct for small amounts");
        assertEq(partnerFee, 0, "Partner fee should be correct for small amounts");
        assertEq(protocolFee, 5, "Protocol fee should be correct for small amounts");
    }

    function test_processFees_SurplusWithPartner_FixedFeeOverridesSurplus() public {
        uint256 partnerAndFee = (uint256(uint160(address(users.alice.account))) << 96) | (1 << 8) | 100; // 1% fee +
            // takes surplus flag
        address token = address(MTK);
        uint256 receivedAmount = 1100 ether;
        uint256 expectedAmount = 1000 ether;

        (uint256 returnAmount, uint256 partnerFee, uint256 protocolFee) =
            FeeManagerLib.processFees(partnerAndFee, token, receivedAmount, expectedAmount);

        assertEq(returnAmount, 1039.5 ether, "Return amount should be correct after fees");
        assertEq(
            partnerFee,
            10.5 ether,
            "Partner fee should be 1% of amount after protocol fee, ignoring surplus-taking flag"
        );
        assertEq(protocolFee, 50 ether, "Protocol fee should be 50% of surplus");
        assertEq(
            FeeManagerLib.getCollectedFees(token, users.alice.account),
            10.5 ether,
            "Collected fees for partner should be correct"
        );
        assertEq(
            FeeManagerLib.getCollectedFees(token, address(0)), 50 ether, "Collected fees for protocol should be correct"
        );
    }

    function testFuzz_processFees(
        address partner,
        uint96 fee,
        bool partnerTakesSurplus,
        address token,
        uint256 receivedAmount,
        uint256 expectedAmount
    )
        public
    {
        fee = uint96(bound(fee, 0, 200));
        uint256 partnerAndFee = (uint256(uint160(partner)) << 96) | (partnerTakesSurplus ? 1 << 8 : 0) | fee;
        receivedAmount = bound(receivedAmount, 0, type(uint128).max);
        expectedAmount = bound(expectedAmount, 0, receivedAmount);

        (uint256 returnAmount, uint256 partnerFee, uint256 protocolFee) =
            FeeManagerLib.processFees(partnerAndFee, token, receivedAmount, expectedAmount);

        if (receivedAmount > expectedAmount) {
            uint256 surplus = receivedAmount - expectedAmount;
            uint256 expectedProtocolFee = (surplus * FeeManagerLib.FIFTY_PERCENT) / FeeManagerLib.HUNDRED_PERCENT;
            assertEq(protocolFee, expectedProtocolFee, "Protocol fee should be 50% of surplus");

            if (partner != address(0)) {
                if (fee > 0) {
                    uint256 expectedPartnerFee = ((receivedAmount - protocolFee) * fee) / FeeManagerLib.HUNDRED_PERCENT;
                    assertEq(
                        partnerFee,
                        expectedPartnerFee,
                        "Partner fee should be correct percentage of amount after protocol fee"
                    );
                } else if (partnerTakesSurplus) {
                    assertEq(partnerFee, surplus - expectedProtocolFee, "Partner fee should be 50% of surplus");
                } else {
                    assertEq(partnerFee, 0, "Partner fee should be 0 when there's no fee and not taking surplus");
                }
            } else {
                assertEq(partnerFee, 0, "Partner fee should be 0 when there's no partner");
            }
        } else {
            assertEq(protocolFee, 0, "Protocol fee should be 0 when there's no surplus");
            if (partner != address(0) && fee > 0) {
                uint256 expectedPartnerFee = (receivedAmount * fee) / FeeManagerLib.HUNDRED_PERCENT;
                assertEq(partnerFee, expectedPartnerFee, "Partner fee should be correct percentage of received amount");
            } else {
                assertEq(partnerFee, 0, "Partner fee should be 0 when there's no partner or fee");
            }
        }

        assertEq(
            returnAmount, receivedAmount - protocolFee - partnerFee, "Return amount should be correct after all fees"
        );
    }
}
