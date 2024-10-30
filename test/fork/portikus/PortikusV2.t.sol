// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { PortikusV2 } from "src/PortikusV2.sol";
import { AugustusExecutor } from "@executors/example/AugustusExecutor.sol";
import { SwapSettlementModule } from "@modules/settlement/SwapSettlementModule.sol";
import { Adapter } from "@adapter/Adapter.sol";

// Libraries
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// Interfaces
import { IExecutor } from "@executors/interfaces/IExecutor.sol";
import { IEIP712 } from "@interfaces/util/IEIP712.sol";

// Tests
import { Fork_Test } from "../Fork.t.sol";

abstract contract PortikusV2_Fork_Test is Fork_Test {
    /*//////////////////////////////////////////////////////////////
                                VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev PortikusV2 contract
    PortikusV2 public portikusV2;
    /// @dev Example augustus executor
    IExecutor public augustusExecutor;
    /// @dev AugustusV6.2 address
    address public augustusV6;
    /// @dev Adapter contract
    Adapter public adapter;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        uint256 _forkBlockNumber,
        string memory _forkUrlOrAlias,
        address _augustusV6
    )
        Fork_Test(_forkBlockNumber, _forkUrlOrAlias)
    {
        // Set AugustusV6 address
        augustusV6 = _augustusV6;
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier preAuthorizedAgent(address _agent) {
        // Prank to admin
        vm.prank(users.admin.account);
        // Set executor as authorized
        address[] memory agents = new address[](1);
        agents[0] = _agent;
        portikusV2.registerAgent(agents);
        // Run the test
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                  SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        // Setup Base Test
        super.setUp();
        // Deploy PortikusV2
        portikusV2 = new PortikusV2(users.admin.account);
        // Prank to admin
        vm.startPrank(users.admin.account);
        // Deploy SwapSettlementModule
        SwapSettlementModule module = new SwapSettlementModule("Swap Settlement Module", "1.0.0", address(portikusV2));

        // Register SwapSettlementModule in PortikusV2 registry
        address[] memory modules = new address[](1);
        modules[0] = address(module);
        portikusV2.registerModule(modules);

        // Deploy Adapter using PortikusV2 factory
        adapter = Adapter(payable(portikusV2.create(bytes32(""), users.admin.account)));
        // Install module in Adapter
        adapter.install(address(module));
        // Deploy AugustusExecutor
        augustusExecutor = IExecutor(new AugustusExecutor((augustusV6)));

        // Label contracts
        vm.label({ account: address(portikusV2), newLabel: "PortikusV2" });
        vm.label({ account: address(augustusExecutor), newLabel: "AugustusExecutor" });
        vm.label({ account: augustusV6, newLabel: "AugustusV6" });
        vm.label({ account: address(adapter), newLabel: "ParaswapDelta" });
        // Stop prank
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                  UTIL
    //////////////////////////////////////////////////////////////*/

    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(IEIP712(address(adapter)).DOMAIN_SEPARATOR(), structHash);
    }
}
