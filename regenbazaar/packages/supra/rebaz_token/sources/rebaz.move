module rebaz::rebaz_coin {
    use std::signer;
    use std::string;
    use std::error;
    use std::option::{Self, Option};

    use supra_framework::coin::{Self, MintCapability};

    use rebaz::rebaz_coin_events;

    const MAX_SUPPLY: u128 = 1000000000; 
  
    struct RebazCoin has store, key {}

    struct Admin has key {
        owner: address,
        pending_owner: Option<address>,
        mint_cap: MintCapability<RebazCoin>
    }

    struct Allocation has key {
        ngo_allocation: u64,
        community_allocation: u64,
        validator_allocation: u64,
        ecosystem_allocation: u64,
        reward_pool: u64,
        total_rewards_distributed: u64,
    }

    const E_NOT_ADMIN: u64 = 1;
    const E_INSUFFICIENT_ALLOCATION: u64 = 2;
    const E_INSUFFICIENT_REWARD_POOL: u64 = 3;
    const E_ALREADY_INITIALIZED: u64 = 4;
    const E_EXCEED_MAX_SUPPLY: u64 = 5;
    const E_EXCEEDS_ALLOCATION_TOTAL: u64 = 6;
    const E_OWNERSHIP_TRANSFER_IN_PROCESS: u64 = 7;
    const E_OWNERSHIP_TRANSFER_NOT_IN_PROCESS: u64 = 8;
    const E_ADMIN_RECORD_NOT_EXIST: u64 = 9;
    const E_INVALID_AUTHORIZATION: u64 = 10;
    const E_ALLOCATION_ALREADY_SET: u64 = 11;
    const E_ALLOCATION_NOT_SET: u64 = 12;
    const E_ZERO_ADDRESS: u64 = 13;


    //////////////////// All view functions ////////////////////////////////

    #[view]
    public fun get_owner_record(admin: address): (address, Option<address>) acquires Admin {
        let stored_admin = borrow_global<Admin>(admin);
        (
            stored_admin.owner,
            stored_admin.pending_owner,
        )
    }

    #[view]
    public fun get_distribution_info(admin: address): (u64, u64, u64, u64) acquires Allocation {
        let allocation_store = borrow_global<Allocation>(admin);
        (
            allocation_store.ngo_allocation,
            allocation_store.community_allocation,
            allocation_store.validator_allocation,
            allocation_store.ecosystem_allocation
        )
    }

    #[view]
    public fun get_reward_pool_balance(admin: address): u64 acquires Allocation {
        let allocation_store = borrow_global<Allocation>(admin);
        allocation_store.reward_pool
    }


    #[view]
    public fun get_reward_distributed(admin: address): u64 acquires Allocation {
        let allocation_store = borrow_global<Allocation>(admin);
        allocation_store.total_rewards_distributed
    }

    //////////////////// All entry functions ////////////////////////////////

    public entry fun initialize(admin: &signer) {
        let admin_addr = signer::address_of(admin);

        assert!(!exists<Admin>(admin_addr), error::invalid_state(E_ALREADY_INITIALIZED)); 
        let name = string::utf8(b"Rebaz Token");
        let symbol = string::utf8(b"RBZ");
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<RebazCoin>(
            admin, 
            name, 
            symbol, 
            6, 
            true
        );
        
        move_to(
            admin, 
            Admin { 
                owner: admin_addr,
                pending_owner: option::none(),
                mint_cap 
            }
        );

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_freeze_cap(freeze_cap);

        rebaz_coin_events::emit_init_event(
            signer::address_of(admin), 
            name,
            symbol
        );
    }

    public entry fun mint(admin: &signer, recipient: address, amount: u64) acquires Admin {
        assert_admin(admin);
        mint_internal(admin, recipient, amount);
    }

    public entry fun set_allocation_schedule(
        admin: &signer, 
        ngo_allocation: u64, 
        community_allocation: u64, 
        validator_allocation: u64, 
        ecosystem_allocation: u64
    ) acquires Admin {
        assert_admin(admin);

        assert!(!exists<Allocation>(signer::address_of(admin)), error::invalid_state(E_ALLOCATION_ALREADY_SET));

        let total_allocation = ngo_allocation + community_allocation + validator_allocation + ecosystem_allocation;
        assert!(total_allocation == 10000, error::invalid_argument(E_EXCEEDS_ALLOCATION_TOTAL));

        move_to(
            admin, 
            Allocation { 
                ngo_allocation,
                community_allocation,
                validator_allocation,
                ecosystem_allocation,
                reward_pool: 0,
                total_rewards_distributed: 0
            }
        );

        rebaz_coin_events::emit_allocation_event(
            signer::address_of(admin), 
            ngo_allocation,
            community_allocation,
            validator_allocation,
            ecosystem_allocation
        );
    }

    public entry fun add_to_reward_pool(admin: &signer, amount: u64) acquires Admin, Allocation {
        assert_admin(admin);
        assert!(exists<Allocation>(signer::address_of(admin)), error::not_found(E_ALLOCATION_NOT_SET));
        let allocation_store = borrow_global_mut<Allocation>(signer::address_of(admin));
        allocation_store.reward_pool = allocation_store.reward_pool + amount;
        rebaz_coin_events::emit_reward_added_event(
            signer::address_of(admin), 
            amount
        );
    }

    public entry fun distribute_rewards(admin: &signer, recipient: address, amount: u64) acquires Admin, Allocation {
        assert_admin(admin);
        assert!(exists<Allocation>(signer::address_of(admin)), error::not_found(E_ALLOCATION_NOT_SET));
        let allocation_store = borrow_global_mut<Allocation>(signer::address_of(admin));
        assert!(allocation_store.reward_pool >= amount, error::invalid_argument(E_INSUFFICIENT_REWARD_POOL));
        allocation_store.reward_pool = allocation_store.reward_pool - amount;
        allocation_store.total_rewards_distributed = allocation_store.total_rewards_distributed + amount;
        mint_internal(admin, recipient, amount);

        rebaz_coin_events::emit_reward_distributed_event(
            signer::address_of(admin), 
            recipient,
            amount
        );
    }

     public entry fun transfer_ownership(admin: &signer, new_admin: address) acquires Admin {
        assert_admin(admin);

        let admin_addr = signer::address_of(admin);
        let stored_admin = borrow_global_mut<Admin>(admin_addr);

        assert!(new_admin != @0x0, error::invalid_argument(E_ZERO_ADDRESS));

        assert!(option::is_none(&stored_admin.pending_owner), error::invalid_state(E_OWNERSHIP_TRANSFER_IN_PROCESS));
        option::fill(&mut stored_admin.pending_owner, new_admin);
        
        rebaz_coin_events::emit_ownership_transfer_event( 
            admin_addr,
            admin_addr,
            new_admin
        );
    }

    public entry fun cancel_ownership_transfer(admin: &signer) acquires Admin {
        assert_admin(admin);

        let admin_addr = signer::address_of(admin);
        let stored_admin = borrow_global_mut<Admin>(admin_addr);

        assert!(option::is_some(&stored_admin.pending_owner), error::invalid_state(E_OWNERSHIP_TRANSFER_NOT_IN_PROCESS));
        option::extract(&mut stored_admin.pending_owner);
        
        rebaz_coin_events::emit_cancel_ownership_transfer_event(
            admin_addr, 
            admin_addr
        );
    }

    public entry fun claim_ownership(account: &signer, old_admin: address) acquires Admin, Allocation {
        assert!(exists<Admin>(old_admin), error::not_found(E_ADMIN_RECORD_NOT_EXIST));
        assert!(exists<Allocation>(old_admin), error::not_found(E_ALLOCATION_NOT_SET));

        let stored_admin = borrow_global_mut<Admin>(old_admin);

        assert!(option::is_some(&stored_admin.pending_owner), error::invalid_state(E_OWNERSHIP_TRANSFER_NOT_IN_PROCESS));

        let new_owner = option::extract(&mut stored_admin.pending_owner);
        let old_owner = stored_admin.owner;
        let caller_address = signer::address_of(account);

        assert!(new_owner == caller_address, error::permission_denied(E_INVALID_AUTHORIZATION));

        let Admin {
            owner: _,
            pending_owner: _,
            mint_cap
        } = move_from<Admin>(old_admin);

        let Allocation {
            ngo_allocation,
            community_allocation,
            validator_allocation,
            ecosystem_allocation,
            reward_pool,
            total_rewards_distributed
        } = move_from<Allocation>(old_admin);

        move_to(
            account, 
            Allocation { 
                ngo_allocation,
                community_allocation,
                validator_allocation,
                ecosystem_allocation,
                reward_pool,
                total_rewards_distributed,
            }
        );

        move_to(
            account, 
            Admin { 
                owner: new_owner,
                pending_owner: option::none(),
                mint_cap
            }
        );
        
        rebaz_coin_events::emit_claim_ownership_event(
            new_owner, 
            new_owner,
            old_owner
        );
    }

    inline fun assert_admin(admin: &signer) acquires Admin {
        assert!(exists<Admin>(signer::address_of(admin)), error::not_found(E_ADMIN_RECORD_NOT_EXIST));
        let stored_admin = borrow_global<Admin>(signer::address_of(admin));
        assert!(signer::address_of(admin) == stored_admin.owner, error::permission_denied(E_NOT_ADMIN));
    }

    inline fun mint_internal(admin: &signer, recipient: address, amount: u64) acquires Admin {
        let curr_supply = coin::supply<RebazCoin>();
        let curr_supply = option::extract(&mut curr_supply);
        let new_supply = curr_supply + (amount as u128);
        assert!(new_supply <= MAX_SUPPLY, error::invalid_argument(E_EXCEED_MAX_SUPPLY));
        let stored_admin = borrow_global<Admin>(signer::address_of(admin));
        let coins = coin::mint<RebazCoin>(amount, &stored_admin.mint_cap);
        coin::deposit(recipient, coins);

        rebaz_coin_events::emit_mint_event(
            signer::address_of(admin), 
            recipient,
            amount
        );
    }
}


#[test_only]
module rebaz::rebaz_coin_tests{
    use std::unit_test;
    use supra_framework::account;
    use supra_framework::coin;
    use supra_framework::timestamp;
    use std::signer;
    use std::vector;
    use std::option;

    use rebaz::rebaz_coin;

    use rebaz::rebaz_coin::RebazCoin;

    const PRECISION: u64 = 10000;

    public fun create_and_setup_signers(
        supra_framework: &signer,
        num: u64
    ): vector<signer> {
        let signers = unit_test::create_signers_for_testing(num+1);
        
        timestamp::set_time_has_started_for_testing(supra_framework);

        let signers_copy = vector::empty();

        while (vector::length(&signers) > 0) {
            let signer_ref = vector::pop_back(&mut signers);
            let account_addr = signer::address_of(&signer_ref);
            account::create_account_for_test(account_addr);
            vector::push_back(&mut signers_copy, signer_ref);
        };

        vector::pop_back(&mut signers_copy); // remove @0x00
        signers_copy
    }


    #[test(supra_framework = @0x1, admin = @0xcbcab0b6f33d30308df448b48d128d1b617d7c99e1b643db803ac79727d98c99)]
    fun test_e2e(supra_framework: &signer, admin: &signer){
        let signers = create_and_setup_signers(supra_framework, 1);

        let recipient = &vector::pop_back(&mut signers);
        
        let admin_addr = signer::address_of(admin);
        let recipient_addr = signer::address_of(recipient);

        rebaz_coin::initialize(admin);

        let ngo_allocation = 1000;
        let community_allocation = 3000;
        let validator_allocation = 4000;
        let ecosystem_allocation = 2000;

        rebaz_coin::set_allocation_schedule(
            admin,
            ngo_allocation,
            community_allocation,
            validator_allocation,
            ecosystem_allocation
        );

        let reward_pool = 5000;
        rebaz_coin::add_to_reward_pool(admin, reward_pool);
        
        coin::register<RebazCoin>(recipient);

        let reward_amount = 500;
        rebaz_coin::distribute_rewards(admin, recipient_addr, reward_amount);

        let reward_pool_balance = rebaz_coin::get_reward_pool_balance(admin_addr);
        let (_ngo_allocation, _community_allocation, _validator_allocation, _ecosystem_allocation) = rebaz_coin::get_distribution_info(admin_addr); 
        
        assert!(ngo_allocation == _ngo_allocation, 0);
        assert!(community_allocation == _community_allocation, 0);
        assert!(validator_allocation == _validator_allocation, 0);
        assert!(ecosystem_allocation == _ecosystem_allocation, 0);
        
        assert!(reward_pool_balance == reward_pool - reward_amount, 0);
        assert!(coin::balance<RebazCoin>(recipient_addr) == reward_amount, 0);
    }

    #[test(supra_framework = @0x1, admin = @0xcbcab0b6f33d30308df448b48d128d1b617d7c99e1b643db803ac79727d98c99)]
    fun test_ownership_transfer_and_claim(supra_framework: &signer, admin: &signer) {
        let signers = create_and_setup_signers(supra_framework, 2);

        let new_owner = &vector::pop_back(&mut signers);
    
        let old_admin_addr =  signer::address_of(admin);
        let new_owner_addr = signer::address_of(new_owner);

        rebaz_coin::initialize(admin);

        let ngo_allocation = 1000;
        let community_allocation = 3000;
        let validator_allocation = 4000;
        let ecosystem_allocation = 2000;

        rebaz_coin::set_allocation_schedule(
            admin,
            ngo_allocation,
            community_allocation,
            validator_allocation,
            ecosystem_allocation
        );

        rebaz_coin::transfer_ownership(
            admin,
            new_owner_addr
        );

        rebaz_coin::claim_ownership(
            new_owner,
            old_admin_addr,
        );

        let (owner, _) = rebaz_coin::get_owner_record(new_owner_addr);

        assert!(owner == new_owner_addr, 0);
    }

    #[test(supra_framework = @0x1, admin = @0xcbcab0b6f33d30308df448b48d128d1b617d7c99e1b643db803ac79727d98c99)]
    public fun test_ownership_transfer_cancel(supra_framework: &signer, admin: &signer) {
        let signers = create_and_setup_signers(supra_framework, 1);

        let new_owner = &vector::pop_back(&mut signers);
    
        let old_admin_addr =  signer::address_of(admin);
        let new_owner_addr = signer::address_of(new_owner);

        rebaz_coin::initialize(admin);

        let ngo_allocation = 1000;
        let community_allocation = 3000;
        let validator_allocation = 4000;
        let ecosystem_allocation = 2000;

        rebaz_coin::set_allocation_schedule(
            admin,
            ngo_allocation,
            community_allocation,
            validator_allocation,
            ecosystem_allocation
        );

        rebaz_coin::transfer_ownership(
            admin,
            new_owner_addr
        );

        rebaz_coin::cancel_ownership_transfer(
            admin
        );

        let (admin, pending_admin) = rebaz_coin::get_owner_record(old_admin_addr);

        assert!(admin == old_admin_addr, 1);
        assert!(pending_admin == option::none(), 1);
    }

    #[test(supra_framework = @0x1, admin = @0xcbcab0b6f33d30308df448b48d128d1b617d7c99e1b643db803ac79727d98c99)]
    #[expected_failure(abort_code = 65549, location=rebaz_coin)]
    public fun test_transferring_ownership_to_zero_address_fails(supra_framework: &signer, admin: &signer) {
        let _ = create_and_setup_signers(supra_framework, 1);

        rebaz_coin::initialize(admin);

        rebaz_coin::transfer_ownership(
            admin,
            @0x0
        );
    }

    #[test(supra_framework = @0x1, admin = @0xcbcab0b6f33d30308df448b48d128d1b617d7c99e1b643db803ac79727d98c99)]
    #[expected_failure(abort_code = 196612, location=rebaz_coin)]
    public fun test_double_initialization_fails(supra_framework: &signer, admin: &signer) {
        let _ = create_and_setup_signers(supra_framework, 1);

        rebaz_coin::initialize(admin);
        rebaz_coin::initialize(admin);
    }


    #[test(supra_framework = @0x1, admin = @0xcbcab0b6f33d30308df448b48d128d1b617d7c99e1b643db803ac79727d98c99)]
    #[expected_failure(abort_code = 393225, location=rebaz_coin)]
    public fun test_non_admin_trying_to_mint_fails(supra_framework: &signer, admin: &signer) {
        let signers = create_and_setup_signers(supra_framework, 2);

        let fake_admin = &vector::pop_back(&mut signers);
        let recipient = &vector::pop_back(&mut signers);

        rebaz_coin::initialize(admin);
        rebaz_coin::mint(fake_admin, signer::address_of(recipient), 1000);
    }

    #[test(supra_framework = @0x1, admin = @0xcbcab0b6f33d30308df448b48d128d1b617d7c99e1b643db803ac79727d98c99)]
    #[expected_failure(abort_code = 65541, location=rebaz_coin)]
    public fun test_mint_exceeding_max_supply_fails(supra_framework: &signer, admin: &signer) {
        let signers = create_and_setup_signers(supra_framework, 1);

        let recipient = &vector::pop_back(&mut signers);
        rebaz_coin::initialize(admin);

        let exceeded_supply = 2000000000;
        rebaz_coin::mint(admin, signer::address_of(recipient), exceeded_supply);
    }

}