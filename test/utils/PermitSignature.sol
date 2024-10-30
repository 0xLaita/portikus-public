// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
/**
 * Vendored on December 18, 2023 from:
 * https://github.com/Uniswap/permit2/blob/cc56ad0f3439c502c246fc5cfcc3db92bb8b7219/test/SignatureTransfer.t.sol#L115
 */

import { Vm } from "@forge-std/Vm.sol";
import { ISignatureTransfer } from "./interfaces/ISignatureTransfer.sol";
import { IAllowanceTransfer } from "./interfaces/IAllowanceTransfer.sol";
import { ERC20LegacyPermit } from "../mocks/erc20/ERC20LegacyPermit.sol";
import { UserData } from "./Types.sol";
import { IERC20Permit } from "@openzeppelin/token/ERC20/extensions/IERC20Permit.sol";

contract PermitSignature {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 public constant _PERMIT_DETAILS_TYPEHASH =
        keccak256("PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)");

    bytes32 public constant _PERMIT_SINGLE_TYPEHASH = keccak256(
        "PermitSingle(PermitDetails details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
    );

    bytes32 public constant _PERMIT_BATCH_TYPEHASH = keccak256(
        "PermitBatch(PermitDetails[] details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
    );

    bytes32 public constant _TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");

    bytes32 public constant _PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    bytes32 public constant _PERMIT_BATCH_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitBatchTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    function getPermitSignatureRaw(
        IAllowanceTransfer.PermitSingle memory permit,
        uint256 privateKey,
        bytes32 domainSeparator
    )
        internal
        pure
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 permitHash = keccak256(abi.encode(_PERMIT_DETAILS_TYPEHASH, permit.details));

        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(abi.encode(_PERMIT_SINGLE_TYPEHASH, permitHash, permit.spender, permit.sigDeadline))
            )
        );

        (v, r, s) = vm.sign(privateKey, msgHash);
    }

    function getCompactPermitSignature(
        IAllowanceTransfer.PermitSingle memory permit,
        uint256 privateKey,
        bytes32 domainSeparator
    )
        internal
        pure
        returns (bytes memory sig)
    {
        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, privateKey, domainSeparator);
        bytes32 vs;
        (r, vs) = _getCompactSignature(v, r, s);
        return bytes.concat(r, vs);
    }

    function getCompactPermitTransferSignature(
        ISignatureTransfer.PermitTransferFrom memory permit,
        uint256 privateKey,
        bytes32 domainSeparator,
        address spender
    )
        internal
        pure
        returns (bytes memory sig)
    {
        bytes32 tokenPermissions = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted));
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(_PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissions, spender, permit.nonce, permit.deadline)
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        bytes32 vs;
        (r, vs) = _getCompactSignature(v, r, s);
        return bytes.concat(r, vs);
    }

    function _getCompactSignature(
        uint8 vRaw,
        bytes32 rRaw,
        bytes32 sRaw
    )
        internal
        pure
        returns (bytes32 r, bytes32 vs)
    {
        uint8 v = vRaw - 27; // 27 is 0, 28 is 1
        vs = bytes32(uint256(v) << 255) | sRaw;
        return (rRaw, vs);
    }

    function getPermitTransferSignature(
        ISignatureTransfer.PermitTransferFrom memory permit,
        uint256 privateKey,
        bytes32 domainSeparator
    )
        internal
        view
        returns (bytes memory sig)
    {
        bytes32 tokenPermissions = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted));
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        _PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissions, address(this), permit.nonce, permit.deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function getPermitWitnessTransferSignature(
        ISignatureTransfer.PermitTransferFrom memory permit,
        uint256 privateKey,
        bytes32 typehash,
        bytes32 witness,
        bytes32 domainSeparator
    )
        internal
        view
        returns (bytes memory sig)
    {
        bytes32 tokenPermissions = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted));

        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(abi.encode(typehash, tokenPermissions, address(this), permit.nonce, permit.deadline, witness))
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function getPermitBatchTransferSignature(
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        uint256 privateKey,
        bytes32 domainSeparator
    )
        internal
        view
        returns (bytes memory sig)
    {
        bytes32[] memory tokenPermissions = new bytes32[](permit.permitted.length);
        for (uint256 i = 0; i < permit.permitted.length; ++i) {
            tokenPermissions[i] = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted[i]));
        }
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        _PERMIT_BATCH_TRANSFER_FROM_TYPEHASH,
                        keccak256(abi.encodePacked(tokenPermissions)),
                        address(this),
                        permit.nonce,
                        permit.deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function getPermitBatchWitnessSignature(
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        uint256 privateKey,
        bytes32 typeHash,
        bytes32 witness,
        bytes32 domainSeparator
    )
        internal
        view
        returns (bytes memory sig)
    {
        bytes32[] memory tokenPermissions = new bytes32[](permit.permitted.length);
        for (uint256 i = 0; i < permit.permitted.length; ++i) {
            tokenPermissions[i] = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted[i]));
        }

        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        typeHash,
                        keccak256(abi.encodePacked(tokenPermissions)),
                        address(this),
                        permit.nonce,
                        permit.deadline,
                        witness
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function defaultERC20PermitTransfer(
        address token0,
        uint256 nonce
    )
        internal
        view
        returns (ISignatureTransfer.PermitTransferFrom memory)
    {
        return ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({ token: token0, amount: 10 ** 18 }),
            nonce: nonce,
            deadline: block.timestamp + 100
        });
    }

    function defaultERC20PermitWitnessTransfer(
        address token0,
        uint256 nonce
    )
        internal
        view
        returns (ISignatureTransfer.PermitTransferFrom memory)
    {
        return ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({ token: token0, amount: 10 ** 18 }),
            nonce: nonce,
            deadline: block.timestamp + 100
        });
    }

    function defaultERC20PermitMultiple(
        address[] memory tokens,
        uint256 nonce
    )
        internal
        view
        returns (ISignatureTransfer.PermitBatchTransferFrom memory)
    {
        ISignatureTransfer.TokenPermissions[] memory permitted =
            new ISignatureTransfer.TokenPermissions[](tokens.length);
        for (uint256 i = 0; i < tokens.length; ++i) {
            permitted[i] = ISignatureTransfer.TokenPermissions({ token: tokens[i], amount: 1 ** 18 });
        }
        return ISignatureTransfer.PermitBatchTransferFrom({
            permitted: permitted,
            nonce: nonce,
            deadline: block.timestamp + 100
        });
    }

    function createValidLegacyPermit(
        ERC20LegacyPermit token,
        UserData memory user,
        address spender,
        uint256 deadline
    )
        internal
        view
        returns (bytes memory permitData)
    {
        // Create permit hash
        bytes32 PERMIT_TYPEHASH = 0xea2aa0a1be11a07ed86d755c93467f4f82362b452371d1ba94d1715123511acb;
        address holder = user.account;
        uint256 nonce = token.nonces(holder);
        bool allowed = true;
        uint256 expiry = deadline;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(PERMIT_TYPEHASH, holder, spender, nonce, expiry, allowed))
            )
        );

        // privateKey = uint256(keccak256(abi.encodePacked(userName)));
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(user.name)));
        // Sign permit hash
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        // check signature
        require(user.account == ecrecover(digest, v, r, s), "Dai/invalid-permit");

        // Return permit calldata
        return abi.encode(holder, spender, nonce, expiry, allowed, v, r, s);
    }

    function createValidPermit(
        IERC20Permit token,
        UserData memory user,
        address spender,
        uint256 value,
        uint256 deadline
    )
        internal
        view
        returns (bytes memory permitData)
    {
        // Create permit hash
        bytes32 permitHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        user.account,
                        spender,
                        value,
                        token.nonces(user.account),
                        deadline
                    )
                )
            )
        );

        // privateKey = uint256(keccak256(abi.encodePacked(userName)));
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(user.name)));
        // Sign permit hash
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, permitHash);

        // Return permit calldata
        return abi.encode(user.account, spender, value, deadline, v, r, s);
    }

    function createInvalidPermit(
        IERC20Permit token,
        UserData memory user,
        address spender,
        uint256 value,
        uint256 deadline
    )
        internal
        view
        returns (bytes memory permitData)
    {
        // Create permit hash
        bytes32 permitHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        user.account,
                        spender,
                        value,
                        token.nonces(user.account),
                        deadline
                    )
                )
            )
        );

        // privateKey = uint256(keccak256(abi.encodePacked(userName)));
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(user.name)));
        // Sign permit hash
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, permitHash);

        // Intentionally return invalid permit calldata
        return abi.encode(user.account, spender, value, deadline, v + 1, r, s);
    }
}
