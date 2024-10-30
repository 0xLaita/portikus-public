// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Libraries
import { FillableStorageLib } from "@modules/libraries/FillableStorageLib.sol";

// Test
import { FillableStorageLib_Test } from "../FillableStorageLib.t.sol";

contract FillableStorageLib_getFilledAmount is FillableStorageLib_Test {
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

    function test_getFilledAmount_ReturnsZeroForUnfilledOrder() public {
        // Arrange
        bytes32 orderHash = keccak256("unfilledOrder");

        // Act
        uint256 filledAmount = mockContract.getFilledAmount(orderHash);

        // Assert
        assertEq(filledAmount, 0, "Unfilled order should return zero");
    }

    function test_getFilledAmount_ReturnsCorrectFilledAmount() public {
        // Arrange
        bytes32 orderHash = keccak256("testOrder");
        uint256 fillAmount = 100;
        mockContract.updateFilled(orderHash, fillAmount);

        // Act
        uint256 filledAmount = mockContract.getFilledAmount(orderHash);

        // Assert
        assertEq(filledAmount, fillAmount, "Should return the correct filled amount");
    }

    function testFuzz_getFilledAmount(bytes32 orderHash, uint256 fillAmount) public {
        // Arrange
        mockContract.updateFilled(orderHash, fillAmount);

        // Act
        uint256 filledAmount = mockContract.getFilledAmount(orderHash);

        // Assert
        assertEq(filledAmount, fillAmount, "Should return the correct filled amount");
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
