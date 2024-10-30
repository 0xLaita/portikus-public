// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

/// @dev A list of users to be used in tests
struct Users {
    /// @dev The default admin user
    UserData admin;
    /// @dev The random users
    UserData alice;
    UserData bob;
    UserData charlie;
    UserData dennis;
    /// @dev Malicious user
    UserData eve;
}

/// @dev User data
struct UserData {
    /// @dev The name of the user, used to create the private/public key pair
    string name;
    /// @dev The account address of the user
    address payable account;
}
