#[test_only]
module impact_factory::test_impact_factory {
    use std::signer;
    use std::string;
    use supra_framework::account;
    use supra_framework::coin;
    use supra_framework::supra_coin;
    
    use impact_factory::impact_factory;
    
    // Test addresses
    const ADMIN: address = @0x1;
    const CREATOR: address = @0x2;
    const BUYER: address = @0x3;
    const PLATFORM: address = @0x4;
    const REBAZ_TOKEN: address = @rebaz_token;
    
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
    
    // Test initialization
    #[test(admin = @impact_factory)]
    public fun test_init(admin: signer) {
        // Initialize the module
        impact_factory::init(&admin);
        
        // Verify the admin was set correctly
        assert!(impact_factory::get_admin() == signer::address_of(&admin), 0);
        
        // Verify default values
        let (creator_split, platform_split) = impact_factory::get_splits();
        let (creator_royalty, platform_royalty) = impact_factory::get_royalties();
        
        assert!(creator_split == 90, 0);
        assert!(platform_split == 10, 0);
        assert!(creator_royalty == 5, 0);
        assert!(platform_royalty == 5, 0);
    }
    
    // Test updating admin address
    #[test(admin = @impact_factory, new_admin = @0x5)]
    public fun test_update_admin(admin: signer, new_admin: signer) {
        // Initialize the module
        impact_factory::init(&admin);
        
        // Update admin
        impact_factory::update_admin(&admin, signer::address_of(&new_admin));
        
        // Verify new admin
        assert!(impact_factory::get_admin() == signer::address_of(&new_admin), 0);
    }
    
    // Test updating platform address
    #[test(admin = @impact_factory, platform = @0x4)]
    public fun test_update_platform_address(admin: signer, platform: signer) {
        // Initialize the module
        impact_factory::init(&admin);
        
        // Update platform address
        impact_factory::update_platform_address(&admin, signer::address_of(&platform));
        
        // Verify platform address
        assert!(impact_factory::get_platform_address() == signer::address_of(&platform), 0);
    }
    
    // Test updating splits
    #[test(admin = @impact_factory)]
    public fun test_update_splits(admin: signer) {
        // Initialize the module
        impact_factory::init(&admin);
        
        // Update splits
        impact_factory::update_splits(&admin, 80, 20);
        
        // Verify splits
        let (creator_split, platform_split) = impact_factory::get_splits();
        assert!(creator_split == 80, 0);
        assert!(platform_split == 20, 0);
    }
    
    // Test creating a collection
    #[test(admin = @impact_factory, creator = @0x2)]
    public fun test_create_collection(admin: signer, creator: signer) {
        // Setup
        account::create_account_for_test(signer::address_of(&creator));
        
        // Initialize the module
        impact_factory::init(&admin);
        
        // Create collection
        impact_factory::create_collection(
            &creator,
            string::utf8(b"Test Collection"),
            string::utf8(b"A test collection description"),
            string::utf8(b"https://example.com/collection"),
            100 // total supply
        );
        
        // Verify collection was created
        let (name, uri, total_supply, minted, is_open) = 
            impact_factory::get_collection_info(signer::address_of(&creator));
        
        assert!(name == string::utf8(b"Test Collection"), 0);
        assert!(uri == string::utf8(b"https://example.com/collection"), 0);
        assert!(total_supply == 100, 0);
        assert!(minted == 0, 0);
        assert!(is_open == false, 0);
    }
    
    // Test adding a tier to a collection
    #[test(admin = @impact_factory, creator = @0x2)]
    public fun test_add_tier(admin: signer, creator: signer) {
        // Setup
        account::create_account_for_test(signer::address_of(&creator));
        
        // Initialize the module
        impact_factory::init(&admin);
        
        // Create collection
        impact_factory::create_collection(
            &creator,
            string::utf8(b"Test Collection"),
            string::utf8(b"A test collection description"),
            string::utf8(b"https://example.com/collection"),
            100 // total supply
        );
        
        // Add tier
        impact_factory::add_tier(
            &creator,
            1, // tier id
            string::utf8(b"Gold Tier"),
            50, // price
            20, // supply
            100 // impact value
        );
        
        // Verify tier was added
        let (id, name, price, supply, minted, impact_value) = 
            impact_factory::get_tier_info(signer::address_of(&creator), 0);
        
        assert!(id == 1, 0);
        assert!(name == string::utf8(b"Gold Tier"), 0);
        assert!(price == 50, 0);
        assert!(supply == 20, 0);
        assert!(minted == 0, 0);
        assert!(impact_value == 100, 0);
    }
    
    // Test opening a collection for minting
    #[test(admin = @impact_factory, creator = @0x2)]
    public fun test_open_collection(admin: signer, creator: signer) {
        // Setup
        account::create_account_for_test(signer::address_of(&creator));
        
        // Initialize the module
        impact_factory::init(&admin);
        
        // Create collection
        impact_factory::create_collection(
            &creator,
            string::utf8(b"Test Collection"),
            string::utf8(b"A test collection description"),
            string::utf8(b"https://example.com/collection"),
            100 // total supply
        );
        
        // Open collection
        impact_factory::open_collection(&creator);
        
        // Verify collection was opened
        let (_, _, _, _, is_open) = 
            impact_factory::get_collection_info(signer::address_of(&creator));
        
        assert!(is_open == true, 0);
    }
    
    // Test minting an NFT
    #[test(supra_framework = @0x1, admin = @impact_factory, creator = @0x2, buyer = @0x3, platform_account = @0x4, rebaz_token = @rebaz_token)]
    public fun test_mint_nft(
        supra_framework: signer, 
        admin: signer, 
        creator: signer, 
        buyer: signer, 
        platform_account: signer,
        rebaz_token: signer
    ) {
        // Setup accounts
        account::create_account_for_test(signer::address_of(&admin));
        account::create_account_for_test(signer::address_of(&creator));
        account::create_account_for_test(signer::address_of(&buyer));
        account::create_account_for_test(signer::address_of(&platform_account));
        
        // Initialize the module
        impact_factory::init(&admin);
        
        // Update platform address
        impact_factory::update_platform_address(&admin, signer::address_of(&platform_account));
        
        // Initialize SupraCoin for test
        let (burn_cap, mint_cap) = supra_coin::initialize_for_test(&supra_framework);
        
        // Register SupraCoin for all accounts
        coin::register<supra_coin::SupraCoin>(&admin);
        coin::register<supra_coin::SupraCoin>(&creator);
        coin::register<supra_coin::SupraCoin>(&buyer);
        coin::register<supra_coin::SupraCoin>(&platform_account);
        
        // Mint SupraCoins to buyer
        let coins = coin::mint<supra_coin::SupraCoin>(1000, &mint_cap);
        coin::deposit(signer::address_of(&buyer), coins);
        
        // Create collection
        impact_factory::create_collection(
            &creator,
            string::utf8(b"Test Collection"),
            string::utf8(b"A test collection description"),
            string::utf8(b"https://example.com/collection"),
            100 // total supply
        );
        
        // Add tier
        impact_factory::add_tier(
            &creator,
            1, // tier id
            string::utf8(b"Gold Tier"),
            50, // price
            20, // supply
            100 // impact value
        );
        
        // Open collection
        impact_factory::open_collection(&creator);
        
        // Mint NFT
        impact_factory::mint_nft(
            &buyer,
            signer::address_of(&creator),
            1, // tier id
            string::utf8(b"Test NFT"),
            string::utf8(b"A test NFT description"),
            string::utf8(b"https://example.com/nft")
        );
        
        // Verify NFT was minted
        let (name, uri, tier, impact_value) = 
            impact_factory::get_nft_info(signer::address_of(&buyer));
        
        assert!(name == string::utf8(b"Test NFT"), 0);
        assert!(uri == string::utf8(b"https://example.com/nft"), 0);
        assert!(tier == 1, 0);
        assert!(impact_value == 100, 0);
        
        // Verify collection minted count increased
        let (_, _, _, minted, _) = 
            impact_factory::get_collection_info(signer::address_of(&creator));
        
        assert!(minted == 1, 0);
        
        // Verify tier minted count increased
        let (_, _, _, _, tier_minted, _) = 
            impact_factory::get_tier_info(signer::address_of(&creator), 0);
        
        assert!(tier_minted == 1, 0);
        
        // Clean up
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    // Test adding impact data to an NFT
    #[test(supra_framework = @0x1, admin = @impact_factory, creator = @0x2, buyer = @0x3, platform_account = @0x4, rebaz_token = @rebaz_token)]
    public fun test_add_impact_data(
        supra_framework: signer, 
        admin: signer, 
        creator: signer, 
        buyer: signer,
        platform_account: signer,
        rebaz_token: signer
    ) {
        // Setup accounts
        account::create_account_for_test(signer::address_of(&admin));
        account::create_account_for_test(signer::address_of(&creator));
        account::create_account_for_test(signer::address_of(&buyer));
        account::create_account_for_test(signer::address_of(&platform_account));
        
        // Initialize the module
        impact_factory::init(&admin);
        
        // Update platform address
        impact_factory::update_platform_address(&admin, signer::address_of(&platform_account));
        
        // Initialize SupraCoin for test
        let (burn_cap, mint_cap) = supra_coin::initialize_for_test(&supra_framework);
        
        // Register SupraCoin for all accounts
        coin::register<supra_coin::SupraCoin>(&admin);
        coin::register<supra_coin::SupraCoin>(&creator);
        coin::register<supra_coin::SupraCoin>(&buyer);
        coin::register<supra_coin::SupraCoin>(&platform_account);
        
        // Mint SupraCoins to buyer
        let coins = coin::mint<supra_coin::SupraCoin>(1000, &mint_cap);
        coin::deposit(signer::address_of(&buyer), coins);
        
        // Create collection
        impact_factory::create_collection(
            &creator,
            string::utf8(b"Test Collection"),
            string::utf8(b"A test collection description"),
            string::utf8(b"https://example.com/collection"),
            100 // total supply
        );
        
        // Add tier
        impact_factory::add_tier(
            &creator,
            1, // tier id
            string::utf8(b"Gold Tier"),
            50, // price
            20, // supply
            100 // impact value
        );
        
        // Open collection
        impact_factory::open_collection(&creator);
        
        // Mint NFT
        impact_factory::mint_nft(
            &buyer,
            signer::address_of(&creator),
            1, // tier id
            string::utf8(b"Test NFT"),
            string::utf8(b"A test NFT description"),
            string::utf8(b"https://example.com/nft")
        );
        
        // Add impact data
        impact_factory::add_impact_data(
            &creator,
            signer::address_of(&buyer),
            string::utf8(b"carbon_offset"),
            string::utf8(b"10 tons")
        );
        
        // Clean up
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    // Test updating NFT URI
    #[test(supra_framework = @0x1, admin = @impact_factory, creator = @0x2, buyer = @0x3, platform_account = @0x4, rebaz_token = @rebaz_token)]
    public fun test_update_nft_uri(
        supra_framework: signer, 
        admin: signer, 
        creator: signer, 
        buyer: signer,
        platform_account: signer,
        rebaz_token: signer
    ) {
        // Setup accounts
        account::create_account_for_test(signer::address_of(&admin));
        account::create_account_for_test(signer::address_of(&creator));
        account::create_account_for_test(signer::address_of(&buyer));
        account::create_account_for_test(signer::address_of(&platform_account));
        
        // Initialize the module
        impact_factory::init(&admin);
        
        // Update platform address
        impact_factory::update_platform_address(&admin, signer::address_of(&platform_account));
        
        // Initialize SupraCoin for test
        let (burn_cap, mint_cap) = supra_coin::initialize_for_test(&supra_framework);
        
        // Register SupraCoin for all accounts
        coin::register<supra_coin::SupraCoin>(&admin);
        coin::register<supra_coin::SupraCoin>(&creator);
        coin::register<supra_coin::SupraCoin>(&buyer);
        coin::register<supra_coin::SupraCoin>(&platform_account);
        
        // Mint SupraCoins to buyer
        let coins = coin::mint<supra_coin::SupraCoin>(1000, &mint_cap);
        coin::deposit(signer::address_of(&buyer), coins);
        
        // Create collection
        impact_factory::create_collection(
            &creator,
            string::utf8(b"Test Collection"),
            string::utf8(b"A test collection description"),
            string::utf8(b"https://example.com/collection"),
            100 // total supply
        );
        
        // Add tier
        impact_factory::add_tier(
            &creator,
            1, // tier id
            string::utf8(b"Gold Tier"),
            50, // price
            20, // supply
            100 // impact value
        );
        
        // Open collection
        impact_factory::open_collection(&creator);
        
        // Mint NFT
        impact_factory::mint_nft(
            &buyer,
            signer::address_of(&creator),
            1, // tier id
            string::utf8(b"Test NFT"),
            string::utf8(b"A test NFT description"),
            string::utf8(b"https://example.com/nft")
        );
        
        // Update NFT URI
        impact_factory::update_nft_uri(
            &creator,
            signer::address_of(&buyer),
            string::utf8(b"https://example.com/nft/updated")
        );
        
        // Verify URI was updated
        let (_, uri, _, _) = 
            impact_factory::get_nft_info(signer::address_of(&buyer));
        
        assert!(uri == string::utf8(b"https://example.com/nft/updated"), 0);
        
        // Clean up
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
}
