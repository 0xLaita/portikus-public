// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { SwapSettlementModule } from "@modules/settlement/SwapSettlementModule.sol";
import { DirectSettlementModule } from "@modules/settlement/DirectSettlementModule.sol";
import { FillableDirectSettlementModule } from "@modules/settlement/FillableDirectSettlementModule.sol";
import { FillableSwapSettlementModule } from "@modules/settlement/FillableSwapSettlementModule.sol";
import { NonceManagementModule } from "@modules/base/NonceManagementModule.sol";
import { FeeClaimerModule } from "@modules/base/FeeClaimerModule.sol";
import { ThreeStepExecutor } from "@executors/example/ThreeStepExecutor.sol";

// Interfaces
import { IModule } from "@modules/interfaces/IModule.sol";

// Test
import { Adapter_Integration_Test } from "../../Adapter.t.sol";

contract SettlementModule_Integration_Test is Adapter_Integration_Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev SwapSettlementModule contract
    SwapSettlementModule public swapModule;
    /// @dev DirectSettlementModule contract
    DirectSettlementModule public directModule;

    /*//////////////////////////////////////////////////////////////
                                   SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        // Setup Adapter Test
        super.setUp();

        // Deploy SwapSettlementModule
        swapModule = new SwapSettlementModule("Swap Settlement Module", "1.0.0", address(portikusV2));

        // Deploy DirectSettlementModule
        directModule = new DirectSettlementModule("Direct Settlement Module", "1.0.0", address(portikusV2));

        // Deploy FillableSwapSettlementModule
        FillableSwapSettlementModule fillableSwapModule =
            new FillableSwapSettlementModule("Fillable Swap Module", "1.0.0", address(portikusV2));

        // Deploy FillableDirectSettlementModule
        FillableDirectSettlementModule fillableDirectModule =
            new FillableDirectSettlementModule("Fillable Direct Module", "1.0.0", address(portikusV2));

        // Deploy NonceManagementModule
        NonceManagementModule nonceModule =
            new NonceManagementModule("Nonce Management Module", "1.0.0", address(portikusV2));

        // Deploy FeeClaimerModule
        FeeClaimerModule feeClaimerModule = new FeeClaimerModule("Fee Claimer Module", "1.0.0", address(portikusV2));

        // Deploy ThreeStepExecutor
        executor = new ThreeStepExecutor();

        // Register modules in PortikusV2 registry
        vm.startPrank(users.admin.account);
        address[] memory modules = new address[](6);
        modules[0] = address(swapModule);
        modules[1] = address(directModule);
        modules[2] = address(fillableSwapModule);
        modules[3] = address(fillableDirectModule);
        modules[4] = address(nonceModule);
        modules[5] = address(feeClaimerModule);
        portikusV2.registerModule(modules);

        // Install modules in Adapter
        adapter.install(address(swapModule));
        adapter.install(address(directModule));
        adapter.install(address(fillableSwapModule));
        adapter.install(address(fillableDirectModule));
        adapter.install(address(nonceModule));
        adapter.install(address(feeClaimerModule));

        vm.stopPrank();
    }
}
