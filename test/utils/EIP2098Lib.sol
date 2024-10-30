// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import { VmSafe } from "@prb-test/Vm.sol";

/// @dev Used to create EIP2098 compliant signatures
library EIP2098Lib {
    function sign2098(VmSafe vm, uint256 privateKey, bytes32 hash) internal pure returns (bytes memory signature) {
        (uint8 vRaw, bytes32 rRaw, bytes32 sRaw) = vm.sign(privateKey, hash);
        uint8 v = vRaw - 27; // 27 is 0, 28 is 1
        bytes32 vs = bytes32(uint256(v) << 255) | sRaw;
        signature = abi.encodePacked(rRaw, vs);
        return signature;
    }
}
