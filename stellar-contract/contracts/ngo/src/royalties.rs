#![no_std]
use soroban_sdk::{contract, contractimpl, contracttype, Address, BytesN, Env, Symbol};

pub const CREATOR_ROYALTY: u64 = 5; // 5% to the original creator
pub const MARKETPLACE_ROYALTY: u64 = 5; // 5% to Regen Bazaar

#[derive(Clone, Debug, PartialEq, Eq)]
#[contracttype]
pub struct RoyaltyInfo {
    pub creator: Address,
    pub marketplace_wallet: Address,
    pub product_id: u32,
    pub royalty_percentage: u64,
}

#[contract]
pub struct RoyaltyContract;

#[contractimpl]
impl RoyaltyContract {
    pub fn distribute_royalties(
        env: Env,
        product_id: u32,
        seller: Address,
        buyer: Address,
        sale_price: u64,
    ) {
        let royalty_info: RoyaltyInfo = env
            .storage()
            .persistent()
            .get(&product_id)
            .expect("product_id not exist");

        let creator_fee = (sale_price * CREATOR_ROYALTY) / 100;
        let marketplace_fee = (sale_price * MARKETPLACE_ROYALTY) / 100;
        let seller_amount = sale_price - (creator_fee + marketplace_fee);

        // Placeholder for fund transfer logic (Replace with Soroban payment logic)
        // transfer(buyer, royalty_info.creator, creator_fee);
        // transfer(buyer, royalty_info.marketplace_wallet, marketplace_fee);
        // transfer(buyer, seller, seller_amount);
    }

    pub fn register_royalty(
        env: Env,
        product_id: u32,
        creator: Address,
        marketplace_wallet: Address,
    ) {
        let royalty_info = RoyaltyInfo {
            creator,
            marketplace_wallet,
            product_id,
            royalty_percentage: CREATOR_ROYALTY + MARKETPLACE_ROYALTY,
        };
        env.storage().persistent().set(&product_id, &royalty_info);
    }

    pub fn get_royalty_info(env: Env, product_id: u32) -> Option<RoyaltyInfo> {
        env.storage().persistent().get(&product_id)
    }
}
