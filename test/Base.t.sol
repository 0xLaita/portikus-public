// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Dependencies
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { StdCheats } from "@forge-std/StdCheats.sol";
import { StdUtils } from "@forge-std/StdUtils.sol";
import { PRBTest } from "@prb-test/PRBTest.sol";

// Mocks
import { ERC20MissingReturn } from "@mocks/erc20/ERC20MissingReturn.sol";
import { ERC20Mock } from "@mocks/erc20/ERC20Mock.sol";
import { ERC20LegacyPermit } from "@mocks/erc20/ERC20LegacyPermit.sol";
import { WETH9 } from "@mocks/erc20/WETH9.sol";

// Types
import { Users, UserData } from "./utils/Types.sol";

/// @notice An abstract base test contract that provides common test logic.
abstract contract Base_Test is StdCheats, PRBTest, StdUtils {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address internal constant ETH = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    Users internal users;

    /*//////////////////////////////////////////////////////////////
                               CONTRACTS
    //////////////////////////////////////////////////////////////*/

    ERC20 internal MTK;
    ERC20LegacyPermit internal DAI;
    ERC20MissingReturn internal USDT;
    WETH9 internal WETH;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // Create users
        users = Users({
            admin: createUser("admin"),
            alice: createUser("alice"),
            bob: createUser("bob"),
            charlie: createUser("charlie"),
            dennis: createUser("dennis"),
            eve: createUser("eve")
        });

        // Prank to admin
        vm.startPrank(users.admin.account);

        // Deploy test tokens
        MTK = new ERC20Mock("MyToken", "MTK");
        DAI = new ERC20LegacyPermit("Dai Stablecoin", "DAI");
        USDT = new ERC20MissingReturn("Tether USD", "USDT", 6);
        WETH = new WETH9();

        // Label the test contracts.
        vm.label({ account: address(MTK), newLabel: "MTK" });
        vm.label({ account: address(DAI), newLabel: "DAI" });
        vm.label({ account: address(USDT), newLabel: "USDT" });
        vm.label({ account: address(WETH), newLabel: "WETH" });

        // Stop pranking
        vm.stopPrank();
    }

    // @dev Create a user with a given name and initial balance of 100 ether.
    function createUser(string memory name) internal returns (UserData memory userData) {
        address payable user = payable(makeAddr(name));
        vm.deal({ account: user, newBalance: 100 ether });
        return UserData({ name: name, account: user });
    }
}
