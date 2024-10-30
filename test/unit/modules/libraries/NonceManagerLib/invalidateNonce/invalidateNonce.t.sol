// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Libraries
import { NonceManagerLib } from "@modules/libraries/NonceManagerLib.sol";

// Test
import { NonceManagerLib_Test } from "../NonceManagerLib.t.sol";

contract NonceManagerLib_invalidateNonce is NonceManagerLib_Test {
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

    function test_invalidateNonce_MarksNonceAsUsed() public {
        // Arrange
        address user = users.alice.account;
        uint256 nonce = 123;
        vm.startPrank(user);

        // Act
        mockContract.invalidateNonce(nonce);

        // Assert
        uint256 nonceIndex = nonce / 256;
        uint256 bitPosition = nonce % 256;
        uint256 expectedBit = 1 << bitPosition;
        assertEq(mockContract.getNonceStorageForUser(user, nonceIndex) & expectedBit, expectedBit);
    }

    function testFuzz_invalidateNonce(uint256 nonce) public {
        // Arrange
        address user = users.alice.account;
        vm.startPrank(user);

        // Act
        mockContract.invalidateNonce(nonce);

        // Assert
        uint256 nonceIndex = nonce / 256;
        uint256 bitPosition = nonce % 256;
        uint256 expectedBit = 1 << bitPosition;
        assertEq(mockContract.getNonceStorageForUser(user, nonceIndex) & expectedBit, expectedBit);
    }

    function test_invalidateNonce_Idempotent() public {
        // Arrange
        address user = users.alice.account;
        uint256 nonce = 123;
        vm.startPrank(user);

        // Act
        mockContract.invalidateNonce(nonce);
        mockContract.invalidateNonce(nonce);

        // Assert
        uint256 nonceIndex = nonce / 256;
        uint256 bitPosition = nonce % 256;
        uint256 expectedBit = 1 << bitPosition;
        assertEq(mockContract.getNonceStorageForUser(user, nonceIndex) & expectedBit, expectedBit);
    }
}

/*//////////////////////////////////////////////////////////////
                                  UTIL
//////////////////////////////////////////////////////////////*/

/// @dev Used to propagate the msg.sender correctly
contract MockContract {
    function getNonceStorageForUser(address user, uint256 nonceIndex) public view returns (uint256) {
        return NonceManagerLib.noncesStorage().nonces[user][nonceIndex];
    }

    function invalidateNonce(uint256 nonce) public {
        NonceManagerLib.invalidateNonce(nonce);
    }
}
