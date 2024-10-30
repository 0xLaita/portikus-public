// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Test
import { Fork_Test } from "@test/fork/Fork.t.sol";

abstract contract ERC20UtilsLib_Fork_Test is Fork_Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    address recipient;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(uint256 _forkBlockNumber, string memory _forkUrlOrAlias) Fork_Test(_forkBlockNumber, _forkUrlOrAlias) { }

    /*//////////////////////////////////////////////////////////////
                                  SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        // Setup Base Test
        super.setUp();
        // Prank to admin
        vm.startPrank(users.admin.account);
        // Transfer MTK to users
        MTK.transfer(users.alice.account, 100);
        MTK.transfer(users.bob.account, 100);
        // Set recipient to charlie
        recipient = users.charlie.account;
    }
}
