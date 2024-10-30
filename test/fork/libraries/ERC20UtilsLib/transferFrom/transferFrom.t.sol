// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Interfaces
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { IAllowanceTransfer } from "@test/utils/interfaces/IAllowanceTransfer.sol";

// Libraries
import { ERC20UtilsLib } from "@modules/libraries/ERC20UtilsLib.sol";

// Test
import { ERC20UtilsLib_Fork_Test } from "../ERC20UtilsLib.t.sol";
import { UserData } from "test/utils/Types.sol";

contract ERC20UtilsLib_transferFrom is ERC20UtilsLib_Fork_Test(18_562_017, "mainnet") {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using ERC20UtilsLib for address;

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

    /// @dev Execute transferFrom with Permit2 (permit length 192)
    function test_transferFrom_Permit2Length192() public {
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

        // Approve Permit2 User -> Permit2 for DAI
        DAI_MAINNET.approve(ERC20UtilsLib.PERMIT2_ADDRESS, type(uint256).max);

        // Permit2 Approve Permit2 User -> Recipient for DAI
        IAllowanceTransfer(ERC20UtilsLib.PERMIT2_ADDRESS).approve(
            address(DAI_MAINNET), address(this), 250e18, uint48(type(uint48).max)
        );

        // Prank to this
        vm.startPrank(address(this));

        // Execute transferFrom
        uint256 transferAmount = 250e18;
        uint256 recipientBalanceBefore = DAI_MAINNET.balanceOf(address(recipient));

        address(DAI_MAINNET).transferFrom(permit2user, address(recipient), transferAmount, 192);

        uint256 recipientBalanceAfter = DAI_MAINNET.balanceOf(address(recipient));

        // Verify transfer
        assertEq(recipientBalanceAfter - recipientBalanceBefore, transferAmount, "Transfer amount incorrect");
    }

    /// @dev Execute transferFrom with Permit2 (permit length 1)
    function test_transferFrom_Permit2Length1() public {
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

        // Approve Permit2 User -> Permit2 for DAI
        DAI_MAINNET.approve(ERC20UtilsLib.PERMIT2_ADDRESS, type(uint256).max);

        // Permit2 Approve Permit2 User -> Recipient for DAI
        IAllowanceTransfer(ERC20UtilsLib.PERMIT2_ADDRESS).approve(
            address(DAI_MAINNET), address(this), 250e18, uint48(type(uint48).max)
        );

        // Prank to this
        vm.startPrank(address(this));

        // Execute transferFrom
        uint256 transferAmount = 250e18;
        uint256 recipientBalanceBefore = DAI_MAINNET.balanceOf(address(recipient));

        address(DAI_MAINNET).transferFrom(permit2user, address(recipient), transferAmount, 1);

        uint256 recipientBalanceAfter = DAI_MAINNET.balanceOf(address(recipient));

        // Verify transfer
        assertEq(recipientBalanceAfter - recipientBalanceBefore, transferAmount, "Transfer amount incorrect");
    }

    /// @dev Execute transferFrom with ERC20 fallback
    function test_transferFrom_ERC20Fallback() public {
        // Create User Account
        address user = address(0x1234);

        // Prank to Whale and transfer DAI to User
        vm.startPrank(whale);
        DAI_MAINNET.transfer(user, 1000e18);
        vm.stopPrank();

        // Prank to User
        vm.startPrank(user);

        // Approve this contract for DAI
        DAI_MAINNET.approve(address(this), 1000e18);

        // Execute transferFrom
        uint256 transferAmount = 250e18;
        uint256 recipientBalanceBefore = DAI_MAINNET.balanceOf(address(recipient));

        address(DAI_MAINNET).transferFrom(user, address(recipient), transferAmount, 0);

        uint256 recipientBalanceAfter = DAI_MAINNET.balanceOf(address(recipient));

        // Verify transfer
        assertEq(recipientBalanceAfter - recipientBalanceBefore, transferAmount, "Transfer amount incorrect");
    }

    /// @dev Execute transferFrom with permit length 96 (no transfer)
    function test_transferFrom_PermitLength96_NoTransfer() public {
        // Create User Account
        address user = address(0x1234);

        // Prank to Whale and transfer DAI to User
        vm.startPrank(whale);
        DAI_MAINNET.transfer(user, 1000e18);
        vm.stopPrank();

        // Execute transferFrom
        uint256 transferAmount = 250e18;
        uint256 recipientBalanceBefore = DAI_MAINNET.balanceOf(address(recipient));
        uint256 userBalanceBefore = DAI_MAINNET.balanceOf(user);

        address(DAI_MAINNET).transferFrom(user, address(recipient), transferAmount, 96);

        uint256 recipientBalanceAfter = DAI_MAINNET.balanceOf(address(recipient));
        uint256 userBalanceAfter = DAI_MAINNET.balanceOf(user);

        // Verify no transfer occurred
        assertEq(recipientBalanceAfter, recipientBalanceBefore, "Recipient balance should not change");
        assertEq(userBalanceAfter, userBalanceBefore, "User balance should not change");
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function callTransferFromWithPermitLength(
        address token,
        address from,
        address to,
        uint256 amount,
        uint256 permitLength
    )
        public
    {
        token.transferFrom(from, to, amount, permitLength);
    }
}
