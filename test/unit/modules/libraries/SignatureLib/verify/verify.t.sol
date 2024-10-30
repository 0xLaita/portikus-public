// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Dependencies
import { VmSafe } from "@prb-test/Vm.sol";

// Libraries
import { SignatureLib } from "@modules/libraries/SignatureLib.sol";
import { EIP2098Lib } from "@test/utils/EIP2098Lib.sol";

// Test
import { SignatureLib_Test } from "../SignatureLib.t.sol";

contract SignatureLib_verify is SignatureLib_Test {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the signature is invalid
    error InvalidSignature();

    /// @notice Emitted when the signer is invalid
    error InvalidSigner();

    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using SignatureLib for bytes;

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_verify_RevertsWhen_ActualSignerIsAddressZero() public {
        // Create invalid signature
        bytes memory signature = abi.encodePacked(bytes32(0x00), bytes32(0x00));
        // Expect revert
        vm.expectRevert(InvalidSignature.selector);
        // Call verify
        (this).callVerify(signature, keccak256("data"), address(0));
    }

    function test_verify_RevertsWhen_SignatureNotSignedBySigner() public {
        // Create test hash
        bytes32 hash = keccak256("data");
        // privateKey = uint256(keccak256(abi.encodePacked(userName)));
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        // Sign hash
        bytes memory signature = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        // Expect revert
        vm.expectRevert(InvalidSigner.selector);
        // Call verify with a different expected signer
        (this).callVerify(signature, hash, users.bob.account);
    }

    function test_verify_RevertsWhen_SignatureLegnthIsNot64() public {
        // Create test hash
        bytes32 hash = keccak256("data");
        // privateKey = uint256(keccak256(abi.encodePacked(userName)));
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        // Sign hash
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);
        // Expect revert
        vm.expectRevert(InvalidSignature.selector);
        // Call verify with a different expected signer
        (this).callVerify(signature, hash, users.bob.account);
    }

    function test_verify_SucceedsWhen_SignatureSignedBySigner() public {
        // Create test hash
        bytes32 hash = keccak256("data");
        // privateKey = uint256(keccak256(abi.encodePacked(userName)));
        uint256 ownerPrivateKey = uint256(keccak256(abi.encodePacked(users.alice.name)));
        // Sign hash
        bytes memory signature = EIP2098Lib.sign2098(vm, ownerPrivateKey, hash);
        // Call verify
        bool success = (this).callVerify(signature, hash, users.alice.account);
        // Assert success
        assertTrue(success);
    }

    function test_verify_SignatureFromERC1271() public {
        // Create test hash
        bytes32 hash = keccak256("data");
        // Create valid signature using the mock signer
        bytes memory signature = mockSigner.sign(hash);
        // Call verify
        bool success = (this).callVerify(signature, hash, address(mockSigner));
        // Assert success
        assertTrue(success);
    }

    function test_verify_RevertsWhen_InvalidSignatureFromERC1271() public {
        // Create test hash
        bytes32 hash = keccak256("wrong");
        // Create invalid signature using the mock signer
        bytes memory signature = mockSigner.invalidSign();
        // Expect revert
        vm.expectRevert(InvalidSignature.selector);
        // Call verify
        (this).callVerify(signature, hash, address(mockSigner));
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPER
    //////////////////////////////////////////////////////////////*/

    /// @dev Mock to propagate the revert
    function callVerify(bytes memory signature, bytes32 hash, address signer) public view returns (bool) {
        signature.verify(hash, signer);
        return true;
    }
}
