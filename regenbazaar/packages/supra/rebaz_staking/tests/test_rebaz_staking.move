#[test_only]
module rebaz_staking::test_rebaz_staking {
    use std::signer;
    use std::string::{String, utf8};
    use std::vector;
    use std::option;
    use std::bcs;
    
    use supra_framework::coin;
    use supra_framework::supra_coin::SupraCoin;
    use supra_framework::object::{Self, Object, ObjectCore};
    use supra_framework::timestamp;
    use supra_framework::account;
    
    use rebaz_staking::staking;
    
    // Test NFT struct
    struct TestNFT has key {}

    // Set up a test environment
    fun setup_test(
        supra: &signer,
        admin: &signer,
        staker: &signer
    ): (address, address) {
        // Initialize timestamp module
        timestamp::set_time_has_started_for_testing(supra);
        timestamp::update_global_time_for_test_secs(1000000);
        
        // Get addresses
        let admin_addr = signer::address_of(admin);
        let staker_addr = signer::address_of(staker);
        
        // Create accounts
        account::create_account_for_test(admin_addr);
        account::create_account_for_test(staker_addr);
        
        // Initialize SupraCoin
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<SupraCoin>(
            supra,
            utf8(b"SupraCoin"),
            utf8(b"SUPRA"),
            8,
            true
        );
        
        // Register coin stores for admin and staker
        coin::register<SupraCoin>(admin);
        coin::register<SupraCoin>(staker);
        
        // Mint some coins for admin to add to pool (10,000,000 tokens)
        let coins = coin::mint<SupraCoin>(10000000000, &mint_cap);
        coin::deposit<SupraCoin>(admin_addr, coins);
        
        // Clean up capabilities
        coin::destroy_burn_cap<SupraCoin>(burn_cap);
        coin::destroy_mint_cap<SupraCoin>(mint_cap);
        coin::destroy_freeze_cap<SupraCoin>(freeze_cap);
        
        (admin_addr, staker_addr)
    }
    
    // Create a test NFT object
    fun create_test_nft(creator: &signer): Object<ObjectCore> {
        let constructor_ref = object::create_object_from_account(creator);
        object::object_from_constructor_ref(&constructor_ref)
    }

    // Calculate the resource account address
    fun get_staking_pool_address(admin_addr: address, pool_name: String): address {
        let seed = bcs::to_bytes(&pool_name);
        vector::append(&mut seed, bcs::to_bytes(&admin_addr));
        account::create_resource_address(&admin_addr, seed)
    }
    
    #[test(supra = @0x1, admin = @0x123, staker = @0x456)]
    public fun test_init_pool(supra: &signer, admin: &signer, staker: &signer) {
        // Setup
        let (admin_addr, _) = setup_test(supra, admin, staker);
        
        // Initialize staking pool
        let base_apy = 500; // 5%
        let pool_name = utf8(b"Test Staking Pool");
        let reward_token_address = @0x1; // Use supra's address since we're using SupraCoin
        
        staking::init(admin, base_apy, pool_name, reward_token_address);
        
        // Calculate the staking pool address
        let staking_pool_addr = get_staking_pool_address(admin_addr, pool_name);
        
        // Verify pool was created
        let (name, apy, total_staked, paused, pool_admin, pending_admin, reward_token) = 
            staking::get_pool_details(staking_pool_addr);
        
        assert!(name == pool_name, 0);
        assert!(apy == base_apy, 1);
        assert!(total_staked == 0, 2);
        assert!(!paused, 3);
        assert!(pool_admin == admin_addr, 4);
        assert!(pending_admin == option::none(), 5);
        assert!(reward_token == reward_token_address, 6);
    }
    
    #[test(supra = @0x1, admin = @0x123, staker = @0x456)]
    public fun test_stake_product(supra: &signer, admin: &signer, staker: &signer) {
        // Setup
        let (admin_addr, staker_addr) = setup_test(supra, admin, staker);
        
        // Initialize staking pool
        let base_apy = 500; // 5%
        let pool_name = utf8(b"Test Staking Pool");
        let reward_token_address = @0x1;
        
        staking::init(admin, base_apy, pool_name, reward_token_address);
        
        // Calculate the staking pool address
        let staking_pool_addr = get_staking_pool_address(admin_addr, pool_name);
        
        // Create NFT object
        let nft = create_test_nft(staker);
        
        // Stake the NFT
        staking::stake_product(staker, nft, staking_pool_addr);
        
        // Verify stake was created
        let stake_ids = staking::get_user_stakes(staker_addr);
        assert!(vector::length(&stake_ids) == 1, 0);
        
        let stake_id = *vector::borrow(&stake_ids, 0);
        let (obj, owner, start_time, is_locked, lock_start, lock_end, lock_multiplier, rewards) = 
            staking::get_stake_details(stake_id, staking_pool_addr);
        
        assert!(obj == nft, 1);
        assert!(owner == staker_addr, 2);
        assert!(start_time > 0, 3);
        assert!(!is_locked, 4);
        assert!(lock_start == option::none(), 5);
        assert!(lock_end == option::none(), 6);
        assert!(lock_multiplier == option::none(), 7);
        assert!(rewards == 0, 8);
        
        // Verify pool state updated
        let (_, _, total_staked, _, _, _, _) = staking::get_pool_details(staking_pool_addr);
        assert!(total_staked == 1, 9);
    }
    
    #[test(supra = @0x1, admin = @0x123, staker = @0x456)]
    public fun test_lock_and_unlock_stake(supra: &signer, admin: &signer, staker: &signer) {
        // Setup
        let (admin_addr, staker_addr) = setup_test(supra, admin, staker);
        
        // Initialize staking pool
        let base_apy = 500; // 5%
        let pool_name = utf8(b"Test Staking Pool");
        let reward_token_address = @0x1;
        
        staking::init(admin, base_apy, pool_name, reward_token_address);
        
        // Calculate the staking pool address
        let staking_pool_addr = get_staking_pool_address(admin_addr, pool_name);
        
        // Create and stake NFT
        let nft = create_test_nft(staker);
        staking::stake_product(staker, nft, staking_pool_addr);
        
        // Get stake ID
        let stake_ids = staking::get_user_stakes(staker_addr);
        let stake_id = *vector::borrow(&stake_ids, 0);
        
        // Lock the stake
        let lock_duration = 2592000; // 30 days
        staking::lock_stake(staker, stake_id, lock_duration, staking_pool_addr);
        
        // Verify stake is locked
        let (_, _, _, is_locked, lock_start, lock_end, lock_multiplier, _) = 
            staking::get_stake_details(stake_id, staking_pool_addr);
        
        assert!(is_locked, 0);
        assert!(option::is_some(&lock_start), 1);
        assert!(option::is_some(&lock_end), 2);
        assert!(option::is_some(&lock_multiplier), 3);
        
        // Fast forward time past lock period
        timestamp::fast_forward_seconds(lock_duration + 1);
        
        // Unlock the stake
        staking::unlock_stake(staker, stake_id, staking_pool_addr);
        
        // Verify stake is unlocked
        let (_, _, _, is_locked, lock_start, lock_end, lock_multiplier, _) = 
            staking::get_stake_details(stake_id, staking_pool_addr);
        
        assert!(!is_locked, 4);
        assert!(lock_start == option::none(), 5);
        assert!(lock_end == option::none(), 6);
        assert!(lock_multiplier == option::none(), 7);
    }
    
    #[test(supra = @0x1, admin = @0x123, staker = @0x456)]
    public fun test_withdraw_stake(supra: &signer, admin: &signer, staker: &signer) {
        // Setup
        let (admin_addr, staker_addr) = setup_test(supra, admin, staker);
        
        // Initialize staking pool
        let base_apy = 500; // 5%
        let pool_name = utf8(b"Test Staking Pool");
        let reward_token_address = @0x1;
        
        staking::init(admin, base_apy, pool_name, reward_token_address);
        
        // Calculate the staking pool address
        let staking_pool_addr = get_staking_pool_address(admin_addr, pool_name);
        
        // Add rewards to the pool (1,000,000 tokens)
        staking::add_rewards_to_pool<SupraCoin>(admin, 1000000000, staking_pool_addr);
        
        // Create and stake NFT
        let nft = create_test_nft(staker);
        staking::stake_product(staker, nft, staking_pool_addr);
        
        // Get stake ID
        let stake_ids = staking::get_user_stakes(staker_addr);
        let stake_id = *vector::borrow(&stake_ids, 0);
        
        // Fast forward to accumulate rewards (1 year)
        timestamp::fast_forward_seconds(31536000);
        
        // Withdraw the stake
        staking::withdraw_stake(staker, stake_id, staking_pool_addr);
        
        // Verify stake was withdrawn
        let stake_ids = staking::get_user_stakes(staker_addr);
        assert!(vector::length(&stake_ids) == 0, 0);
        
        // Verify pool state updated
        let (_, _, total_staked, _, _, _, _) = staking::get_pool_details(staking_pool_addr);
        assert!(total_staked == 0, 1);
        
        // Verify rewards were accumulated
        let unclaimed_rewards = staking::get_user_unclaimed_rewards(staker_addr);
        assert!(unclaimed_rewards > 0, 2);
    }
    
    #[test(supra = @0x1, admin = @0x123, staker = @0x456)]
    public fun test_claim_rewards(supra: &signer, admin: &signer, staker: &signer) {
        // Setup
        let (admin_addr, staker_addr) = setup_test(supra, admin, staker);
        
        // Initialize staking pool
        let base_apy = 500; // 5%
        let pool_name = utf8(b"Test Staking Pool");
        let reward_token_address = @0x1;
        
        staking::init(admin, base_apy, pool_name, reward_token_address);
        
        // Calculate the staking pool address
        let staking_pool_addr = get_staking_pool_address(admin_addr, pool_name);
        
        // Add rewards to the pool (1,000,000 tokens)
        staking::add_rewards_to_pool<SupraCoin>(admin, 1000000000, staking_pool_addr);
        
        // Create and stake NFT
        let nft = create_test_nft(staker);
        staking::stake_product(staker, nft, staking_pool_addr);
        
        // Get stake ID
        let stake_ids = staking::get_user_stakes(staker_addr);
        let stake_id = *vector::borrow(&stake_ids, 0);
        
        // Fast forward to accumulate rewards (1 year)
        timestamp::fast_forward_seconds(31536000);
        
        // Withdraw the stake to accumulate rewards
        staking::withdraw_stake(staker, stake_id, staking_pool_addr);
        
        // Get unclaimed rewards
        let unclaimed_rewards = staking::get_user_unclaimed_rewards(staker_addr);
        assert!(unclaimed_rewards > 0, 0);
        
        // Claim rewards
        staking::claim_rewards<SupraCoin>(staker, staking_pool_addr);
        
        // Verify rewards were claimed
        let unclaimed_rewards = staking::get_user_unclaimed_rewards(staker_addr);
        assert!(unclaimed_rewards == 0, 1);
        
        // Verify user received the rewards
        let balance = coin::balance<SupraCoin>(staker_addr);
        assert!(balance > 0, 2);
    }
    
    #[test(supra = @0x1, admin = @0x123, staker = @0x456)]
    public fun test_admin_functions(supra: &signer, admin: &signer, staker: &signer) {
        // Setup
        let (admin_addr, _) = setup_test(supra, admin, staker);
        
        // Initialize staking pool
        let base_apy = 500; // 5%
        let pool_name = utf8(b"Test Staking Pool");
        let reward_token_address = @0x1;
        
        staking::init(admin, base_apy, pool_name, reward_token_address);
        
        // Calculate the staking pool address
        let staking_pool_addr = get_staking_pool_address(admin_addr, pool_name);
        
        // Update base APY
        let new_apy = 800; // 8%
        staking::update_base_apy(admin, new_apy, staking_pool_addr);
        
        // Verify APY was updated
        let (_, apy, _, _, _, _, _) = staking::get_pool_details(staking_pool_addr);
        assert!(apy == new_apy, 0);
        
        // Pause staking pool
        staking::pause_staking_pool(admin, true, staking_pool_addr);
        
        // Verify pool was paused
        let (_, _, _, paused, _, _, _) = staking::get_pool_details(staking_pool_addr);
        assert!(paused, 1);
        
        // Unpause staking pool
        staking::pause_staking_pool(admin, false, staking_pool_addr);
        
        // Verify pool was unpaused
        let (_, _, _, paused, _, _, _) = staking::get_pool_details(staking_pool_addr);
        assert!(!paused, 2);
    }
}
