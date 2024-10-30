// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Interfaces
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { ISignatureTransfer } from "test/utils/interfaces/ISignatureTransfer.sol";
import { IEIP712 } from "@interfaces/util/IEIP712.sol";
import { ISwapSettlementModule } from "@modules/settlement/interfaces/ISwapSettlementModule.sol";

// Libraries
import { OrderHashLib } from "@modules/libraries/OrderHashLib.sol";
import { ERC20UtilsLib } from "@modules/libraries/ERC20UtilsLib.sol";
import { SafeTransferLib } from "@solady/utils/SafeTransferLib.sol";

// Tests
import { PortikusV2_Fork_Test } from "../PortikusV2.t.sol";

// Types
import { Order, OrderWithSig } from "@types/Order.sol";
import { UserData } from "test/utils/Types.sol";
import { ExecutorData } from "@executors/example/AugustusExecutor.sol";

// Util
import { EIP2098Lib } from "test/utils/EIP2098Lib.sol";
import { PermitSignature } from "test/utils/PermitSignature.sol";

contract PortikusV2_Adapter_SwapSettleModule_swapSettle_Fork_Test is
    PortikusV2_Fork_Test(20_175_059, "mainnet", 0x6A000F20005980200259B80c5102003040001068),
    PermitSignature
{
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using OrderHashLib for Order;
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error DeadlineExpired();
    error InsufficientReturnAmount();
    error InvalidNonce();

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    IERC20 internal USDC_MAINNET = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 internal USDT_MAINNET = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        // Setup Base Test
        super.setUp();
        // Label tokens
        vm.label(address(USDC_MAINNET), "USDC_MAINNET");
        vm.label(address(USDT_MAINNET), "USDT_MAINNET");
    }

    /*//////////////////////////////////////////////////////////////
                                SETTLE
    //////////////////////////////////////////////////////////////*/

    function test_swapSettle_augustusExecutor_preAuthorized() public preAuthorizedAgent(users.charlie.account) {
        // Prank to whale and transfer USDC to alice
        uint256 srcAmount = 1_750_000_000;
        uint256 feeAmount = 10;
        uint256 destAmount = 1_746_836_447;
        address whale = 0xb338B3177B1668eb4c921c5971853712Ae1F7219;
        vm.startPrank(whale);
        // Transfer USDC to alice
        USDC_MAINNET.transfer(users.alice.account, srcAmount);
        // Prank to alice and approve USDC to adapter
        vm.startPrank(users.alice.account);
        USDC_MAINNET.approve(address(adapter), srcAmount);

        // Arrange
        Order memory order = Order({
            owner: users.alice.account,
            beneficiary: users.alice.account,
            srcToken: address(USDC_MAINNET),
            destToken: address(USDT_MAINNET),
            srcAmount: srcAmount,
            destAmount: destAmount - feeAmount - 1,
            expectedDestAmount: destAmount - feeAmount - 1,
            deadline: block.timestamp + 100,
            nonce: 1,
            partnerAndFee: 0,
            permit: ""
        });
        // Arrange valid signature
        bytes32 hash = _hashTypedDataV4(order.hash());
        // privateKey = uint256(keccak256(abi.encodePacked(userName)));
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        // Sign hash
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        // Arrange order with signature
        OrderWithSig memory orderWithSig = OrderWithSig({ order: order, signature: sig });
        // Set executorData
        bytes memory executorCalldataData = bytes(
            hex"e3ead59e0000000000000000000000005f0000d4780a00d2dce0a00004000800cb0e5041000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec700000000000000000000000000000000000000000000000000000000684ee180000000000000000000000000000000000000000000000000000000006748f1d60000000000000000000000000000000000000000000000000000000068540661ebf344dae6954e74afd2ed0dd4d3fc540000000000000000000000000133d8d100000000000000000000000000000000000000000000000000000000000000004130d9c537bb5a6eb47e2f23fbc78f307cab95e118000000000000000000001400000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001e0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001e0a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000006000240000ff00000300000000000000000000000000000000000000000000000000000000a9059cbb000000000000000000000000944cd6142d2834be243c773e1da7d40a2e25d0ea00000000000000000000000000000000000000000000000000000000684ee180944cd6142d2834be243c773e1da7d40a2e25d0ea000001000024000020000003000000000000000000000000000000000000000000000000000000003eece7db0000000000000000000000006a000f20005980200259b80c510200304000106800000000000000000000000000000000000000000000000000000000684ee18000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006300000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000000"
        );
        ExecutorData memory executorData =
            ExecutorData(executorCalldataData, address(0), address(USDC_MAINNET), address(USDT_MAINNET), feeAmount);

        // Check balance of USDT before swapSettle
        uint256 balanceBefore = USDT_MAINNET.balanceOf(users.alice.account);

        // Prank to charlie (authorized agent)
        vm.startPrank(users.charlie.account);

        // Settle
        ISwapSettlementModule(address(adapter)).swapSettle(
            orderWithSig, abi.encode(executorData), address(augustusExecutor)
        );

        // Check balance of USDT after swapSettle
        uint256 balanceAfter = USDT_MAINNET.balanceOf(users.alice.account);

        // Assert user received destAmount of USDT
        assertEq(balanceAfter, balanceBefore + destAmount - feeAmount - 1);
    }

    function test_swapSettle_augustusExecutor_RevertsWhen_NonceAlreadyUsed_preAuthorized()
        public
        preAuthorizedAgent(users.charlie.account)
    {
        // Prank to whale and transfer USDC to alice
        uint256 srcAmount = 1_750_000_000;
        uint256 feeAmount = 10;
        uint256 destAmount = 1_746_836_447;
        address whale = 0xb338B3177B1668eb4c921c5971853712Ae1F7219;
        vm.startPrank(whale);
        // Transfer USDC to alice
        USDC_MAINNET.transfer(users.alice.account, srcAmount);
        // Prank to alice and approve USDC to adapter
        vm.startPrank(users.alice.account);
        USDC_MAINNET.approve(address(adapter), srcAmount);

        // Arrange
        Order memory order = Order({
            owner: users.alice.account,
            beneficiary: users.alice.account,
            srcToken: address(USDC_MAINNET),
            destToken: address(USDT_MAINNET),
            srcAmount: srcAmount,
            destAmount: destAmount - feeAmount - 1,
            expectedDestAmount: destAmount - feeAmount - 1,
            deadline: block.timestamp + 100,
            partnerAndFee: 0,
            nonce: 1,
            permit: ""
        });
        // Arrange valid signature
        bytes32 hash = _hashTypedDataV4(order.hash());
        // privateKey = uint256(keccak256(abi.encodePacked(userName)));
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        // Sign hash
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        // Arrange order with signature
        OrderWithSig memory orderWithSig = OrderWithSig({ order: order, signature: sig });
        // Set executorData
        bytes memory executorCalldataData = bytes(
            hex"e3ead59e0000000000000000000000005f0000d4780a00d2dce0a00004000800cb0e5041000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec700000000000000000000000000000000000000000000000000000000684ee180000000000000000000000000000000000000000000000000000000006748f1d60000000000000000000000000000000000000000000000000000000068540661ebf344dae6954e74afd2ed0dd4d3fc540000000000000000000000000133d8d100000000000000000000000000000000000000000000000000000000000000004130d9c537bb5a6eb47e2f23fbc78f307cab95e118000000000000000000001400000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001e0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001e0a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000006000240000ff00000300000000000000000000000000000000000000000000000000000000a9059cbb000000000000000000000000944cd6142d2834be243c773e1da7d40a2e25d0ea00000000000000000000000000000000000000000000000000000000684ee180944cd6142d2834be243c773e1da7d40a2e25d0ea000001000024000020000003000000000000000000000000000000000000000000000000000000003eece7db0000000000000000000000006a000f20005980200259b80c510200304000106800000000000000000000000000000000000000000000000000000000684ee18000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006300000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000000"
        );
        ExecutorData memory executorData =
            ExecutorData(executorCalldataData, address(0), address(USDC_MAINNET), address(USDT_MAINNET), feeAmount);

        // Check balance of USDT before swapSettle
        uint256 balanceBefore = USDT_MAINNET.balanceOf(users.alice.account);

        // Prank to charlie (authorized agent)
        vm.startPrank(users.charlie.account);

        // Settle
        ISwapSettlementModule(address(adapter)).swapSettle(
            orderWithSig, abi.encode(executorData), address(augustusExecutor)
        );

        // Check balance of USDT after swapSettle
        uint256 balanceAfter = USDT_MAINNET.balanceOf(users.alice.account);

        // Assert user received destAmount of USDT
        assertEq(balanceAfter, balanceBefore + destAmount - feeAmount - 1);

        vm.startPrank(0x944cd6142D2834bE243c773e1Da7d40A2e25D0eA);
        // Transfer USDC to alice
        USDC_MAINNET.transfer(users.alice.account, srcAmount);
        // Prank to alice and approve USDC to adapter
        vm.startPrank(users.alice.account);
        USDC_MAINNET.approve(address(adapter), srcAmount);

        // Check balance of USDT before swapSettle
        balanceBefore = USDT_MAINNET.balanceOf(users.alice.account);

        // Prank to charlie (authorized agent)
        vm.startPrank(users.charlie.account);

        // Expect revert when nonce is already used
        vm.expectRevert(InvalidNonce.selector);

        // Settle
        ISwapSettlementModule(address(adapter)).swapSettle(orderWithSig, abi.encode(executorData), address(augustusV6));
    }

    function test_swapSettle_augustusExecutor_WithPermit_preAuthorized()
        public
        preAuthorizedAgent(users.charlie.account)
    {
        // Prank to whale and transfer USDC to alice
        uint256 srcAmount = 1_750_000_000;
        uint256 feeAmount = 10;
        uint256 destAmount = 1_746_836_447;
        address whale = 0xb338B3177B1668eb4c921c5971853712Ae1F7219;
        vm.startPrank(whale);
        // Transfer USDC to alice
        USDC_MAINNET.transfer(users.alice.account, srcAmount);
        // Prepare permit data for USDC to approve adapter
        bytes memory permit = createValidPermit(
            IERC20Permit(address(USDC_MAINNET)), users.alice, address(adapter), type(uint256).max, block.timestamp + 100
        );

        // Arrange
        Order memory order = Order({
            owner: users.alice.account,
            beneficiary: users.alice.account,
            srcToken: address(USDC_MAINNET),
            destToken: address(USDT_MAINNET),
            srcAmount: srcAmount,
            destAmount: destAmount - feeAmount - 1,
            expectedDestAmount: destAmount - feeAmount - 1,
            deadline: block.timestamp + 100,
            partnerAndFee: 0,
            nonce: 1,
            permit: permit
        });
        // Arrange valid signature
        bytes32 hash = _hashTypedDataV4(order.hash());
        // privateKey = uint256(keccak256(abi.encodePacked(userName)));
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        // Sign hash
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        // Arrange order with signature
        OrderWithSig memory orderWithSig = OrderWithSig({ order: order, signature: sig });
        // Set executorData
        bytes memory executorCalldataData = bytes(
            hex"e3ead59e0000000000000000000000005f0000d4780a00d2dce0a00004000800cb0e5041000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec700000000000000000000000000000000000000000000000000000000684ee180000000000000000000000000000000000000000000000000000000006748f1d60000000000000000000000000000000000000000000000000000000068540661ebf344dae6954e74afd2ed0dd4d3fc540000000000000000000000000133d8d100000000000000000000000000000000000000000000000000000000000000004130d9c537bb5a6eb47e2f23fbc78f307cab95e118000000000000000000001400000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001e0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001e0a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000006000240000ff00000300000000000000000000000000000000000000000000000000000000a9059cbb000000000000000000000000944cd6142d2834be243c773e1da7d40a2e25d0ea00000000000000000000000000000000000000000000000000000000684ee180944cd6142d2834be243c773e1da7d40a2e25d0ea000001000024000020000003000000000000000000000000000000000000000000000000000000003eece7db0000000000000000000000006a000f20005980200259b80c510200304000106800000000000000000000000000000000000000000000000000000000684ee18000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006300000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000000"
        );
        ExecutorData memory executorData =
            ExecutorData(executorCalldataData, address(0), address(USDC_MAINNET), address(USDT_MAINNET), feeAmount);
        // Check balance of USDT before swapSettle
        uint256 balanceBefore = USDT_MAINNET.balanceOf(users.alice.account);

        // Prank to charlie (authorized agent)
        vm.startPrank(users.charlie.account);

        // Settle
        ISwapSettlementModule(address(adapter)).swapSettle(
            orderWithSig, abi.encode(executorData), address(augustusExecutor)
        );

        // Check balance of USDT after swapSettle
        uint256 balanceAfter = USDT_MAINNET.balanceOf(users.alice.account);

        // Assert user received destAmount of USDT
        assertEq(balanceAfter, balanceBefore + destAmount - feeAmount - 1);
    }

    function test_swapSettle_augustusExecutor_WithPermit2_preAuthorized()
        public
        preAuthorizedAgent(users.charlie.account)
    {
        // Prank to whale and transfer USDC to alice
        uint256 srcAmount = 1_750_000_000;
        uint256 feeAmount = 10;
        uint256 destAmount = 1_746_836_447;
        address whale = 0xb338B3177B1668eb4c921c5971853712Ae1F7219;
        vm.startPrank(whale);
        // Transfer USDC to alice
        USDC_MAINNET.transfer(users.alice.account, srcAmount);
        // Prank to alice
        vm.startPrank(users.alice.account);
        // Approve USDC for Permit2
        USDC_MAINNET.approve(ERC20UtilsLib.PERMIT2_ADDRESS, type(uint256).max);
        // Construct permitTransferFromData
        uint256 nonce = 10;
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({ token: address(USDC_MAINNET), amount: 1_750_000_000 }),
            nonce: nonce,
            deadline: block.timestamp + 100
        });

        // Get Permit2 Signature
        bytes memory permitSig = getCompactPermitTransferSignature(
            permit,
            uint256(keccak256(abi.encodePacked(users.alice.name))),
            IEIP712(ERC20UtilsLib.PERMIT2_ADDRESS).DOMAIN_SEPARATOR(),
            address(adapter)
        );

        // Encode Permit2 calldata:
        // We only need to pack nonce and sig
        bytes memory permit2 = abi.encodePacked(nonce, permitSig);

        // Arrange
        Order memory order = Order({
            owner: users.alice.account,
            beneficiary: users.alice.account,
            srcToken: address(USDC_MAINNET),
            destToken: address(USDT_MAINNET),
            srcAmount: srcAmount,
            destAmount: destAmount - feeAmount - 1,
            expectedDestAmount: destAmount - feeAmount - 1,
            deadline: block.timestamp + 100,
            partnerAndFee: 0,
            nonce: 1,
            permit: permit2
        });
        // Arrange valid signature
        bytes32 hash = _hashTypedDataV4(order.hash());
        // privateKey = uint256(keccak256(abi.encodePacked(userName)));
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        // Sign hash
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        // Arrange order with signature
        OrderWithSig memory orderWithSig = OrderWithSig({ order: order, signature: sig });
        // Set executorData
        bytes memory executorCalldataData = bytes(
            hex"e3ead59e0000000000000000000000005f0000d4780a00d2dce0a00004000800cb0e5041000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec700000000000000000000000000000000000000000000000000000000684ee180000000000000000000000000000000000000000000000000000000006748f1d60000000000000000000000000000000000000000000000000000000068540661ebf344dae6954e74afd2ed0dd4d3fc540000000000000000000000000133d8d100000000000000000000000000000000000000000000000000000000000000004130d9c537bb5a6eb47e2f23fbc78f307cab95e118000000000000000000001400000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001e0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001e0a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000006000240000ff00000300000000000000000000000000000000000000000000000000000000a9059cbb000000000000000000000000944cd6142d2834be243c773e1da7d40a2e25d0ea00000000000000000000000000000000000000000000000000000000684ee180944cd6142d2834be243c773e1da7d40a2e25d0ea000001000024000020000003000000000000000000000000000000000000000000000000000000003eece7db0000000000000000000000006a000f20005980200259b80c510200304000106800000000000000000000000000000000000000000000000000000000684ee18000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006300000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000000"
        );
        ExecutorData memory executorData =
            ExecutorData(executorCalldataData, address(0), address(USDC_MAINNET), address(USDT_MAINNET), feeAmount);

        // Check balance of USDT before swapSettle
        uint256 balanceBefore = USDT_MAINNET.balanceOf(users.alice.account);

        // Prank to charlie (authorized agent)
        vm.startPrank(users.charlie.account);

        // Settle
        ISwapSettlementModule(address(adapter)).swapSettle(
            orderWithSig, abi.encode(executorData), address(augustusExecutor)
        );

        // Check balance of USDT after swapSettle
        uint256 balanceAfter = USDT_MAINNET.balanceOf(users.alice.account);

        // Assert user received destAmount of USDT
        assertEq(balanceAfter, balanceBefore + 1_746_836_447 - 10 - 1);
    }

    function test_swapSettle_augustusExecutor_preAuthorized_RevertsWhen_DeadlineExpired()
        public
        preAuthorizedAgent(users.charlie.account)
    {
        // Prank to whale and transfer USDC to alice
        uint256 srcAmount = 1_750_000_000;
        uint256 feeAmount = 10;
        uint256 destAmount = 1_746_836_447;
        address whale = 0xb338B3177B1668eb4c921c5971853712Ae1F7219;
        vm.startPrank(whale);
        // Transfer USDC to alice
        USDC_MAINNET.transfer(users.alice.account, srcAmount);
        // Prank to alice and approve USDC to adapter
        vm.startPrank(users.alice.account);
        USDC_MAINNET.approve(address(adapter), srcAmount);

        // Arrange
        Order memory order = Order({
            owner: users.alice.account,
            beneficiary: users.alice.account,
            srcToken: address(USDC_MAINNET),
            destToken: address(USDT_MAINNET),
            srcAmount: srcAmount,
            destAmount: destAmount - feeAmount,
            expectedDestAmount: destAmount - feeAmount,
            deadline: block.timestamp - 100,
            partnerAndFee: 0,
            nonce: 1,
            permit: ""
        });
        // Arrange valid signature
        bytes32 hash = _hashTypedDataV4(order.hash());
        // privateKey = uint256(keccak256(abi.encodePacked(userName)));
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        // Sign hash
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        // Arrange order with signature
        OrderWithSig memory orderWithSig = OrderWithSig({ order: order, signature: sig });
        // Set executorData
        bytes memory executorCalldataData = bytes(
            hex"e3ead59e0000000000000000000000005f0000d4780a00d2dce0a00004000800cb0e5041000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec700000000000000000000000000000000000000000000000000000000684ee180000000000000000000000000000000000000000000000000000000006748f1d60000000000000000000000000000000000000000000000000000000068540661ebf344dae6954e74afd2ed0dd4d3fc540000000000000000000000000133d8d100000000000000000000000000000000000000000000000000000000000000004130d9c537bb5a6eb47e2f23fbc78f307cab95e118000000000000000000001400000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001e0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001e0a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000006000240000ff00000300000000000000000000000000000000000000000000000000000000a9059cbb000000000000000000000000944cd6142d2834be243c773e1da7d40a2e25d0ea00000000000000000000000000000000000000000000000000000000684ee180944cd6142d2834be243c773e1da7d40a2e25d0ea000001000024000020000003000000000000000000000000000000000000000000000000000000003eece7db0000000000000000000000006a000f20005980200259b80c510200304000106800000000000000000000000000000000000000000000000000000000684ee18000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006300000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000000"
        );
        ExecutorData memory executorData =
            ExecutorData(executorCalldataData, address(0), address(USDC_MAINNET), address(USDT_MAINNET), feeAmount);

        // Prank to charlie (authorized agent)
        vm.startPrank(users.charlie.account);

        // Expect DeadlineExpired revert
        vm.expectRevert(DeadlineExpired.selector);

        // Settle
        ISwapSettlementModule(address(adapter)).swapSettle(
            orderWithSig, abi.encode(executorData), address(augustusExecutor)
        );
    }

    function test_swapSettle_augustusExecutor_preAuthorized_RevertsWhen_InsufficientReturnAmount()
        public
        preAuthorizedAgent(users.charlie.account)
    {
        // Prank to whale and transfer USDC to alice
        uint256 srcAmount = 1_750_000_000;
        uint256 feeAmount = 836_447; // Make feeAmount huge to cause InsufficientReturnAmount
        uint256 destAmount = 1_746_836_447;
        address whale = 0xb338B3177B1668eb4c921c5971853712Ae1F7219;
        vm.startPrank(whale);
        // Transfer USDC to alice
        USDC_MAINNET.transfer(users.alice.account, srcAmount);
        // Prank to alice and approve USDC to adapter
        vm.startPrank(users.alice.account);
        USDC_MAINNET.approve(address(adapter), srcAmount);

        // Arrange
        Order memory order = Order({
            owner: users.alice.account,
            beneficiary: users.alice.account,
            srcToken: address(USDC_MAINNET),
            destToken: address(USDT_MAINNET),
            srcAmount: srcAmount,
            destAmount: destAmount,
            expectedDestAmount: destAmount,
            deadline: block.timestamp + 100,
            partnerAndFee: 0,
            nonce: 1,
            permit: ""
        });
        // Arrange valid signature
        bytes32 hash = _hashTypedDataV4(order.hash());
        // privateKey = uint256(keccak256(abi.encodePacked(userName)));
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        // Sign hash
        bytes memory sig = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        // Arrange order with signature
        OrderWithSig memory orderWithSig = OrderWithSig({ order: order, signature: sig });
        // Set executorData
        bytes memory executorCalldataData = bytes(
            hex"e3ead59e0000000000000000000000005f0000d4780a00d2dce0a00004000800cb0e5041000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec700000000000000000000000000000000000000000000000000000000684ee180000000000000000000000000000000000000000000000000000000006748f1d60000000000000000000000000000000000000000000000000000000068540661ebf344dae6954e74afd2ed0dd4d3fc540000000000000000000000000133d8d100000000000000000000000000000000000000000000000000000000000000004130d9c537bb5a6eb47e2f23fbc78f307cab95e118000000000000000000001400000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001e0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001e0a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000006000240000ff00000300000000000000000000000000000000000000000000000000000000a9059cbb000000000000000000000000944cd6142d2834be243c773e1da7d40a2e25d0ea00000000000000000000000000000000000000000000000000000000684ee180944cd6142d2834be243c773e1da7d40a2e25d0ea000001000024000020000003000000000000000000000000000000000000000000000000000000003eece7db0000000000000000000000006a000f20005980200259b80c510200304000106800000000000000000000000000000000000000000000000000000000684ee18000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006300000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000000"
        );
        ExecutorData memory executorData =
            ExecutorData(executorCalldataData, address(0), address(USDC_MAINNET), address(USDT_MAINNET), feeAmount);

        // Prank to charlie (authorized agent)
        vm.startPrank(users.charlie.account);

        // Expect InsufficientReturnAmount revert
        vm.expectRevert(InsufficientReturnAmount.selector);

        // Settle
        ISwapSettlementModule(address(adapter)).swapSettle(
            orderWithSig, abi.encode(executorData), address(augustusExecutor)
        );
    }
}
