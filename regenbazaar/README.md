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
### 4 Local Deployment with Anvil & Foundry
#### 4.1 Start Anvil ( Local Ethereum Blokchain node)
```bash
# Open a new terminal and run:
anvil --block-time 5
# This will start the local blockchain with a block time of 5 seconds
```
#### 4.2 Set up environment
```bash
# Open a new terminal and run:
cd regenbazaar/packages/foundry
```
#### 4.3 Set Private Key For Deployment
```bash
# Export the first Anvil account’s private key (this is always the same for local Anvil):
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```
#### 4.4 Deploy Contracts
```bash
# Run each command one by one, waiting for each to finish:

# 1. Deploy REBAZToken
forge script script/deploy/1_DeployREBAZToken.s.sol:DeployREBAZToken --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY --broadcast

# 2. Deploy ImpactProductNFT
forge script script/deploy/2_DeployImpactProductNFT.s.sol:DeployImpactProductNFT --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY --broadcast

# 3. Deploy ImpactProductStaking
forge script script/deploy/3_DeployImpactProductStaking.s.sol:DeployImpactProductStaking --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY --broadcast

# 4. Deploy RegenMarketplace
forge script script/deploy/4_DeployMarketplace.s.sol:DeployMarketplace --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY --broadcast

# 5. Deploy ImpactProductFactory
forge script script/deploy/5_DeployImpactProductFactory.s.sol:DeployImpactProductFactory --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY --broadcast
```
#### 4.5 Check Deployment Output 
Each deployment will print the contract address and status to your terminal.
You can also check `deployments/addresses.json` for all deployed addresses.

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