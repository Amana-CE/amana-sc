# Amana Chain Entities (Amana CE)

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Aiken](https://img.shields.io/badge/aiken-v1.1.15-blue)](https://aiken-lang.org)
[![Cardano](https://img.shields.io/badge/cardano-plutus%20v3-green)](https://cardano.org)

Amana Chain Entities (Amana CE) is a blockchain-based platform designed to revolutionize Savings and Credit Cooperative Organizations (SACCOs) in Africa by leveraging Cardano blockchain technology to enhance transparency, improve governance, and increase operational efficiency.

## 🌟 Features

Amana CE offers a modular platform with the following components:

- **Entity Management**: Create and manage digital SACCO entities with configurable parameters
- **Member Management**: Register and manage members with role-based permissions
- **Treasury Management**: Handle financial operations with secure multi-signature approval
- **Governance System**: Facilitate transparent decision-making through on-chain voting

## 📋 Project Structure

The smart contracts are organized into a modular architecture:

```
amana-contracts/
├── lib/                        # Libraries and shared utilities
│   ├── common/                 # Common utilities and shared types
│   ├── entity/                 # Entity registration module
│   ├── treasury/               # Treasury management module
│   └── governance/             # Governance module
└── validators/                 # Main validator scripts
    ├── entity_registry.ak      # Entity registry validator
    ├── treasury.ak             # Treasury management validator
    └── governance.ak           # Governance validator
```

## 🚀 Getting Started

### Prerequisites

- [Aiken](https://aiken-lang.org/installation-guide) (v1.1.15 or higher)
- [Cardano node](https://docs.cardano.org/getting-started/installing-the-cardano-node/) (optional for local testing)
- Node.js and npm (for off-chain code)

### Installation

1. Clone this repository
   ```bash
   git clone https://github.com/amanace/amana-contracts.git
   cd amana-contracts
   ```

2. Build the smart contracts
   ```bash
   aiken build
   ```

3. Run tests
   ```bash
   aiken check
   ```

## 📝 Usage

### Building the Smart Contracts

```bash
aiken build
```

This will compile the contracts and generate a `plutus.json` file containing compiled contract code.

### Testing the Smart Contracts

```bash
aiken check
```

### Generating Documentation

```bash
aiken docs
```

This will generate HTML documentation for the project.

### Viewing Contract Addresses

```bash
aiken blueprint address
```

## 📘 Documentation

- [Project Structure](docs/project-structure.md)
- [Testing Guide](docs/testing-guide.md)
- [Deployment Guide](docs/deployment-guide.md)

## 🔧 Development

We welcome contributions to Amana CE! Please see our [Contribution Guidelines](CONTRIBUTING.md) for details.

### Development Workflow

1. Create a feature branch
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes and test them
   ```bash
   aiken check
   ```

3. Build the contracts to ensure they compile
   ```bash
   aiken build
   ```

4. Submit a pull request

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgements

- The [Aiken](https://aiken-lang.org) team for their amazing Cardano smart contract language
- The [Cardano](https://cardano.org) community for their support and inspiration
- All contributors to this project

## 📬 Contact

For questions or support, please open an issue on this repository or contact the maintainers.
