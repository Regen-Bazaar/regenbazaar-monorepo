#![cfg(test)]

use super::*;
use crate::ImpactBuyerContract;
use soroban_sdk::token::{StellarAssetClient as TokenAdmin, TokenClient};
use soroban_sdk::{map, testutils::Address as _, Address, Env, Map, String};

#[test]
fn test_initialize() {
    let env = Env::default();
    let contract_id = env.register_contract(None, ImpactBuyerContract);
    let client = ImpactBuyerContractClient::new(&env, &contract_id);

    let admin = Address::generate(&env);

    // Invoke initialize with authentication
    env.mock_all_auths();
    client.initialize(&admin);

    // Verify the admin was set correctly
    let stored_admin = client.get_admin();
    assert_eq!(stored_admin, admin);
}

#[test]
fn test_list_and_get_product() {
    let env = Env::default();
    let contract_id = env.register_contract(None, ImpactBuyerContract);
    let client = ImpactBuyerContractClient::new(&env, &contract_id);

    let admin = Address::generate(&env);
    let seller = Address::generate(&env);

    // Create token contract
    let token_admin = Address::generate(&env);
    let token_contract = env.register_stellar_asset_contract_v2(token_admin.clone());
    let token_contract_id = token_contract.address();

    // Initialize contract
    env.mock_all_auths();
    client.initialize(&admin);

    // Create impact metrics
    let mut impact_metrics = Map::new(&env);
    impact_metrics.set(
        String::from_str(&env, "carbon_offset"),
        String::from_str(&env, "100kg"),
    );
    impact_metrics.set(
        String::from_str(&env, "certification"),
        String::from_str(&env, "Green Seal"),
    );

    // List a product
    env.mock_all_auths();
    let product_id = client.list_product(
        &seller,
        &String::from_str(&env, "Eco-friendly T-shirt"),
        &String::from_str(&env, "Made from recycled materials"),
        &100_000_000, // 100 tokens
        &token_contract_id,
        &10, // 10 items available
        &impact_metrics,
    );

    // Verify product ID
    assert_eq!(product_id, 1);

    // Get the product
    let product = client.get_product(&product_id).unwrap();

    // Verify product details
    assert_eq!(product.id, 1);
    assert_eq!(product.name, String::from_str(&env, "Eco-friendly T-shirt"));
    assert_eq!(
        product.description,
        String::from_str(&env, "Made from recycled materials")
    );
    assert_eq!(product.price, 100_000_000);
    assert_eq!(product.seller, seller);
    assert_eq!(product.token, token_contract_id);
    assert_eq!(product.quantity, 10);
    assert_eq!(
        product
            .impact_metrics
            .get(String::from_str(&env, "carbon_offset")),
        Some(String::from_str(&env, "100kg"))
    );
    assert_eq!(
        product
            .impact_metrics
            .get(String::from_str(&env, "certification")),
        Some(String::from_str(&env, "Green Seal"))
    );
}

#[test]
fn test_buy_product() {
    let env = Env::default();
    let contract_id = env.register_contract(None, ImpactBuyerContract);
    let client = ImpactBuyerContractClient::new(&env, &contract_id);

    let admin = Address::generate(&env);
    let seller = Address::generate(&env);
    let buyer = Address::generate(&env);

    // Create token contract
    let token_admin = Address::generate(&env);
    let token_contract = env.register_stellar_asset_contract_v2(token_admin.clone());
    let token_contract_id = token_contract.address();
    let token = TokenAdmin::new(&env, &token_contract_id);

    // Initialize contract
    env.mock_all_auths();

    // Mint tokens to buyer
    token.mint(&buyer, &500_000_000);

    client.initialize(&admin);

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

    // List a product
    env.mock_all_auths();
    let product_id = client.list_product(
        &seller,
        &String::from_str(&env, "Eco-friendly T-shirt"),
        &String::from_str(&env, "Made from recycled materials"),
        &100_000_000, // 100 tokens
        &token_contract_id,
        &10, // 10 items available
        &impact_metrics,
    );

    // Buy the product
    env.mock_all_auths();
    let purchase_id = client.buy_product(
        &buyer,
        &product_id,
        &2, // Buy 2 items
    );

    // Verify purchase ID
    assert_eq!(purchase_id, 1);

    // Get the purchase
    let purchase = client.get_purchase(&purchase_id).unwrap();

    // Verify purchase details
    assert_eq!(purchase.id, 1);
    assert_eq!(purchase.product_id, product_id);
    assert_eq!(purchase.buyer, buyer);
    assert_eq!(purchase.quantity, 2);
    assert_eq!(purchase.total_price, 200_000_000); // 2 * 100_000_000

    // Get the updated product
    let updated_product = client.get_product(&product_id).unwrap();

    // Verify updated quantity
    assert_eq!(updated_product.quantity, 8); // 10 - 2

    // Verify token balances
    let token_client = TokenClient::new(&env, &token_contract_id);
    assert_eq!(token_client.balance(&buyer), 300_000_000); // 500_000_000 - 200_000_000
    assert_eq!(token_client.balance(&seller), 200_000_000);

    // Get buyer's purchase history
    let buyer_purchases = client.get_buyer_purchases(&buyer);

    // Verify buyer's purchase history
    assert_eq!(buyer_purchases.len(), 1);
    assert_eq!(buyer_purchases.get(0).unwrap().id, purchase_id);
}

#[test]
fn test_update_product() {
    let env = Env::default();
    let contract_id = env.register_contract(None, ImpactBuyerContract);
    let client = ImpactBuyerContractClient::new(&env, &contract_id);

    let admin = Address::generate(&env);
    let seller = Address::generate(&env);

    // Create token contract
    let token_admin = Address::generate(&env);
    let token_contract = env.register_stellar_asset_contract_v2(token_admin.clone());
    let token_contract_id = token_contract.address();

    // Initialize contract
    env.mock_all_auths();
    client.initialize(&admin);

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

    // List a product
    env.mock_all_auths();
    let product_id = client.list_product(
        &seller,
        &String::from_str(&env, "Eco-friendly T-shirt"),
        &String::from_str(&env, "Made from recycled materials"),
        &100_000_000, // 100 tokens
        &token_contract_id,
        &10, // 10 items available
        &impact_metrics,
    );

    // Update the product
    env.mock_all_auths();
    let updated = client.update_product(
        &seller,
        &product_id,
        &Some(String::from_str(&env, "Premium Eco-friendly T-shirt")),
        &None,
        &Some(120_000_000), // Increase price
        &Some(15),          // Increase quantity
        &None,
    );

    // Verify update success
    assert!(updated);

    // Get the updated product
    let updated_product = client.get_product(&product_id).unwrap();

    // Verify updated details
    assert_eq!(
        updated_product.name,
        String::from_str(&env, "Premium Eco-friendly T-shirt")
    );
    assert_eq!(
        updated_product.description,
        String::from_str(&env, "Made from recycled materials")
    ); // Unchanged
    assert_eq!(updated_product.price, 120_000_000);
    assert_eq!(updated_product.quantity, 15);
    assert_eq!(
        updated_product
            .impact_metrics
            .get(String::from_str(&env, "carbon_offset")),
        Some(String::from_str(&env, "100kg"))
    ); // Unchanged
}

#[test]
fn test_list_products() {
    let env = Env::default();
    let contract_id = env.register_contract(None, ImpactBuyerContract);
    let client = ImpactBuyerContractClient::new(&env, &contract_id);

    let admin = Address::generate(&env);
    let seller = Address::generate(&env);

    // Create token contract
    let token_admin = Address::generate(&env);
    let token_contract = env.register_stellar_asset_contract_v2(token_admin.clone());
    let token_contract_id = token_contract.address();

    // Initialize contract
    env.mock_all_auths();
    client.initialize(&admin);

    // Create impact metrics
    let impact_metrics = map![
        &env,
        (
            String::from_str(&env, "carbon_offset"),
            String::from_str(&env, "100kg")
        )
    ];

    // List multiple products
    env.mock_all_auths();
    let product_id1 = client.list_product(
        &seller,
        &String::from_str(&env, "Eco-friendly T-shirt"),
        &String::from_str(&env, "Made from recycled materials"),
        &100_000_000,
        &token_contract_id,
        &10,
        &impact_metrics,
    );

    env.mock_all_auths();
    let product_id2 = client.list_product(
        &seller,
        &String::from_str(&env, "Sustainable Water Bottle"),
        &String::from_str(&env, "Reusable and BPA-free"),
        &50_000_000,
        &token_contract_id,
        &20,
        &impact_metrics,
    );

    // List products
    let products = client.list_products();

    // Verify products list
    assert_eq!(products.len(), 2);
    assert_eq!(products.get(0).unwrap().id, product_id1);
    assert_eq!(products.get(1).unwrap().id, product_id2);
}
