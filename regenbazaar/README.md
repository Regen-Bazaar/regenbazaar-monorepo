# 🏗 Regen Bazaar Monorepo

<p align="center">
  <a href="https://docs.scaffoldeth.io">Scaffold-ETH 2 Docs</a> |
  <a href="https://scaffoldeth.io">Scaffold-ETH 2 Website</a>
</p>

> An open-source toolkit for building dapps on Ethereum.  
> Powers the Regen Bazaar platform frontend (Next.js, TypeScript, Wagmi/Viem) and smart contracts (Foundry).

---

## Requirements

- Node.js ≥ 18.18  
- Yarn (v1 or v2+)  
- Git  
- Foundry (Forge, Cast, Anvil)

---

## Quickstart

### 1. Clone & install

```bash
# Clone using SSH (recommended)
git clone https://github.com/trudransh/regenbazaar-monorepo.git
# Or with HTTPS
# git clone https://github.com/Regen-Bazaar/regenbazaar-monorepo.git

cd regenbazaar-monorepo
npm install
```

### 2. Start a local environment like Ganache using anvil

```bash
# Launch Anvil via Foundry
anvil
```

### 3. Compile smart contracts

```bash
cd regenbazaar/packages/foundry

# Clean and install dependencies (if you encounter issues)
rm -rf lib/forge-std/ lib/openzeppelin-contracts/
forge install foundry-rs/forge-std --no-commit
forge install OpenZeppelin/openzeppelin-contracts --no-commit

# Build contracts
forge compile
```

## Contract Structure

Inside `packages/foundry/contracts` you'll find:

- **tokens/REBAZToken.sol**  
  ERC20 governance & utility token  
- **tokens/ImpactProductNFT.sol**  
  ERC721 NFT for real-world impact projects  
- **factory/ImpactProductFactory.sol**  
  Factory to mint new ImpactProductNFTs  
- **marketplace/RegenBazaarMarketplace.sol**  
  Listing and trading of impact NFTs  
- **staking/ImpactProductStaking.sol**  
  Staking logic for REBAZ tokens & NFTs  
- **interfaces/**  
  All contract interfaces (IREBAZ, IImpactProductNFT, IImpactProductFactory, IImpactProductNFT, IImpactProductStaking)

---

## Troubleshooting

### Authentication Issues
If you encounter authentication errors with GitHub:
```bash
# Configure Git to use SSH instead of HTTPS for GitHub (if you have SSH set up)
git config --global url."git@github.com:".insteadOf "https://github.com/"
```

### Missing Dependencies
- If you see errors about missing files, ensure all dependencies are properly installed:
```bash
# Reinstall forge standard libraries
rm -rf lib/forge-std
forge install foundry-rs/forge-std --no-commit

# Reinstall OpenZeppelin
rm -rf lib/openzeppelin-contracts
forge install OpenZeppelin/openzeppelin-contracts --no-commit
```

### Import Errors
- Ensure remappings in `packages/foundry/remappings.txt` or `foundry.toml` include:  
  ```
  @openzeppelin/=lib/openzeppelin-contracts/
  forge-std/=lib/forge-std/src/
  ```

### Linearization errors
When using multiple ERC721 extensions, put the more-specific contract first in the `is` list:
```solidity
contract MyNFT is ERC721URIStorage, ERC721Enumerable { … }
```

---

© 2024 Regen Bazaar · Built on Scaffold-ETH 2 · MIT License  