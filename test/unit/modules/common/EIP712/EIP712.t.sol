// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Mocks
import { MockEIP712 } from "@mocks/EIP712/MockEIP712.sol";

// Test
import { Base_Test } from "@test/Base.t.sol";

abstract contract EIP712_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    MockEIP712 public mockEIP712;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        // Setup base test
        super.setUp();
        // Deploy the mock EIP712 contract
        mockEIP712 = new MockEIP712();
    }
}
