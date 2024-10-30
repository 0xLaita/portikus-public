// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Contracts
import { Adapter_Test } from "../Adapter.t.sol";

// Test
contract Adapter_transferOwnership is Adapter_Test {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when caller is not the owner
    error UnauthorizedAccount(address account);

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_transferOwnership_SuccessfullyChangesOwner() public {
        // Arrange
        address newOwner = users.charlie.account;

        // Act
        vm.startPrank(users.admin.account);
        adapter.transferOwnership(newOwner);

        // Assert
        assertEq(adapter.owner(), newOwner, "New owner should be Charlie");
    }

    function test_transferOwnership_RevertsWhen_CalledByNonOwner() public {
        // Arrange
        address newOwner = users.charlie.account;

        // Act
        vm.startPrank(users.bob.account);
        vm.expectRevert(abi.encodeWithSelector(UnauthorizedAccount.selector, users.bob.account));
        adapter.transferOwnership(newOwner);

        // Assert
        assertEq(adapter.owner(), users.admin.account, "Owner should remain the same");
    }
}
