# Impact Buyer Smart Contract

This smart contract enables retail users to purchase impact products on the
Stellar blockchain using Soroban.

## Overview

The Impact Buyer contract provides functionality for:

1. Listing impact products with detailed information including impact metrics
2. Purchasing impact products using Stellar tokens
3. Tracking purchase history
4. Updating product information

## Contract Structure

The contract consists of two main data structures:

1. **ImpactProduct**: Represents an impact product with properties like name,
   description, price, seller, token, quantity, and impact metrics.
2. **Purchase**: Represents a purchase record with details like product ID,
   buyer, quantity, total price, and timestamp.

## Functions

### Admin Functions

- `initialize(admin: Address)`: Initializes the contract with an admin address.

### Seller Functions

- `list_product(seller: Address, name: String, description: String, price: i128, token: Address, quantity: u32, impact_metrics: Map<String, String>) -> u32`:
  Lists a new impact product and returns the product ID.
- `update_product(seller: Address, product_id: u32, name: Option<String>, description: Option<String>, price: Option<i128>, quantity: Option<u32>, impact_metrics: Option<Map<String, String>>) -> bool`:
  Updates an existing product's details.

### Buyer Functions

- `buy_product(buyer: Address, product_id: u32, quantity: u32) -> u32`:
  Purchases a product and returns the purchase ID.
- `get_buyer_purchases(buyer: Address) -> Vec<Purchase>`: Retrieves a buyer's
  purchase history.

### Query Functions

- `get_product(product_id: u32) -> Option<ImpactProduct>`: Retrieves details of
  a specific product.
- `list_products() -> Vec<ImpactProduct>`: Lists all available products.
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

1. **Initialize Contract**: Set up the contract with an admin address.
2. **List Products**: Sellers list impact products with details and impact
   metrics.
3. **Browse Products**: Buyers can view available products.
4. **Purchase Products**: Buyers purchase products, which transfers tokens and
   updates inventory.
5. **View Purchase History**: Buyers can view their purchase history.
6. **Update Products**: Sellers can update product details as needed.
