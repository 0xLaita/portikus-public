// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title IExecutor
/// @notice Interface for executor contracts on Portikus
interface IExecutor {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the execution of calldata fails
    error ExecutionFailed();

    /*//////////////////////////////////////////////////////////////
                                EXTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Executes the provided executor data
    /// @param executorData The data to execute
    function execute(bytes calldata executorData) external;
}
