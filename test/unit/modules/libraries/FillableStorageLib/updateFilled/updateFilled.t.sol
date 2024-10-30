// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Libraries
import { FillableStorageLib } from "@modules/libraries/FillableStorageLib.sol";

// Test
import { FillableStorageLib_Test } from "../FillableStorageLib.t.sol";

contract FillableStorageLib_updateFilled is FillableStorageLib_Test {
    /*//////////////////////////////////////////////////////////////
                                VARIABLES
    //////////////////////////////////////////////////////////////*/

    MockContract internal mockContract;

    /*//////////////////////////////////////////////////////////////
                                  SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        // Setup Base Test
        super.setUp();
        // Deploy the MockContract
        mockContract = new MockContract();
    }

    /*//////////////////////////////////////////////////////////////
                                   TESTS
    //////////////////////////////////////////////////////////////*/

    function test_updateFilled_UpdatesFilledAmount() public {
        // Arrange
        bytes32 orderHash = keccak256("testOrder");
        uint256 fillAmount = 100;

        // Act
        mockContract.updateFilled(orderHash, fillAmount);

        // Assert
        assertEq(mockContract.getFilledAmount(orderHash), fillAmount, "Filled amount should be updated");
    }

    function test_updateFilled_AddsToExistingFilledAmount() public {
        // Arrange
        bytes32 orderHash = keccak256("testOrder");
        uint256 initialFillAmount = 100;
        uint256 additionalFillAmount = 50;

        // Act
        mockContract.updateFilled(orderHash, initialFillAmount);
        mockContract.updateFilled(orderHash, additionalFillAmount);

        // Assert
        assertEq(
            mockContract.getFilledAmount(orderHash),
            initialFillAmount + additionalFillAmount,
            "Filled amount should be cumulative"
        );
    }

    function testFuzz_updateFilled(bytes32 orderHash, uint256 fillAmount1, uint256 fillAmount2) public {
        // Assume
        vm.assume(fillAmount1 <= type(uint256).max / 2); // Prevent overflow
        vm.assume(fillAmount2 <= type(uint256).max / 2); // Prevent overflow

        // Act
        mockContract.updateFilled(orderHash, fillAmount1);
        mockContract.updateFilled(orderHash, fillAmount2);

        // Assert
        assertEq(
            mockContract.getFilledAmount(orderHash), fillAmount1 + fillAmount2, "Filled amount should be cumulative"
        );
    }
}

/*//////////////////////////////////////////////////////////////
                                   UTIL
//////////////////////////////////////////////////////////////*/

/// @dev Used to propagate the msg.sender correctly
contract MockContract {
    function updateFilled(bytes32 orderHash, uint256 fillAmount) public {
        FillableStorageLib.updateFilled(orderHash, fillAmount);
    }

    function getFilledAmount(bytes32 orderHash) public view returns (uint256) {
        return FillableStorageLib.getFilledAmount(orderHash);
    }
}
