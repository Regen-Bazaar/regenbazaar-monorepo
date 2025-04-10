module rebaz::rebaz_coin_events {
  use std::string::String;

  use supra_framework::event;
  
  friend rebaz::rebaz_coin;

  #[event]
  struct InitEvent has drop, store {
    coin: address,
    name: String,
    symbol: String,
  }

  public(friend) fun emit_init_event(
    coin: address,
    name: String,
    symbol: String,
  ) {
      event::emit(InitEvent {
        coin,
        name,
        symbol
      });
  }

  #[event]
  struct MintEvent has drop, store {
    coin: address,
    recipient: address,
    amount: u64
  }

  public(friend) fun emit_mint_event(
    coin: address,
    recipient: address,
    amount: u64
  ) {
      event::emit(MintEvent {
        coin,
        recipient,
        amount
      });
  }

  #[event]
  struct RewardAddedEvent has drop, store {
    coin: address,
    amount: u64
  }

  public(friend) fun emit_reward_added_event(
    coin: address,
    amount: u64
  ) {
      event::emit(RewardAddedEvent {
        coin,
        amount
      });
  }

  #[event]
  struct RewardDistributedEvent has drop, store {
    coin: address,
    recipient: address,
    amount: u64
  }

  public(friend) fun emit_reward_distributed_event(
    coin: address,
    recipient: address,
    amount: u64
  ) {
      event::emit(RewardDistributedEvent {
        coin,
        recipient,
        amount
      });
  }

  #[event]
  struct SetAllocationEvent has drop, store {
    coin: address,
    ngo_allocation: u64, 
    community_allocation: u64, 
    validator_allocation: u64, 
    ecosystem_allocation: u64
  }

  public(friend) fun emit_allocation_event(
    coin: address,
    ngo_allocation: u64, 
    community_allocation: u64, 
    validator_allocation: u64, 
    ecosystem_allocation: u64
  ) {
      event::emit(SetAllocationEvent {
        coin,
        ngo_allocation,
        community_allocation,
        validator_allocation,
        ecosystem_allocation
      });
  }

  #[event]
  struct OwnershipTransferEvent has drop, store {
    coin: address,
    owner: address,
    new_owner: address,
  }

  public(friend) fun emit_ownership_transfer_event(
    coin: address,
    owner: address,
    new_owner: address,
  ) {
      event::emit(OwnershipTransferEvent {
          coin,
          owner,
          new_owner,
      });
  }

  #[event]
  struct CancelTransferEvent has drop, store {
    coin: address,
    owner: address,
  }

  public(friend) fun emit_cancel_ownership_transfer_event(
    coin: address,
    owner: address,
  ) {
      event::emit(CancelTransferEvent {
          coin,
          owner,
      });
  }

  #[event]
  struct ClaimOwnershipEvent has drop, store {
    coin: address,
    new_owner: address,
    old_owner: address,
  }

  public(friend) fun emit_claim_ownership_event(
    coin: address,
    new_owner: address,
    old_owner: address,
  ) {
      event::emit(ClaimOwnershipEvent {
          coin,
          new_owner,
          old_owner
      });
  }
}