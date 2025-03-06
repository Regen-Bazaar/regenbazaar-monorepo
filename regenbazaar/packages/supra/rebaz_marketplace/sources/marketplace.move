module rebaz::marketplace {
    use std::bcs;
    use std::error;
    use std::option::{Self, Option};
    use std::signer;
    use std::vector;
    use std::string::{String};

    use aptos_std::table::Table;
    use aptos_std::table;

    use supra_framework::account::{SignerCapability, create_signer_with_capability};
    use supra_framework::account;
    use supra_framework::coin;
    use supra_framework::object::{Self, Object, ObjectCore};
    use supra_framework::supra_account;

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
    const EINSUFFICIENT_BALANCE: u64 = 10;
    const EZERO_VALUE: u64 = 11;
    const EMARKETPLACE_PAUSED: u64 = 12;

    const PRECISION: u64 = 10000;
    
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
        products: Table<u64, ImpactProduct>
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
    public fun get_product_details(product_id: u64, marketplace: address): (String, Object<ObjectCore>, address, u64) acquires ProductsStorage {
        let product = borrow_product(product_id, marketplace);
        (
            product.name,
            product.nft_object,
            product.seller,
            product.price
        )
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
    public fun get_product_metadata(product_id: u64, marketplace: address): events::TokenMetadata acquires ProductsStorage {
        let product = borrow_product(product_id, marketplace);
        events::token_metadata(object::convert(product.nft_object))
    }

    //////////////////// All public functions ////////////////////////////////
 
    public entry fun init(
        admin: &signer,
        fee_percentage: u64,
        name: String,
    ){
        init_marketplace_and_get_address(admin, fee_percentage, name);
    }

    public fun init_marketplace_and_get_address(
        admin: &signer,
        fee_percentage: u64,
        name: String,
    ): address {
        assert!(check_fee(fee_percentage) <= 100, error::invalid_argument(EINVALID_FEE_PERCENTAGE));

        // create a resource account
        let seed = bcs::to_bytes(&name);
        let admin_address = signer::address_of(admin);
        vector::append(&mut seed, bcs::to_bytes(&admin_address));

        let (market_signer, res_cap) = account::create_resource_account(admin, seed);

        move_to(
            &market_signer,
            Market {
                name,
                fee_percentage,
                next_product_id: 0,
                market_signer_capability: res_cap,
                paused: false,
                admin: admin_address,
                pending_admin: option::none(),
            }
        );

        move_to(
            &market_signer,
            ProductsStorage {
                products: table::new()
            }
        );

        let market_addr = signer::address_of(&market_signer);

        events::emit_init_event(market_addr, name, fee_percentage, admin_address);

        market_addr
    }

    public entry fun list_product(
        seller: &signer,
        name: String,
        nft_object: Object<ObjectCore>,
        price: u64,
        marketplace: address,
    ) acquires Market, ProductsStorage {
        list_product_internal(seller, name, nft_object, price, marketplace);
    }

    public fun list_product_internal(
        seller: &signer,
        name: String,
        nft_object: Object<ObjectCore>,
        price: u64,
        marketplace: address,
    ): u64 acquires Market, ProductsStorage {
        assert!(exists<Market>(marketplace), error::not_found(EMARKETPLACE_NOT_EXIST));
        let market = borrow_global_mut<Market>(marketplace);

        assert!(!market.paused, error::invalid_state(EMARKETPLACE_PAUSED));
        assert!(price > 0, error::invalid_argument(EZERO_VALUE));

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

        events::emit_list_event(
            marketplace, 
            product_id, 
            name, 
            seller_addr, 
            price, 
            events::token_metadata(object::convert(nft_object))
        );

        product_id
    }

    public entry fun unlist_product(
        seller: &signer,
        product_id: u64,
        marketplace: address
    ) acquires Market, ProductsStorage {
        assert!(exists<Market>(marketplace), error::not_found(EMARKETPLACE_NOT_EXIST));
        let market = borrow_global<Market>(marketplace);

        let product = borrow_product(product_id, marketplace);

        let seller_addr = signer::address_of(seller);

        assert!(product.seller == seller_addr, error::permission_denied(EINVALID_CREATOR_ACCOUNT));
        
        assert!(!product.is_sold, error::invalid_state(EPRODUCT_SOLD));

        let product_store = borrow_global_mut<ProductsStorage>(marketplace);

        let ImpactProduct { nft_object, id: _, name: _, price: price, seller: _, buyer: _, is_sold: _ } = table::remove(&mut product_store.products, product_id);

        let market_signer = create_signer_with_capability(&market.market_signer_capability);

        object::transfer(&market_signer, nft_object, seller_addr);

        events::emit_unlist_event(
            marketplace, 
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
    ) acquires Market, ProductsStorage {
        assert!(exists<Market>(marketplace), error::not_found(EMARKETPLACE_NOT_EXIST));
        let market = borrow_global<Market>(marketplace);

        assert!(!market.paused, error::invalid_state(EMARKETPLACE_PAUSED));

        let buyer_addr = signer::address_of(buyer);

        let product = borrow_product_mut(product_id, marketplace);
        
        assert!(!product.is_sold, error::invalid_state(EPRODUCT_SOLD));

        assert!(option::is_none(&product.buyer), error::invalid_state(EPRODUCT_SOLD));
        
        let buyer_balance = coin::balance<CoinType>(buyer_addr);

        assert!(buyer_balance >= product.price, error::invalid_argument(EINSUFFICIENT_BALANCE));

        let coins = coin::withdraw<CoinType>(buyer, product.price);
        
        let fee_value = calculate_fee(product.price, market.fee_percentage);
        
        let fee = coin::extract(&mut coins, fee_value);
        supra_account::deposit_coins(marketplace, fee);

        // Seller gets what is left
        supra_account::deposit_coins(product.seller, coins);

        let market_signer = create_signer_with_capability(&market.market_signer_capability);

        object::transfer(&market_signer, product.nft_object, buyer_addr);

        product.is_sold = true;

        option::fill(&mut product.buyer, buyer_addr);

        events::emit_buy_event(
            marketplace, 
            product_id, 
            product.seller, 
            buyer_addr,
            product.price, 
            fee_value,
            events::token_metadata(object::convert(product.nft_object))
        );
    }

    //////////////////// Admin functions ////////////////////////////////

    public entry fun transfer_ownership(admin: &signer, new_admin: address, marketplace: address) acquires Market {
        assert!(exists<Market>(marketplace), error::not_found(EMARKETPLACE_NOT_EXIST));
        let market = borrow_global_mut<Market>(marketplace);

        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == market.admin, error::permission_denied(EINVALID_ADMIN_ACCOUNT));

        assert!(option::is_none(&market.pending_admin), error::invalid_state(EADMIN_TRANSFER_IN_PROCESS));
        option::fill(&mut market.pending_admin, new_admin);
        
        events::emit_ownership_transfer_event(
            marketplace, 
            admin_addr,
            new_admin
        );
    }

    public entry fun cancel_ownership_transfer(admin: &signer, marketplace: address) acquires Market {
        assert!(exists<Market>(marketplace), error::not_found(EMARKETPLACE_NOT_EXIST));
        let market = borrow_global_mut<Market>(marketplace);
        
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == market.admin, error::permission_denied(EINVALID_ADMIN_ACCOUNT));

        // marketplace offer exists
        assert!(option::is_some(&market.pending_admin), error::invalid_state(EADMIN_TRANSFER_NOT_IN_PROCESS));
        option::extract(&mut market.pending_admin);
        
        events::emit_cancel_ownership_transfer_event(
            marketplace, 
            admin_addr
        );
    }

    public entry fun claim_ownership(account: &signer, marketplace: address) acquires Market {
        // marketplace offer exists
        assert!(exists<Market>(marketplace), error::not_found(EMARKETPLACE_NOT_EXIST));
        let market = borrow_global_mut<Market>(marketplace);

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
        
        events::emit_claim_ownership_event(
            marketplace, 
            new_admin,
            old_admin
        );
    }

    public entry fun disable_ownership(admin: &signer, marketplace: address) acquires Market {
        assert!(exists<Market>(marketplace), error::not_found(EMARKETPLACE_NOT_EXIST));
        let market = borrow_global_mut<Market>(marketplace);

        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == market.admin, error::permission_denied(EINVALID_ADMIN_ACCOUNT));

        let new_admin = @0x0;
        // make sure no one can be admin of the marketplace
        market.admin = new_admin;

        events::emit_disable_ownership_event(
            marketplace, 
            new_admin,
            admin_addr
        );
    }

    public entry fun update_fees_percentage(admin: &signer, new_fee_percentage: u64, marketplace: address) acquires Market {
        assert!(exists<Market>(marketplace), error::not_found(EMARKETPLACE_NOT_EXIST));
        let market = borrow_global_mut<Market>(marketplace);

        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == market.admin, error::permission_denied(EINVALID_ADMIN_ACCOUNT));

        // update the marketplace fee
        let old_fee_percentage = market.fee_percentage;
        assert!(check_fee(new_fee_percentage) <= 100, error::invalid_argument(EINVALID_FEE_PERCENTAGE));

        market.fee_percentage = new_fee_percentage;
        
        events::emit_fees_update_event(
            marketplace, 
            admin_addr,
            old_fee_percentage,
            new_fee_percentage
        );
    }

    public entry fun pause_market(admin: &signer, pause: bool, marketplace: address) acquires Market {
        assert!(exists<Market>(marketplace), error::not_found(EMARKETPLACE_NOT_EXIST));
        let market = borrow_global_mut<Market>(marketplace);

        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == market.admin, error::permission_denied(EINVALID_ADMIN_ACCOUNT));

        market.paused = pause;
        
        events::emit_pause_event(
            marketplace, 
            admin_addr,
            pause
        );
    }

    public entry fun withdraw_fees<CoinType>(admin: &signer, amount: u64, marketplace: address) acquires Market {
        assert!(exists<Market>(marketplace), error::not_found(EMARKETPLACE_NOT_EXIST));
        let market = borrow_global<Market>(marketplace);

        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == market.admin, error::permission_denied(EINVALID_ADMIN_ACCOUNT));

        assert!(coin::balance<CoinType>(marketplace) >= amount, error::invalid_argument(EINSUFFICIENT_BALANCE));
        
        let market_signer = create_signer_with_capability(&market.market_signer_capability);
        let coins = coin::withdraw<CoinType>(&market_signer, amount);

        supra_account::deposit_coins(admin_addr, coins);

        events::emit_withdraw_fees_event(
            marketplace, 
            admin_addr,
            amount
        );
    }
    
    inline fun borrow_product(product_id: u64, marketplace: address): &ImpactProduct acquires ProductsStorage {
        assert!(exists<ProductsStorage>(marketplace), error::not_found(EPRODUCTS_NOT_EXIST_AT_ADDRESS));
        let products = &borrow_global<ProductsStorage>(marketplace).products;
        assert!(table::contains(products, product_id), error::not_found(EPRODUCT_ID_NOT_EXIST));
        table::borrow(products, product_id)
    }

    inline fun borrow_product_mut(product_id: u64, marketplace: address): &mut ImpactProduct acquires ProductsStorage {
        assert!(exists<ProductsStorage>(marketplace), error::not_found(EPRODUCTS_NOT_EXIST_AT_ADDRESS));
        let products_storage = borrow_global_mut<ProductsStorage>(marketplace);
        assert!(table::contains(&products_storage.products, product_id), error::not_found(EPRODUCT_ID_NOT_EXIST));
        table::borrow_mut(&mut products_storage.products, product_id)
    }

    inline fun calculate_fee(amount: u64, fee_percentage: u64): u64 {
        (amount * fee_percentage) / PRECISION
    }

    inline fun check_fee(fee_percentage: u64): u64 {
        (fee_percentage * 100) / PRECISION
    }
}

//////////////////// Tests ////////////////////////////////

#[test_only]
module rebaz::marketplace_tests{
    use std::unit_test;
    use aptos_token_objects::aptos_token;
    use supra_framework::account;
    use supra_framework::supra_coin::{Self, SupraCoin};
    use supra_framework::coin;
    use supra_framework::timestamp;
    use std::string;
    use std::signer;
    use std::vector;
    use std::option;

    use aptos_token_objects::token::{Token};

    use supra_framework::object::{Self, Object};

    use rebaz::marketplace;

    const PRECISION: u64 = 10000;

    public fun create_and_setup_signers(
        supra_framework: &signer,
        num: u64
    ): vector<signer> {
        let signers = unit_test::create_signers_for_testing(num);
        
        timestamp::set_time_has_started_for_testing(supra_framework);
        let (burn_cap, mint_cap) = supra_coin::initialize_for_test(supra_framework);

        let signers_copy = vector::empty();

        while (vector::length(&signers) > 0) {
            let signer_ref = vector::pop_back(&mut signers);
            let account_addr = signer::address_of(&signer_ref);
            account::create_account_for_test(account_addr);
            coin::register<SupraCoin>(&signer_ref);

            let coins = coin::mint(10_000, &mint_cap);
            coin::deposit(account_addr, coins);
            vector::push_back(&mut signers_copy, signer_ref);
        };

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);

        signers_copy
    }

    public fun mint_token(seller: &signer): Object<Token> {
        let collection_name = string::utf8(b"collection_name");

        let _ = aptos_token::create_collection_object(
            seller,
            string::utf8(b"collection description"),
            2,
            collection_name,
            string::utf8(b"collection uri"),
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            1,
            100,
        );

        let aptos_token = aptos_token::mint_token_object(
            seller,
            collection_name,
            string::utf8(b"description"),
            string::utf8(b"token_name"),
            string::utf8(b"uri"),
            vector::empty(),
            vector::empty(),
            vector::empty(),
        );
        object::convert(aptos_token)
    }

    #[test(supra_framework = @0x1)]
    fun test_e2e(supra_framework: &signer) {
        let signers = create_and_setup_signers(supra_framework, 3);

        let admin = &vector::pop_back(&mut signers);
        let seller = &vector::pop_back(&mut signers);
        let buyer = &vector::pop_back(&mut signers);
        
        let admin_addr =  signer::address_of(admin);
        let seller_addr = signer::address_of(seller);
        let buyer_addr = signer::address_of(buyer);

        assert!(coin::balance<SupraCoin>(buyer_addr) == 10000, 0);

        let fee_percentage = 2000; // 2%
        let marketplace_address = marketplace::init_marketplace_and_get_address(
            admin,
            fee_percentage,
            string::utf8(b"rebaz_marketplace"),
        );

        let token = mint_token(seller);
        let price = 50;

        let product_id = marketplace::list_product_internal(
            seller,
            string::utf8(b"product_1"),
            object::convert(token),
            price,
            marketplace_address,
        );

        marketplace::unlist_product(
            seller,
            product_id,
            marketplace_address
        );

        let product_id = marketplace::list_product_internal(
            seller,
            string::utf8(b"product_1"),
            object::convert(token),
            50, // price
            marketplace_address,
        );

        marketplace::buy_product<SupraCoin>(
            buyer,
            product_id,
            marketplace_address,
        );

        let expected_fee = (price * fee_percentage) / PRECISION;

        marketplace::withdraw_fees<SupraCoin>(
            admin,
            expected_fee,
            marketplace_address
        );
      
        let final_amount = price - expected_fee;

        assert!(coin::balance<SupraCoin>(admin_addr) == 10000 + expected_fee, 0);
        assert!(coin::balance<SupraCoin>(seller_addr) == 10000 + final_amount, 0);
        assert!(coin::balance<SupraCoin>(buyer_addr) == 10000 - price, 0);
        assert!(object::owner(token) == buyer_addr, 0);
    }

    #[test(supra_framework = @0x1)]
    fun test_ownership_transfer_and_claim(supra_framework: &signer) {
        let signers = create_and_setup_signers(supra_framework, 2);

        let admin = &vector::pop_back(&mut signers);
        let new_admin = &vector::pop_back(&mut signers);
    
        let _admin_addr =  signer::address_of(admin);
        let new_admin_addr = signer::address_of(new_admin);

        let fee_percentage = 2000; // 2%

        let marketplace_address = marketplace::init_marketplace_and_get_address(
            admin,
            fee_percentage,
            string::utf8(b"rebaz_marketplace"),
        );

        marketplace::transfer_ownership(
            admin,
            new_admin_addr,
            marketplace_address
        );

        marketplace::claim_ownership(
            new_admin,
            marketplace_address,
        );

        let (_, _, _, _, admin, _ ) = marketplace::get_marketplace_details(marketplace_address);

        assert!(admin == new_admin_addr, 0);
    }

    #[test(supra_framework = @0x1)]
    public fun test_transferring_ownership_to_zero_address(supra_framework: &signer) {
        let signers = create_and_setup_signers(supra_framework, 1);

        let admin = &vector::pop_back(&mut signers);

        let fee_percentage = 2000; // 2%
        
        let marketplace_address = marketplace::init_marketplace_and_get_address(
            admin,
            fee_percentage,
            string::utf8(b"rebaz_marketplace"),
        );

        let zero_addr = @0x0;

        marketplace::transfer_ownership(
            admin,
            zero_addr,
            marketplace_address
        );

        // admin has to claim when sending to zero addr
        marketplace::claim_ownership(
            admin,
            marketplace_address,
        );

        let (_, _, _, _, admin, _ ) = marketplace::get_marketplace_details(marketplace_address);

        assert!(admin == zero_addr, 1);
    }

    #[test(supra_framework = @0x1)]
    public fun test_ownership_transfer_cancel(supra_framework: &signer) {
        let signers = create_and_setup_signers(supra_framework, 2);

        let admin = &vector::pop_back(&mut signers);
        let new_admin = &vector::pop_back(&mut signers);

        let admin_addr = signer::address_of(admin);
        let new_admin_addr = signer::address_of(new_admin);

        let fee_percentage = 2000; // 2%
        
        let marketplace_address = marketplace::init_marketplace_and_get_address(
            admin,
            fee_percentage,
            string::utf8(b"rebaz_marketplace"),
        );

        marketplace::transfer_ownership(
            admin,
            new_admin_addr,
            marketplace_address
        );

        marketplace::cancel_ownership_transfer(
            admin,
            marketplace_address,
        );

        let (_, _, _, _, admin, pending_admin ) = marketplace::get_marketplace_details(marketplace_address);

        assert!(admin == admin_addr, 1);
        assert!(pending_admin == option::none(), 1);
    }

    #[test(supra_framework = @0x1)]
    public fun test_admin_update_fees(supra_framework: &signer) {
        let signers = create_and_setup_signers(supra_framework, 1);

        let admin = &vector::pop_back(&mut signers);

        let fee_percentage = 2000; // 2%
        
        let marketplace_address = marketplace::init_marketplace_and_get_address(
            admin,
            fee_percentage,
            string::utf8(b"rebaz_marketplace"),
        );

        let new_fee_percentage = 500;

        marketplace::update_fees_percentage(
            admin,
            new_fee_percentage,
            marketplace_address,
        );

        let (_, fees, _, _, _, _ ) = marketplace::get_marketplace_details(marketplace_address);

        assert!(fees == new_fee_percentage, 1);
    }

    #[test(supra_framework = @0x1)]
    public fun test_admin_pause_market(supra_framework: &signer) {
        let signers = create_and_setup_signers(supra_framework, 1);

        let admin = &vector::pop_back(&mut signers);

        let fee_percentage = 2000; // 2%
        
        let marketplace_address = marketplace::init_marketplace_and_get_address(
            admin,
            fee_percentage,
            string::utf8(b"rebaz_marketplace"),
        );

        marketplace::pause_market(
            admin,
            true,
            marketplace_address,
        );

        let (_, _, _, paused, _, _ ) = marketplace::get_marketplace_details(marketplace_address);

        assert!(paused, 1);
    }

    #[test(supra_framework = @0x1)]
    fun test_user_can_unlist_if_contract_is_paused(supra_framework: &signer) {
        let signers = create_and_setup_signers(supra_framework, 2);
        let admin = &vector::pop_back(&mut signers);
        let seller = &vector::pop_back(&mut signers);
        let marketplace_address = marketplace::init_marketplace_and_get_address(
            admin,
            2000,
            string::utf8(b"paused_marketplace"),
        );
        let token = mint_token(seller);
        let price = 50;
        let product_id = marketplace::list_product_internal(
            seller,
            string::utf8(b"multi_buyer_product"),
            object::convert(token),
            price,
            marketplace_address,
        );
        marketplace::pause_market(admin, true, marketplace_address);
        marketplace::unlist_product(
            seller,
            product_id,
            marketplace_address,
        );

        assert!(object::owner(token) == signer::address_of(seller), 0);
    }

    #[test(supra_framework = @0x1)]
    #[expected_failure(abort_code = 65545, location=marketplace)]
    fun test_initialization_with_invalid_fee_fails(supra_framework: &signer) {
        let signers = create_and_setup_signers(supra_framework, 1);
        let admin = &vector::pop_back(&mut signers);
        marketplace::init_marketplace_and_get_address(
            admin,
            110000, // Invalid fee percentage (more than 100%)
            string::utf8(b"invalid_marketplace"),
        );
    }

    #[test(supra_framework = @0x1)]
    #[expected_failure(abort_code = 65547, location=marketplace)]
    fun test_listing_product_with_zero_price_fails(supra_framework: &signer) {
        let signers = create_and_setup_signers(supra_framework, 2);
        let admin = &vector::pop_back(&mut signers);
        let seller = &vector::pop_back(&mut signers);
        let marketplace_address = marketplace::init_marketplace_and_get_address(
            admin,
            2000,
            string::utf8(b"zero_price_marketplace"),
        );
        let token = mint_token(seller);
        marketplace::list_product_internal(
            seller,
            string::utf8(b"zero_price_product"),
            object::convert(token),
            0, // Invalid price
            marketplace_address,
        );
    }

    #[test(supra_framework = @0x1)]
    #[expected_failure(abort_code = 65546, location=marketplace)]
    fun test_buying_product_without_sufficient_balance_fails(supra_framework: &signer) {
        let signers = create_and_setup_signers(supra_framework, 3);
        let admin = &vector::pop_back(&mut signers);
        let seller = &vector::pop_back(&mut signers);
        let buyer = &vector::pop_back(&mut signers);

        let marketplace_address = marketplace::init_marketplace_and_get_address(
            admin,
            2000,
            string::utf8(b"insufficient_balance_marketplace"),
        );
        let token = mint_token(seller);
        let price = 15000; // More than the buyer has

        let product_id = marketplace::list_product_internal(
            seller,
            string::utf8(b"expensive_product"),
            object::convert(token),
            price,
            marketplace_address,
        );
        marketplace::buy_product<SupraCoin>(
            buyer,
            product_id,
            marketplace_address,
        );
    }

    #[test(supra_framework = @0x1)]
    #[expected_failure(abort_code = 196613, location=marketplace)]
    fun test_multiple_buyers_for_same_product_fails(supra_framework: &signer) {
        let signers = create_and_setup_signers(supra_framework, 4);
        let admin = &vector::pop_back(&mut signers);
        let seller = &vector::pop_back(&mut signers);
        let buyer1 = &vector::pop_back(&mut signers);
        let buyer2 = &vector::pop_back(&mut signers);

        let marketplace_address = marketplace::init_marketplace_and_get_address(
            admin,
            2000,
            string::utf8(b"multi_buyer_marketplace"),
        );
        let token = mint_token(seller);
        let price = 50;
        let product_id = marketplace::list_product_internal(
            seller,
            string::utf8(b"multi_buyer_product"),
            object::convert(token),
            price,
            marketplace_address,
        );
        marketplace::buy_product<SupraCoin>(
            buyer1,
            product_id,
            marketplace_address,
        );
        
        marketplace::buy_product<SupraCoin>(
            buyer2,
            product_id,
            marketplace_address,
        );
    }

    #[test(supra_framework = @0x1)]
    #[expected_failure(abort_code = 196620, location=marketplace)]
    fun test_user_cannot_list_if_contract_is_paused(supra_framework: &signer) {
        let signers = create_and_setup_signers(supra_framework, 2);
        let admin = &vector::pop_back(&mut signers);
        let seller = &vector::pop_back(&mut signers);
        let marketplace_address = marketplace::init_marketplace_and_get_address(
            admin,
            2000,
            string::utf8(b"paused_marketplace"),
        );
        marketplace::pause_market(admin, true, marketplace_address);
        let token = mint_token(seller);
        let price = 50;
        marketplace::list_product_internal(
            seller,
            string::utf8(b"multi_buyer_product"),
            object::convert(token),
            price,
            marketplace_address,
        );
    }

    #[test(supra_framework = @0x1)]
    #[expected_failure(abort_code = 196620, location=marketplace)]
    fun test_user_cannot_buy_if_contract_is_paused(supra_framework: &signer) {
        let signers = create_and_setup_signers(supra_framework, 3);
        let admin = &vector::pop_back(&mut signers);
        let buyer = &vector::pop_back(&mut signers);
        let seller = &vector::pop_back(&mut signers);
        let marketplace_address = marketplace::init_marketplace_and_get_address(
            admin,
            2000,
            string::utf8(b"paused_marketplace"),
        );
        let token = mint_token(seller);
        let price = 50;
        let product_id = marketplace::list_product_internal(
            seller,
            string::utf8(b"multi_buyer_product"),
            object::convert(token),
            price,
            marketplace_address,
        );
        marketplace::pause_market(admin, true, marketplace_address);
        marketplace::buy_product<SupraCoin>(
            buyer,
            product_id,
            marketplace_address,
        );
    }

    #[test(supra_framework = @0x1)]
    #[expected_failure(abort_code = 327684, location=marketplace)]
    fun test_only_seller_can_unlist_product(supra_framework: &signer) {
        let signers = create_and_setup_signers(supra_framework, 2);
        let admin = &vector::pop_back(&mut signers);
        let seller = &vector::pop_back(&mut signers);
        let marketplace_address = marketplace::init_marketplace_and_get_address(
            admin,
            2000,
            string::utf8(b"unlist_test_marketplace"),
        );
        let token = mint_token(seller);
        let product_id = marketplace::list_product_internal(
            seller,
            string::utf8(b"product"),
            object::convert(token),
            50,
            marketplace_address,
        );
        marketplace::unlist_product(
            admin,
            product_id,
            marketplace_address,
        );
    }

    #[test(supra_framework = @0x1)]
    #[expected_failure(abort_code = 65544, location=marketplace)]
    fun test_ownership_claim_without_being_pending_admin(supra_framework: &signer) {
        let signers = create_and_setup_signers(supra_framework, 2);
        let admin = &vector::pop_back(&mut signers);
        let unauthorized_user = &vector::pop_back(&mut signers);
        let marketplace_address = marketplace::init_marketplace_and_get_address(
            admin,
            2000,
            string::utf8(b"ownership_claim_test"),
        );
        marketplace::claim_ownership(
            unauthorized_user,
            marketplace_address,
        );
    }

    #[test(supra_framework = @0x1)]
    #[expected_failure(abort_code = 393219, location=marketplace)]
    fun test_buying_non_existent_product(supra_framework: &signer) {
        let signers = create_and_setup_signers(supra_framework, 2);
        let admin = &vector::pop_back(&mut signers);
        let buyer = &vector::pop_back(&mut signers);
        let marketplace_address = marketplace::init_marketplace_and_get_address(
            admin,
            2000,
            string::utf8(b"non_existent_product_marketplace"),
        );
        marketplace::buy_product<SupraCoin>(
            buyer,
            99999,
            marketplace_address,
        );
    }

    #[test(supra_framework = @0x1)]
    #[expected_failure(abort_code = 327686, location=marketplace)]
    public fun test_non_admin_pause_market(supra_framework: &signer) {
        let signers = create_and_setup_signers(supra_framework, 2);
        
        let admin = &vector::pop_back(&mut signers);
        let unauthorized_user = &vector::pop_back(&mut signers);

        let fee_percentage = 2000; // 2%
        
        let marketplace_address = marketplace::init_marketplace_and_get_address(
            admin,
            fee_percentage,
            string::utf8(b"rebaz_marketplace"),
        );

        marketplace::pause_market(
            unauthorized_user,
            true,
            marketplace_address,
        );
    }
}