// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Contracts
import { BaseModule } from "@modules/base/BaseModule.sol";

// Interfaces
import { IFeeClaimerModule } from "@modules/interfaces/IFeeClaimerModule.sol";
import { IModule } from "@modules/interfaces/IModule.sol";

// Libraries
import { FeeManagerLib } from "@modules/libraries/FeeManagerLib.sol";
import { ModuleManagerLib } from "@modules/libraries/ModuleManagerLib.sol";

/// @title Fee Claimer Module
/// @notice A module that allows partners to claim their collected fees
contract FeeClaimerModule is BaseModule, IFeeClaimerModule {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using FeeManagerLib for address;
    using FeeManagerLib for address[];

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
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verifies that has called the function is the protocol fee claimer,
    ///         reverts if the caller is not the protocol fee claimer with UnauthorizedAccount(msg.sender)
    modifier onlyProtocolFeeClaimer() {
        FeeManagerLib.isProtocolFeeClaimer();
        _;
    }

    /// @notice Verifies that the caller is the owner of the adapter,
    ///         reverts if the caller is not the owner with UnauthorizedAccount(msg.sender)
    modifier onlyOwner() {
        ModuleManagerLib.isOwner();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              PARTNER FEES
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFeeClaimerModule
    function withdrawFees(address token, uint256 amount, address recipient) external nonReentrant {
        token.withdrawFees(msg.sender, amount, recipient);
    }

    /// @inheritdoc IFeeClaimerModule
    function withdrawAllFees(address token, address recipient) external nonReentrant returns (uint256 amount) {
        return token.withdrawAllFees(msg.sender, recipient);
    }

    /// @inheritdoc IFeeClaimerModule
    function batchWithdrawAllFees(address[] calldata tokens, address recipient) external nonReentrant {
        tokens.batchWithdrawAllFees(msg.sender, recipient);
    }

    /// @inheritdoc IFeeClaimerModule
    function getCollectedFees(address partner, address token) external view returns (uint256) {
        return token.getCollectedFees(partner);
    }

    /// @inheritdoc IFeeClaimerModule
    function batchGetCollectedFees(
        address partner,
        address[] calldata tokens
    )
        external
        view
        returns (uint256[] memory amounts)
    {
        return tokens.batchGetCollectedFees(partner);
    }

    /*//////////////////////////////////////////////////////////////
                             PROTOCOL FEES
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFeeClaimerModule
    function withdrawProtocolFees(
        address token,
        uint256 amount,
        address recipient
    )
        external
        nonReentrant
        onlyProtocolFeeClaimer
    {
        token.withdrawFees(address(0), amount, recipient);
    }

    /// @inheritdoc IFeeClaimerModule
    function withdrawAllProtocolFees(
        address token,
        address recipient
    )
        external
        onlyProtocolFeeClaimer
        nonReentrant
        returns (uint256 amount)
    {
        return token.withdrawAllFees(address(0), recipient);
    }

    /// @inheritdoc IFeeClaimerModule
    function batchWithdrawAllProtocolFees(
        address[] calldata tokens,
        address recipient
    )
        external
        onlyProtocolFeeClaimer
        nonReentrant
    {
        tokens.batchWithdrawAllFees(address(0), recipient);
    }

    /*//////////////////////////////////////////////////////////////
                              FEE CLAIMER
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFeeClaimerModule
    function setProtocolFeeClaimer(address protocolFeeClaimer) external onlyOwner {
        protocolFeeClaimer.setFeeClaimer();
    }

    /// @inheritdoc IFeeClaimerModule
    function getProtocolFeeClaimer() external view returns (address) {
        return FeeManagerLib.getFeeClaimer();
    }

    /*//////////////////////////////////////////////////////////////
                               SELECTORS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IModule
    function selectors() external pure override(BaseModule, IModule) returns (bytes4[] memory moduleSelectors) {
        moduleSelectors = new bytes4[](10);
        moduleSelectors[0] = this.withdrawFees.selector;
        moduleSelectors[1] = this.withdrawAllFees.selector;
        moduleSelectors[2] = this.batchWithdrawAllFees.selector;
        moduleSelectors[3] = this.getCollectedFees.selector;
        moduleSelectors[4] = this.batchGetCollectedFees.selector;
        moduleSelectors[5] = this.withdrawProtocolFees.selector;
        moduleSelectors[6] = this.withdrawAllProtocolFees.selector;
        moduleSelectors[7] = this.batchWithdrawAllProtocolFees.selector;
        moduleSelectors[8] = this.setProtocolFeeClaimer.selector;
        moduleSelectors[9] = this.getProtocolFeeClaimer.selector;
    }
}
