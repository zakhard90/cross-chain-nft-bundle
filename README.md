#  Cross-Chain NFT Bundle Marketplace

A PoC Solidity smart contract that enables cross-chain NFT bundle sales using Chainlink CCIP, supporting ERC1155 tokens and flexible bundle creation.

## Features
- Create NFT bundles with multiple tokens
- Cross-chain bundle purchases via Chainlink CCIP
- Quantity-based bundle sales
- Owner-controlled bundle management

## Contract Capabilities
- Bundle Creation: Owners can create bundles with:
  - Multiple NFT types
  - Specific quantities
  - Fixed pricing
- Cross-Chain Purchases: Buy bundles from different blockchain networks
- Bundle Deactivation: Owners can disable unsold bundles

## Dependencies
- OpenZeppelin Contracts
- Chainlink CCIP Contracts

## Cross-Chain Purchase Flow
1. Initiate purchase from source chain
2. CCIP relays message to destination chain
3. Bundle transferred to buyer
4. Payment sent to bundle creator

# Usage

##### Install dependencies and run tests

```
npm ci
npm run test
```

## License
This project is licensed under the MIT License - see the LICENSE file for details.
