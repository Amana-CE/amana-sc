# Amana Chain Entities

A blockchain-based platform that transforms SACCO operations through transparent governance and decentralized finance solutions built on Cardano.

## Overview

Amana Chain Entities (Amana CE) addresses key challenges facing Savings and Credit Cooperative Organizations (SACCOs):

- **Funds Mismanagement** - Through transparent blockchain transactions
- **Poor Governance** - With decentralized decision-making
- **Limited Access** - Eliminating geographical constraints

## Smart Contract Architecture

Our platform consists of three interconnected smart contracts:

```
┌──────────────────┐    ┌───────────────────┐    ┌──────────────────┐
│  Entity Registry │    │     Treasury      │    │    Governance    │
│    Contract      │◄───┤    Management     │◄───┤     Contract     │
│                  │    │     Contract      │    │                  │
└────────┬─────────┘    └─────────┬─────────┘    └────────┬─────────┘
         │                        │                       │
         ▼                        ▼                       ▼
┌────────────────────────────────────────────────────────────────────┐
│                           Cardano Blockchain                        │
└────────────────────────────────────────────────────────────────────┘
```

- **Entity Registry**: Manages SACCO entities and their members
- **Treasury Management**: Handles financial operations with multi-signature approval
- **Governance**: Facilitates decision-making through proposals and voting

## Documentation

Detailed documentation is available in the `/documentation` directory:

- [Entity Registry](./documentation/ENTITY_REGISTRY.md)
- [Treasury Management](./documentation/TREASURY_MANAGEMENT.md)
- [Governance](./documentation/GOVERNANCE.md)

## Getting Started

### Requirements

- Aiken v1.1.15 or higher
- Cardano development environment

### Build and Test

```bash
# Build the contracts
aiken build

# Run the test suite
aiken check
```

## Key Features

### Entity Registry
- SACCO entity creation and management
- Member registration with status tracking
- Admin management with multi-admin support

### Treasury Management
- Transparent fund management
- Multi-signature transaction approval
- Comprehensive transaction history

### Governance
- Proposal creation and management
- Transparent voting system
- Automatic execution of approved decisions

## Project Structure

```
amana-contracts/
├── aiken.toml               # Project configuration
├── lib/                     # Shared library code
│   ├── entity_registry/     # Entity Registry types
│   ├── governance/          # Governance types
│   └── treasury_management/ # Treasury Management types
├── validators/              # Smart contracts
│   ├── entity_registry/     # Entity Registry contract
│   ├── governance/          # Governance contract
│   └── treasury_management/ # Treasury Management contract
└── documentation/           # Detailed documentation
```

## License

Apache License 2.0