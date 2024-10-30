// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Interfaces
import { IExecutor } from "@executors/interfaces/IExecutor.sol";

// Libraries
import { ExecutorLib } from "@executors/libraries/ExecutorLib.sol";
import { SafeTransferLib } from "@solady/utils/SafeTransferLib.sol";

/*//////////////////////////////////////////////////////////////
                               STRUCTS
//////////////////////////////////////////////////////////////*/

/// @notice Executor data struct, containing all data required to execute a swap
/// @param executorCalldata The calldata to execute
/// @param feeRecipient The address to receive the fee
/// @param srcToken The address of the src token to approve for the swap, if set to 0x0, no approval is needed
/// @param destToken The address of the dest token
/// @param feeAmount The amount of fee to be paid for the swap
struct ExecutorData {
    bytes executionCalldata;
    address feeRecipient;
    address srcToken;
    address destToken;
    uint256 feeAmount;
}

contract AugustusExecutor is IExecutor {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using ExecutorLib for address;
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Augustus V6 address
    address public immutable AUGUSTUS_V6;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param _augustusV6 The address of the Augustus V6 contract
    constructor(address _augustusV6) {
        AUGUSTUS_V6 = _augustusV6;
    }

    /*//////////////////////////////////////////////////////////////
                               EXECUTE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IExecutor
    function execute(bytes calldata executorData) external {
        // Parse the executor data
        ExecutorData memory data = abi.decode(executorData, (ExecutorData));

        // Approve src token to the execution address if address is not 0x0
        if (data.srcToken != address(0)) {
            data.srcToken.safeApproveWithRetry(AUGUSTUS_V6, type(uint256).max);
        }

        // Execute the calldata on AUGUSTUS_V6, reverting on failure
        (bool success,) = AUGUSTUS_V6.call(data.executionCalldata);
        if (!success) {
            revert ExecutionFailed();
        }

        // Transfer the fees and output amount
        msg.sender.transferFeesAndETH(data.feeRecipient, data.destToken, data.feeAmount);
    }

    /*//////////////////////////////////////////////////////////////
                                RECEIVE
    //////////////////////////////////////////////////////////////*/

    /// @notice Fallback function to receive native ETH
    receive() external payable { }
}
