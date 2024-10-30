// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { PortikusV2 } from "src/PortikusV2.sol";

// Mocks
import { MockSettlementModule } from "@mocks/modules/MockSettlementModule.sol";

// Test
import { Base_Test } from "@test/Base.t.sol";

abstract contract BaseSettlementModule_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////
                                VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev MockModule contract
    MockSettlementModule public mockModule;

    /// @dev PortikusV2 contract
    PortikusV2 public portikusV2;

    /*//////////////////////////////////////////////////////////////
                                  SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        // Setup Base Test
        super.setUp();
        // Deploy PortikusV2
        portikusV2 = new PortikusV2(users.admin.account);
        // Deploy MockModule
        mockModule = new MockSettlementModule("Mock Module", "1.0.0", address(portikusV2));
    }
}
