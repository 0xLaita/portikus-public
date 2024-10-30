// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title Fillable Storage Manager Library
/// @notice A library for managing fillable orders within adapter modules inside the PortikusV2 protocol
library FillableStorageLib {
    /*//////////////////////////////////////////////////////////////
                                CONSTANT
    //////////////////////////////////////////////////////////////*/

    /// @notice 100% in basis points
    uint256 internal constant HUNDRED_PERCENT = 10_000;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice keccak256(abi.encode(uint256(keccak256("FillableStorageLib.fillable")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 internal constant FILLABLE_SLOT = 0x55818b417247258199b5342c0eba0e207dcef5a8388eb3b27657217637448d00;

    /// @custom:storage-location erc7201:FillableStorageLib.fillable
    struct FillableStorage {
        // orderHash => filled amount (in wei)
        mapping(bytes32 orderHash => uint256 filledAmount) filled;
    }

    /// @notice Get the pointer to the fillable storage slot
    /// @return fs The pointer to the fillable storage slot
    function fillableStorage() internal pure returns (FillableStorage storage fs) {
        bytes32 slot = FILLABLE_SLOT;
        assembly {
            fs.slot := slot
        }
    }

    /*//////////////////////////////////////////////////////////////
                                  SET
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates the filled amount for a specific order, adding the fill amount to the current filled amount
    /// @param orderHash The hash of the order
    /// @param fillAmount The amount to fill
    /// @return newTotalFilled The new total filled amount
    function updateFilled(bytes32 orderHash, uint256 fillAmount) internal returns (uint256 newTotalFilled) {
        FillableStorage storage fs = fillableStorage();
        uint256 currentFilled = fs.filled[orderHash];
        uint256 newFilled = currentFilled + fillAmount;

        fs.filled[orderHash] = newFilled;
        return newFilled;
    }

    /*//////////////////////////////////////////////////////////////
                                  GET
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the filled amount for a specific order
    /// @param orderHash The hash of the order
    /// @return The amount filled for the order
    function getFilledAmount(bytes32 orderHash) internal view returns (uint256) {
        return fillableStorage().filled[orderHash];
    }
}
