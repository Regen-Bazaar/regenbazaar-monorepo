# Marketplace Smart Contract - Supra Move

## Overview

Deployed Contract (check wallet modules) [Testnet](https://testnet.suprascan.io/tx/0x128f338869fc2d0094f4dd7d5ec1bf9b065f846b2a690acfa45e2e19969f504d/f)

The Marketplace smart contract is built using **Move** on the **Supra Network**. It provides a decentralized marketplace where users can:

- **List** Impact products for sale.
- **Buy** listed products using SupraCoin ($SUPRA).
- **Unlist** products before they are sold.
- **Transfer ownership** of the marketplace to a new admin.
- **Withdraw fees** collected from transactions.
- **Pause/unpause** the marketplace for maintenance.

## Features

### 1. **Marketplace Creation**

- The marketplace is initialized by an **admin** using the `init_marketplace_and_get_address` function.
- It requires a **name** and a **fee percentage** (e.g., 2% of sales as platform fees).

### 2. **Listing a Product**

- Sellers can list NFT-based products using `list_product_internal`.
- Requires:
  - **Product Name**
  - **NFT Object**
  - **Price in SupraCoin ($SUPRA)**
  - **Marketplace Address**

### 3. **Buying a Product**

- Users can purchase products using the `buy_product` function.
- The contract:
  - Transfers **funds** from the buyer to the seller (minus fees).
  - Transfers **NFT ownership** to the buyer.
  - Ensures a product **cannot be sold twice**.

### 4. **Unlisting a Product**

- Only the **seller** can remove a listed product before it is sold using `unlist_product`.
- After a product is unlisted, the NFT is **returned to the seller**.

### 5. **Marketplace Fees**

- A percentage of each sale is **collected as fees**.
- The admin can withdraw accumulated fees using `withdraw_fees`.

### 6. **Marketplace Ownership Transfer**

- The admin can **transfer ownership** using `transfer_ownership`.
- The new owner must **claim ownership** using `claim_ownership`.
- Admin transfers can be **canceled** before being claimed.
- The admin can **permanently disable** ownership by setting it to `0x0`.

### 7. **Marketplace Management**

- The admin can **pause/unpause** the marketplace using `update_pause`.
- When paused, **new transactions (buys & listings) are disabled**.

## Installation & Setup

### **1. Install Supra CLI with Docker**

Follow the official installation guide:
[Install Supra CLI](https://docs.supra.com/move/getting-started/supra-cli-with-docker)

### **2. Compile the Marketplace Contract**

```sh
supra move tool compile --package-dir /supra/configs/move_workspace/<PROJECT_NAME>
```

### **3. Run Tests**

To ensure the contract works correctly, run the unit tests:

```sh
supra move tool test --package-dir /supra/configs/move_workspace/<PROJECT_NAME>
```

### **4. Deploy the Contract**

Deployment requires specifying a named address within the `move.toml` file.

```sh
supra move tool publish --package-dir /supra/configs/move_workspace/<PROJECT_NAME> --profile <YOUR_PROFILE> --url <RPC_URL>
```

For the latest RPC URL, check the **Supra Network Information** page.

## Smart Contract Tests

This contract includes extensive unit tests covering:

- **Listing and unlisting products**
- **Purchasing with correct funds**
- **Handling insufficient balance purchases**
- **Ensuring only sellers can unlist**
- **Ownership transfer and claim validation**
- **Marketplace pausing and fee withdrawals**
