#![no_std]
mod client;
mod interfaces;
mod types;

pub use client::{ImpactBuyerClient, ImpactBuyerInterface};
use interfaces::{NftClient, TokenClient};
use soroban_sdk::{contract, contractimpl, Address, Env, Map, String, Vec};
use types::{ContractConfig, DataKey, ErrorCode, ImpactProduct, Purchase};

#[contract]
pub struct ImpactBuyerContract;

#[contractimpl]
impl ImpactBuyerInterface for ImpactBuyerContract {
    // Initialize the contract with admin
    fn initialize(env: Env, admin: Address, fee_percentage: u32) {
        if env.storage().instance().has(&DataKey::Admin) {
            panic!("{:?}", ErrorCode::AlreadyInitialized);
        }

        // Validate fee percentage (max 30%)
        if fee_percentage > 300 {
            panic!("Fee percentage too high");
        }

        admin.require_auth();

        // Store admin address
        env.storage().instance().set(&DataKey::Admin, &admin);

        // Initialize configuration
        let config = ContractConfig {
            fee_percentage,
            is_paused: false,
        };
        env.storage().instance().set(&DataKey::Config, &config);

        // Initialize product counter
        env.storage()
            .instance()
            .set(&DataKey::ProductCounter, &0u32);

        // Initialize purchase counter
        env.storage()
            .instance()
            .set(&DataKey::PurchaseCounter, &0u32);
    }

    // List a new impact NFT product
    fn list_product(
        env: Env,
        seller: Address,
        price: i128,
        token: Address,
        nft_contract: Address,
        nft_token_id: String,
        impact_metrics: Map<String, String>,
    ) -> u32 {
        // Check if contract is paused
        Self.ensure_not_paused(&env);

        // Require seller authorization
        seller.require_auth();

        // Verify the seller owns the NFT
        let nft_client = NftClient::new(&env, &nft_contract);
        let nft_owner = nft_client.owner(&nft_token_id);

        if nft_owner != seller {
            panic!("{:?}", ErrorCode::Unauthorized);
        }

        // Get and increment product counter
        let product_counter: u32 = env
            .storage()
            .instance()
            .get(&DataKey::ProductCounter)
            .unwrap_or(0);
        let new_product_id = product_counter + 1;

        env.storage()
            .instance()
            .set(&DataKey::ProductCounter, &new_product_id);

        // Create new product
        let product = ImpactProduct {
            id: new_product_id,
            price,
            seller: seller.clone(),
            token,
            nft_contract,
            nft_token_id: nft_token_id.clone(),
            impact_metrics,
            is_listed: true,
        };

        // Transfer NFT from seller to the contract (escrow)
        let contract_address = env.current_contract_address();
        nft_client.transfer(&seller, &contract_address, &nft_token_id);

        // Store product
        env.storage()
            .instance()
            .set(&DataKey::Product(new_product_id), &product);

        // Add product to seller's products list
        let mut seller_products: Vec<u32> = env
            .storage()
            .instance()
            .get(&DataKey::SellerProducts(seller.clone()))
            .unwrap_or(Vec::new(&env));
        seller_products.push_back(new_product_id);
        env.storage()
            .instance()
            .set(&DataKey::SellerProducts(seller.clone()), &seller_products);

        // Publish list event
        Self.publish_list_event(&env, new_product_id, seller);

        new_product_id
    }

    // Unlist an NFT product (only seller can unlist)
    fn unlist_product(env: Env, seller: Address, product_id: u32) -> bool {
        // Check if contract is paused
        Self.ensure_not_paused(&env);

        // Require seller authorization
        seller.require_auth();

        // Get product
        let mut product: ImpactProduct = env
            .storage()
            .instance()
            .get(&DataKey::Product(product_id))
            .unwrap_or_else(|| panic!("{:?}", ErrorCode::ProductNotFound));

        // Check if caller is the seller or admin
        let is_admin = Self.is_admin(&env, &seller);
        if product.seller != seller && !is_admin {
            panic!("{:?}", ErrorCode::Unauthorized);
        }

        // Check if product is already unlisted
        if !product.is_listed {
            return false;
        }

        // Update listing status
        product.is_listed = false;

        // Store updated product
        env.storage()
            .instance()
            .set(&DataKey::Product(product_id), &product);

        // Return the NFT to the seller
        let nft_client = NftClient::new(&env, &product.nft_contract);
        let contract_address = env.current_contract_address();
        nft_client.transfer(&contract_address, &product.seller, &product.nft_token_id);

        true
    }

    // Get product details
    fn get_product(env: Env, product_id: u32) -> Option<ImpactProduct> {
        env.storage().instance().get(&DataKey::Product(product_id))
    }

    // List all active listings
    fn get_active_products(env: Env) -> Vec<ImpactProduct> {
        let product_counter: u32 = env
            .storage()
            .instance()
            .get(&DataKey::ProductCounter)
            .unwrap_or(0);
        let mut products = Vec::new(&env);

        for id in 1..=product_counter {
            if let Some(product) = env
                .storage()
                .instance()
                .get::<DataKey, ImpactProduct>(&DataKey::Product(id))
            {
                // Only include products that are listed
                if product.is_listed {
                    products.push_back(product);
                }
            }
        }

        products
    }

    // List all products (active and inactive)
    fn get_all_products(env: Env) -> Vec<ImpactProduct> {
        let product_counter: u32 = env
            .storage()
            .instance()
            .get(&DataKey::ProductCounter)
            .unwrap_or(0);
        let mut products = Vec::new(&env);

        for id in 1..=product_counter {
            if let Some(product) = env
                .storage()
                .instance()
                .get::<DataKey, ImpactProduct>(&DataKey::Product(id))
            {
                products.push_back(product);
            }
        }

        products
    }

    // Get seller's products
    fn get_seller_products(env: Env, seller: Address) -> Vec<ImpactProduct> {
        let product_ids: Vec<u32> = env
            .storage()
            .instance()
            .get(&DataKey::SellerProducts(seller))
            .unwrap_or(Vec::new(&env));

        let mut products = Vec::new(&env);
        for id in product_ids.iter() {
            if let Some(product) = env
                .storage()
                .instance()
                .get::<DataKey, ImpactProduct>(&DataKey::Product(id))
            {
                products.push_back(product);
            }
        }

        products
    }

    // Buy an NFT impact product
    fn buy_product(env: Env, buyer: Address, product_id: u32) -> u32 {
        // Check if contract is paused
        Self.ensure_not_paused(&env);

        // Require buyer authorization
        buyer.require_auth();

        // Get product
        let mut product: ImpactProduct = env
            .storage()
            .instance()
            .get(&DataKey::Product(product_id))
            .unwrap_or_else(|| panic!("{:?}", ErrorCode::ProductNotFound));

        // Check if NFT is listed for sale
        if !product.is_listed {
            panic!("{:?}", ErrorCode::ProductNotListed);
        }

        // Check if buyer is trying to buy their own NFT
        if product.seller == buyer {
            panic!("{:?}", ErrorCode::CannotBuyOwnNFT);
        }

        // Calculate total price and platform fee
        let total_price = product.price;
        let fee = Self.calculate_fee(&env, total_price);
        let seller_amount = total_price - fee;

        // Transfer payment tokens from buyer to seller and admin
        let token_client = TokenClient::new(&env, &product.token);
        let buyer_balance = token_client.balance(&buyer);
        if buyer_balance < total_price {
            panic!("{:?}", ErrorCode::InsufficientFunds);
        }

        // Transfer seller's share
        token_client.transfer(&buyer, &product.seller, &seller_amount);

        // Transfer platform fee to admin
        let admin: Address = env.storage().instance().get(&DataKey::Admin).unwrap();
        token_client.transfer(&buyer, &admin, &fee);

        // Transfer NFT from contract to buyer (from escrow)
        let nft_client = NftClient::new(&env, &product.nft_contract);
        let contract_address = env.current_contract_address();
        nft_client.transfer(&contract_address, &buyer, &product.nft_token_id);

        // Mark product as unlisted
        product.is_listed = false;
        env.storage()
            .instance()
            .set(&DataKey::Product(product_id), &product);

        // Get and increment purchase counter
        let purchase_counter: u32 = env
            .storage()
            .instance()
            .get(&DataKey::PurchaseCounter)
            .unwrap_or(0);
        let new_purchase_id = purchase_counter + 1;
        env.storage()
            .instance()
            .set(&DataKey::PurchaseCounter, &new_purchase_id);

        // Create purchase record
        let purchase = Purchase {
            id: new_purchase_id,
            product_id,
            buyer: buyer.clone(),
            total_price,
            platform_fee: fee,
            nft_contract: product.nft_contract,
            nft_token_id: product.nft_token_id,
            timestamp: env.ledger().timestamp(),
        };

        // Store purchase
        env.storage()
            .instance()
            .set(&DataKey::Purchase(new_purchase_id), &purchase);

        // Add purchase to buyer's history
        let mut buyer_purchases: Vec<u32> = env
            .storage()
            .instance()
            .get(&DataKey::BuyerPurchases(buyer.clone()))
            .unwrap_or(Vec::new(&env));
        buyer_purchases.push_back(new_purchase_id);
        env.storage()
            .instance()
            .set(&DataKey::BuyerPurchases(buyer.clone()), &buyer_purchases);

        // Publish buy event
        Self.publish_buy_event(&env, new_purchase_id, buyer);

        // Return purchase ID
        new_purchase_id
    }

    // Batch buy multiple NFT impact products
    fn batch_buy_products(env: Env, buyer: Address, product_ids: Vec<u32>) -> Vec<u32> {
        // Check if contract is paused
        Self.ensure_not_paused(&env);

        // Require buyer authorization
        buyer.require_auth();

        let mut purchase_ids = Vec::new(&env);
        for id in product_ids.into_iter() {
            let purchase_id = Self::buy_product(env.clone(), buyer.clone(), id);
            purchase_ids.push_back(purchase_id);
        }

        purchase_ids
    }

    // Get purchase details
    fn get_purchase(env: Env, purchase_id: u32) -> Option<Purchase> {
        env.storage()
            .instance()
            .get(&DataKey::Purchase(purchase_id))
    }

    // Get buyer's purchase history
    fn get_buyer_purchases(env: Env, buyer: Address) -> Vec<Purchase> {
        let purchase_ids: Vec<u32> = env
            .storage()
            .instance()
            .get(&DataKey::BuyerPurchases(buyer))
            .unwrap_or(Vec::new(&env));

        let mut purchases = Vec::new(&env);
        for id in purchase_ids.iter() {
            if let Some(purchase) = env
                .storage()
                .instance()
                .get::<DataKey, Purchase>(&DataKey::Purchase(id))
            {
                purchases.push_back(purchase);
            }
        }

        purchases
    }

    // Update product details (only seller can update)
    fn update_product(
        env: Env,
        seller: Address,
        product_id: u32,
        price: Option<i128>,
        impact_metrics: Option<Map<String, String>>,
    ) -> bool {
        // Check if contract is paused
        Self.ensure_not_paused(&env);

        // Require seller authorization
        seller.require_auth();

        // Get product
        let mut product: ImpactProduct = env
            .storage()
            .instance()
            .get(&DataKey::Product(product_id))
            .unwrap_or_else(|| panic!("{:?}", ErrorCode::ProductNotFound));

        // Check if caller is the seller
        if product.seller != seller {
            panic!("{:?}", ErrorCode::Unauthorized);
        }

        // Check if product is still listed
        if !product.is_listed {
            panic!("{:?}", ErrorCode::ProductNotListed);
        }

        // Update fields if provided
        if let Some(new_price) = price {
            product.price = new_price;
        }

        if let Some(new_impact_metrics) = impact_metrics {
            product.impact_metrics = new_impact_metrics;
        }

        // Store updated product
        env.storage()
            .instance()
            .set(&DataKey::Product(product_id), &product);

        true
    }

    // Pause the contract (admin only)
    fn pause_contract(env: Env, admin: Address) -> bool {
        admin.require_auth();

        // Check if admin
        if !Self.is_admin(&env, &admin) {
            panic!("{:?}", ErrorCode::Unauthorized);
        }

        // Get current config
        let mut config: ContractConfig = env.storage().instance().get(&DataKey::Config).unwrap();

        // Check if already paused
        if config.is_paused {
            return false;
        }

        // Update config
        config.is_paused = true;
        env.storage().instance().set(&DataKey::Config, &config);

        true
    }

    // Unpause the contract (admin only)
    fn unpause_contract(env: Env, admin: Address) -> bool {
        admin.require_auth();

        // Check if admin
        if !Self.is_admin(&env, &admin) {
            panic!("{:?}", ErrorCode::Unauthorized);
        }

        // Get current config
        let mut config: ContractConfig = env.storage().instance().get(&DataKey::Config).unwrap();

        // Check if already unpaused
        if !config.is_paused {
            return false;
        }

        // Update config
        config.is_paused = false;
        env.storage().instance().set(&DataKey::Config, &config);

        true
    }

    // Update fee percentage (admin only)
    fn update_fee_percentage(env: Env, admin: Address, new_fee_percentage: u32) -> bool {
        admin.require_auth();

        // Check if admin
        if !Self.is_admin(&env, &admin) {
            panic!("{:?}", ErrorCode::Unauthorized);
        }

        // Validate fee percentage (max 30%)
        if new_fee_percentage > 300 {
            panic!("Fee percentage too high");
        }

        // Get current config
        let mut config: ContractConfig = env.storage().instance().get(&DataKey::Config).unwrap();

        // Update config
        config.fee_percentage = new_fee_percentage;
        env.storage().instance().set(&DataKey::Config, &config);

        true
    }

    // Get contract configuration
    fn get_config(env: Env) -> ContractConfig {
        env.storage().instance().get(&DataKey::Config).unwrap()
    }

    // Get the admin address
    fn get_admin(env: Env) -> Address {
        env.storage().instance().get(&DataKey::Admin).unwrap()
    }
}

impl ImpactBuyerContract {
    // Check if caller is admin
    fn is_admin(&self, env: &Env, caller: &Address) -> bool {
        let admin: Address = env.storage().instance().get(&DataKey::Admin).unwrap();
        &admin == caller
    }

    // Check if contract is paused
    fn is_paused(&self, env: &Env) -> bool {
        let config: ContractConfig = env.storage().instance().get(&DataKey::Config).unwrap();
        config.is_paused
    }

    // Calculate platform fee
    fn calculate_fee(&self, env: &Env, amount: i128) -> i128 {
        let config: ContractConfig = env.storage().instance().get(&DataKey::Config).unwrap();
        (amount * (config.fee_percentage as i128)) / 1000i128
    }

    // Ensure contract is not paused
    fn ensure_not_paused(&self, env: &Env) {
        if self.is_paused(env) {
            panic!("{:?}", ErrorCode::ContractPaused);
        }
    }

    fn publish_list_event(&self, env: &Env, product_id: u32, seller: Address) {
        let topics = (DataKey::ProductListed, seller.clone(), product_id);
        env.events().publish(topics, (seller, product_id));
    }

    fn publish_buy_event(&self, env: &Env, purchase_id: u32, buyer: Address) {
        let topics = (DataKey::ProductBought, buyer.clone(), purchase_id);
        env.events().publish(topics, (buyer, purchase_id));
    }
}

mod test;
