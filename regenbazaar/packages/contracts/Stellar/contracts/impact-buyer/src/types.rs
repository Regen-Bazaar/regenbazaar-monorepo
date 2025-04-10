use soroban_sdk::{contracterror, contracttype, Address, Map, String};

// Define the NFT impact product structure
#[contracttype]
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ImpactProduct {
    // Unique identifier for the product
    pub id: u32,
    // Price in tokens
    pub price: i128,
    // Seller address
    pub seller: Address,
    // Token contract address used for payment
    pub token: Address,
    // NFT contract address
    pub nft_contract: Address,
    // NFT token ID in the NFT contract
    pub nft_token_id: String,
    // Impact metrics or certifications
    pub impact_metrics: Map<String, String>,
    // Whether the NFT is still listed for sale
    pub is_listed: bool,
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
    // Total price paid
    pub total_price: i128,
    // Platform fee paid
    pub platform_fee: i128,
    // NFT contract address
    pub nft_contract: Address,
    // NFT token ID that was transferred
    pub nft_token_id: String,
    // Timestamp of purchase
    pub timestamp: u64,
}

// Define contract configuration
#[contracttype]
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ContractConfig {
    // Fee percentage (out of 1000 to allow for fractional percentages)
    pub fee_percentage: u32,
    // Whether the contract is paused
    pub is_paused: bool,
}

// Define storage keys
#[contracttype]
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum DataKey {
    Admin,                   // Contract administrator
    Config,                  // Contract configuration
    ProductCounter,          // Counter for product IDs
    PurchaseCounter,         // Counter for purchase IDs
    Product(u32),            // Product data by ID
    Purchase(u32),           // Purchase data by ID
    BuyerPurchases(Address), // List of purchases by buyer
    SellerProducts(Address), // List of products by seller
    ProductListed,           // Product listed event by ID
    ProductBought,           // Product bought event by ID
}

// Define error codes
#[contracterror]
#[derive(Clone, Debug, Eq, PartialEq, Copy)]
pub enum ErrorCode {
    AlreadyInitialized = 0,
    Unauthorized = 1,
    ProductNotFound = 2,
    ProductNotListed = 3,
    InsufficientFunds = 4,
    CannotBuyOwnNFT = 5,
    ContractPaused = 6,
}
