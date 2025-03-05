module rebaz::marketplace {
    use std::bcs;
    use std::error;
    use std::option::{Self, Option};
    use std::signer;
    use std::vector;
    use std::string::{Self, String};

    use aptos_std::math64;
    use aptos_std::table::Table;
    use aptos_std::table;

    use supra_framework::account::{SignerCapability, create_signer_with_capability};
    use supra_framework::account;
    use supra_framework::coin::{Self, Coin};
    use supra_framework::object::{Self, Object, ObjectCore};
    use supra_framework::timestamp;
    use supra_framework::aptos_account;

    use rebaz::events;

    const EMARKETPLACE_NOT_EXIST: u64 = 1;
    const EPRODUCTS_NOT_EXIST_AT_ADDRESS: u64 = 2;
    const EPRODUCT_ID_NOT_EXIST: u64 = 3;
    const EINVALID_CREATOR_ACCOUNT: u64 = 4;
    const EINVALID_AUTHORIZATION: u64 = 9;
    const EPRODUCT_SOLD: u64 = 5;
    const EINVALID_ADMIN_ACCOUNT: u64 = 6;
    const EADMIN_TRANSFER_IN_PROCESS: u64 = 7;
    const EADMIN_TRANSFER_NOT_IN_PROCESS: u64 = 8;
    const EINVALID_FEE_PERCENTAGE: u64 = 9;

    const PRECISION: u64 = 1000;
    
    struct Market has key {
        name: String,
        fee_percentage: u64,
        next_product_id: u64,
        paused: bool,
        market_signer_capability: SignerCapability,
        admin: address,
        pending_admin: Option<address>,
    }

    /// All ProductsStorage
    // #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    struct ProductsStorage has key {
        products: Table<u64, ImpactProduct>,
        seller_products: Table<address, vector<u64>>,
        buyer_products: Table<address, vector<u64>>,
    }

    /// Store the general information about the Impact Product
    // #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    struct ImpactProduct has copy, drop, store {
        id: u64,
        name: String,
        price: u64,
        seller: address,
        buyer: Option<address>,
        nft_object: Object<ObjectCore>,
        is_sold: bool
    }

    //////////////////// All view functions ////////////////////////////////
    #[view]
    public fun get_product_details(product_id: u64, marketplace: address): (String, Object<ObjectCore>, address, u64) acquires ImpactProduct, ProductsStorage {
        let product = borrow_product(product_id, marketplace);
        (
            product.name,
            product.nft_object,
            product.seller,
            product.price
        )
    }

    #[view]
    public fun is_product_listed(product_id: u64, marketplace: address): bool acquires ImpactProduct, ProductsStorage {
        let product = borrow_product(product_id, marketplace);
        product.is_listed
    }

    #[view]
    /// Unpack the Market fields
    public fun get_marketplace_details(marketplace: address): (String, u64, u64, bool, address, Option<address>) acquires Market {
        assert!(exists<Market>(marketplace), error::not_found(EMARKETPLACE_NOT_EXIST));
        let market = borrow_global<Market>(marketplace);
        (
            market.name,
            market.fee_percentage,
            market.next_product_id,
            market.paused,
            market.admin,
            market.pending_admin,
        )
    }

    #[view]
    public fun get_product_metadata(product_id: u64, marketplace: address): events::TokenMetadata acquires ImpactProduct, ProductsStorage {
        let product = borrow_product(product_id, marketplace);
        events::token_metadata(object::convert(product.nft_object))
    }

    //////////////////// All public functions ////////////////////////////////

    public entry fun init(
        admin: &signer,
        fee_percentage: u64,
        name: String,
    ): address {
        assert!(fee_percentage / PRECISION <= 100, error::invalid_argument(EINVALID_FEE_PERCENTAGE));

        // create a resource account
        let seed = bcs::to_bytes(&name);
        let admin_address = signer::address_of(admin);
        vector::append(&mut seed, bcs::to_bytes(&admin_address));

        let (res_signer, res_cap) = account::create_resource_account(admin, seed);

        move_to(
            &res_signer,
            Market {
                name,
                fee_percentage,
                next_listing_id: 0,
                market_signer_capability: res_cap,
                paused: false,
                admin: admin_address,
                pending_admin: option::none(),
            }
        );

        move_to(
            &res_signer,
            ProductsStorage {
                products: table::new(),
                buyer_products: table::new(),
                seller_products: table::new(),
            }
        )

        let market_addr = signer::address_of(&res_signer);

        event::emit_init_event(market_addr, name, fee_percentage, admin_address);

        market_addr
    }

    public entry fun list_product(
        seller: &signer,
        name: String,
        nft_object: Object<ObjectCore>,
        price: u64,
        marketplace: address,
    ) acquires Market, ProductsStorage {
        assert!(exists<Market>(marketplace), error::not_found(EMARKETPLACE_NOT_EXIST));
        let market = borrow_global_mut<Market>(marketplace);

        let product_id = market.next_product_id;
        let seller_addr = signer::address_of(seller);

        let product = ImpactProduct {
            id: product_id,
            name,
            price,
            seller: seller_addr,
            buyer: option::none(),
            nft_object,
            is_sold: false,
        };

        object::transfer(seller, nft_object, marketplace);

        let product_store = borrow_global_mut<ProductsStorage>(marketplace);

        table::add(&mut product_store.products, product_id, product);

        market.next_product_id = product_id + 1;

        event::emit_list_event(
            market_addr, 
            product_id, 
            name, 
            seller_addr, 
            price, 
            events::token_metadata(object::convert(nft_object))
        );
    }

    public entry fun unlist_product(
        seller: &signer,
        product_id: u64,
        marketplace: address
    ) acquires Market, ProductsStorage, ImpactProduct {
        assert!(exists<Market>(marketplace), error::not_found(EMARKETPLACE_NOT_EXIST));
        let market = borrow_global<Market>(marketplace);

        let product = borrow_product(product_id, marketplace);

        let seller_addr = signer::address_of(seller);

        assert!(product.seller == seller_addr, error::permission_denied(EINVALID_CREATOR_ACCOUNT));
        
        assert!(!product.is_sold, error::invalid_state(EPRODUCT_SOLD));

        let product_store = borrow_global_mut<ProductsStorage>(marketplace);

        let ImpactProduct { nft_object, id: _, name: _, price: _, seller: _, buyer: _, is_sold: _ } = table::remove(&mut product_store.products, product_id);

        let res_signer = create_signer_with_capability(&market.market_signer_capability);

        object::transfer(&res_signer, nft_object, seller_addr);

        event::emit_unlist_event(
            market_addr, 
            product_id, 
            seller_addr, 
            price, 
            events::token_metadata(object::convert(nft_object))
        );
    }

    public entry fun buy_product<CoinType>(
        buyer: &signer,
        product_id: u64,
        marketplace: address,
        coins: Coin<CoinType>,
    ) acquires Market, ProductsStorage, ImpactProduct {
        assert!(exists<Market>(marketplace), error::not_found(EMARKETPLACE_NOT_EXIST));
        let market = borrow_global<Market>(marketplace);

        let buyer_addr = signer::address_of(buyer);

        let product = borrow_product_mut(product_id, marketplace);
        
        assert!(!product.is_sold, error::invalid_state(EPRODUCT_SOLD));

        assert!(option::is_none(&product.buyer), error::invalid_state(EPRODUCT_SOLD));

        let fee_value = calculate_fee(product.price, market.fee_percentage);
        let fee = coin::extract(&mut coins, fee_value);
        aptos_account::deposit_coins(marketplace, fee);

        // Seller gets what is left
        aptos_account::deposit_coins(seller, coins)

        let res_signer = create_signer_with_capability(&market.market_signer_capability);

        object::transfer(&res_signer, nft_object, buyer_addr);

        product.is_sold = true;

        option::fill(&mut product.buyer, buyer_addr);

        event::emit_buy_event(
            market_addr, 
            product_id, 
            product.seller, 
            buyer,
            price, 
            fee_value,
            events::token_metadata(object::convert(nft_object))
        );
    }

    //////////////////// Admin functions ////////////////////////////////

    public entry fun transfer_ownership(admin: &signer, marketplace: address, new_admin: address) acquires Market {
        assert!(exists<Market>(marketplace), error::not_found(EMARKETPLACE_NOT_EXIST));
        let market = borrow_global<Market>(marketplace);

        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == market.admin, error::permission_denied(EINVALID_ADMIN_ACCOUNT));

        assert!(option::is_none(&market.pending_admin), error::invalid_state(EADMIN_TRANSFER_IN_PROCESS));
        option::fill(&mut market.pending_admin, new_admin);
        
        event::emit_ownership_transfer_event(
            market_addr, 
            admin,
            new_admin
        );
    }

    public entry fun cancel_admin_transfer(admin: &signer, marketplace: address) acquires Market {
        assert!(exists<Market>(marketplace), error::not_found(EMARKETPLACE_NOT_EXIST));
        let market = borrow_global<Market>(marketplace);
        
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == market.admin, error::permission_denied(EINVALID_ADMIN_ACCOUNT));

        // marketplace offer exists
        assert!(option::is_some(&market.pending_admin), error::invalid_state(EADMIN_TRANSFER_NOT_IN_PROCESS));
        option::extract(&mut market.pending_admin);
        
        event::emit_cancel_ownership_transfer_event(
            market_addr, 
            admin
        );
    }

    public entry fun claim_ownership(account: &signer, marketplace: address) acquires Market {
        // marketplace offer exists
        assert!(exists<Market>(marketplace), error::not_found(EMARKETPLACE_NOT_EXIST));
        let market = borrow_global<Market>(marketplace);

        assert!(option::is_some(&market.pending_admin), error::invalid_argument(EADMIN_TRANSFER_NOT_IN_PROCESS));

        // Allow setting the admin to 0x0.
        let new_admin = option::extract(&mut market.pending_admin);
        let old_admin = market.admin;
        let caller_address = signer::address_of(account);
        if (new_admin == @0x0) {
            // If the admin is being updated to 0x0, for security reasons, this finalization must only be done by the
            // current admin.
            assert!(old_admin == caller_address, error::permission_denied(EINVALID_ADMIN_ACCOUNT));
        } else {
            // Otherwise, only the new admin can finalize the transfer.
            assert!(new_admin == caller_address, error::permission_denied(EINVALID_AUTHORIZATION));
        };

        // update the marketplace's admin address
        market.admin = new_admin;
        
        event::emit_claim_ownership_event(
            market_addr, 
            new_admin,
            old_admin
        );
    }

    public entry fun disable_ownership(admin: &signer, marketplace: address) acquires Market {
        assert!(exists<Market>(marketplace), error::not_found(EMARKETPLACE_NOT_EXIST));
        let market = borrow_global<Market>(marketplace);

        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == market.admin, error::permission_denied(EINVALID_ADMIN_ACCOUNT));

        let new_admin = @0x0;
        // make sure no one can be admin of the marketplace
        market.admin = new_admin;

        event::emit_disable_ownership_event(
            market_addr, 
            new_admin,
            old_admin
        );
    }

    public entry fun update_fees_percentage(admin: &signer, marketplace: address, new_fee_percentage: u64) acquires Market {
        assert!(exists<Market>(marketplace), error::not_found(EMARKETPLACE_NOT_EXIST));
        let market = borrow_global<Market>(marketplace);

        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == market.admin, error::permission_denied(EINVALID_ADMIN_ACCOUNT));

        // update the marketplace fee
        let old_fee_percentage = market.fee_percentage;
        assert!(new_fee_percentage <= 100000, error::invalid_argument(EINVALID_FEE_PERCENTAGE));

        market.fee_percentage = new_fee_percentage;
        
        event::emit_fees_update_event(
            market_addr, 
            admin,
            old_fee_percentage,
            new_fee_percentage
        );
    }

    public entry fun update_pause(admin: &signer, marketplace: address, pause: bool) acquires Market {
        assert!(exists<Market>(marketplace), error::not_found(EMARKETPLACE_NOT_EXIST));
        let market = borrow_global<Market>(marketplace);

        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == market.admin, error::permission_denied(EINVALID_ADMIN_ACCOUNT));

        market.paused = pause;
        
        event::emit_fees_update_event(
            market_addr, 
            admin,
            pause
        );
    }
    
    inline fun borrow_product(product_id: u64, marketplace: address): &ImpactProduct acquires ProductsStorage {
        assert!(exists<ProductsStorage>(marketplace), error::not_found(EPRODUCTS_NOT_EXIST_AT_ADDRESS));
        let products = &borrow_global<ProductsStorage>(marketplace).products;
        assert!(table::contains(products, product_id), error::not_found(EPRODUCT_ID_NOT_EXIST));
        table::borrow(products, product_id)
    }

    inline fun borrow_product_mut(product_id: u64, marketplace: address): &ImpactProduct acquires ProductsStorage {
        assert!(exists<ProductsStorage>(marketplace), error::not_found(EPRODUCTS_NOT_EXIST_AT_ADDRESS));
        let products = &borrow_global_mut<ProductsStorage>(marketplace).products;
        assert!(table::contains(products, product_id), error::not_found(EPRODUCT_ID_NOT_EXIST));
        table::borrow_mut(&mut products, product_id)
    }

    inline fun calculate_fee(amount: u64, fee_percentage: u64): u64 {
        (amount * fee_percentage) / PRECISION
    }
}