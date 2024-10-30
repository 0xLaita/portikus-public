// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Dependencies
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

contract ERC20LegacyPermit is ERC20 {
    mapping(address => uint256) public nonces;

    // --- EIP712 niceties ---
    bytes32 public DOMAIN_SEPARATOR;
    // bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address holder,address spender,uint256 nonce,uint256
    // expiry,bool allowed)");
    bytes32 public constant PERMIT_TYPEHASH = 0xea2aa0a1be11a07ed86d755c93467f4f82362b452371d1ba94d1715123511acb;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        // mint maximum uint256 to the contract creator
        _mint(msg.sender, type(uint256).max);
    }

    function permit(
        address holder,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
    {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, holder, spender, nonce, expiry, allowed))
            )
        );

        require(holder != address(0), "Dai/invalid-address-0");
        require(holder == ecrecover(digest, v, r, s), "Dai/invalid-permit");
        require(expiry == 0 || block.timestamp <= expiry, "Dai/permit-expired");
        require(nonce == nonces[holder]++, "Dai/invalid-nonce");
        uint256 wad = allowed ? type(uint256).max : 0;
        _approve(holder, spender, wad);
    }
}
