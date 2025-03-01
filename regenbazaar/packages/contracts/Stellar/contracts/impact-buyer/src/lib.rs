#![no_std]
use soroban_sdk::{contract, contractimpl, contracttype, token, Address, Env, Map, String, Vec};

// Define the product structure
#[contracttype]
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ImpactProduct {
    // Unique identifier for the product
    pub id: u32,
    // Name of the product
    pub name: String,
    // Description of the product
    pub description: String,
    // Price in tokens
    pub price: i128,
    // Seller address
    pub seller: Address,
    // Token contract address used for payment
    pub token: Address,
    // Available quantity
    pub quantity: u32,
    // Impact metrics or certifications
    pub impact_metrics: Map<String, String>,
}

// Define the purchase record
#[contracttype]
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Purchase {
    // Unique identifier for the purchase
    pub id: u32,
    // Product ID that was purchased
    pub product_id: u32,
    // Buyer address
    pub buyer: Address,
    // Quantity purchased
    pub quantity: u32,
    // Total price paid
    pub total_price: i128,
    // Timestamp of purchase
    pub timestamp: u64,
}

// Define storage keys
#[contracttype]
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum DataKey {
    Admin,                   // Contract administrator
    ProductCounter,          // Counter for product IDs
    PurchaseCounter,         // Counter for purchase IDs
    Product(u32),            // Product data by ID
    Purchase(u32),           // Purchase data by ID
    BuyerPurchases(Address), // List of purchases by buyer
}

#[contract]
pub struct ImpactBuyerContract;

#[contractimpl]
impl ImpactBuyerContract {
    // Initialize the contract with admin
    pub fn initialize(env: Env, admin: Address) {
        if env.storage().instance().has(&DataKey::Admin) {
            panic!("Contract already initialized");
        }
        admin.require_auth();

        // Store admin address
        env.storage().instance().set(&DataKey::Admin, &admin);

        // Initialize product counter
        env.storage()
            .instance()
            .set(&DataKey::ProductCounter, &0u32);

        // Initialize purchase counter
        env.storage()
            .instance()
            .set(&DataKey::PurchaseCounter, &0u32);
    }

    // List a new impact product
    pub fn list_product(
        env: Env,
        seller: Address,
        name: String,
        description: String,
        price: i128,
        token: Address,
        quantity: u32,
        impact_metrics: Map<String, String>,
    ) -> u32 {
        // Require seller authorization
        seller.require_auth();

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
            name,
            description,
            price,
            seller,
            token,
            quantity,
            impact_metrics,
        };

        // Store product
        env.storage()
            .instance()
            .set(&DataKey::Product(new_product_id), &product);

        new_product_id
    }

    // Get product details
    pub fn get_product(env: Env, product_id: u32) -> Option<ImpactProduct> {
        env.storage().instance().get(&DataKey::Product(product_id))
    }

    // List all products
    pub fn list_products(env: Env) -> Vec<ImpactProduct> {
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
                // Only include products with available quantity
                if product.quantity > 0 {
                    products.push_back(product);
                }
            }
        }

        products
    }

    // Buy an impact product
    pub fn buy_product(env: Env, buyer: Address, product_id: u32, quantity: u32) -> u32 {
        // Require buyer authorization
        buyer.require_auth();

        // Get product
        let mut product: ImpactProduct = env
            .storage()
            .instance()
            .get(&DataKey::Product(product_id))
            .expect("Product not found");

        // Check if enough quantity is available
        if product.quantity < quantity {
            panic!("Not enough quantity available");
        }

        // Calculate total price
        let total_price = product.price * (quantity as i128);

        // Transfer tokens from buyer to seller
        let token_client = token::Client::new(&env, &product.token);

        let buyer_balance = token_client.balance(&buyer);
        if buyer_balance < total_price {
            panic!("Insufficient funds");
        }
        token_client.transfer(&buyer, &product.seller, &total_price);

        // Update product quantity
        product.quantity -= quantity;
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
            quantity,
            total_price,
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
            .set(&DataKey::BuyerPurchases(buyer), &buyer_purchases);

        // Return purchase ID
        new_purchase_id
    }

    // Get purchase details
    pub fn get_purchase(env: Env, purchase_id: u32) -> Option<Purchase> {
        env.storage()
            .instance()
            .get(&DataKey::Purchase(purchase_id))
    }

    // Get buyer's purchase history
    pub fn get_buyer_purchases(env: Env, buyer: Address) -> Vec<Purchase> {
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
    pub fn update_product(
        env: Env,
        seller: Address,
        product_id: u32,
        name: Option<String>,
        description: Option<String>,
        price: Option<i128>,
        quantity: Option<u32>,
        impact_metrics: Option<Map<String, String>>,
    ) -> bool {
        // Require seller authorization
        seller.require_auth();

        // Get product
        let mut product: ImpactProduct = env
            .storage()
            .instance()
            .get(&DataKey::Product(product_id))
            .expect("Product not found");

        // Check if caller is the seller
        if product.seller != seller {
            panic!("Only the seller can update the product");
        }

        // Update fields if provided
        if let Some(new_name) = name {
            product.name = new_name;
        }

        if let Some(new_description) = description {
            product.description = new_description;
        }

        if let Some(new_price) = price {
            product.price = new_price;
        }

        if let Some(new_quantity) = quantity {
            product.quantity = new_quantity;
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

    // Get the admin address
    pub fn get_admin(env: Env) -> Address {
        env.storage().instance().get(&DataKey::Admin).unwrap()
    }
}

mod test;
