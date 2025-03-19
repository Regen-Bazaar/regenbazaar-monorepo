# Impact Buyer Smart Contract

This smart contract enables retail users to purchase impact products on the
Stellar blockchain using Soroban.

## Overview

The Impact Buyer contract provides functionality for:

1. Listing impact products with detailed information including impact metrics
2. Purchasing impact products using Stellar tokens
3. Tracking purchase history
4. Updating product information

## Deployed Testnet Contract

The Impact Buyer Contract is deployed on the Stellar Testnet with the following
details:

- **Contract ID**: `CBQMGNXROC5YZ6VXZPOH4T545QWU36DP66KYRNB3QKGIR4LARWRRANF5`
- **Network**: Stellar Testnet
- **Admin**: `GA5NODJI2XMEQGDP7UHYJJYLRFSONXAFQ4SGFFXNXC2VR57DOY3JSUDW`
- **Fee Percentage**: 2.5% (25/1000)

You can view the contract on Stellar Expert Explorer:
[Impact Buyer Contract](https://stellar.expert/explorer/testnet/contract/CBQMGNXROC5YZ6VXZPOH4T545QWU36DP66KYRNB3QKGIR4LARWRRANF5)

## Contract Structure

The contract consists of two main data structures:

1. **ImpactProduct**: Represents an NFT impact product with properties like
   price, seller, token, NFT contract, NFT token ID, and impact metrics.
2. **Purchase**: Represents a purchase record with details like product ID,
   buyer, total price, platform fee, NFT contract, NFT token ID, and timestamp.

## Functions

### Admin Functions

- `initialize(admin: Address, fee_percentage: u32)`: Initializes the contract
  with an admin address and fee percentage.
- `pause_contract(admin: Address)`: Pauses the contract to prevent new listings
  and purchases.
- `unpause_contract(admin: Address)`: Unpauses the contract.
- `update_fee_percentage(admin: Address, new_fee_percentage: u32)`: Updates the
  platform fee percentage.
- `get_admin(env: Env)`: Returns the admin address.
- `get_config(env: Env)`: Returns the contract configuration.

### Seller Functions

- `list_product(seller: Address, price: i128, token: Address, nft_contract: Address, nft_token_id: String, impact_metrics: Map<String, String>) -> u32`:
  Lists a new NFT impact product and returns the product ID. NFT is held in
  escrow by the contract.
- `unlist_product(seller: Address, product_id: u32) -> bool`: Unlists a product
  and returns the NFT to the seller.
- `update_product(seller: Address, product_id: u32, price: Option<i128>, impact_metrics: Option<Map<String, String>>) -> bool`:
  Updates an existing product's details.
- `get_seller_products(seller: Address) -> Vec<ImpactProduct>`: Returns all
  products listed by a seller.

### Buyer Functions

- `buy_product(buyer: Address, product_id: u32) -> u32`: Purchases an NFT
  product and returns the purchase ID.
- `batch_buy_products(buyer: Address, product_ids: Vec<u32>) -> Vec<u32>`:
  Purchases multiple NFT products in a single transaction.
- `get_buyer_purchases(buyer: Address) -> Vec<Purchase>`: Retrieves a buyer's
  purchase history.

### Query Functions

- `get_product(product_id: u32) -> Option<ImpactProduct>`: Retrieves details of
  a specific product.
- `get_active_products() -> Vec<ImpactProduct>`: Lists all actively listed
  products.
- `get_all_products() -> Vec<ImpactProduct>`: Lists all products (active and
  inactive).
- `get_purchase(purchase_id: u32) -> Option<Purchase>`: Retrieves details of a
  specific purchase.

## Building and Testing

To build the contract:

```bash
stellar contract build
```

To run tests:

```bash
cargo test
```

## Usage Flow

1. **Initialize Contract**: Set up the contract with an admin address and fee
   percentage.
2. **List NFT Products**: Sellers list NFT impact products with price, token
   information, and impact metrics. The NFT is transferred to the contract
   (escrow).
3. **Browse Products**: Buyers can view available NFT products.
4. **Purchase NFTs**: Buyers purchase NFTs, which transfers tokens to the seller
   and fee to admin, then transfers the NFT from the contract to the buyer.
5. **Unlist Products**: Sellers can unlist their products and get their NFTs
   back if they haven't been sold.
6. **View Purchase History**: Buyers and sellers can view their transaction
   history.
7. **Update Products**: Sellers can update product price and impact metrics as
   needed.
8. **Admin Controls**: Admin can pause/unpause the contract and update fee
   percentages.

## Interacting with the Contract

To interact with the deployed contract on testnet, use the Stellar CLI:

```bash
# Initialize (only needs to be done once)
stellar contract invoke --id CBQMGNXROC5YZ6VXZPOH4T545QWU36DP66KYRNB3QKGIR4LARWRRANF5 --source YOUR_KEY --network testnet -- initialize --admin ADMIN_ADDRESS --fee_percentage 25

# Check configuration
stellar contract invoke --id CBQMGNXROC5YZ6VXZPOH4T545QWU36DP66KYRNB3QKGIR4LARWRRANF5 --source YOUR_KEY --network testnet -- get_config

# List product (seller must own the NFT)
stellar contract invoke --id CBQMGNXROC5YZ6VXZPOH4T545QWU36DP66KYRNB3QKGIR4LARWRRANF5 --source YOUR_KEY --network testnet -- list_product --seller SELLER_ADDRESS --price 100000000 --token TOKEN_ADDRESS --nft_contract NFT_CONTRACT_ADDRESS --nft_token_id "NFT_ID" --impact_metrics '{}'

# Buy product
stellar contract invoke --id CBQMGNXROC5YZ6VXZPOH4T545QWU36DP66KYRNB3QKGIR4LARWRRANF5 --source YOUR_KEY --network testnet -- buy_product --buyer BUYER_ADDRESS --product_id 1
```
