// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Test
import { BaseSettlementModule_Test } from "../BaseSettlementModule.t.sol";

contract BaseSettlementModule_onlyAuthorizedAgents is BaseSettlementModule_Test {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the msg.sender is not an authorized agent
    error UnauthorizedAgent();

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_onlyAuthorizedAgent_RevertsWhen_NotAuthorized() public {
        // Arrange
        // Ensure the current user is not authorized
        // Expect the call to revert
        vm.expectRevert(UnauthorizedAgent.selector);

        // Act
        mockModule.mockFunctionWithModifier();
    }

    function test_onlyAuthorizedAgent_SucceedsWhen_Authorized() public {
        // Arrange
        address[] memory agents = new address[](1);
        agents[0] = users.bob.account;
        vm.prank(users.admin.account);
        portikusV2.registerAgent(agents);

        // Prank to bob
        vm.prank(users.bob.account);

        // Act
        uint256 result = mockModule.mockFunctionWithModifier();

        // Assert
        assertEq(result, 1);
    }
}
