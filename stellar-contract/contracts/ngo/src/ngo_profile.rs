#![no_std]
use soroban_sdk::{contracttype, Address, Env, String};

#[contracttype]
pub struct NGOProfile {
    pub owner: Address,
    pub name: String,
    pub description: String,
    pub total_impact_products: u64,
    pub total_sold: u64,
    pub total_earnings: u64,
    pub verified: bool,
}

pub fn _register_ngo(env: &Env, owner: Address, name: String, description: String) {
    let admin = owner.clone();
    let profile = NGOProfile {
        owner,
        name,
        description,
        total_impact_products: 0,
        total_sold: 0,
        total_earnings: 0,
        verified: false,
    };
    env.storage().persistent().set(&admin, &profile);
}

pub fn _get_ngo_profile(env: &Env, owner: Address) -> Option<NGOProfile> {
    env.storage().persistent().get(&owner)
}
