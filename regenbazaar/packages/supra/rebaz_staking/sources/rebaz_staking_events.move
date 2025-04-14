module rebaz_staking::rebaz_staking_events {
    use std::string::String;
    use supra_framework::event;
    use supra_framework::object::{Object, ObjectCore};

    friend rebaz_staking::staking;

    #[event]
    struct PoolInitEvent has drop, store {
        admin: address,
        pool_address: address,
        base_apy: u64,
        name: String,
        timestamp: u64,
    }

    #[event]
    struct StakeEvent has drop, store {
        staker: address,
        stake_id: u64,
        nft_object: Object<ObjectCore>,
        timestamp: u64,
    }

    #[event]
    struct LockEvent has drop, store {
        staker: address,
        stake_id: u64,
        lock_duration: u64,
        multiplier: u64,
        timestamp: u64,
    }

    #[event]
    struct UnlockEvent has drop, store {
        staker: address,
        stake_id: u64,
        timestamp: u64,
    }

    #[event]
    struct WithdrawEvent has drop, store {
        staker: address,
        stake_id: u64,
        nft_object: Object<ObjectCore>,
        timestamp: u64,
    }

    #[event]
    struct ClaimEvent has drop, store {
        staker: address,
        amount: u64,
        timestamp: u64,
    }

    #[event]
    struct RewardRateUpdateEvent has drop, store {
        admin: address,
        old_rate: u64,
        new_rate: u64,
        timestamp: u64,
    }

    public(friend) fun emit_pool_init_event(
        admin: address,
        pool_address: address,
        base_apy: u64,
        name: String,
        timestamp: u64,
    ) {
        event::emit(PoolInitEvent {
            admin,
            pool_address,
            base_apy,
            name,
            timestamp,
        });
    }

    public(friend) fun emit_stake_event(
        staker: address,
        stake_id: u64,
        nft_object: Object<ObjectCore>,
        timestamp: u64,
    ) {
        event::emit(StakeEvent {
            staker,
            stake_id,
            nft_object,
            timestamp,
        });
    }

    public(friend) fun emit_lock_event(
        staker: address,
        stake_id: u64,
        lock_duration: u64,
        multiplier: u64,
        timestamp: u64,
    ) {
        event::emit(LockEvent {
            staker,
            stake_id,
            lock_duration,
            multiplier,
            timestamp,
        });
    }

    public(friend) fun emit_unlock_event(
        staker: address,
        stake_id: u64,
        timestamp: u64,
    ) {
        event::emit(UnlockEvent {
            staker,
            stake_id,
            timestamp,
        });
    }

    public(friend) fun emit_withdraw_event(
        staker: address,
        stake_id: u64,
        nft_object: Object<ObjectCore>,
        timestamp: u64,
    ) {
        event::emit(WithdrawEvent {
            staker,
            stake_id,
            nft_object,
            timestamp,
        });
    }

    public(friend) fun emit_claim_event(
        staker: address,
        amount: u64,
        timestamp: u64,
    ) {
        event::emit(ClaimEvent {
            staker,
            amount,
            timestamp,
        });
    }

    public(friend) fun emit_reward_rate_update_event(
        admin: address,
        old_rate: u64,
        new_rate: u64,
        timestamp: u64,
    ) {
        event::emit(RewardRateUpdateEvent {
            admin,
            old_rate,
            new_rate,
            timestamp,
        });
    }
}
