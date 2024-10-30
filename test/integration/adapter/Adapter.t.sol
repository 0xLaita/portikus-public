// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { Adapter } from "@adapter/Adapter.sol";
import { PortikusV2 } from "src/PortikusV2.sol";

// Interfaces
import { IModule } from "@modules/interfaces/IModule.sol";
import { IEIP712 } from "@interfaces/util/IEIP712.sol";
import { IExecutor } from "@executors/interfaces/IExecutor.sol";

// Libraries
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// Mocks
import { MockDex } from "@mocks/dex/MockDex.sol";

// Tests
import { Base_Test } from "@test/Base.t.sol";
import { StdInvariant } from "@forge-std/StdInvariant.sol";

abstract contract Adapter_Integration_Test is Base_Test, StdInvariant {
    /*//////////////////////////////////////////////////////////////
                                VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev Adapter contract
    Adapter public adapter;
    /// @dev PortikusV2 contract
    PortikusV2 public portikusV2;
    /// @dev Module contract
    IModule[] public module;
    /// @dev Executor contract
    IExecutor public executor;
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
        // Deploy Adapter using PortikusV2 factory
        adapter = Adapter(payable(portikusV2.create(bytes32(""), users.admin.account)));
        // Deploy MockDex
        dex = new MockDex();
        // Prank to admin
        vm.startPrank(users.admin.account);
        // Send ETH, MTK, DAI to DEX
        payable(address(dex)).transfer(100 ether);
        MTK.transfer(address(dex), 100 ether);
        DAI.transfer(address(dex), 100 ether);
        WETH.transfer(address(dex), 100 ether);
        // Exclude PortikusV2 contract
        excludeContract(address(portikusV2));
    }

    /*//////////////////////////////////////////////////////////////
                                  UTIL
    //////////////////////////////////////////////////////////////*/

    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(IEIP712(address(adapter)).DOMAIN_SEPARATOR(), structHash);
    }
}
