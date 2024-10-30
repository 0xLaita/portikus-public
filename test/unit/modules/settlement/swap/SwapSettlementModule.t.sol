// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { PortikusV2 } from "src/PortikusV2.sol";
import { ThreeStepExecutor } from "@executors/example/ThreeStepExecutor.sol";

// Interfaces
import { IEIP712 } from "@interfaces/util/IEIP712.sol";

// Libraries
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// Mocks
import { MockDex } from "@mocks/dex/MockDex.sol";
import { MockSwapSettlementModule } from "@mocks/modules/MockSwapSettlementModule.sol";

// Test
import { Base_Test } from "@test/Base.t.sol";

abstract contract SwapSettlementModule_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////
                                VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev MockSwapSettlementModule contract
    MockSwapSettlementModule public module;

    /// @dev PortikusV2 contract
    PortikusV2 public portikusV2;

    /// @dev ThreeStepExecutor contract
    ThreeStepExecutor public executor;

    /// @dev Mock dex contract
    MockDex public dex;

    /*//////////////////////////////////////////////////////////////
                                  SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        // Setup Base Test
        super.setUp();
        // Deploy PortikusV2
        portikusV2 = new PortikusV2(users.admin.account);
        // Deploy module
        module = new MockSwapSettlementModule("Swap Settlement Module", "1.0.0", address(portikusV2));
        // Deploy executor
        executor = new ThreeStepExecutor();
        // Deploy mock dex
        dex = new MockDex();
        // Prank to admin
        vm.startPrank(users.admin.account);
        // Send ETH, MTK, DAI to DEX
        payable(address(dex)).transfer(100 ether);
        MTK.transfer(address(dex), 100 ether);
        DAI.transfer(address(dex), 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                                  UTIL
    //////////////////////////////////////////////////////////////*/

    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(IEIP712(address(module)).DOMAIN_SEPARATOR(), structHash);
    }
}
