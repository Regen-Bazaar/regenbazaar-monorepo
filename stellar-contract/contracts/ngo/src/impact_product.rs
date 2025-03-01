#![no_std]
use core::iter::Product;

use crate::COUNTER_KEY;
use soroban_sdk::{contracttype, Address, BytesN, Env, String, Symbol};

#[contracttype]
pub struct ImpactProduct {
    pub creator: Address,
    pub metadata_uri: String,
    pub impact_value: u64,
    pub price: u64,
    pub listed: bool,
    pub sold: bool,
}

pub fn create_impact_product(
    env: &Env,
    creator: Address,
    metadata_uri: String,
    impact_value: u64,
    price: u64,
) -> u32 {
    let mut product_id: u32 = match env.storage().instance().get(&COUNTER_KEY) {
        Some(x) => x,
        None => 0 as u32,
    };
    product_id += 1;
    env.storage().instance().set(&COUNTER_KEY, &product_id);

    let product = ImpactProduct {
        creator,
        metadata_uri,
        impact_value,
        price,
        listed: false,
        sold: false,
    };

    env.storage().persistent().set(&product_id, &product);
    product_id
}
