// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { Adapter } from "@adapter/Adapter.sol";
import { PortikusV2 } from "src/PortikusV2.sol";

// Mocks
import { MockModule } from "@mocks/modules/MockModule.sol";

// Test
import { Base_Test } from "@test/Base.t.sol";

abstract contract Adapter_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev Adapter contract
    Adapter public adapter;
    /// @dev PortikusV2 contract
    PortikusV2 public portikusV2;
    /// @dev MockModule contract
    MockModule public mockModule;

    /*//////////////////////////////////////////////////////////////
                                  SETUPa
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        // Setup Base Test
        super.setUp();
        // Deploy PortikusV2
        portikusV2 = new PortikusV2(users.admin.account);
        // Deploy adapter
        // Prank to portikus because adapter expects to be called by a PortikusV2 contract
        vm.prank(address(portikusV2));
        adapter = new Adapter(users.admin.account);
        // Deploy MockModule
        mockModule = new MockModule("Mock Module", "1.0.0", address(portikusV2));
        // Register module
        vm.prank(users.admin.account);
        address[] memory modules = new address[](1);
        modules[0] = address(mockModule);
        portikusV2.registerModule(modules);
    }
}
