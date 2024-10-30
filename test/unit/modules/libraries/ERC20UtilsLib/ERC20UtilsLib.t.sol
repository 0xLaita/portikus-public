// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Test
import { Base_Test } from "@test/Base.t.sol";

abstract contract ERC20UtilsLib_Test is Base_Test {
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
    }
}
