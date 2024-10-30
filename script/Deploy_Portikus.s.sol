// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { PortikusV2 } from "src/PortikusV2.sol";
import { FeeClaimerModule } from "@modules/base/FeeClaimerModule.sol";
import { NonceManagementModule } from "@modules/base/NonceManagementModule.sol";
import { FillableDirectSettlementModule } from "@modules/settlement/FillableDirectSettlementModule.sol";
import { DirectSettlementModule } from "@modules/settlement/DirectSettlementModule.sol";
import { FillableSwapSettlementModule } from "@modules/settlement/FillableSwapSettlementModule.sol";
import { SwapSettlementModule } from "@modules/settlement/SwapSettlementModule.sol";
import { AugustusExecutor } from "@executors/example/AugustusExecutor.sol";
import { Adapter } from "@adapter/Adapter.sol";

// Std
import { Script } from "@forge-std/Script.sol";

/// @dev Deploys PortikusV2, Adapter for Paraswap Delta and AugustusExecutor
/// @notice This script is meant to be used for testing purposes only
contract Deploy is Script {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address private immutable AUGUSTUS_V6_ADDRESS = vm.envAddress("AUGUSTUS_V6_ADDRESS");
    address private immutable AGENT_ADDRESS = vm.envAddress("AGENT_ADDRESS");

    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 private deployerPrivateKey;
    address private deployer;
    PortikusV2 private portikusV2;
    FeeClaimerModule private feeClaimerModule;
    NonceManagementModule private nonceManagementModule;
    DirectSettlementModule private directSettlementModule;
    FillableDirectSettlementModule private fillableDirectSettlementModule;
    SwapSettlementModule private swapSettlementModule;
    FillableSwapSettlementModule private fillableSwapSettlementModule;
    Adapter private deltaAdapter;
    AugustusExecutor private augustusExecutor;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        // Set deployer private key
        deployerPrivateKey = uint256(vm.envBytes32("PK"));
        // Set deployer
        deployer = vm.addr(deployerPrivateKey);
        // Label deployer
        vm.label(deployer, "Deployer");
    }

    function run() public returns (address, address, address) {
        //-----------------------------------------------------------------------------------
        // Start broadcast
        //-----------------------------------------------------------------------------------

        vm.startBroadcast(deployerPrivateKey);

        //-----------------------------------------------------------------------------------
        // Deploy PortikusV1
        //-----------------------------------------------------------------------------------

        deployPortikus();

        //-----------------------------------------------------------------------------------
        // Deploy modules
        //-----------------------------------------------------------------------------------

        deployModules();

        //-----------------------------------------------------------------------------------
        // Register modules
        //-----------------------------------------------------------------------------------

        registerModules();

        //-----------------------------------------------------------------------------------
        // Create Delta adapter
        //-----------------------------------------------------------------------------------

        createDeltaAdapter();

        //-----------------------------------------------------------------------------------
        // Install modules
        //-----------------------------------------------------------------------------------

        installModules();

        //-----------------------------------------------------------------------------------
        // Register agent
        //-----------------------------------------------------------------------------------

        registerAgent();

        //-----------------------------------------------------------------------------------
        // Deploy Augustus Executor
        //-----------------------------------------------------------------------------------

        deployAugustusExecutor();

        //-----------------------------------------------------------------------------------

        // Stop broadcast
        vm.stopBroadcast();

        return (address(portikusV2), address(deltaAdapter), address(augustusExecutor));
    }

    function deployPortikus() private {
        // Deploy PortikusV2
        portikusV2 = new PortikusV2(deployer);
    }

    function deployModules() private {
        address portikusV2Address = address(portikusV2);
        // Deploy FeeClaimerModule
        feeClaimerModule = new FeeClaimerModule("FeeClaimerModule", "1.0.0", portikusV2Address);
        // Deploy NonceManagementModule
        nonceManagementModule = new NonceManagementModule("NonceManagementModule", "1.0.0", portikusV2Address);
        // Deploy DirectSettlementModule
        directSettlementModule = new DirectSettlementModule("DirectSettlementModule", "1.0.0", portikusV2Address);
        // Deploy FillableDirectSettlementModule
        fillableDirectSettlementModule =
            new FillableDirectSettlementModule("FillableDirectSettlementModule", "1.0.0", portikusV2Address);
        // Deploy SwapSettlementModule
        swapSettlementModule = new SwapSettlementModule("SwapSettlementModule", "1.0.0", portikusV2Address);
        // Deploy FillableSwapSettlementModule
        fillableSwapSettlementModule =
            new FillableSwapSettlementModule("FillableSwapSettlementModule", "1.0.0", portikusV2Address);
    }

    function registerModules() private {
        // Setup modules[]
        address[] memory modules = new address[](6);
        modules[0] = address(feeClaimerModule);
        modules[1] = address(nonceManagementModule);
        modules[2] = address(directSettlementModule);
        modules[3] = address(swapSettlementModule);
        modules[4] = address(fillableDirectSettlementModule);
        modules[5] = address(fillableSwapSettlementModule);
        // Register deployed modules in PortikusV2 registry
        portikusV2.registerModule(modules);
    }

    function createDeltaAdapter() private {
        // Create Delta Adapter
        deltaAdapter = Adapter(payable(portikusV2.create(bytes32(0), deployer)));
    }

    function installModules() private {
        // Install modules
        deltaAdapter.install(address(feeClaimerModule));
        deltaAdapter.install(address(nonceManagementModule));
        deltaAdapter.install(address(directSettlementModule));
        deltaAdapter.install(address(swapSettlementModule));
        deltaAdapter.install(address(fillableDirectSettlementModule));
        deltaAdapter.install(address(fillableSwapSettlementModule));
    }

    function deployAugustusExecutor() private {
        // Deploy AugustusExecutor
        augustusExecutor = new AugustusExecutor(AUGUSTUS_V6_ADDRESS);
    }

    function registerAgent() private {
        // Register agent
        address[] memory agents = new address[](1);
        agents[0] = AGENT_ADDRESS;
        portikusV2.registerAgent(agents);
    }
}
