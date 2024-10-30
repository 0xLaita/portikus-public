# PortikusV2 [![Github Actions][gha-badge]][gha] ![Coverage][coverage-badge] [![Foundry][foundry-badge]][foundry] [![License: MIT][license-badge]][license]

## Overview

Portikus is an **_intent-based protocol_** designed to facilitate **_gasless swaps_** through the execution of **_signed
user intents_** by authorized **_agents_**. The protocol's architecture is centered around a **_registry_** of agents
and modules and a **_factory_** for **_adapter_** creation.

Key aspects of the protocol include:

1. **Intent Execution**: The core logic for intent execution is encapsulated within modular **_contracts_**
   (**_modules_**) that can be dynamically installed on adapters.
2. **Permission Management**: The protocol implements permission controls, ensuring that only **_authorized agents_**
   can execute intents.
3. **Modularity and Extensibility**: Portikus is designed with a focus on flexibility, allowing for integration of new
   modules to extend functionality or modify execution strategies.

## Glossary

**Portikus**: The central contract of the protocol, responsible for:

- Managing the registry of agents and modules
- Facilitating the creation of new adapters
- Enforcing system-wide permissions and rules

**Agent**: An entity authorized to execute intents on behalf of users.

- Can be either an Externally Owned Account (EOA) or a smart contract
- Must be registered and explicitly authorized within the protocol
- Interacts with adapters to execute user intents

**Module**: A contract defining specific logic for intent execution.

- Registered within the Portikus protocol
- Can be dynamically installed on adapters
- Allows for diverse execution strategies (e.g., different swap mechanisms, fee structures)
- Facilitates the addition of new functionalities to adapters (e.g., fee collection, complex order types)
- Enables adapter functionality extensibility without requiring full system redeployment

**Adapter**: A contract created via the Portikus adapter factory, inspired by the Diamond Proxy (ERC-2535) pattern for
modularity and ERC-7201 for storage collision avoidance.

- Allows for dynamic installation and uninstallation of registered modules
- Serves as the primary interaction point for both users (approvals) and agents (intent execution)
- Implements a modular architecture, enabling customization of behavior through module composition
- Facilitates upgradability and extensibility of the protocol's execution logic

**Intent**: A signed message containing the user's desired input and output assets, along with additional parameters for
execution.

- Secured by EIP-712 compliant signatures
- Uses nonces to prevent replay attacks
- Can be executed by authorized agents on behalf of users

**Executor**: An external contract responsible for executing swaps for swap settlement modules.

- Implements the `IExecutor` interface for compatibility with the Portikus protocol
- Allows for flexible and customizable swap execution strategies
- Agents can choose the appropriate executor when executing intents, based on their requirements.

**Fees**: The fee system in Portikus V2 is implemented through all of the settlement modules and the `FeeClaimerModule`.
The fees are collected by the adapters and distributed to the partners and the protocol. The fee structure is as
follows:

- When there's a surplus (received amount > expected amount):

  - Protocol Fee: 50% of the surplus.
  - Partner Fee: Either a fixed percentage (up to 2%) of the remaining amount after protocol fee deduction, or the
    remaining 50% of the surplus.

- When there's no surplus (received amount <= expected amount):
  - Protocol Fee: None.
  - Partner Fee: Up to 2% of the received amount, if specified.

## Folder Structure

```
.
├── script
│   └── Deploy_Portikus.s.sol  # Deployment script for Portikus
├── src
│   ├── PortikusV2.sol         # Entrypoint contract for Portikus V2
│   ├── adapter                # Adapter-related contracts
│   ├── executors              # Executor contracts and interfaces
│   ├── factory                # Factory contract
│   ├── interfaces             # Core interfaces for Portikus and utilities
│   ├── modules                # Module contracts, interfaces, and libraries
│   ├── registry               # Registry contract
│   └── types                  # Type definitions
└── test
    ├── fork                   # Fork-based tests
    ├── integration            # Integration tests
    ├── mocks                  # Mock contracts for testing
    ├── unit                   # Unit tests
    └── utils                  # Utility contracts for testing
```

## Detailed Explanation

### 1. script

- **`Deploy_Portikus.s.sol`**: Deployment script for the Portikus protocol. Handles initialization and deployment of
  various contracts in the correct order, setting up the entire system.

### 2. src (Source Code)

**`PortikusV2.sol`** Main contract for the Portikus V2 protocol. Imports the factory and registry contracts.

**adapter/**

- **`Adapter.sol`**: The code for a Portikus adapter, created using the Portikus factory, allows management of modules.
- **interfaces/**
  - **`IAdapter.sol`**: Interface for the Adapter contract.
  - **`IERC173.sol`**: Standard interface for contract ownership.
  - **`IErrors.sol`**: Interface defining custom errors for the adapter.

**executors/**

- **example/**
  - **`AugustusExecutor.sol`**: An example executor that uses the Augustus protocol for token swaps.
  - **`ThreeStepExecutor.sol`**: An example executor that uses a three-step process for token swaps.
- **interfaces/**
  - **`IExecutor.sol`**: Standard interface for executor contracts.
- **libraries/**
  - **`ExecutorLib.sol`**: Library containing shared functionality for executors.

**factory/**

- **`Factory.sol`**: Contract for creating new instances of adapters.

**interfaces/**

- **portikus/**
  - **`IErrors.sol`**: Defines custom errors for the main protocol.
  - **`IFactory.sol`**: Interface for the factory contract.
  - **`IRegistry.sol`**: Interface for the registry contract.
- **util/**
  - **`IEIP712.sol`**: Interface for EIP-712 signature standard.
  - **`IERC1271.sol`**: Interface for ERC-1271 signature validation standard.

**modules/**

- **base/**
  - **`BaseModule.sol`**: Base contract for all modules.
  - **`FeeClaimerModule.sol`**: Module for managing and claiming fees.
  - **`NonceManagementModule.sol`**: Module for managing transaction nonces.
- **interfaces/**: Interfaces for various modules (`IFeeClaimerModule`, `IModule`, `INonceManagementModule`).
- **libraries/**: Utility libraries (`ERC20Utils`, `FeeManager`, `OrderHash`, `Signature`, etc.).
- **settlement/**
  - Various settlement modules (`DirectSettlement`, `FillableDirectSettlement`, `FillableSwapSettlement`,
    `SwapSettlement`).
  - Handles different types of order settlements and swap executions.
- **util/**
  - **`EIP712.sol`**: Implementation of the EIP-712 standard for structured data hashing and signing.

**registry/**

- **`Registry.sol`**: Central registry contract, manages agents and modules.

**types/**

- **`Order.sol`**: Defines the structure and types for orders in the protocol.

### 3. test

- **fork/**: Fork-based tests, used for testing against a live network fork.
- **integration/**: Integration tests to ensure different components work together correctly.
- **mocks/**: Mock contracts used for isolating and testing specific functionalities.
- **unit/**: Unit tests for individual contract functions and modules.
- **utils/**: Utility contracts and functions to assist in testing.

## Modules

Portikus V2 implements a modular architecture with several specialized modules to handle different aspects of the
protocol. The modules can be installed on **_adapters_** to extend their functionality and provide additional features.

### Settlement Modules

1. **`DirectSettlementModule`**

   - Handles direct settlement of orders using the agent's funds.
   - Verifies orders, transfers input assets to the agent, and output assets to the beneficiary.
   - Supports single and batch settlements.
   - Implements fee processing and emits settlement events.

2. **`FillableDirectSettlementModule`**

   - Extends `DirectSettlementModule` to support partial order filling.
   - Tracks filled amounts for orders and allows multiple partial settlements.
   - Implements additional checks and events for partial fills.

3. **`SwapSettlementModule`**

   - Manages swap-based order settlements using external executor contracts.
   - Verifies orders, transfers input assets to the executor, and output assets to the beneficiary.
   - Supports single and batch swap settlements.
   - Implements dynamic execution of swap logic through executor contracts.

4. **`FillableSwapSettlementModule`**
   - Extends `SwapSettlementModule` to support partial order filling.
   - Supports partial filling of swap-based orders.
   - Tracks filled amounts and allows multiple partial swap settlements.

### Utility Modules

5. **`FeeClaimerModule`**

   - Allows partners to claim their collected fees.
   - Provides functions for withdrawing fees for single or multiple tokens.
   - Supports querying collected fees for partners.

6. **`NonceManagementModule`**
   - Manages nonce invalidation and querying for enhanced security.
   - Allows users to invalidate single or multiple nonces.
   - Provides functions to check if nonces are used or valid.

### Base Modules

7. **`BaseModule`**

   - Serves as the foundation for other modules.
   - Implements common functionality and interfaces.

8. **`BaseSettlementModule`**
   - Extends `BaseModule` with settlement-specific features.
   - Provides common functions and checks used across settlement modules.

## Executors

Portikus V2 implements executor contracts that handle the actual execution of swaps. These executors allow msg.sender
context to be passed to external contracts, enabling flexible and customizable swap execution strategies. Currently
there are two example executors, but more can be added as needed. Agents can choose the appropriate executor based on
their requirements, using an existing one or creating a new one.

### 1. `ThreeStepExecutor`

This executor implements a three-step process for executing swaps, providing flexibility and the ability to perform
additional actions before and after the main execution (e.g. flash loans).

Key features:

- Executes three steps: before, main, and after.
- Each step can have its own calldata and execution address.
- Supports fee transfer to a specified recipient.
- Handles both ETH and ERC20 token transfers.
- Allows for complex swap strategies with pre- and post-execution actions.

### 2. `AugustusExecutor`

This executor is optimized to interact specifically with the Augustus V6 contract for token swaps.

Key features:

- Executes a single step on the Augustus V6 contract.
- Handles approval of source tokens if necessary.

### Common Features of Executors

1. **`IExecutor` Interface**: Both executors implement the `IExecutor` interface, ensuring a consistent execution
   method.
2. **Fee Handling**: Executors manage fee transfers to specified recipients.
3. **Flexible Execution**: Executors use external calls with provided calldata, allowing for adaptable execution logic.
4. **ETH Handling**: Both include a `receive()` function to handle incoming ETH transfers.

## Setup

### Install

Install bun dependencies:

```sh
$ bun install
```

Install forge dependencies:

```sh
$ forge install
```

## Scripts

This is a list of the most frequently needed commands.

### Build

Build the contracts:

```sh
$ forge build
```

### Clean

Delete the build artifacts and cache directories:

```sh
$ forge clean
```

### Coverage

Generate test coverage with lcov report

```sh
$ bun run test:coverage:report
```

### Lint

Lint the contracts:

```sh
$ bun run lint
```

### Test

Run the tests:

```sh
$ forge test
```

### Deploy

Add env variables and run the following command to deploy the contracts:

```sh
$ forge script script/Deploy_Portikus.s.sol:Deploy \
--rpc-url $RPC_URL \
--broadcast \
--slow \
-vvv
```

## License

This project is licensed under MIT.

[coverage-badge]: assets/coverage-badge.svg
[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg
[license]: https://opensource.org/licenses/MIT
[license-badge]: https://img.shields.io/badge/License-MIT-blue.svg
[gha]: https://github.com/0xLaita/portikus-public/actions/
[gha-badge]: https://github.com/0xLaita/portikus-public/actions/workflows/ci.yml/badge.svg
