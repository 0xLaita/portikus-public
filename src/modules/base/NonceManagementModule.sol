// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Contracts
import { BaseModule } from "@modules/base/BaseModule.sol";

// Interfaces
import { INonceManagementModule } from "@modules/interfaces/INonceManagementModule.sol";
import { IModule } from "@modules/interfaces/IModule.sol";

// Libraries
import { NonceManagerLib } from "@modules/libraries/NonceManagerLib.sol";

/// @title Nonce Management Module
/// @notice A module that allows users to invalidate nonces and query nonce statuses
contract NonceManagementModule is BaseModule, INonceManagementModule {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using NonceManagerLib for address;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _version,
        address _portikusV2
    )
        BaseModule(_name, _version, _portikusV2)
    { }

    /*//////////////////////////////////////////////////////////////
                            NONCE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc INonceManagementModule
    function invalidateNonce(uint256 nonce) external {
        NonceManagerLib.invalidateNonce(nonce);
        emit NonceInvalidated(msg.sender, nonce);
    }

    /// @inheritdoc INonceManagementModule
    function invalidateNonces(uint256[] calldata nonces) external {
        for (uint256 i = 0; i < nonces.length; i++) {
            NonceManagerLib.invalidateNonce(nonces[i]);
            emit NonceInvalidated(msg.sender, nonces[i]);
        }
    }

    /// @inheritdoc INonceManagementModule
    function isNonceUsed(address owner, uint256 nonce) external view returns (bool used) {
        return owner.isNonceUsed(nonce);
    }

    /// @inheritdoc INonceManagementModule
    function areNoncesUsed(address owner, uint256[] calldata nonces) external view returns (bool[] memory used) {
        used = new bool[](nonces.length);
        for (uint256 i = 0; i < nonces.length; i++) {
            used[i] = owner.isNonceUsed(nonces[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                               SELECTORS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IModule
    function selectors() external pure override(BaseModule, IModule) returns (bytes4[] memory moduleSelectors) {
        moduleSelectors = new bytes4[](4);
        moduleSelectors[0] = this.invalidateNonce.selector;
        moduleSelectors[1] = this.invalidateNonces.selector;
        moduleSelectors[2] = this.isNonceUsed.selector;
        moduleSelectors[3] = this.areNoncesUsed.selector;
    }
}
