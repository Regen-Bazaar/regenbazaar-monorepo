use crate::types::{ContractConfig, ImpactProduct, Purchase};
use soroban_sdk::{contractclient, Address, Env, Map, String, Vec};

/// This trait defines the interface for the ImpactBuyerContract
/// Other contracts can use this interface to interact with our marketplace
#[contractclient(name = "ImpactBuyerClient")]
pub trait ImpactBuyerInterface {
    /// Initialize the contract with admin and fee percentage
    fn initialize(env: Env, admin: Address, fee_percentage: u32);

    /// List a new impact NFT product for sale
    fn list_product(
        env: Env,
        seller: Address,
        price: i128,
        token: Address,
        nft_contract: Address,
        nft_token_id: String,
        impact_metrics: Map<String, String>,
    ) -> u32;

    /// Unlist an NFT product from the marketplace
    fn unlist_product(env: Env, seller: Address, product_id: u32) -> bool;

    /// Get details of a specific product
    fn get_product(env: Env, product_id: u32) -> Option<ImpactProduct>;

    /// Get all actively listed products
    fn get_active_products(env: Env) -> Vec<ImpactProduct>;

    /// Get all products (both active and inactive)
    fn get_all_products(env: Env) -> Vec<ImpactProduct>;

    /// Get all products listed by a specific seller
    fn get_seller_products(env: Env, seller: Address) -> Vec<ImpactProduct>;

    /// Buy a specific NFT product
    fn buy_product(env: Env, buyer: Address, product_id: u32) -> u32;

    /// Buy multiple NFT products in a batch
    fn batch_buy_products(env: Env, buyer: Address, product_ids: Vec<u32>) -> Vec<u32>;

    /// Get details of a specific purchase
    fn get_purchase(env: Env, purchase_id: u32) -> Option<Purchase>;

    /// Get all purchases made by a specific buyer
    fn get_buyer_purchases(env: Env, buyer: Address) -> Vec<Purchase>;

    /// Update a product's details
    fn update_product(
        env: Env,
        seller: Address,
        product_id: u32,
        price: Option<i128>,
        impact_metrics: Option<Map<String, String>>,
    ) -> bool;

    /// Pause the contract (admin only)
    fn pause_contract(env: Env, admin: Address) -> bool;

    /// Unpause the contract (admin only)
    fn unpause_contract(env: Env, admin: Address) -> bool;

    /// Update the fee percentage (admin only)
    fn update_fee_percentage(env: Env, admin: Address, new_fee_percentage: u32) -> bool;

    /// Get the current contract configuration
    fn get_config(env: Env) -> ContractConfig;

    /// Get the admin address
    fn get_admin(env: Env) -> Address;
}
