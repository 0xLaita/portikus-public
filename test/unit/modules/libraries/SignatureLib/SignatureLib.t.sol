// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Mocks
import { MockERC1271Signer } from "@mocks/ERC1271/MockERC1271Signer.sol";

// Test
import { Base_Test } from "@test/Base.t.sol";

abstract contract SignatureLib_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    MockERC1271Signer internal mockSigner;

    /*//////////////////////////////////////////////////////////////
                                  SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        // Setup Base Test
        super.setUp();
        // Deploy mock signer
        mockSigner = new MockERC1271Signer();
    }
}
