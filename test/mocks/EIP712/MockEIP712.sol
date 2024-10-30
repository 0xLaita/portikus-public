// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import { EIP712 } from "@modules/util/EIP712.sol";

contract MockEIP712 is EIP712 {
    constructor() EIP712() { }

    function calculateDomainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function hashTypedDataV4(bytes32 structHash) external view returns (bytes32) {
        return _hashTypedDataV4(structHash);
    }
}
