// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Contracts
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// Interfaces
import { IRegistry } from "@interfaces/portikus/IRegistry.sol";

/// @title Registry
/// @notice A registry of verified agents that can execute orders on behalf of users, and modules that can be installed
///         by Portikus adapter contracts to expand their functionality
contract Registry is Ownable, IRegistry {
    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The list of registered agents
    address[] public agents;

    /// @notice A mapping of agents to their registration status
    /// @dev The agent address is the key, and the value is a boolean indicating if the agent is registered
    mapping(address agent => bool isRegistered) public override isAgentRegistered;

    /// @notice The list of registered modules
    address[] public modules;

    /// @notice A mapping of modules to their registration status
    /// @dev The module address is the key, and the value is a boolean indicating if the module is registered
    mapping(address module => bool isRegistered) public override isModuleRegistered;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) Ownable(_owner) { }

    /*//////////////////////////////////////////////////////////////
                                REGISTER
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRegistry
    function registerAgent(address[] calldata _agents) external onlyOwner {
        // Loop through the agents and register them
        for (uint256 i = 0; i < _agents.length; i++) {
            address agent = _agents[i];
            if (!isAgentRegistered[agent]) {
                agents.push(agent);
                isAgentRegistered[agent] = true;
                emit AgentRegistered(agent);
            }
        }
    }

    /// @inheritdoc IRegistry
    function registerModule(address[] calldata _modules) external onlyOwner {
        // Loop through the modules and register them
        for (uint256 i = 0; i < _modules.length; i++) {
            address module = _modules[i];
            if (!isModuleRegistered[module]) {
                modules.push(module);
                isModuleRegistered[module] = true;
                emit ModuleRegistered(module);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                               UNREGISTER
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRegistry
    function unregisterAgent(address[] calldata _agents) external onlyOwner {
        // Loop through the agents to unregister
        for (uint256 i = 0; i < _agents.length; i++) {
            address agent = _agents[i];
            // Loop through the agents and unregister the specified agent
            for (uint256 j; j < agents.length; j++) {
                if (agents[j] == agent) {
                    // Move the last agent to the current index and pop the last agent
                    agents[j] = agents[agents.length - 1];
                    agents.pop();
                    // Update the agent registration status
                    isAgentRegistered[agent] = false;
                    // Emit the AgentUnregistered event
                    emit AgentUnregistered(agent);
                    break;
                }
            }
        }
    }

    /// @inheritdoc IRegistry
    function unregisterModule(address[] calldata _modules) external onlyOwner {
        // Loop through the modules to unregister
        for (uint256 i = 0; i < _modules.length; i++) {
            address module = _modules[i];
            // Loop through the modules and unregister the specified module
            for (uint256 j; j < modules.length; j++) {
                if (modules[j] == module) {
                    // Move the last module to the current index and pop the last module
                    modules[j] = modules[modules.length - 1];
                    modules.pop();
                    // Update the module registration status
                    isModuleRegistered[module] = false;
                    // Emit the ModuleUnregistered event
                    emit ModuleUnregistered(module);
                    break;
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 GETTERS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRegistry
    function getAgents() external view override returns (address[] memory) {
        return agents;
    }

    /// @inheritdoc IRegistry
    function getModules() external view override returns (address[] memory) {
        return modules;
    }
}
