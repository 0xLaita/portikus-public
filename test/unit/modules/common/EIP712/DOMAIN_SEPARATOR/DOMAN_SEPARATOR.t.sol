// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Test
import { EIP712_Test } from "../EIP712.t.sol";

contract EIP712_DOMAIN_SEPARATOR is EIP712_Test {
    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DOMAIN_SEPARATOR_CorrectCalculation() public {
        // Arrange expected domain separator
        bytes32 expectedDomainSeparator = mockEIP712.calculateDomainSeparator();

        // Act
        bytes32 domainSeparator = mockEIP712.DOMAIN_SEPARATOR();

        // Assert
        assertEq(domainSeparator, expectedDomainSeparator, "Domain separator should be calculated correctly");
    }

    function test_DOMAIN_SEPARATOR_RebuildOnChainIdChange() public {
        // Arrange
        vm.chainId(1);

        // Arrange expected domain separator
        bytes32 expectedDomainSeparator = mockEIP712.calculateDomainSeparator();

        // Change chain ID (simulate chain ID change)
        vm.chainId(2);

        // Act
        bytes32 domainSeparator = mockEIP712.calculateDomainSeparator();

        // Assert
        assertNotEq(domainSeparator, expectedDomainSeparator, "Domain separator should be rebuilt on chain ID change");
    }
}
