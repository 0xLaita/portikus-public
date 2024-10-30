// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @notice Interface for the Portikus V2 registry
interface IRegistry {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new agent is registered
    event AgentRegistered(address agent);

    /// @notice Emitted when a new module is registered
    event ModuleRegistered(address module);

    /// @notice Emitted when an agent is unregistered
    event AgentUnregistered(address agent);

    /// @notice Emitted when a module is unregistered
    event ModuleUnregistered(address module);

    /*//////////////////////////////////////////////////////////////
                                REGISTER
    //////////////////////////////////////////////////////////////*/

    /// @notice Register new agents
    /// @param _agents The list of agents to register
    function registerAgent(address[] calldata _agents) external;

    /// @notice Register new modules
    /// @param _modules The list of modules to register
    function registerModule(address[] calldata _modules) external;

    /*//////////////////////////////////////////////////////////////
                                UNREGISTER
    //////////////////////////////////////////////////////////////*/

    /// @notice Unregister agents
    /// @param _agents The list of agents to unregister
    function unregisterAgent(address[] calldata _agents) external;

    /// @notice Unregister modules
    /// @param _modules The list of modules to unregister
    function unregisterModule(address[] calldata _modules) external;

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the list of registered agents
    function getAgents() external returns (address[] memory);

    /// @notice Get the list of registered modules
    function getModules() external returns (address[] memory);

    /// @notice Check if an agent is registered
    function isAgentRegistered(address agent) external returns (bool);

    /// @notice Check if a module is registered
    function isModuleRegistered(address module) external returns (bool);
}
