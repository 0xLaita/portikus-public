// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Contracts
import { Factory } from "@factory/Factory.sol";
import { Registry } from "@registry/Registry.sol";

//  _____                                                                  _____
// ( ___ )----------------------------------------------------------------( ___ )
//  |   |                                                                  |   |
//  |   |                                                                  |   |
//  |   |                                                                  |   |
//  |   |   '||''|.                    .    ||  '||                        |   |
//  |   |    ||   ||   ...   ... ..  .||.  ...   ||  ..  ... ...   ....    |   |
//  |   |    ||...|' .|  '|.  ||' ''  ||    ||   || .'    ||  ||  ||. '    |   |
//  |   |    ||      ||   ||  ||      ||    ||   ||'|.    ||  ||  . '|..   |   |
//  |   |   .||.      '|..|' .||.     '|.' .||. .||. ||.  '|..'|. |'..|'   |   |
//  |   |                                                                  |   |
//  |   |                                                                  |   |
//  |___|                                                                  |___|
// (_____)----------------------------------------------------------------(_____)

/// @title Portikus V2
/// @notice The V2 implementation of the Portikus protocol, consisting of the following components:
///        - Factory: A factory for creating modular adapter contracts
///        - Registry: A registry of verified agents that can execute orders on behalf of users and modules that can be
///                    installed by the adapter contracts to expand their functionality
/// @author Laita Labs
contract PortikusV2 is Factory, Registry {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) Registry(_owner) { }
}
