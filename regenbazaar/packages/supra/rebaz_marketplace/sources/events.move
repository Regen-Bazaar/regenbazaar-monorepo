module rebaz::events {
    use std::option::{Self, Option};
    use std::string::String;

    use supra_framework::event;
    use supra_framework::object::{Object};

    use aptos_token_objects::collection;
    use aptos_token_objects::token;

    friend rebaz::marketplace;

    struct TokenMetadata has drop, store {
      creator_address: address,
      collection_name: String,
      collection: Option<Object<collection::Collection>>,
      token_name: String,
      token: Option<Object<token::Token>>,
      property_version: Option<u64>,
    }

    public fun token_metadata(token: Object<token::Token>): TokenMetadata {
      TokenMetadata {
        creator_address: token::creator(token),
        collection_name: token::collection_name(token),
        collection: option::some(token::collection_object(token)),
        token_name: token::name(token),
        token: option::some(token),
        property_version: option::none(),
      }
    }

    #[event]
    struct InitEvent has drop, store {
      marketplace: address,
      name: String,
      fee_percentage: u64,
      admin: address,
    }

    public(friend) fun emit_init_event(
      marketplace: address,
      name: String,
      fee_percentage: u64,
      admin: address
    ) {
        event::emit(InitEvent {
            marketplace,
            name,
            fee_percentage,
            admin,
        });
    }

    #[event]
    struct ListEvent has drop, store {
      marketplace: address,
      product_id: u64,
      product_name: String,
      creator: address,
      price: u64,
      token_metadata: TokenMetadata
    }

    public(friend) fun emit_list_event(
      marketplace: address,
      product_id: u64,
      product_name: String,
      creator: address,
      price: u64,
      token_metadata: TokenMetadata
    ) {
        event::emit(ListEvent {
            marketplace,
            product_id,
            product_name,
            creator,
            price,
            token_metadata
        });
    }

    #[event]
    struct UnlistEvent has drop, store {
      marketplace: address,
      product_id: u64,
      creator: address,
      price: u64,
      token_metadata: TokenMetadata
    }

    public(friend) fun emit_unlist_event(
      marketplace: address,
      product_id: u64,
      creator: address,
      price: u64,
      token_metadata: TokenMetadata
    ) {
        event::emit(UnlistEvent {
            marketplace,
            product_id,
            creator,
            price,
            token_metadata
        });
    }

    #[event]
    struct BuyEvent has drop, store {
      marketplace: address,
      product_id: u64,
      seller: address,
      buyer: address,
      price: u64,
      fees: u64,
      token_metadata: TokenMetadata
    }

    public(friend) fun emit_buy_event(
      marketplace: address,
      product_id: u64,
      seller: address,
      buyer: address,
      price: u64,
      fees: u64,
      token_metadata: TokenMetadata
    ) {
        event::emit(BuyEvent {
            marketplace,
            product_id,
            seller,
            buyer,
            price,
            fees,
            token_metadata
        });
    }


    #[event]
    struct OwnershipTransferEvent has drop, store {
      marketplace: address,
      admin: address,
      new_admin: address,
    }

    public(friend) fun emit_ownership_transfer_event(
      marketplace: address,
      admin: address,
      new_admin: address,
    ) {
        event::emit(OwnershipTransferEvent {
            marketplace,
            admin,
            new_admin,
        });
    }

    #[event]
    struct CancelTransferEvent has drop, store {
      marketplace: address,
      admin: address,
    }

    public(friend) fun emit_cancel_ownership_transfer_event(
      marketplace: address,
      admin: address,
    ) {
        event::emit(CancelTransferEvent {
            marketplace,
            admin,
        });
    }

    #[event]
    struct ClaimOwnershipEvent has drop, store {
      marketplace: address,
      new_admin: address,
      old_admin: address,
    }

    public(friend) fun emit_claim_ownership_event(
      marketplace: address,
      new_admin: address,
      old_admin: address,
    ) {
        event::emit(ClaimOwnershipEvent {
            marketplace,
            new_admin,
            old_admin
        });
    }

    #[event]
    struct DisableOwnershipEvent has drop, store {
      marketplace: address,
      new_admin: address,
      old_admin: address,
    }

    public(friend) fun emit_disable_ownership_event(
      marketplace: address,
      new_admin: address,
      old_admin: address,
    ) {
        event::emit(DisableOwnershipEvent {
            marketplace,
            new_admin,
            old_admin
        });
    }

    #[event]
    struct FeesUpdateEvent has drop, store {
      marketplace: address,
      admin: address,
      old_fee_percentage: u64,
      new_fee_percentage: u64,
    }

    public(friend) fun emit_fees_update_event(
      marketplace: address,
      admin: address,
      old_fee_percentage: u64,
      new_fee_percentage: u64,
    ) {
        event::emit(FeesUpdateEvent {
            marketplace,
            admin,
            old_fee_percentage,
            new_fee_percentage,
        });
    }

    #[event]
    struct PauseEvent has drop, store {
      marketplace: address,
      admin: address,
      pause: bool
    }

    public(friend) fun emit_pause_event(
      marketplace: address,
      admin: address,
      pause: bool
    ) {
        event::emit(PauseEvent {
            marketplace,
            admin,
            pause
        });
    }

    #[event]
    struct WitdrawFeesEvent has drop, store {
      marketplace: address,
      admin: address,
      amount: u64
    }

    public(friend) fun emit_withdraw_fees_event(
      marketplace: address,
      admin: address,
      amount: u64
    ) {
        event::emit(WitdrawFeesEvent {
            marketplace,
            admin,
            amount
        });
    }
    
}