module impact_factory::impact_factory {
    use std::error;
    use std::signer;
    use std::string::{String};
    use std::vector;

    use supra_framework::event;
    use supra_framework::coin::{transfer};
    use supra_framework::supra_coin::SupraCoin;
    
    // Error codes
    const ENO_PERMISSION: u64 = 1;
    const EINVALID_ROYALTY: u64 = 2;
    const EINVALID_PRICE: u64 = 3;
    const EINVALID_TIER: u64 = 4;
    const ECOLLECTION_ALREADY_EXISTS: u64 = 5;
    const ECOLLECTION_NOT_FOUND: u64 = 6;
    const ENFT_NOT_FOUND: u64 = 7;
    const EINVALID_SUPPLY: u64 = 8;
    const EMINTING_CLOSED: u64 = 9;
    const ECONFIG_NOT_INITIALIZED: u64 = 10;
    const EINVALID_PAYMENT: u64 = 11;
    
    // Default values - these are only used during initialization
    const DEFAULT_CREATOR_SPLIT: u64 = 90; // 90% to creator
    const DEFAULT_PLATFORM_SPLIT: u64 = 10; // 10% to Regen Bazaar
    const DEFAULT_CREATOR_ROYALTY: u64 = 5; // 5% to creator
    const DEFAULT_PLATFORM_ROYALTY: u64 = 5; // 5% to Regen Bazaar
    
    // ======== Structs ========
    
    // System configuration resource
    struct SystemConfig has key {
        // Admin address
        admin: address,
        // Platform address to receive fees
        platform_address: address,
        // Payment token address
        rebaz_token_address: address,
        // Revenue splits
        creator_split: u64,
        platform_split: u64,
        // Royalty settings
        creator_royalty: u64,
        platform_royalty: u64,
        // Additional parameters
        max_collection_supply: u64,
        min_tier_price: u64
    }
    
    // Factory admin capabilities
    struct AdminCap has key {
        owner: address
    }
    
    // Registry to keep track of all collections
    struct Registry has key {
        collections: vector<address>
    }
    
    // Impact Collection
    struct ImpactCollection has key {
        name: String,
        description: String,
        uri: String,
        creator: address,
        platform: address,
        tiers: vector<ImpactTier>,
        total_supply: u64,
        minted: u64,
        is_open: bool
    }
    
    // Collection creator capability
    struct CreatorCap has key, store {
        collection_address: address
    }
    
    // Impact NFT tier configuration
    struct ImpactTier has store, drop {
        id: u64,
        name: String,
        price: u64,
        supply: u64,
        minted: u64,
        impact_value: u64
    }
    
    // Impact NFT
    struct ImpactNFT has key, store {
        name: String,
        description: String,
        uri: String,
        collection_address: address,
        tier: u64,
        impact_value: u64,
        impact_data: vector<ImpactData>,
        creator: address,
        platform: address
    }
    
    // Impact data key-value pair
    struct ImpactData has store, drop {
        key: String,
        value: String
    }
    
    // Events
    #[event]
    struct CollectionCreatedEvent has drop, store {
        collection_address: address,
        name: String,
        creator: address,
        total_supply: u64
    }
    
    #[event]
    struct NFTMintedEvent has drop, store {
        nft_address: address,
        collection_address: address,
        tier: u64,
        recipient: address,
        price: u64
    }
    
    #[event]
    struct ConfigUpdatedEvent has drop, store {
        admin: address,
        creator_split: u64,
        platform_split: u64,
        creator_royalty: u64,
        platform_royalty: u64
    }

    #[event]
    struct PaymentProcessedEvent has drop, store {
        payment_from: address,
        creator_amount: u64,
        platform_amount: u64,
        tier_id: u64,
        collection_address: address
    }
    
    // ======== Module Functions ========
    
    // Initialize the module
    public fun init(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        
        // Create Admin Capability
        let admin_cap = AdminCap {
            owner: admin_addr
        };
        
        // Create system configuration
        let system_config = SystemConfig {
            admin: admin_addr,
            platform_address: admin_addr, // Default platform is admin, can be changed later
            rebaz_token_address: @rebaz_token, 
            creator_split: DEFAULT_CREATOR_SPLIT,
            platform_split: DEFAULT_PLATFORM_SPLIT,
            creator_royalty: DEFAULT_CREATOR_ROYALTY,
            platform_royalty: DEFAULT_PLATFORM_ROYALTY,
            max_collection_supply: 10000, // Default max collection supply
            min_tier_price: 1 // Default minimum price
        };
        
        // Create registry
        let registry = Registry {
            collections: vector::empty<address>()
        };
        
        // Store resources at module address
        move_to(admin, admin_cap);
        move_to(admin, system_config);
        move_to(admin, registry);
        
        // Emit config created event
        event::emit(ConfigUpdatedEvent {
            admin: admin_addr,
            creator_split: DEFAULT_CREATOR_SPLIT,
            platform_split: DEFAULT_PLATFORM_SPLIT,
            creator_royalty: DEFAULT_CREATOR_ROYALTY,
            platform_royalty: DEFAULT_PLATFORM_ROYALTY
        });
    }
    
    // ======== Admin functions to manage system configuration ========
    
    // Update admin address
    public entry fun update_admin(
        current_admin: &signer,
        new_admin: address
    ) acquires SystemConfig {
        let current_admin_addr = signer::address_of(current_admin);
        let config = borrow_global_mut<SystemConfig>(@impact_factory);
        
        // Ensure caller is the current admin
        assert!(current_admin_addr == config.admin, error::permission_denied(ENO_PERMISSION));
        
        // Update admin address
        config.admin = new_admin;
    }
    
    // Update platform address
    public entry fun update_platform_address(
        admin: &signer,
        new_platform_address: address
    ) acquires SystemConfig {
        let admin_addr = signer::address_of(admin);
        let config = borrow_global_mut<SystemConfig>(@impact_factory);
        
        // Ensure caller is the admin
        assert!(admin_addr == config.admin, error::permission_denied(ENO_PERMISSION));
        
        // Update platform address
        config.platform_address = new_platform_address;
    }

    // Update Rebaz token address
    public entry fun update_rebaz_token_address(
        admin: &signer,
        new_token_address: address
    ) acquires SystemConfig {
        let admin_addr = signer::address_of(admin);
        let config = borrow_global_mut<SystemConfig>(@impact_factory);
        
        // Ensure caller is the admin
        assert!(admin_addr == config.admin, error::permission_denied(ENO_PERMISSION));
        
        // Update token address
        config.rebaz_token_address = new_token_address;
    }
    
    // Update revenue splits
    public entry fun update_splits(
        admin: &signer,
        creator_split: u64,
        platform_split: u64
    ) acquires SystemConfig {
        let admin_addr = signer::address_of(admin);
        let config = borrow_global_mut<SystemConfig>(@impact_factory);
        
        // Ensure caller is the admin
        assert!(admin_addr == config.admin, error::permission_denied(ENO_PERMISSION));
        
        // Validate splits (must sum to 100)
        assert!(creator_split + platform_split == 100, error::invalid_argument(EINVALID_ROYALTY));
        
        // Update splits
        config.creator_split = creator_split;
        config.platform_split = platform_split;
        
        // Emit config updated event
        event::emit(ConfigUpdatedEvent {
            admin: admin_addr,
            creator_split,
            platform_split,
            creator_royalty: config.creator_royalty,
            platform_royalty: config.platform_royalty
        });
    }
    
    // Update royalty percentages
    public entry fun update_royalties(
        admin: &signer,
        creator_royalty: u64,
        platform_royalty: u64
    ) acquires SystemConfig {
        let admin_addr = signer::address_of(admin);
        let config = borrow_global_mut<SystemConfig>(@impact_factory);
        
        // Ensure caller is the admin
        assert!(admin_addr == config.admin, error::permission_denied(ENO_PERMISSION));
        
        // Validate royalties (should be reasonable, e.g., < 50% total)
        assert!(creator_royalty + platform_royalty <= 50, error::invalid_argument(EINVALID_ROYALTY));
        
        // Update royalties
        config.creator_royalty = creator_royalty;
        config.platform_royalty = platform_royalty;
        
        // Emit config updated event
        event::emit(ConfigUpdatedEvent {
            admin: admin_addr,
            creator_split: config.creator_split,
            platform_split: config.platform_split,
            creator_royalty,
            platform_royalty
        });
    }
    
    // Update collection limits
    public entry fun update_collection_limits(
        admin: &signer,
        max_collection_supply: u64,
        min_tier_price: u64
    ) acquires SystemConfig {
        let admin_addr = signer::address_of(admin);
        let config = borrow_global_mut<SystemConfig>(@impact_factory);
        
        // Ensure caller is the admin
        assert!(admin_addr == config.admin, error::permission_denied(ENO_PERMISSION));
        
        // Update limits
        config.max_collection_supply = max_collection_supply;
        config.min_tier_price = min_tier_price;
    }
    
    // ======== View functions for system configuration ========
    
    // View admin address
    #[view]
    public fun get_admin(): address acquires SystemConfig {
        let config = borrow_global<SystemConfig>(@impact_factory);
        config.admin
    }
    
    // View platform address
    #[view]
    public fun get_platform_address(): address acquires SystemConfig {
        let config = borrow_global<SystemConfig>(@impact_factory);
        config.platform_address
    }

    // View Rebaz token address
    #[view]
    public fun get_rebaz_token_address(): address acquires SystemConfig {
        let config = borrow_global<SystemConfig>(@impact_factory);
        config.rebaz_token_address
    }
    
    // View splits
    #[view]
    public fun get_splits(): (u64, u64) acquires SystemConfig {
        let config = borrow_global<SystemConfig>(@impact_factory);
        (config.creator_split, config.platform_split)
    }
    
    // View royalties
    #[view]
    public fun get_royalties(): (u64, u64) acquires SystemConfig {
        let config = borrow_global<SystemConfig>(@impact_factory);
        (config.creator_royalty, config.platform_royalty)
    }
    
    // View collection limits
    #[view]
    public fun get_collection_limits(): (u64, u64) acquires SystemConfig {
        let config = borrow_global<SystemConfig>(@impact_factory);
        (config.max_collection_supply, config.min_tier_price)
    }
    
    // View all system config at once
    #[view]
    public fun get_full_config(): (address, address, address, u64, u64, u64, u64, u64, u64) acquires SystemConfig {
        let config = borrow_global<SystemConfig>(@impact_factory);
        (
            config.admin,
            config.platform_address,
            config.rebaz_token_address,
            config.creator_split,
            config.platform_split,
            config.creator_royalty,
            config.platform_royalty,
            config.max_collection_supply,
            config.min_tier_price
        )
    }
    
    // ======== Core functionality ========
    
    // Create a new impact collection
    public fun create_collection(
        creator: &signer,
        name: String,
        description: String,
        uri: String,
        total_supply: u64,
    ) acquires Registry, SystemConfig {
        let creator_address = signer::address_of(creator);
        
        // Get system config
        assert!(exists<SystemConfig>(@impact_factory), error::not_found(ECONFIG_NOT_INITIALIZED));
        let config = borrow_global<SystemConfig>(@impact_factory);
        
        // Validate against system config
        assert!(total_supply <= config.max_collection_supply, error::invalid_argument(EINVALID_SUPPLY));
        
        // Create collection
        let collection = ImpactCollection {
            name,
            description,
            uri,
            creator: creator_address,
            platform: config.platform_address,
            tiers: vector::empty<ImpactTier>(),
            total_supply,
            minted: 0,
            is_open: false
        };
        
        // Create creator capability
        let collection_address = creator_address;
        let creator_cap = CreatorCap {
            collection_address
        };
        
        // Register collection
        let registry = borrow_global_mut<Registry>(@impact_factory);
        vector::push_back(&mut registry.collections, collection_address);
        
        // Transfer creator capability and collection
        move_to(creator, creator_cap);
        move_to(creator, collection);

        // Emit collection created event
        event::emit(CollectionCreatedEvent {
            collection_address,
            name,
            creator: creator_address,
            total_supply
        });
    }
    
    // Add a tier to a collection
    public fun add_tier(
        creator: &signer,
        tier_id: u64,
        tier_name: String,
        price: u64,
        supply: u64,
        impact_value: u64,
    ) acquires ImpactCollection, SystemConfig {
        let creator_address = signer::address_of(creator);
        
        // Get system config
        assert!(exists<SystemConfig>(@impact_factory), error::not_found(ECONFIG_NOT_INITIALIZED));
        let config = borrow_global<SystemConfig>(@impact_factory);
        
        // Ensure collection exists at the creator's address
        assert!(exists<ImpactCollection>(creator_address), error::not_found(ECOLLECTION_NOT_FOUND));
        
        // Get the collection
        let collection = borrow_global_mut<ImpactCollection>(creator_address);
        
        // Ensure valid price and supply based on system config
        assert!(price >= config.min_tier_price, error::invalid_argument(EINVALID_PRICE));
        assert!(supply > 0, error::invalid_argument(EINVALID_SUPPLY));
        
        // Ensure total supply isn't exceeded
        let total_tier_supply = 0;
        let i = 0;
        let tiers_len = vector::length(&collection.tiers);
        
        while (i < tiers_len) {
            let tier = vector::borrow(&collection.tiers, i);
            total_tier_supply = total_tier_supply + tier.supply;
            i = i + 1;
        };
        
        assert!(total_tier_supply + supply <= collection.total_supply, error::invalid_argument(EINVALID_SUPPLY));
        
        // Create and add tier
        let tier = ImpactTier {
            id: tier_id,
            name: tier_name,
            price,
            supply,
            minted: 0,
            impact_value
        };
        
        vector::push_back(&mut collection.tiers, tier);
    }
    
    // Update collection URI
    public fun update_collection_uri(
        creator: &signer,
        new_uri: String
    ) acquires ImpactCollection {
        let creator_address = signer::address_of(creator);
        
        // Ensure collection exists
        assert!(exists<ImpactCollection>(creator_address), error::not_found(ECOLLECTION_NOT_FOUND));
        
        // Get the collection
        let collection = borrow_global_mut<ImpactCollection>(creator_address);
        
        // Ensure caller is the creator
        assert!(creator_address == collection.creator, error::permission_denied(ENO_PERMISSION));
        
        collection.uri = new_uri;
    }
    
    // Open collection for minting
    public fun open_collection(
        creator: &signer
    ) acquires ImpactCollection {
        let creator_address = signer::address_of(creator);
        
        // Ensure collection exists
        assert!(exists<ImpactCollection>(creator_address), error::not_found(ECOLLECTION_NOT_FOUND));
        
        // Get the collection
        let collection = borrow_global_mut<ImpactCollection>(creator_address);
        
        // Ensure caller is the creator
        assert!(creator_address == collection.creator, error::permission_denied(ENO_PERMISSION));
        
        collection.is_open = true;
    }
    
    // Close collection for minting
    public fun close_collection(
        creator: &signer
    ) acquires ImpactCollection {
        let creator_address = signer::address_of(creator);
        
        // Ensure collection exists
        assert!(exists<ImpactCollection>(creator_address), error::not_found(ECOLLECTION_NOT_FOUND));
        
        // Get the collection
        let collection = borrow_global_mut<ImpactCollection>(creator_address);
        
        // Ensure caller is the creator
        assert!(creator_address == collection.creator, error::permission_denied(ENO_PERMISSION));
        
        collection.is_open = false;
    }
    
    // Find tier in collection by ID
    fun find_tier_mut(tiers: &mut vector<ImpactTier>, tier_id: u64): &mut ImpactTier {
        let i = 0;
        let len = vector::length(tiers);
        
        while (i < len) {
            let tier = vector::borrow_mut(tiers, i);
            if (tier.id == tier_id) {
                return tier
            };
            i = i + 1;
        };
        
        abort error::not_found(EINVALID_TIER)
    }
    
    // Mint an NFT from a collection
    public entry fun mint_nft(
        buyer: &signer,
        collection_address: address,
        tier_id: u64,
        nft_name: String,
        nft_description: String,
        nft_uri: String
    ) acquires ImpactCollection, SystemConfig {
        let buyer_address = signer::address_of(buyer);
        
        // Get system config for platform info
        assert!(exists<SystemConfig>(@impact_factory), error::not_found(ECONFIG_NOT_INITIALIZED));
        let config = borrow_global<SystemConfig>(@impact_factory);
        
        // Ensure collection exists
        assert!(exists<ImpactCollection>(collection_address), error::not_found(ECOLLECTION_NOT_FOUND));
        
        // Get the collection
        let collection = borrow_global_mut<ImpactCollection>(collection_address);
        
        // Ensure collection is open for minting
        assert!(collection.is_open, error::permission_denied(EMINTING_CLOSED));
        
        // Find tier and ensure supply isn't exceeded
        let tier = find_tier_mut(&mut collection.tiers, tier_id);
        assert!(tier.minted < tier.supply, error::resource_exhausted(EINVALID_SUPPLY));
        
        // Calculate splits based on system config
        let creator_amount = (tier.price * config.creator_split) / 100;
        let platform_amount = tier.price - creator_amount;
        
        // Process payment - using direct transfer approach
        // Transfer to creator
        if (creator_amount > 0) {
            transfer<SupraCoin>(buyer, collection.creator, creator_amount);
        };
        
        // Transfer to platform
        if (platform_amount > 0) {
            transfer<SupraCoin>(buyer, config.platform_address, platform_amount);
        };
        
        // Emit payment processed event
        event::emit(PaymentProcessedEvent {
            payment_from: buyer_address,
            creator_amount,
            platform_amount,
            tier_id,
            collection_address
        });
        
        // Create the NFT with empty impact data
        let nft = ImpactNFT {
            name: nft_name,
            description: nft_description,
            uri: nft_uri,
            collection_address,
            tier: tier_id,
            impact_value: tier.impact_value,
            impact_data: vector::empty<ImpactData>(),
            creator: collection.creator,
            platform: config.platform_address 
        };
        
        // Update counters
        tier.minted = tier.minted + 1;
        collection.minted = collection.minted + 1;

        // Emit NFT minted event
        event::emit(NFTMintedEvent {
            nft_address: buyer_address,
            collection_address,
            tier: tier_id,
            recipient: buyer_address,
            price: tier.price
        });
        
        // Transfer NFT to buyer
        move_to(buyer, nft);
    }
    
    // Add impact data to an NFT
    public fun add_impact_data(
        creator: &signer,
        nft_owner: address,
        key: String,
        value: String
    ) acquires ImpactNFT {
        let creator_address = signer::address_of(creator);
        
        // Ensure NFT exists
        assert!(exists<ImpactNFT>(nft_owner), error::not_found(ENFT_NOT_FOUND));
        
        // Get the NFT
        let nft = borrow_global_mut<ImpactNFT>(nft_owner);
        
        // Ensure caller is the creator
        assert!(creator_address == nft.creator, error::permission_denied(ENO_PERMISSION));
        
        // Add impact data
        let data = ImpactData { key, value };
        vector::push_back(&mut nft.impact_data, data);
    }
    
    // Update NFT URI (for image updates)
    public fun update_nft_uri(
        creator: &signer,
        nft_owner: address,
        new_uri: String
    ) acquires ImpactNFT {
        let creator_address = signer::address_of(creator);
        
        // Ensure NFT exists
        assert!(exists<ImpactNFT>(nft_owner), error::not_found(ENFT_NOT_FOUND));
        
        // Get the NFT
        let nft = borrow_global_mut<ImpactNFT>(nft_owner);
        
        // Ensure caller is the creator
        assert!(creator_address == nft.creator, error::permission_denied(ENO_PERMISSION));
        
        nft.uri = new_uri;
    }
    
    // Get collection info
    #[view]
    public fun get_collection_info(collection_address: address): (String, String, u64, u64, bool) acquires ImpactCollection {
        let collection = borrow_global<ImpactCollection>(collection_address);
        
        (
            collection.name,
            collection.uri,
            collection.total_supply,
            collection.minted,
            collection.is_open
        )
    }

    // Get registry info
    #[view]
    public fun get_registry_collections(): vector<address> acquires Registry {
        let registry = borrow_global<Registry>(@impact_factory);
        registry.collections
    }
    
    // Get tier info by index
    #[view]
    public fun get_tier_info(collection_address: address, index: u64): (u64, String, u64, u64, u64, u64) acquires ImpactCollection {
        let collection = borrow_global<ImpactCollection>(collection_address);
        let tier = vector::borrow(&collection.tiers, index);
        
        (
            tier.id,
            tier.name,
            tier.price,
            tier.supply,
            tier.minted,
            tier.impact_value
        )
    }
    
    // Get NFT info
    #[view]
    public fun get_nft_info(nft_owner: address): (String, String, u64, u64) acquires ImpactNFT {
        let nft = borrow_global<ImpactNFT>(nft_owner);
        
        (
            nft.name,
            nft.uri,
            nft.tier,
            nft.impact_value
        )
    }
}

