#![no_std]
use core::iter::Product;

use crate::impact_product::ImpactProduct;
use crate::{COUNTER_KEY, MARKETPLACE_FEE};
use soroban_sdk::{
    contract, contractimpl, contracttype, Address, BytesN, Env, String, Symbol, Vec,
};

#[derive(Clone, Debug, PartialEq, Eq)]
#[contracttype]
pub struct MarketplaceListing {
    pub product_id: u32,
    pub seller: Address,
    pub price: u32,
    pub status: Symbol, // "Unsold", "Sold"
}

#[contract]
pub struct MarketplaceContract;

#[contractimpl]
impl MarketplaceContract {
    pub fn list_for_sale(env: Env, seller: Address, product_id: u32, price: u32) {
        let mut product: ImpactProduct = env
            .storage()
            .persistent()
            .get(&product_id)
            .expect("product_id not exist");
        if product.creator != seller {
            panic!("You are not owner");
        }

        let listing = MarketplaceListing {
            product_id,
            seller: seller.clone(),
            price,
            status: Symbol::new(&env, "Unsold"),
        };

        env.storage().persistent().set(&product_id, &listing);
    }

    pub fn purchase_nft(env: Env, buyer: Address, product_id: u32) {
        let mut listing: MarketplaceListing = env
            .storage()
            .persistent()
            .get(&product_id)
            .expect("product_id not exist");

        if listing.status != Symbol::new(&env, "Unsold") {
            panic!("NFT is not available for sale");
        }

        let seller = listing.seller.clone();
        let price = listing.price;
        let marketplace_fee = (price * MARKETPLACE_FEE) / 100;
        let seller_amount = price - marketplace_fee;

        // Transfer funds (Placeholder, replace with Soroban payment logic)
        // transfer(buyer, seller, seller_amount);
        // transfer(buyer, regen_bazaar_wallet, marketplace_fee);

        listing.status = Symbol::new(&env, "Sold");
        env.storage().persistent().set(&product_id, &listing);
    }

    pub fn delist_product(env: Env, seller: Address, product_id: u32) {
        let listing: MarketplaceListing = env.storage().persistent().get(&product_id).unwrap();

        if listing.seller != seller {
            panic!("Unauthorized: Only the seller can delist");
        }

        env.storage().persistent().remove(&product_id);
    }

    pub fn get_product_details(env: Env, product_id: u32) -> Option<MarketplaceListing> {
        env.storage().persistent().get(&product_id)
    }
}
