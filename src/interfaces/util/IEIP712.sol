// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title IEIP712
/// @notice Interface for the fetching the EIP-712 domain separator
interface IEIP712 {
    /*//////////////////////////////////////////////////////////////
                                EXTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the domain separator for the EIP-712 signature
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
