// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Test
import { EIP712_Test } from "../EIP712.t.sol";

// Libraries
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract EIP712_hashTypedDataV4 is EIP712_Test {
    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_hashTypedDataV4_CorrectHashing() public {
        // Arrange struct hash
        bytes32 structHash = keccak256("TestStruct");

        // Act
        bytes32 hashedData = mockEIP712.hashTypedDataV4(structHash);

        // Assert
        bytes32 expectedHashedData = MessageHashUtils.toTypedDataHash(mockEIP712.DOMAIN_SEPARATOR(), structHash);
        assertEq(hashedData, expectedHashedData, "Hashed data should match the expected value");
    }
}
