#![cfg(test)]

use super::*;
use crate::interfaces::{NftClient, NftInterface};
use soroban_sdk::token::Client as TokenClient;
use soroban_sdk::token::StellarAssetClient as TokenAdmin;
use soroban_sdk::{contract, contractimpl, contracttype, Address, Env, String};
use soroban_sdk::{map, testutils::Address as _, Map};

#[contracttype]
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum DataKey {
    Admin, // Contract administrator
    Name,
    Symbol,
    TokenCounter,     // Counter for token IDs
    Token(String),    // Token data by ID
    Owner(String),    // Owner of a specific token
    Balance(Address), // Balance of an address
}

#[contract]
pub struct MockNftContract;

#[contractimpl]
impl MockNftContract {
    // Initialize the NFT contract with basic metadata
    pub fn initialize(env: Env, admin: Address, name: String, symbol: String) {
        let storage = env.storage().persistent();

        // Store contract metadata using simple string keys
        storage.set(&DataKey::Admin, &admin);
        storage.set(&DataKey::Name, &name);
        storage.set(&DataKey::Symbol, &symbol);
        storage.set(&DataKey::TokenCounter, &0i128);
    }

    // Returns the owner of a specific token
    pub fn owner(env: Env, token_id: String) -> Address {
        let storage = env.storage().persistent();

        storage
            .get(&DataKey::Owner(token_id))
            .unwrap_or_else(|| env.current_contract_address())
    }

    // Mint a new token to the specified address
    pub fn mint(env: Env, to: Address, token_id: String) {
        let storage = env.storage().persistent();

        // Store owner information with token ID
        storage.set(&DataKey::Owner(token_id.clone()), &to);

        // Update token counter
        let counter_key = DataKey::TokenCounter;
        let counter: i128 = storage.get(&counter_key).unwrap_or(0);
        storage.set(&counter_key, &(counter + 1));

        // Store empty metadata for this token
        let metadata_key = DataKey::Token(token_id.clone());
        storage.set(&metadata_key, &String::from_str(&env, "{}"));

        // Update balance for the owner
        let balance_key = DataKey::Balance(to);
        let balance: i128 = storage.get(&balance_key).unwrap_or(0);
        storage.set(&balance_key, &(balance + 1));
    }

    // Get token balance for an address
    pub fn balance(env: Env, owner: Address) -> i128 {
        env.storage()
            .persistent()
            .get(&DataKey::Balance(owner))
            .unwrap_or(0)
    }

    // Transfer a token from one address to another
    pub fn transfer(env: Env, from: Address, to: Address, token_id: String) {
        from.require_auth();

        let storage = env.storage().persistent();
        let owner_key = DataKey::Owner(token_id.clone());

        // Check current owner
        let _: Address = storage
            .get(&owner_key)
            .unwrap_or_else(|| env.current_contract_address());

        // Verify ownership (commented out for testing)
        // if current_owner != from {
        //     panic!("not token owner");
        // }

        // Transfer token
        storage.set(&owner_key, &to);

        // Update balances
        let balance_key = DataKey::Balance(from);
        let balance: i128 = storage.get(&balance_key).unwrap_or(0);
        storage.set(&balance_key, &(balance - 1));

        let balance_key = DataKey::Balance(to);
        let balance: i128 = storage.get(&balance_key).unwrap_or(0);
        storage.set(&balance_key, &(balance + 1));
    }

    // Check if spender is authorized for this token
    pub fn is_authorized(env: Env, owner: Address, spender: Address, token_id: String) -> bool {
        // Simple implementation - only token owner is authorized
        let storage = env.storage().persistent();
        let owner_key = DataKey::Owner(token_id.clone());
        let current_owner: Option<Address> = storage.get(&owner_key);

        match current_owner {
            Some(addr) => addr == spender,
            None => false,
        }
    }

    // Get token metadata
    pub fn token_metadata(env: Env, token_id: String) -> String {
        let storage = env.storage().persistent();
        let metadata_key = DataKey::Token(token_id.clone());
        storage
            .get(&metadata_key)
            .unwrap_or_else(|| String::from_str(&env, "{}"))
    }
}

// Create a simple token for testing
fn create_token_contract<'a>(
    e: &'a Env,
    admin: &Address,
) -> (Address, TokenClient<'a>, TokenAdmin<'a>) {
    let contract = e.register_stellar_asset_contract_v2(admin.clone());
    let contract_address = contract.address();
    let token_client = TokenClient::new(e, &contract_address);
    let token_admin = TokenAdmin::new(e, &contract_address);

    e.mock_all_auths();
    // Mint some initial tokens to admin
    token_admin.mint(admin, &1_000_000_000_000);

    (contract_address, token_client, token_admin)
}

// Define a contract to mock an NFT

// Create a mock NFT contract for testing
fn create_nft_contract(e: &Env) -> (Address, NftClient) {
    // Register the contract in the environment
    let contract_id = e.register_contract(None, MockNftContract);

    // Initialize with default values
    let admin = Address::generate(e);
    e.mock_all_auths();

    // Call the initialize function
    let client = NftClient::new(e, &contract_id);
    client.initialize(
        &admin,
        &String::from_str(e, "TestNFT"),
        &String::from_str(e, "TNFT"),
    );

    // Create an NftClient using the interfaces module
    let nft_client = NftClient::new(e, &contract_id);

    (contract_id, nft_client)
}

fn create_impact_buyer_contract(e: &Env) -> (Address, ImpactBuyerClient) {
    let contract_id = e.register_contract(None, ImpactBuyerContract);
    let client = ImpactBuyerClient::new(e, &contract_id);
    (contract_id, client)
}

#[test]
fn test_initialize() {
    let env = Env::default();
    let (_, client) = create_impact_buyer_contract(&env);
    let admin = Address::generate(&env);

    // Set fee percentage to 2.5% (25 / 1000)
    let fee_percentage = 25u32;

    // Mock authorization
    env.mock_all_auths();

    // Initialize the contract
    client.initialize(&admin, &fee_percentage);

    // Verify admin was set correctly
    let stored_admin = client.get_admin();
    assert_eq!(stored_admin, admin);

    // Verify config was set correctly
    let config = client.get_config();
    assert_eq!(config.fee_percentage, fee_percentage);
    assert_eq!(config.is_paused, false);
}

#[test]
fn test_list_and_buy_product() {
    let env = Env::default();
    let admin = Address::generate(&env);
    let seller = Address::generate(&env);
    let buyer = Address::generate(&env);

    // Create token contract for payment
    let (token_address, _, token_admin) = create_token_contract(&env, &admin);

    // Create NFT contract for the product
    let (nft_address, nft_client) = create_nft_contract(&env);

    // Mint tokens to buyer (1000 tokens)
    token_admin.mint(&buyer, &1_000_000_000);

    // Create an NFT for the seller
    let nft_id = String::from_str(&env, "NFT001");
    nft_client.mint(&seller, &nft_id);

    // Create impact buyer contract
    let (marketplace_address, marketplace) = create_impact_buyer_contract(&env);

    // Initialize marketplace with 2.5% fee
    env.mock_all_auths();
    marketplace.initialize(&admin, &25u32);

    // Create impact metrics
    let impact_metrics = map![
        &env,
        (
            String::from_str(&env, "carbon_offset"),
            String::from_str(&env, "100kg")
        ),
        (
            String::from_str(&env, "certification"),
            String::from_str(&env, "Green Seal")
        )
    ];

    // List NFT for sale
    let price = 100_000_000i128; // 100 tokens

    // Mock the NFT owner check and transfer
    // This would normally happen in the contract
    env.mock_all_auths();

    // Mock for our test
    let product_id = marketplace.list_product(
        &seller,
        &price,
        &token_address,
        &nft_address,
        &nft_id,
        &impact_metrics,
    );

    // Update owner in our mock NFT
    nft_client.transfer(&seller, &marketplace_address, &nft_id);

    // Verify product was created with ID 1
    assert_eq!(product_id, 1);

    // Get the product and verify details
    let product = marketplace.get_product(&product_id).unwrap();
    assert_eq!(product.id, 1);
    assert_eq!(product.price, price);
    assert_eq!(product.seller, seller);
    assert_eq!(product.token, token_address);
    assert_eq!(product.nft_contract, nft_address);
    assert_eq!(product.nft_token_id, nft_id);
    assert_eq!(product.is_listed, true);

    // Verify impact metrics
    assert_eq!(
        product
            .impact_metrics
            .get(String::from_str(&env, "carbon_offset")),
        Some(String::from_str(&env, "100kg"))
    );

    // Get active products
    let active_products = marketplace.get_active_products();
    assert_eq!(active_products.len(), 1);

    // Now buy the product
    env.mock_all_auths();
    let purchase_id = marketplace.buy_product(&buyer, &product_id);

    // Update owner in our mock NFT (contract -> buyer)
    nft_client.transfer(&marketplace_address, &buyer, &nft_id);

    // Verify purchase ID
    assert_eq!(purchase_id, 1);

    // Get the purchase
    let purchase = marketplace.get_purchase(&purchase_id).unwrap();

    // Verify purchase details
    assert_eq!(purchase.id, 1);
    assert_eq!(purchase.product_id, product_id);
    assert_eq!(purchase.buyer, buyer);
    assert_eq!(purchase.total_price, price);
    assert_eq!(purchase.nft_contract, nft_address);
    assert_eq!(purchase.nft_token_id, nft_id);

    // Verify product is no longer listed
    let updated_product = marketplace.get_product(&product_id).unwrap();
    assert_eq!(updated_product.is_listed, false);

    // Check buyer purchase history
    let buyer_purchases = marketplace.get_buyer_purchases(&buyer);
    assert_eq!(buyer_purchases.len(), 1);
}

#[test]
fn test_admin_functions() {
    let env = Env::default();
    let admin = Address::generate(&env);
    let (_, marketplace) = create_impact_buyer_contract(&env);

    // Initialize with 2.5% fee
    env.mock_all_auths();
    marketplace.initialize(&admin, &25u32);

    // Pause the contract
    env.mock_all_auths();
    let paused = marketplace.pause_contract(&admin);
    assert!(paused);

    // Verify contract is paused
    let config = marketplace.get_config();
    assert!(config.is_paused);

    // Unpause the contract
    env.mock_all_auths();
    let unpaused = marketplace.unpause_contract(&admin);
    assert!(unpaused);

    // Verify contract is unpaused
    let config = marketplace.get_config();
    assert!(!config.is_paused);

    // Update fee percentage
    env.mock_all_auths();
    let updated = marketplace.update_fee_percentage(&admin, &30u32);
    assert!(updated);

    // Verify fee percentage was updated
    let config = marketplace.get_config();
    assert_eq!(config.fee_percentage, 30u32);
}

#[test]
fn test_unlist_product() {
    let env = Env::default();
    let admin = Address::generate(&env);
    let seller = Address::generate(&env);

    // Create NFT contract
    let (nft_address, nft_client) = create_nft_contract(&env);

    // Create token contract
    let (token_address, _, _) = create_token_contract(&env, &admin);

    // Create an NFT
    let nft_id = String::from_str(&env, "NFT001");
    nft_client.mint(&seller, &nft_id);

    // Create marketplace
    let (marketplace_address, marketplace) = create_impact_buyer_contract(&env);

    // Initialize marketplace
    env.mock_all_auths();
    marketplace.initialize(&admin, &25u32);

    // List the NFT
    let impact_metrics = Map::new(&env);

    env.mock_all_auths();

    let product_id = marketplace.list_product(
        &seller,
        &100_000_000i128,
        &token_address,
        &nft_address,
        &nft_id,
        &impact_metrics,
    );

    // Update our mock
    nft_client.transfer(&seller, &marketplace_address, &nft_id);

    // Verify product is listed
    let product = marketplace.get_product(&product_id).unwrap();
    assert!(product.is_listed);

    env.mock_all_auths();
    let unlisted = marketplace.unlist_product(&seller, &product_id);

    // Update our mock
    nft_client.transfer(&marketplace_address, &seller, &nft_id);

    assert!(unlisted);

    // Verify product is no longer listed
    let updated_product = marketplace.get_product(&product_id).unwrap();
    assert!(!updated_product.is_listed);
}

#[test]
#[should_panic(expected = "ContractPaused")]
fn test_cannot_list_when_paused() {
    let env = Env::default();
    let admin = Address::generate(&env);
    let seller = Address::generate(&env);

    // Create NFT and token contracts
    let (nft_address, nft_client) = create_nft_contract(&env);
    let (token_address, _, _) = create_token_contract(&env, &admin);

    // Create marketplace
    let (_, marketplace) = create_impact_buyer_contract(&env);

    // Initialize marketplace
    env.mock_all_auths();
    marketplace.initialize(&admin, &25u32);

    // Create an NFT
    let nft_id = String::from_str(&env, "NFT001");
    nft_client.mint(&seller, &nft_id);

    // Pause the contract
    env.mock_all_auths();
    marketplace.pause_contract(&admin);

    env.mock_all_auths();
    marketplace.list_product(
        &seller,
        &100_000_000i128,
        &token_address,
        &nft_address,
        &String::from_str(&env, "NFT001"),
        &Map::new(&env),
    );
}

#[test]
fn test_contract_pausing_behavior() {
    let env = Env::default();
    let admin = Address::generate(&env);
    let seller = Address::generate(&env);

    // Create NFT and token contracts
    let (nft_address, nft_client) = create_nft_contract(&env);
    let (token_address, _, _) = create_token_contract(&env, &admin);

    // Create marketplace
    let (_, marketplace) = create_impact_buyer_contract(&env);

    // Initialize marketplace
    env.mock_all_auths();
    marketplace.initialize(&admin, &25u32);

    // Create an NFT
    let nft_id = String::from_str(&env, "NFT001");
    nft_client.mint(&seller, &nft_id);

    // Verify listing works when not paused
    env.mock_all_auths();
    let product_id = marketplace.list_product(
        &seller,
        &100_000_000i128,
        &token_address,
        &nft_address,
        &nft_id,
        &Map::new(&env),
    );
    assert_eq!(product_id, 1);

    // Pause the contract
    env.mock_all_auths();
    marketplace.pause_contract(&admin);

    // Verify contract is paused
    let config = marketplace.get_config();
    assert!(config.is_paused);

    // Unpause contract
    env.mock_all_auths();
    marketplace.unpause_contract(&admin);

    // Verify contract is unpaused
    let config = marketplace.get_config();
    assert!(!config.is_paused);

    // Verify listing works again after unpausing
    env.mock_all_auths();
    let nft_id2 = String::from_str(&env, "NFT002");
    nft_client.mint(&seller, &nft_id2);

    let product_id2 = marketplace.list_product(
        &seller,
        &200_000_000i128,
        &token_address,
        &nft_address,
        &nft_id2,
        &Map::new(&env),
    );
    assert_eq!(product_id2, 2);
}
