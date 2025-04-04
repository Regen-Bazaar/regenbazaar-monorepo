module rebaz_staking::staking {
    use std::bcs;
    use std::error;
    use std::option::{Self, Option};
    use std::signer;
    use std::string::{String};
    use std::vector;

    use aptos_std::table::{Self, Table};

    use supra_framework::account::{Self, SignerCapability, create_signer_with_capability};
    use supra_framework::coin;
    use supra_framework::object::{Self, Object, ObjectCore};
    use supra_framework::supra_account;
    use supra_framework::timestamp;

    // Add address for rebaz
    use rebaz_staking::rebaz_staking_events;

    // Error codes
    const ESTAKING_POOL_ALREADY_EXISTS: u64 = 1;
    const ESTAKING_POOL_DOES_NOT_EXIST: u64 = 2;
    const EINVALID_ADMIN_ACCOUNT: u64 = 3;
    const EADMIN_TRANSFER_IN_PROCESS: u64 = 4;
    const EADMIN_TRANSFER_NOT_IN_PROCESS: u64 = 5;
    const EINVALID_AUTHORIZATION: u64 = 6;
    const ESTAKE_DOES_NOT_EXIST: u64 = 7;
    const ESTAKE_ALREADY_LOCKED: u64 = 8;
    const ESTAKE_NOT_LOCKED: u64 = 9;
    const ESTAKE_LOCKED_PERIOD_NOT_ENDED: u64 = 10;
    const EINVALID_LOCK_DURATION: u64 = 11;
    const EZERO_REWARD_BALANCE: u64 = 12;
    const ESTAKING_POOL_PAUSED: u64 = 13;
    const ENOT_OWNER_OF_STAKE: u64 = 14;

    // Constants
    const SECONDS_PER_YEAR: u64 = 31536000; // 365 days
    const PRECISION: u64 = 10000; // 4 decimal places for percentage values
    const MIN_LOCK_DURATION: u64 = 2592000; // 30 days
    const MAX_LOCK_DURATION: u64 = 31536000; // 365 days (1 year)
    
    // Lock durations and their multipliers
    const LOCK_DURATION_30_DAYS: u64 = 2592000; // 30 days
    const LOCK_DURATION_90_DAYS: u64 = 7776000; // 90 days
    const LOCK_DURATION_180_DAYS: u64 = 15552000; // 180 days
    const LOCK_DURATION_365_DAYS: u64 = 31536000; // 365 days
    
    const LOCK_MULTIPLIER_30_DAYS: u64 = 12000; // 1.2x
    const LOCK_MULTIPLIER_90_DAYS: u64 = 15000; // 1.5x
    const LOCK_MULTIPLIER_180_DAYS: u64 = 20000; // 2.0x
    const LOCK_MULTIPLIER_365_DAYS: u64 = 30000; // 3.0x

    struct StakingPool has key {
        name: String,
        base_apy: u64, // Base APY in bps (e.g., 500 = 5%)
        total_staked_products: u64,
        next_stake_id: u64,
        paused: bool,
        staking_pool_signer_capability: SignerCapability,
        admin: address,
        pending_admin: Option<address>,
        reward_token_address: address,
    }

    struct StakesStorage has key {
        stakes: Table<u64, StakedProduct>
    }

    struct UserStakesInfo has key {
        stake_ids: vector<u64>,
        unclaimed_rewards: u64
    }

    struct StakedProduct has copy, drop, store {
        id: u64,
        nft_object: Object<ObjectCore>,
        staker: address,
        staking_start_time: u64,
        is_locked: bool,
        lock_start_time: Option<u64>,
        lock_end_time: Option<u64>,
        lock_multiplier: Option<u64>,
        accumulated_rewards: u64,
        last_reward_calculation_time: u64
    }

    #[view]
    public fun get_pool_details(staking_pool_addr: address): (String, u64, u64, bool, address, Option<address>, address) acquires StakingPool {
        assert!(exists<StakingPool>(staking_pool_addr), error::not_found(ESTAKING_POOL_DOES_NOT_EXIST));
        let pool = borrow_global<StakingPool>(staking_pool_addr);
        (
            pool.name,
            pool.base_apy,
            pool.total_staked_products,
            pool.paused,
            pool.admin,
            pool.pending_admin,
            pool.reward_token_address
        )
    }

    fun get_stake_info(stake_id: u64, staking_pool_addr: address): StakedProduct acquires StakesStorage {
        assert!(exists<StakesStorage>(staking_pool_addr), error::not_found(ESTAKING_POOL_DOES_NOT_EXIST));
        let stakes_storage = borrow_global<StakesStorage>(staking_pool_addr);
        assert!(table::contains(&stakes_storage.stakes, stake_id), error::not_found(ESTAKE_DOES_NOT_EXIST));
        *table::borrow(&stakes_storage.stakes, stake_id)
    }

    fun update_stake_info(stake_id: u64, staking_pool_addr: address, stake: StakedProduct) acquires StakesStorage {
        assert!(exists<StakesStorage>(staking_pool_addr), error::not_found(ESTAKING_POOL_DOES_NOT_EXIST));
        let stakes_storage = borrow_global_mut<StakesStorage>(staking_pool_addr);
        assert!(table::contains(&stakes_storage.stakes, stake_id), error::not_found(ESTAKE_DOES_NOT_EXIST));
        *table::borrow_mut(&mut stakes_storage.stakes, stake_id) = stake;
    }

    #[view]
    public fun get_stake_details(stake_id: u64, staking_pool_addr: address): (Object<ObjectCore>, address, u64, bool, Option<u64>, Option<u64>, Option<u64>, u64) acquires StakesStorage {
        let stake = get_stake_info(stake_id, staking_pool_addr);
        (
            stake.nft_object,
            stake.staker,
            stake.staking_start_time,
            stake.is_locked,
            stake.lock_start_time,
            stake.lock_end_time,
            stake.lock_multiplier,
            stake.accumulated_rewards
        )
    }

    #[view]
    public fun get_user_stakes(user_addr: address): vector<u64> acquires UserStakesInfo {
        if (!exists<UserStakesInfo>(user_addr)) {
            return vector::empty()
        };
        *&borrow_global<UserStakesInfo>(user_addr).stake_ids
    }

    #[view]
    public fun get_user_unclaimed_rewards(user_addr: address): u64 acquires UserStakesInfo {
        if (!exists<UserStakesInfo>(user_addr)) {
            return 0
        };
        borrow_global<UserStakesInfo>(user_addr).unclaimed_rewards
    }

    #[view]
    public fun calculate_lock_multiplier(lock_duration: u64): (u64, bool) {
        if (lock_duration == LOCK_DURATION_30_DAYS) {
            (LOCK_MULTIPLIER_30_DAYS, true)
        } else if (lock_duration == LOCK_DURATION_90_DAYS) {
            (LOCK_MULTIPLIER_90_DAYS, true)
        } else if (lock_duration == LOCK_DURATION_180_DAYS) {
            (LOCK_MULTIPLIER_180_DAYS, true)
        } else if (lock_duration == LOCK_DURATION_365_DAYS) {
            (LOCK_MULTIPLIER_365_DAYS, true)
        } else {
            (0, false)
        }
    }

    public entry fun init(
        admin: &signer,
        base_apy: u64,
        name: String,
        reward_token_address: address
    ) {
        let admin_addr = signer::address_of(admin);
        assert!(!exists<StakingPool>(admin_addr), error::already_exists(ESTAKING_POOL_ALREADY_EXISTS));

        let seed = bcs::to_bytes(&name);
        vector::append(&mut seed, bcs::to_bytes(&admin_addr));
        let (staking_pool_signer, staking_pool_cap) = account::create_resource_account(admin, seed);
        let staking_pool_addr = signer::address_of(&staking_pool_signer);

        move_to(
            &staking_pool_signer,
            StakingPool {
                name,
                base_apy,
                total_staked_products: 0,
                next_stake_id: 0,
                paused: false,
                staking_pool_signer_capability: staking_pool_cap,
                admin: admin_addr,
                pending_admin: option::none(),
                reward_token_address,
            }
        );

        move_to(
            &staking_pool_signer,
            StakesStorage {
                stakes: table::new()
            }
        );

        let current_time = timestamp::now_seconds();
        rebaz_staking_events::emit_pool_init_event(
            admin_addr,
            staking_pool_addr,
            base_apy,
            name,
            current_time
        );
    }

    public entry fun stake_product(
        staker: &signer,
        product_object: Object<ObjectCore>,
        staking_pool_addr: address
    ) acquires StakingPool, StakesStorage, UserStakesInfo {
        assert!(exists<StakingPool>(staking_pool_addr), error::not_found(ESTAKING_POOL_DOES_NOT_EXIST));
        let pool = borrow_global_mut<StakingPool>(staking_pool_addr);
        
        assert!(!pool.paused, error::invalid_state(ESTAKING_POOL_PAUSED));
        
        let staker_addr = signer::address_of(staker);
        
        if (!exists<UserStakesInfo>(staker_addr)) {
            move_to(
                staker, 
                UserStakesInfo {
                    stake_ids: vector::empty(),
                    unclaimed_rewards: 0
                }
            );
        };
        
        assert!(object::owner(product_object) == staker_addr, error::permission_denied(ENOT_OWNER_OF_STAKE));
        
        let stake_id = pool.next_stake_id;
        let current_time = timestamp::now_seconds();
        
        let staked_product = StakedProduct {
            id: stake_id,
            nft_object: product_object,
            staker: staker_addr,
            staking_start_time: current_time,
            is_locked: false,
            lock_start_time: option::none(),
            lock_end_time: option::none(),
            lock_multiplier: option::none(),
            accumulated_rewards: 0,
            last_reward_calculation_time: current_time
        };
        
        object::transfer(staker, product_object, staking_pool_addr);
        
        let stakes_storage = borrow_global_mut<StakesStorage>(staking_pool_addr);
        table::add(&mut stakes_storage.stakes, stake_id, staked_product);
        
        let user_stakes = borrow_global_mut<UserStakesInfo>(staker_addr);
        vector::push_back(&mut user_stakes.stake_ids, stake_id);
        
        pool.next_stake_id = stake_id + 1;
        pool.total_staked_products = pool.total_staked_products + 1;
        
        rebaz_staking_events::emit_stake_event(
            staker_addr,
            stake_id,
            product_object,
            current_time
        );
    }

    public entry fun lock_stake(
        staker: &signer,
        stake_id: u64,
        lock_duration: u64,
        staking_pool_addr: address
    ) acquires StakingPool, StakesStorage {
        assert!(exists<StakingPool>(staking_pool_addr), error::not_found(ESTAKING_POOL_DOES_NOT_EXIST));
        let pool = borrow_global<StakingPool>(staking_pool_addr);
        
        assert!(!pool.paused, error::invalid_state(ESTAKING_POOL_PAUSED));
        
        let (multiplier, is_valid) = calculate_lock_multiplier(lock_duration);
        assert!(is_valid, error::invalid_argument(EINVALID_LOCK_DURATION));
        
        let staker_addr = signer::address_of(staker);
        let mut_stake = get_stake_info(stake_id, staking_pool_addr);
        
        assert!(mut_stake.staker == staker_addr, error::permission_denied(ENOT_OWNER_OF_STAKE));
        assert!(!mut_stake.is_locked, error::invalid_state(ESTAKE_ALREADY_LOCKED));
        
        update_accumulated_rewards(stake_id, staking_pool_addr);
        mut_stake = get_stake_info(stake_id, staking_pool_addr); // Get updated stake info after rewards update
        
        let current_time = timestamp::now_seconds();
        mut_stake.is_locked = true;
        mut_stake.lock_start_time = option::some(current_time);
        mut_stake.lock_end_time = option::some(current_time + lock_duration);
        mut_stake.lock_multiplier = option::some(multiplier);
        
        update_stake_info(stake_id, staking_pool_addr, mut_stake);
        
        rebaz_staking_events::emit_lock_event(
            staker_addr,
            stake_id,
            lock_duration,
            multiplier,
            current_time
        );
    }

    public entry fun unlock_stake(
        staker: &signer,
        stake_id: u64,
        staking_pool_addr: address
    ) acquires StakingPool, StakesStorage {
        assert!(exists<StakingPool>(staking_pool_addr), error::not_found(ESTAKING_POOL_DOES_NOT_EXIST));
        
        let staker_addr = signer::address_of(staker);
        let mut_stake = get_stake_info(stake_id, staking_pool_addr);
        
        assert!(mut_stake.staker == staker_addr, error::permission_denied(ENOT_OWNER_OF_STAKE));
        assert!(mut_stake.is_locked, error::invalid_state(ESTAKE_NOT_LOCKED));
        
        let current_time = timestamp::now_seconds();
        let lock_end_time = *option::borrow(&mut_stake.lock_end_time);
        assert!(current_time >= lock_end_time, error::invalid_state(ESTAKE_LOCKED_PERIOD_NOT_ENDED));
        
        update_accumulated_rewards(stake_id, staking_pool_addr);
        mut_stake = get_stake_info(stake_id, staking_pool_addr); // Get updated stake info after rewards update
        
        mut_stake.is_locked = false;
        mut_stake.lock_start_time = option::none();
        mut_stake.lock_end_time = option::none();
        mut_stake.lock_multiplier = option::none();
        
        update_stake_info(stake_id, staking_pool_addr, mut_stake);
        
        rebaz_staking_events::emit_unlock_event(
            staker_addr,
            stake_id,
            current_time
        );
    }

    public entry fun withdraw_stake(
        staker: &signer,
        stake_id: u64,
        staking_pool_addr: address
    ) acquires StakingPool, StakesStorage, UserStakesInfo {
        assert!(exists<StakingPool>(staking_pool_addr), error::not_found(ESTAKING_POOL_DOES_NOT_EXIST));
        let staker_addr = signer::address_of(staker);
        
        assert!(exists<StakesStorage>(staking_pool_addr), error::not_found(ESTAKING_POOL_DOES_NOT_EXIST));
        let stakes_storage = borrow_global<StakesStorage>(staking_pool_addr);
        assert!(table::contains(&stakes_storage.stakes, stake_id), error::not_found(ESTAKE_DOES_NOT_EXIST));
        let stake = table::borrow(&stakes_storage.stakes, stake_id);
        
        assert!(stake.staker == staker_addr, error::permission_denied(ENOT_OWNER_OF_STAKE));
        assert!(!stake.is_locked, error::invalid_state(ESTAKE_ALREADY_LOCKED));
        
        let user_stakes = borrow_global<UserStakesInfo>(staker_addr);
        let stake_ids = *&user_stakes.stake_ids;
        let len = vector::length(&stake_ids);
        let i = 0;
        while (i < len) {
            let current_stake_id = *vector::borrow(&stake_ids, i);
            update_accumulated_rewards(current_stake_id, staking_pool_addr);
            i = i + 1;
        };
        
        // Now we can safely borrow the pool and stakes
        let pool = borrow_global_mut<StakingPool>(staking_pool_addr);
        
        assert!(exists<StakesStorage>(staking_pool_addr), error::not_found(ESTAKING_POOL_DOES_NOT_EXIST));
        let stakes_storage = borrow_global<StakesStorage>(staking_pool_addr);
        assert!(table::contains(&stakes_storage.stakes, stake_id), error::not_found(ESTAKE_DOES_NOT_EXIST));
        let stake = get_stake_info(stake_id, staking_pool_addr);
        
        assert!(stake.staker == staker_addr, error::permission_denied(ENOT_OWNER_OF_STAKE));
        assert!(!stake.is_locked, error::invalid_state(ESTAKE_ALREADY_LOCKED));
        
        let nft_object = stake.nft_object;
        let updated_accumulated_rewards = stake.accumulated_rewards;
        
        add_to_unclaimed_rewards(staker_addr, updated_accumulated_rewards);
        
        let stakes_storage = borrow_global_mut<StakesStorage>(staking_pool_addr);
        let StakedProduct { id: _, nft_object: _, staker: _, staking_start_time: _, is_locked: _, 
            lock_start_time: _, lock_end_time: _, lock_multiplier: _, accumulated_rewards: _, last_reward_calculation_time: _ } = 
            table::remove(&mut stakes_storage.stakes, stake_id);
        
        let user_stakes = borrow_global_mut<UserStakesInfo>(staker_addr);
        let (exists, index) = vector::index_of(&user_stakes.stake_ids, &stake_id);
        if (exists) {
            vector::remove(&mut user_stakes.stake_ids, index);
        };
        
        let pool_signer = create_signer_with_capability(&pool.staking_pool_signer_capability);
        object::transfer(&pool_signer, nft_object, staker_addr);
        
        pool.total_staked_products = pool.total_staked_products - 1;
        
        let current_time = timestamp::now_seconds();
        rebaz_staking_events::emit_withdraw_event(
            staker_addr,
            stake_id,
            nft_object,
            current_time
        );
    }

    fun distribute_rewards<CoinType>(
        staker_addr: address,
        amount: u64,
        staking_pool_addr: address
    ) acquires StakingPool {
        let pool = borrow_global<StakingPool>(staking_pool_addr);
        let pool_signer = create_signer_with_capability(&pool.staking_pool_signer_capability);
        
        assert!(
            coin::is_account_registered<CoinType>(staking_pool_addr) && 
            coin::balance<CoinType>(staking_pool_addr) >= amount,
            error::invalid_state(EZERO_REWARD_BALANCE)
        );
        
        let reward_coins = coin::withdraw<CoinType>(
            &pool_signer,
            amount
        );
        
        supra_account::deposit_coins(staker_addr, reward_coins);
    }

    public entry fun claim_rewards<CoinType>(
        staker: &signer,
        staking_pool_addr: address
    ) acquires StakingPool, UserStakesInfo, StakesStorage {
        assert!(exists<StakingPool>(staking_pool_addr), error::not_found(ESTAKING_POOL_DOES_NOT_EXIST));
        
        let staker_addr = signer::address_of(staker);
        
        assert!(exists<UserStakesInfo>(staker_addr), error::not_found(ESTAKE_DOES_NOT_EXIST));
        let user_stakes = borrow_global<UserStakesInfo>(staker_addr);
        
        let stake_ids = *&user_stakes.stake_ids;
        let len = vector::length(&stake_ids);
        let i = 0;
        while (i < len) {
            let stake_id = *vector::borrow(&stake_ids, i);
            update_accumulated_rewards(stake_id, staking_pool_addr);
            i = i + 1;
        };
        
        let user_stakes = borrow_global_mut<UserStakesInfo>(staker_addr);
        let unclaimed_amount = user_stakes.unclaimed_rewards;
        
        assert!(unclaimed_amount > 0, error::invalid_state(EZERO_REWARD_BALANCE));
        
        user_stakes.unclaimed_rewards = 0;
        
        distribute_rewards<CoinType>(staker_addr, unclaimed_amount, staking_pool_addr);
        
        let current_time = timestamp::now_seconds();
        rebaz_staking_events::emit_claim_event(
            staker_addr,
            unclaimed_amount,
            current_time
        );
    }

    public entry fun update_base_apy(
        admin: &signer,
        new_base_apy: u64,
        staking_pool_addr: address
    ) acquires StakingPool {
        assert!(exists<StakingPool>(staking_pool_addr), error::not_found(ESTAKING_POOL_DOES_NOT_EXIST));
        let pool = borrow_global_mut<StakingPool>(staking_pool_addr);
        
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == pool.admin, error::permission_denied(EINVALID_ADMIN_ACCOUNT));
        
        let old_rate = pool.base_apy;
        pool.base_apy = new_base_apy;
        
        let current_time = timestamp::now_seconds();
        rebaz_staking_events::emit_reward_rate_update_event(
            admin_addr,
            old_rate,
            new_base_apy,
            current_time
        );
    }

    // Admin functions
    public entry fun pause_staking_pool(
        admin: &signer,
        pause: bool,
        staking_pool_addr: address
    ) acquires StakingPool {
        assert!(exists<StakingPool>(staking_pool_addr), error::not_found(ESTAKING_POOL_DOES_NOT_EXIST));
        let pool = borrow_global_mut<StakingPool>(staking_pool_addr);
        
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == pool.admin, error::permission_denied(EINVALID_ADMIN_ACCOUNT));
        
        pool.paused = pause;
    }

    public entry fun transfer_ownership(
        admin: &signer,
        new_admin: address,
        staking_pool_addr: address
    ) acquires StakingPool {
        assert!(exists<StakingPool>(staking_pool_addr), error::not_found(ESTAKING_POOL_DOES_NOT_EXIST));
        let pool = borrow_global_mut<StakingPool>(staking_pool_addr);
        
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == pool.admin, error::permission_denied(EINVALID_ADMIN_ACCOUNT));
        
        assert!(option::is_none(&pool.pending_admin), error::invalid_state(EADMIN_TRANSFER_IN_PROCESS));
        option::fill(&mut pool.pending_admin, new_admin);
    }

    public entry fun claim_ownership(
        account: &signer,
        staking_pool_addr: address
    ) acquires StakingPool {
        assert!(exists<StakingPool>(staking_pool_addr), error::not_found(ESTAKING_POOL_DOES_NOT_EXIST));
        let pool = borrow_global_mut<StakingPool>(staking_pool_addr);
        
        assert!(option::is_some(&pool.pending_admin), error::invalid_state(EADMIN_TRANSFER_NOT_IN_PROCESS));
        
        let new_admin = option::extract(&mut pool.pending_admin);
        let old_admin = pool.admin;
        let caller_address = signer::address_of(account);
        
        if (new_admin == @0x0) {
            assert!(old_admin == caller_address, error::permission_denied(EINVALID_ADMIN_ACCOUNT));
        } else {
            assert!(new_admin == caller_address, error::permission_denied(EINVALID_AUTHORIZATION));
        };
        
        pool.admin = new_admin;
    }

    public entry fun cancel_ownership_transfer(
        admin: &signer,
        staking_pool_addr: address
    ) acquires StakingPool {
        assert!(exists<StakingPool>(staking_pool_addr), error::not_found(ESTAKING_POOL_DOES_NOT_EXIST));
        let pool = borrow_global_mut<StakingPool>(staking_pool_addr);
        
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == pool.admin, error::permission_denied(EINVALID_ADMIN_ACCOUNT));
        
        assert!(option::is_some(&pool.pending_admin), error::invalid_state(EADMIN_TRANSFER_NOT_IN_PROCESS));
        option::extract(&mut pool.pending_admin);
    }

    // Admin function to add rewards to the pool
    public entry fun add_rewards_to_pool<CoinType>(
        admin: &signer,
        amount: u64,
        staking_pool_addr: address
    ) acquires StakingPool {
        assert!(exists<StakingPool>(staking_pool_addr), error::not_found(ESTAKING_POOL_DOES_NOT_EXIST));
        let pool = borrow_global<StakingPool>(staking_pool_addr);
        
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == pool.admin, error::permission_denied(EINVALID_ADMIN_ACCOUNT));
        
        let coins = coin::withdraw<CoinType>(admin, amount);
        
        let pool_signer = create_signer_with_capability(&pool.staking_pool_signer_capability);
        if (!coin::is_account_registered<CoinType>(staking_pool_addr)) {
            coin::register<CoinType>(&pool_signer);
        };
        
        coin::deposit<CoinType>(staking_pool_addr, coins);
    }

    fun update_accumulated_rewards(stake_id: u64, staking_pool_addr: address) acquires StakingPool, StakesStorage {
        let pool = borrow_global<StakingPool>(staking_pool_addr);
        let base_apy = pool.base_apy;
        
        let mut_stake = get_stake_info(stake_id, staking_pool_addr);
        let current_time = timestamp::now_seconds();
        let time_elapsed = current_time - mut_stake.last_reward_calculation_time;
        
        if (time_elapsed > 0) {
            let multiplier = if (mut_stake.is_locked) {
                *option::borrow(&mut_stake.lock_multiplier)
            } else {
                PRECISION
            };
            
            // Calculate rewards: base_apy * multiplier * time_elapsed / SECONDS_PER_YEAR / PRECISION
            let rewards = (base_apy * multiplier * time_elapsed) / (SECONDS_PER_YEAR * PRECISION);
            
            mut_stake.accumulated_rewards = mut_stake.accumulated_rewards + rewards;
            mut_stake.last_reward_calculation_time = current_time;
            
            update_stake_info(stake_id, staking_pool_addr, mut_stake);
        };
    }

    fun add_to_unclaimed_rewards(user_addr: address, amount: u64) acquires UserStakesInfo {
        if (exists<UserStakesInfo>(user_addr)) {
            let user_stakes = borrow_global_mut<UserStakesInfo>(user_addr);
            user_stakes.unclaimed_rewards = user_stakes.unclaimed_rewards + amount;
        };
    }
} 