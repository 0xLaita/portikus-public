// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Libraries
import { ERC20UtilsLib } from "@modules/libraries/ERC20UtilsLib.sol";

// Interfaces
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

// Mock
import { ERC20LegacyPermit } from "@mocks/erc20/ERC20LegacyPermit.sol";

// Test
import { ERC20UtilsLib_Test } from "../ERC20UtilsLib.t.sol";
import { UserData } from "test/utils/Types.sol";

// Util
import { PermitSignature } from "test/utils/PermitSignature.sol";

contract ERC20UtilsLib_permit is ERC20UtilsLib_Test, PermitSignature {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using ERC20UtilsLib for address;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error PermitFailed();

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_permit_RevertsWhen_WrongLength() public {
        vm.startPrank(users.eve.account);

        vm.expectRevert(PermitFailed.selector);

        bytes memory invalidPermitData =
            abi.encode("123123", "123123", "123123", "123123", "123123", "123123", "123123");

        this.callPermitWithCalldata(invalidPermitData);
    }

    function test_permit() public {
        vm.startPrank(users.alice.account);

        bytes memory validPermitData =
            createValidPermit(IERC20Permit(address(MTK)), users.alice, users.bob.account, 1000, block.timestamp + 300);

        this.callPermitWithCalldata(validPermitData);
    }

    function test_permit_ZeroLength() public {
        vm.startPrank(users.alice.account);

        bytes memory zeroLength = "";

        this.callPermitWithCalldata(zeroLength);
    }

    function test_permitLegacy() public {
        vm.startPrank(users.alice.account);

        bytes memory validPermitData =
            createValidLegacyPermit(DAI, users.alice, users.bob.account, block.timestamp + 300);

        this.callLegacyPermitWithCalldata(validPermitData);
    }

    function test_permitLegacy_Fillable() public {
        vm.startPrank(users.alice.account);

        bytes memory validPermitData =
            createValidLegacyPermit(DAI, users.alice, users.bob.account, block.timestamp + 300);

        this.callFillablePermitWithCalldata(address(DAI), validPermitData, users.alice.account);
    }

    function test_permit_Fillable_ZeroLength() public {
        vm.startPrank(users.alice.account);

        bytes memory zeroLength = "";

        this.callFillablePermitWithCalldata(address(MTK), zeroLength, users.alice.account);
    }

    function test_permit_Fillable() public {
        vm.startPrank(users.alice.account);

        bytes memory validPermitData =
            createValidPermit(IERC20Permit(address(MTK)), users.alice, users.bob.account, 1000, block.timestamp + 300);

        this.callFillablePermitWithCalldata(address(MTK), validPermitData, users.alice.account);
    }

    function test_permit_Fillable_RevertsWhen_WrongLength() public {
        vm.startPrank(users.eve.account);

        vm.expectRevert(PermitFailed.selector);

        bytes memory invalidPermitData =
            abi.encode("123123", "123123", "123123", "123123", "123123", "123123", "123123");

        this.callFillablePermitWithCalldata(address(MTK), invalidPermitData, users.eve.account);
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function callPermitWithCalldata(bytes calldata permitData) public {
        address(MTK).permit(permitData, address(0), 0, 0, address(0));
    }

    function callLegacyPermitWithCalldata(bytes calldata permitData) public {
        address(DAI).permit(permitData, address(0), 0, 0, address(0));
    }

    function callFillablePermitWithCalldata(address token, bytes calldata permitData, address owner) public {
        token.permit(permitData, owner);
    }
}
