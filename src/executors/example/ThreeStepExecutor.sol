// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Interfaces
import { IExecutor } from "@executors/interfaces/IExecutor.sol";

// Libraries
import { ExecutorLib } from "@executors/libraries/ExecutorLib.sol";

/*//////////////////////////////////////////////////////////////
                               STRUCTS
//////////////////////////////////////////////////////////////*/

/// @notice Executor data struct, containing all data required to execute a swap
/// @param beforeCalldata The calldata to execute in the before step
/// @param mainCalldata The calldata to execute in the main step
/// @param afterCalldata The calldata to execute in the after step
/// @param feeRecipient The address to receive the fee
/// @param destToken The address of the dest token
/// @param feeAmount The amount of fee to be paid for the swap
struct ExecutorData {
    StepData beforeCalldata;
    StepData mainCalldata;
    StepData afterCalldata;
    address feeRecipient;
    address destToken;
    uint256 feeAmount;
}

/// @notice Step data struct, containing the calldata and the execution address
/// @param stepCalldata The calldata for the step
/// @param executionAddress The address to execute the step
struct StepData {
    bytes stepCalldata;
    address executionAddress;
}

/// @dev A contract that executes a three-step process, before, main, and after steps
///      using the provided calldata and execution address. This allows flexibility in
///      the execution process, where the before and after steps can be used to perform
///      additional actions before and after the main execution step such as approvals,
///      flash loans, etc. After execution, each PortikusV2 executor called by a swap module
///      is required to transfer the output amount back to the adapter, which will then
///      transfer the output amount to the beneficiary. The executor should also transfer
///      any required fees to the specified fee recipient.
contract ThreeStepExecutor is IExecutor {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using ExecutorLib for address;

    /*//////////////////////////////////////////////////////////////
                               EXECUTE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IExecutor
    function execute(bytes calldata executorData) external {
        // Parse the executor data
        ExecutorData memory data = abi.decode(executorData, (ExecutorData));

        // Execute the before step if provided
        _executeBefore(data.beforeCalldata);

        // Execute the main execution step
        _executeMain(data.mainCalldata);

        // Execute the after step if provided
        _executeAfter(data.afterCalldata);

        // Transfer the fees and output amount
        msg.sender.transferFeesAndETH(data.feeRecipient, data.destToken, data.feeAmount);
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Executes the before step using the provided calldata and execution address
    function _executeBefore(StepData memory beforeCalldata) internal {
        if (beforeCalldata.executionAddress != address(0)) {
            (bool success,) = beforeCalldata.executionAddress.call(beforeCalldata.stepCalldata);
            if (!success) {
                revert ExecutionFailed();
            }
        }
    }

    /// @notice Executes the main step using the provided calldata and execution address
    function _executeMain(StepData memory executionCalldata) internal {
        (bool success,) = executionCalldata.executionAddress.call(executionCalldata.stepCalldata);
        if (!success) {
            revert ExecutionFailed();
        }
    }

    /// @notice Executes the after step using the provided calldata and execution address
    function _executeAfter(StepData memory afterCalldata) internal {
        if (afterCalldata.executionAddress != address(0)) {
            (bool success,) = afterCalldata.executionAddress.call(afterCalldata.stepCalldata);
            if (!success) {
                revert ExecutionFailed();
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                                RECEIVE
    //////////////////////////////////////////////////////////////*/

    /// @notice Fallback function to receive native ETH
    receive() external payable { }
}
