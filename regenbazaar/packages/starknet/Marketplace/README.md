# Marketplace Smart Contract

This repository contains the implementation of a marketplace smart contract written in Cairo for StarkNet, a Layer 2 scaling solution for Ethereum. The contract facilitates the buying and selling of tokenized assets through direct listings.

## Functionality Overview

### `validate_direct_listing_sale`

The `validate_direct_listing_sale` function is a core part of the marketplace contract. It ensures that all conditions for a direct listing sale are met before the transaction is executed. This validation process helps maintain the integrity of the marketplace by preventing invalid or unauthorized sales.

#### Key Responsibilities:
1. **Validate Token Quantity**:
   - Ensures that the listing has a positive quantity of tokens available.
   - Confirms that the quantity the buyer wants to purchase (`_quantityToBuy`) is greater than zero and does not exceed the available quantity in the listing.

2. **Validate Sale Window**:
   - Checks that the current block timestamp is within the sale's start and end time.

3. **Validate ERC20 Balance and Allowance**:
   - Verifies that the buyer (`_payer`) has sufficient ERC20 token balance and has approved the marketplace contract to spend the required amount (`settledTotalPrice`).

4. **Validate Ownership and Approval**:
   - Ensures that the seller (`_listing.tokenOwner`) owns the listed asset and has approved the marketplace contract to transfer the asset on their behalf.

#### Parameters:
- `self`: The contract state.
- `_listing`: The listing object containing details about the sale (e.g., token owner, asset contract, token ID, quantity, start and end time).
- `_payer`: The address of the buyer.
- `_quantityToBuy`: The quantity of tokens the buyer wants to purchase.
- `_currency`: The ERC20 token address used for payment.
- `settledTotalPrice`: The total price for the transaction.

#### Assertions:
- Validates that the token quantity and sale window are correct.
- Ensures the buyer has sufficient balance and allowance.
- Confirms the seller owns the asset and has approved the marketplace for transfer.

## Use Case

The `validate_direct_listing_sale` function is called during the execution of a direct sale to ensure all conditions are met before proceeding with the transaction. It is a critical component of the marketplace's functionality, ensuring secure and valid transactions.

## Prerequisites

- **Cairo**: The contract is written in Cairo, a programming language for StarkNet. Ensure you have the Cairo development environment set up.
- **StarkNet**: The contract is deployed on StarkNet, a Layer 2 scaling solution for Ethereum.

## How to Use

1. Clone the repository.
2. Set up the Cairo development environment.
3. Deploy the contract to StarkNet.
4. Interact with the contract using the provided functions to list, buy, and sell tokenized assets.


## Deployed Contract Address

The marketplace smart contract has been deployed to the following address:

- **StarkNet Contract Address**: `https://sepolia.starkscan.co/contract/0x7def7b451e1dd813c1781c241a7ea2365f88fbfa5dd7aad9c6b1a4e1d0e75b`



## License

This project is licensed under the MIT License. See the LICENSE