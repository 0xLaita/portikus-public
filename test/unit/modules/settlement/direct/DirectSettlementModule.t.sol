// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { PortikusV2 } from "src/PortikusV2.sol";

// Interfaces
import { IEIP712 } from "@interfaces/util/IEIP712.sol";

// Libraries
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// Mocks
import { MockDirectSettlementModule } from "@mocks/modules/MockDirectSettlementModule.sol";

// Test
import { Base_Test } from "@test/Base.t.sol";

abstract contract DirectSettlementModule_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////
                                VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev MockDirectSettlementModule contract
    MockDirectSettlementModule public module;

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
        // Deploy module
        module = new MockDirectSettlementModule("Direct Settlement Module", "1.0.0", address(portikusV2));

        // Prank to admin
        vm.startPrank(users.admin.account);
        // Send ETH, MTK, DAI to the agent (charlie)
        payable(users.charlie.account).transfer(100 ether);
        MTK.transfer(users.charlie.account, 100 ether);
        DAI.transfer(users.charlie.account, 100 ether);

        // Register charlie as an authorized agent
        address[] memory agents = new address[](1);
        agents[0] = users.charlie.account;
        portikusV2.registerAgent(agents);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                  UTIL
    //////////////////////////////////////////////////////////////*/

    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(IEIP712(address(module)).DOMAIN_SEPARATOR(), structHash);
    }
}
