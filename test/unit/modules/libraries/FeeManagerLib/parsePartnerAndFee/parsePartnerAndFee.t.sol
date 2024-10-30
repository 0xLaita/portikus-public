// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Libraries
import { FeeManagerLib } from "@modules/libraries/FeeManagerLib.sol";

// Test
import { FeeManagerLib_Test } from "../FeeManagerLib.t.sol";

contract FeeManagerLib_parsePartnerAndFee is FeeManagerLib_Test {
    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_parsePartnerAndFee_ValidInput() public {
        address expectedPartner = address(0x1234567890123456789012345678901234567890);
        uint256 expectedFee = 100; // 1%
        bool expectedPartnerTakesSurplus = false;
        uint256 partnerAndFee = uint256(uint160(expectedPartner)) << 96 | expectedFee;

        (address partner, uint256 fee, bool partnerTakesSurplus) = FeeManagerLib.parsePartnerAndFee(partnerAndFee);

        assertEq(partner, expectedPartner, "Partner address should be correctly extracted");
        assertEq(fee, expectedFee, "Fee should be correctly extracted");
        assertEq(
            partnerTakesSurplus, expectedPartnerTakesSurplus, "Partner takes surplus flag should be correctly extracted"
        );
    }

    function test_parsePartnerAndFee_ZeroAddress() public {
        address expectedPartner = address(0);
        uint256 expectedFee = 50; // 0.5%
        bool expectedPartnerTakesSurplus = false;
        uint256 partnerAndFee = uint256(uint160(expectedPartner)) << 96 | expectedFee;

        (address partner, uint256 fee, bool partnerTakesSurplus) = FeeManagerLib.parsePartnerAndFee(partnerAndFee);

        assertEq(partner, expectedPartner, "Zero address should be correctly extracted");
        assertEq(fee, expectedFee, "Fee should be correctly extracted");
        assertEq(
            partnerTakesSurplus, expectedPartnerTakesSurplus, "Partner takes surplus flag should be correctly extracted"
        );
    }

    function test_parsePartnerAndFee_MaxFee() public {
        address expectedPartner = address(0x9876543210987654321098765432109876543210);
        uint256 expectedFee = 200; // 2% (max fee)
        bool expectedPartnerTakesSurplus = false;
        uint256 partnerAndFee = uint256(uint160(expectedPartner)) << 96 | expectedFee;

        (address partner, uint256 fee, bool partnerTakesSurplus) = FeeManagerLib.parsePartnerAndFee(partnerAndFee);

        assertEq(partner, expectedPartner, "Partner address should be correctly extracted");
        assertEq(fee, expectedFee, "Max fee should be correctly extracted");
        assertEq(
            partnerTakesSurplus, expectedPartnerTakesSurplus, "Partner takes surplus flag should be correctly extracted"
        );
    }

    function test_parsePartnerAndFee_FeeLargerThanMax() public {
        address expectedPartner = address(0xabCDeF0123456789AbcdEf0123456789aBCDEF01);
        uint256 inputFee = 0xFE; // 254 (2.54%)
        uint256 expectedFee = 200; // Should be capped at 2%
        bool expectedPartnerTakesSurplus = false;
        uint256 partnerAndFee = uint256(uint160(expectedPartner)) << 96 | inputFee;

        (address partner, uint256 fee, bool partnerTakesSurplus) = FeeManagerLib.parsePartnerAndFee(partnerAndFee);

        assertEq(partner, expectedPartner, "Partner address should be correctly extracted");
        assertEq(fee, expectedFee, "Fee should be capped at max value");
        assertEq(
            partnerTakesSurplus, expectedPartnerTakesSurplus, "Partner takes surplus flag should be correctly extracted"
        );
    }

    function test_parsePartnerAndFee_PartnerTakesSurplus() public {
        address expectedPartner = address(0xabCDeF0123456789AbcdEf0123456789aBCDEF01);
        uint256 expectedFee = 100; // 1%
        bool expectedPartnerTakesSurplus = true;
        uint256 partnerAndFee = uint256(uint160(expectedPartner)) << 96 | (1 << 8) | expectedFee;

        (address partner, uint256 fee, bool partnerTakesSurplus) = FeeManagerLib.parsePartnerAndFee(partnerAndFee);

        assertEq(partner, expectedPartner, "Partner address should be correctly extracted");
        assertEq(fee, expectedFee, "Fee should be correctly extracted");
        assertEq(
            partnerTakesSurplus, expectedPartnerTakesSurplus, "Partner takes surplus flag should be correctly extracted"
        );
    }

    function testFuzz_parsePartnerAndFee(
        address expectedPartner,
        uint256 inputFee,
        bool expectedPartnerTakesSurplus
    )
        public
    {
        inputFee = bound(inputFee, 0, FeeManagerLib.FEE_IN_BASIS_POINTS_MASK); // Cap input fee
        uint256 expectedFee = inputFee > 200 ? 200 : inputFee; // Cap fee at 2%
        uint256 partnerAndFee =
            uint256(uint160(expectedPartner)) << 96 | (expectedPartnerTakesSurplus ? 1 << 8 : 0) | inputFee;

        (address partner, uint256 fee, bool partnerTakesSurplus) = FeeManagerLib.parsePartnerAndFee(partnerAndFee);

        assertEq(partner, expectedPartner, "Partner address should be correctly extracted");
        assertEq(fee, expectedFee, "Fee should be correctly extracted and capped if necessary");
        assertEq(
            partnerTakesSurplus, expectedPartnerTakesSurplus, "Partner takes surplus flag should be correctly extracted"
        );
    }
}
