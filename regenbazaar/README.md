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
git clone https://github.com/Regen-Bazaar/regenbazaar-monorepo.git
cd regenbazaar-monorepo
cd regenbazaar
npm install
```

### 2. Start a local envirobment like Ganache using anvil

```bash
# Launch Anvil via Foundry
anvil
```

### 3. Compile smart contracts

```bash
cd packages/foundry
forge install OpenZeppelin/openzeppelin-contracts   # only first time
forge build --via-ir # We're using --via-ir to solve "Stack too deep" errors .This flag enables Solidity's Intermediate Representation optimization
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

- **Imports not found**  
  Ensure remappings in `packages/foundry/remappings.txt` or `foundry.toml`:  
  ```
  @openzeppelin/=lib/openzeppelin-contracts/
  ```
- **Linearization errors**  
  When using multiple ERC721 extensions, put the more-specific contract first in the `is` list:
  ```solidity
  contract MyNFT is ERC721URIStorage, ERC721Enumerable { … }
  ```





---

© 2024 Regen Bazaar · Built on Scaffold-ETH 2 · MIT License  