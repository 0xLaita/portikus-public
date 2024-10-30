// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Libraries
import { SafeTransferLib } from "@solady/utils/SafeTransferLib.sol";
import { ERC20UtilsLib } from "@modules/libraries/ERC20UtilsLib.sol";

/// @title Fee Manager Library
/// @notice A library for managing fees within adapter modules inside the PortikusV2 protocol
library FeeManagerLib {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when attempting to withdraw more fees than available
    error InsufficientFees();

    /// @notice Emitted when an unauthorized account attempts to perform an action
    error UnauthorizedAccount(address account);

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when fee claimer has been set
    event FeeClaimerSet(address indexed feeClaimer);

    /// @notice Emitted when fees are withdrawn by a partner
    event FeesWithdrawn(address indexed partner, address indexed token, uint256 amount, address recipient);

    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fee basis points mask
    uint256 internal constant FEE_IN_BASIS_POINTS_MASK = 0xFF;

    /// @notice The maximum fee in basis points (2%)
    uint256 internal constant MAX_FEE_IN_BASIS_POINTS = 200;

    /// @notice Flag to indicate that the partner takes the surplus
    uint256 internal constant PARTNER_TAKES_SURPLUS = 1 << 8;

    /// @notice 100% in basis points
    uint256 internal constant HUNDRED_PERCENT = 10_000;

    /// @notice 50% in basis points
    uint256 internal constant FIFTY_PERCENT = 5000;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice keccak256(abi.encode(uint256(keccak256("FeeManagerLib.fees")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 internal constant FEES_SLOT = 0x9d6776f3e6f4c790d2c9ed210f024b8fa98c21608927f8a73193e44a78ce0600;

    /// @custom:storage-location erc7201:FeeManagerLib.fees
    /// @notice The structure that defines the storage layout for managing fees
    /// @param fees A mapping of fees for each partner to an indexed mapping of token to amount
    ///        - partner: The address of the partner for whom we are managing fees.
    ///        - token: The address of the token for which we are managing fees.
    ///        - amount: The amount of fees collected for the partner and token.
    /// @param feeClaimer The address of the fee claimer
    struct FeeStorage {
        mapping(address partner => mapping(address token => uint256 amount)) fees;
        address feeClaimer;
    }

    /// @notice Get the pointer to the fees storage slot
    /// @return fs The pointer to the fees storage slot
    function feesStorage() internal pure returns (FeeStorage storage fs) {
        bytes32 slot = FEES_SLOT;
        assembly {
            fs.slot := slot
        }
    }

    /*//////////////////////////////////////////////////////////////
                              FEE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Processes fees for given partnerAndFee, token, amount and expectedAmount
    /// @param partnerAndFee The partner and fee encoded in a single uint256 value
    /// @param token The address of the token to process fees in
    /// @param receivedAmount The amount received after settling the order
    /// @param expectedAmount The expected amount from the order (signed destAmount)
    /// @return returnAmount The amount to return to the user after processing fees
    /// @return partnerFee The amount of fees collected for the partner
    /// @return protocolFee The amount of fees collected for the protocol
    function processFees(
        uint256 partnerAndFee,
        address token,
        uint256 receivedAmount,
        uint256 expectedAmount
    )
        internal
        returns (uint256 returnAmount, uint256 partnerFee, uint256 protocolFee)
    {
        // Parse the partner and fee from the partnerAndFee value
        (address partner, uint256 feeInBps, bool partnerTakesSurplus) = parsePartnerAndFee(partnerAndFee);

        // Set the returnAmount to the receivedAmount
        returnAmount = receivedAmount;

        // Check if there is a surplus
        if (receivedAmount > expectedAmount) {
            // Calculate the surplus
            uint256 surplus = receivedAmount - expectedAmount;

            // Calculate and collect the protocol fee
            protocolFee = (surplus * FIFTY_PERCENT) / HUNDRED_PERCENT;
            collectFees(address(0), token, protocolFee);

            // Update the returnAmount after the protocol fee
            returnAmount -= protocolFee;

            // Handle partner fee if there's a partner
            if (partner != address(0)) {
                // If fee is set, collect the fee as partner fee
                if (feeInBps != 0) {
                    // Collect fixed fee on the remaining amount as partner fee
                    partnerFee = (returnAmount * feeInBps) / HUNDRED_PERCENT;
                }
                // If partnerTakesSurplus flag is set, collect the remaining surplus as partner fee
                else if (partnerTakesSurplus) {
                    // Collect the remaining 50% of surplus as partner fee
                    partnerFee = surplus - protocolFee;
                }
                // Collect the partner fee
                if (partnerFee != 0) {
                    collectFees(partner, token, partnerFee);
                    // Update the returnAmount after the partner fee
                    returnAmount -= partnerFee;
                }
            }
        }
        // If there is no surplus
        else {
            // If partner address and fee are set
            if (partner != address(0) && feeInBps > 0) {
                // Collect fixed fee as partner fee
                partnerFee = (returnAmount * feeInBps) / HUNDRED_PERCENT;
                collectFees(partner, token, partnerFee);
                // Update the returnAmount after the partner fee
                returnAmount -= partnerFee;
            }
        }

        return (returnAmount, partnerFee, protocolFee);
    }

    /// @notice Parses the partner and fee from a single uint256 value, extracting the partner address, fee,
    ///         and the partner takes surplus flag, capping the fee at the maximum value
    /// @param partnerAndFee The uint256 value containing the partner, fee, and flags
    /// @return partner The parsed partner address
    /// @return fee The parsed fee, capped at MAX_FEE_IN_BASIS_POINTS
    /// @return partnerTakesSurplus A boolean indicating whether the partner takes the surplus
    function parsePartnerAndFee(uint256 partnerAndFee)
        internal
        pure
        returns (address partner, uint256 fee, bool partnerTakesSurplus)
    {
        assembly {
            partner := shr(96, partnerAndFee)
            fee := and(partnerAndFee, FEE_IN_BASIS_POINTS_MASK)
            if gt(fee, MAX_FEE_IN_BASIS_POINTS) { fee := MAX_FEE_IN_BASIS_POINTS }
            partnerTakesSurplus := and(shr(8, partnerAndFee), 1)
        }
    }

    /// @notice Collects fees for a partner
    /// @param partner The address of the partner
    /// @param token The address of the token
    /// @param amount The amount of fees to collect
    function collectFees(address partner, address token, uint256 amount) internal {
        // Update the fees for the partner and token
        feesStorage().fees[partner][token] += amount;
    }

    /// @notice Allows a partner to withdraw their collected fees
    /// @param token The address of the token to withdraw
    /// @param partner The address of the partner
    /// @param amount The amount of fees to withdraw
    /// @param recipient The address to transfer the fees to
    function withdrawFees(address token, address partner, uint256 amount, address recipient) internal {
        // Get the fees storage reference
        FeeStorage storage fs = feesStorage();
        // Check if the partner has enough fees to withdraw
        if (fs.fees[partner][token] < amount) {
            revert InsufficientFees();
        }
        // Update the fees for the partner and token
        fs.fees[partner][token] -= amount;
        // Transfer the fees to the recipient
        _transferFees(partner, recipient, token, amount);
    }

    /// @notice Allows a partner to withdraw all their collected fees for a specific token
    /// @param token The address of the token to withdraw (use address(0) for ETH)
    /// @param partner The address of the partner
    /// @param recipient The address to transfer the fees to
    /// @return amount The amount of fees withdrawn
    function withdrawAllFees(address token, address partner, address recipient) internal returns (uint256 amount) {
        // Get the fees storage reference
        FeeStorage storage fs = feesStorage();
        // Get the amount of fees for the partner and token
        amount = fs.fees[partner][token];
        // Check if the partner has any fees to withdraw
        if (amount != 0) {
            // Update the fees for the partner and token
            delete fs.fees[partner][token];
            // Transfer the fees to the recipient
            _transferFees(partner, recipient, token, amount);
        }
    }

    /// @notice Allows a partner to withdraw all fees for multiple tokens in a single transaction
    /// @param tokens An array of token addresses to withdraw
    /// @param partner The address of the partner
    /// @param recipient The address to transfer the fees to
    function batchWithdrawAllFees(address[] calldata tokens, address partner, address recipient) internal {
        // Iterate over the tokens
        for (uint256 i = 0; i < tokens.length; i++) {
            // Withdraw the fees for the partner and token
            withdrawAllFees(tokens[i], partner, recipient);
        }
    }

    /// @notice Gets the amount of collected fees for a partner and token
    /// @param token The address of the token
    /// @param partner The address of the partner
    /// @return The amount of collected fees
    function getCollectedFees(address token, address partner) internal view returns (uint256) {
        return feesStorage().fees[partner][token];
    }

    /// @notice Gets collected fees for a partner for specified tokens
    /// @param tokens An array of token addresses to check
    /// @param partner The address of the partner
    /// @return amounts An array of collected fee amounts corresponding to the input tokens
    function batchGetCollectedFees(
        address[] calldata tokens,
        address partner
    )
        internal
        view
        returns (uint256[] memory amounts)
    {
        FeeStorage storage fs = feesStorage();
        amounts = new uint256[](tokens.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            amounts[i] = fs.fees[partner][tokens[i]];
        }
    }

    /*//////////////////////////////////////////////////////////////
                                TRANSFER
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfers the fees to the partner, either in ETH or ERC20 tokens
    /// @param partner The address of the partner
    /// @param recipient The address of the recipient
    /// @param token The address of the token
    /// @param amount The amount of fees to transfer
    function _transferFees(address partner, address recipient, address token, uint256 amount) private {
        // Check partner address
        if (recipient == address(0)) {
            recipient = msg.sender;
        }
        // Transfer ETH or ERC20 tokens to the partner
        if (token == ERC20UtilsLib.ETH_ADDRESS) {
            recipient.safeTransferETH(amount);
        } else {
            token.safeTransfer(recipient, amount);
        }
        // Emit the FeesWithdrawn event
        emit FeesWithdrawn(partner, token, amount, recipient);
    }

    /*//////////////////////////////////////////////////////////////
                              FEE CLAIMER
    //////////////////////////////////////////////////////////////*/

    /// @notice Verifies that the caller has the fee claimer role
    function isProtocolFeeClaimer() internal view {
        if (msg.sender != feesStorage().feeClaimer) {
            revert UnauthorizedAccount(msg.sender);
        }
    }

    /// @notice Allows the owner to set the fee claimer
    /// @param feeClaimer The address of the fee claimer
    function setFeeClaimer(address feeClaimer) internal {
        feesStorage().feeClaimer = feeClaimer;
        // emit the FeeClaimerSet event
        emit FeeClaimerSet(feeClaimer);
    }

    /// @notice Gets the address of the fee claimer
    /// @return The address of the fee claimer
    function getFeeClaimer() internal view returns (address) {
        return feesStorage().feeClaimer;
    }
}
