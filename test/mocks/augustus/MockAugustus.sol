// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @dev A mock AugustusV6 contract to test the ExampleExecutor
contract MockAugustus {
    /// @dev A mock function that reverts if you pass false
    function mockFunction(bool _shouldRevert) external pure {
        if (!_shouldRevert) revert("MockAugustus: Reverting");
    }
}
