// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Interfaces
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { ERC20LegacyPermit } from "@mocks/erc20/ERC20LegacyPermit.sol";
import { IEIP712 } from "@interfaces/util/IEIP712.sol";
import { ISignatureTransfer } from "test/utils/interfaces/ISignatureTransfer.sol";
import { IAllowanceTransfer } from "test/utils/interfaces/IAllowanceTransfer.sol";

// Libraries
import { ERC20UtilsLib } from "@modules/libraries/ERC20UtilsLib.sol";

// Test
import { ERC20UtilsLib_Fork_Test } from "../ERC20UtilsLib.t.sol";
import { UserData } from "test/utils/Types.sol";

// Util
import { PermitSignature } from "test/utils/PermitSignature.sol";

contract ERC20UtilsLib_permit is ERC20UtilsLib_Fork_Test(18_562_017, "mainnet"), PermitSignature {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using ERC20UtilsLib for address;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error PermitFailed();

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address internal constant whale = 0x075e72a5eDf65F0A5f44699c7654C1a76941Ddc8;
    address internal constant MCD_PSM_MTK = 0x89B78CfA322F6C5dE0aBcEecab66Aee45393cC5A;
    IERC20 internal constant DAI_MAINNET = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        // Setup Base Test
        super.setUp();
        // Label Contracts
        vm.label({ account: whale, newLabel: "Whale" });
        vm.label({ account: address(ERC20UtilsLib.PERMIT2_ADDRESS), newLabel: "Permit2" });
        vm.label({ account: address(DAI_MAINNET), newLabel: "DAI" });
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Execute permit2TransferFrom
    function test_permit2TransferFrom() public {
        // Create Permit2 User Account
        uint256 fromPrivateKey = 0x12345543211234554321;
        address permit2user = vm.addr(fromPrivateKey);
        vm.label({ account: address(permit2user), newLabel: "Permit2 Fan" });

        // Prank to Whale
        vm.startPrank(whale);

        // Transfer DAI to Permit2 User
        DAI_MAINNET.transfer(permit2user, 464_970_191_372_510_874_460_745);

        // Prank to Permit2 User
        vm.startPrank(permit2user);

        // Approve Permit2 User -> Permit2 for DAI
        DAI_MAINNET.approve(ERC20UtilsLib.PERMIT2_ADDRESS, type(uint256).max);

        // Construct permitTransferFromData
        uint256 nonce = 10;
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({
                token: address(DAI_MAINNET),
                amount: 464_970_191_372_510_874_460_745
            }),
            nonce: nonce,
            deadline: block.timestamp + 100
        });

        // Get Permit2 Signature
        bytes memory sig = getCompactPermitTransferSignature(
            permit, fromPrivateKey, IEIP712(ERC20UtilsLib.PERMIT2_ADDRESS).DOMAIN_SEPARATOR(), address(this)
        );
        assertEq(sig.length, 64);

        // Set owner
        address owner = permit2user;

        // Encode Permit2 calldata:
        // We only need to pack nonce and sig
        bytes memory permit2 = abi.encodePacked(nonce, sig);

        // Check DAI balance of recipient before
        uint256 recipientBalanceBefore = DAI_MAINNET.balanceOf(address(recipient));

        // Check DAI balance of Permit2 User before
        uint256 permit2UserBalanceBefore = DAI_MAINNET.balanceOf(permit2user);

        // Execute Permit2TransferFrom
        this.callPermitWithCalldata(
            address(DAI_MAINNET), permit2, owner, block.timestamp + 100, 464_970_191_372_510_874_460_745
        );

        // Check DAI balance of recipient after
        uint256 recipientBalanceAfter = DAI_MAINNET.balanceOf(address(recipient));

        // Check DAI balance of Permit2 User after
        uint256 permit2UserBalanceAfter = DAI_MAINNET.balanceOf(permit2user);

        // Assert balance of recipient increased
        assertEq(recipientBalanceAfter - recipientBalanceBefore, 464_970_191_372_510_874_460_745);

        // Assert balance of Permit2 User decreased
        assertEq(permit2UserBalanceBefore - permit2UserBalanceAfter, 464_970_191_372_510_874_460_745);
    }

    /// @dev Execute permit2 allowance setting
    function test_permit2Allowance() public {
        // Create Permit2 User Account
        uint256 fromPrivateKey = 0x12345543211234554321;
        address permit2user = vm.addr(fromPrivateKey);
        vm.label({ account: address(permit2user), newLabel: "Permit2 Fan" });

        // Prank to Whale and transfer DAI to Permit2 User
        vm.startPrank(whale);
        DAI_MAINNET.transfer(permit2user, 1000e18);
        vm.stopPrank();

        // Prank to Permit2 User
        vm.startPrank(permit2user);

        // Construct permitSingle data
        uint48 nonce = 0;
        uint48 expiration = uint48(block.timestamp + 1 hours);
        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(DAI_MAINNET),
                amount: 500e18,
                expiration: expiration,
                nonce: nonce
            }),
            spender: address(this),
            sigDeadline: expiration
        });

        // Get Permit2 Signature
        bytes memory sig = getCompactPermitSignature(
            permitSingle, fromPrivateKey, IEIP712(ERC20UtilsLib.PERMIT2_ADDRESS).DOMAIN_SEPARATOR()
        );
        assertEq(sig.length, 64);

        // Encode Permit2 calldata
        bytes memory permit2Data = abi.encode(
            permitSingle.details.amount,
            permitSingle.details.expiration,
            permitSingle.details.nonce,
            permitSingle.sigDeadline
        );
        permit2Data = abi.encodePacked(permit2Data, sig);

        // Execute Permit2 Allowance
        this.callPermitWithCalldata(address(DAI_MAINNET), permit2Data, permit2user, expiration, 0);

        // Verify allowance is set correctly
        (uint160 amount, uint48 allowanceExpiration, uint48 allowanceNonce) = IAllowanceTransfer(
            ERC20UtilsLib.PERMIT2_ADDRESS
        ).allowance(permit2user, address(DAI_MAINNET), address(this));
        assertEq(amount, 500e18, "Allowance amount not set correctly");
        assertEq(allowanceExpiration, expiration, "Allowance expiration not set correctly");
        assertEq(allowanceNonce, nonce + 1, "Allowance nonce not set correctly");
    }

    /// @dev Execute fillable permit2 allowance setting
    function test_permit2Allowance_Fillable() public {
        // Create Permit2 User Account
        uint256 fromPrivateKey = 0x12345543211234554321;
        address permit2user = vm.addr(fromPrivateKey);
        vm.label({ account: address(permit2user), newLabel: "Permit2 Fan" });

        // Prank to Whale and transfer DAI to Permit2 User
        vm.startPrank(whale);
        DAI_MAINNET.transfer(permit2user, 1000e18);
        vm.stopPrank();

        // Prank to Permit2 User
        vm.startPrank(permit2user);

        // Construct permitSingle data
        uint48 nonce = 0;
        uint48 expiration = uint48(block.timestamp + 1 hours);
        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(DAI_MAINNET),
                amount: 500e18,
                expiration: expiration,
                nonce: nonce
            }),
            spender: address(this),
            sigDeadline: expiration
        });

        // Get Permit2 Signature
        bytes memory sig = getCompactPermitSignature(
            permitSingle, fromPrivateKey, IEIP712(ERC20UtilsLib.PERMIT2_ADDRESS).DOMAIN_SEPARATOR()
        );
        assertEq(sig.length, 64);

        // Encode Permit2 calldata
        bytes memory permit2Data = abi.encode(
            permitSingle.details.amount,
            permitSingle.details.expiration,
            permitSingle.details.nonce,
            permitSingle.sigDeadline
        );
        permit2Data = abi.encodePacked(permit2Data, sig);

        // Execute Permit2 Allowance
        this.callFillablePermitWithCalldata(address(DAI_MAINNET), permit2Data, permit2user);

        // Verify allowance is set correctly
        (uint160 amount, uint48 allowanceExpiration, uint48 allowanceNonce) = IAllowanceTransfer(
            ERC20UtilsLib.PERMIT2_ADDRESS
        ).allowance(permit2user, address(DAI_MAINNET), address(this));
        assertEq(amount, 500e18, "Allowance amount not set correctly");
        assertEq(allowanceExpiration, expiration, "Allowance expiration not set correctly");
        assertEq(allowanceNonce, nonce + 1, "Allowance nonce not set correctly");
    }

    function test_permit2Allowance_Fillable_RevertsWhen_InvalidSignature() public {
        // Create Permit2 User Account
        uint256 fromPrivateKey = 0x12345543211234554321;
        address permit2user = vm.addr(fromPrivateKey);
        vm.label({ account: address(permit2user), newLabel: "Permit2 Fan" });

        // Prank to Whale and transfer DAI to Permit2 User
        vm.startPrank(whale);
        DAI_MAINNET.transfer(permit2user, 1000e18);
        vm.stopPrank();

        // Prank to Permit2 User
        vm.startPrank(permit2user);

        // Construct permitSingle data
        uint48 nonce = 0;
        uint48 expiration = uint48(block.timestamp + 1 hours);
        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(DAI_MAINNET),
                amount: 500e18,
                expiration: expiration,
                nonce: nonce
            }),
            spender: address(this),
            sigDeadline: expiration
        });

        // Get Permit2 Signature
        bytes memory sig = getCompactPermitSignature(
            permitSingle, fromPrivateKey, IEIP712(ERC20UtilsLib.PERMIT2_ADDRESS).DOMAIN_SEPARATOR()
        );
        assertEq(sig.length, 64);

        // Encode Permit2 calldata
        bytes memory permit2Data = abi.encode(
            permitSingle.details.amount,
            permitSingle.details.expiration,
            permitSingle.details.nonce + 1, // Invalid nonce
            permitSingle.sigDeadline
        );
        permit2Data = abi.encodePacked(permit2Data, sig);

        // Expect revert
        vm.expectRevert();

        // Execute Permit2 Allowance
        this.callFillablePermitWithCalldata(address(DAI_MAINNET), permit2Data, permit2user);
    }

    /// @dev Execute permit2TransferFrom
    function test_permit2TransferFrom_RevertsWhen_InvalidSignature() public {
        // Create Permit2 User Account
        uint256 fromPrivateKey = 0x12345543211234554321;
        address permit2user = vm.addr(fromPrivateKey);
        vm.label({ account: address(permit2user), newLabel: "Permit2 Fan" });

        // Prank to Whale
        vm.startPrank(whale);

        // Transfer DAI to Permit2 User
        DAI_MAINNET.transfer(permit2user, 464_970_191_372_510_874_460_745);

        // Prank to Permit2 User
        vm.startPrank(permit2user);

        // Approve Permit2 User -> Permit2 for DAI
        DAI_MAINNET.approve(ERC20UtilsLib.PERMIT2_ADDRESS, type(uint256).max);

        // Construct permitTransferFromData
        uint256 nonce = 10;
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({
                token: address(DAI_MAINNET),
                amount: 464_970_191_372_510_874_460_745
            }),
            nonce: nonce,
            deadline: block.timestamp + 100
        });

        // Get Permit2 Signature
        bytes memory sig = getCompactPermitTransferSignature(
            permit, fromPrivateKey, IEIP712(ERC20UtilsLib.PERMIT2_ADDRESS).DOMAIN_SEPARATOR(), address(this)
        );
        assertEq(sig.length, 64);

        // Set owner
        address owner = permit2user;

        // Encode Permit2 calldata:
        // We only need to pack nonce and sig
        bytes memory permit2 = abi.encodePacked(nonce + 1, sig); // Invalid nonce

        // Expect revert
        vm.expectRevert();

        // Execute Permit2TransferFrom
        this.callPermitWithCalldata(
            address(DAI_MAINNET), permit2, owner, block.timestamp + 100, 464_970_191_372_510_874_460_745
        );
    }

    /// @dev Execute permit2 allowance setting
    function test_permit2Allowance_RevertsWhen_InvalidSignature() public {
        // Create Permit2 User Account
        uint256 fromPrivateKey = 0x12345543211234554321;
        address permit2user = vm.addr(fromPrivateKey);
        vm.label({ account: address(permit2user), newLabel: "Permit2 Fan" });

        // Prank to Whale and transfer DAI to Permit2 User
        vm.startPrank(whale);
        DAI_MAINNET.transfer(permit2user, 1000e18);
        vm.stopPrank();

        // Prank to Permit2 User
        vm.startPrank(permit2user);

        // Construct permitSingle data
        uint48 nonce = 0;
        uint48 expiration = uint48(block.timestamp + 1 hours);
        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(DAI_MAINNET),
                amount: 500e18,
                expiration: expiration,
                nonce: nonce
            }),
            spender: address(this),
            sigDeadline: expiration
        });

        // Get Permit2 Signature
        bytes memory sig = getCompactPermitSignature(
            permitSingle, fromPrivateKey, IEIP712(ERC20UtilsLib.PERMIT2_ADDRESS).DOMAIN_SEPARATOR()
        );
        assertEq(sig.length, 64);

        // Encode Permit2 calldata
        bytes memory permit2Data = abi.encode(
            permitSingle.details.amount,
            permitSingle.details.expiration,
            permitSingle.details.nonce + 1, // Invalid nonce
            permitSingle.sigDeadline
        );
        permit2Data = abi.encodePacked(permit2Data, sig);

        // Expect revert
        vm.expectRevert();

        // Execute Permit2 Allowance
        this.callPermitWithCalldata(address(DAI_MAINNET), permit2Data, permit2user, expiration, 0);
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function callPermitWithCalldata(
        address token,
        bytes calldata permitData,
        address owner,
        uint256 deadline,
        uint256 amount
    )
        public
    {
        token.permit(permitData, owner, deadline, amount, recipient);
    }

    function callFillablePermitWithCalldata(address token, bytes calldata permitData, address owner) public {
        token.permit(permitData, owner);
    }
}
