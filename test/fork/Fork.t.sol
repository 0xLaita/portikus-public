// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Tests
import { Base_Test } from "@test/Base.t.sol";

abstract contract Fork_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    // The block number to fork from
    uint256 internal forkBlockNumber;

    // The network url or alias to fork from
    string internal forkUrlOrAlias;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(uint256 _forkBlockNumber, string memory _forkUrlOrAlias) {
        // Set fork block number
        forkBlockNumber = _forkBlockNumber;
        forkUrlOrAlias = _forkUrlOrAlias;
    }

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        // Fork Ethereum Mainnet
        vm.createSelectFork({ blockNumber: forkBlockNumber, urlOrAlias: forkUrlOrAlias });
        // Setup base test
        super.setUp();
    }
}
