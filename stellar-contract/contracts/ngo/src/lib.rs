#![no_std]
use soroban_sdk::{contract, contractimpl, symbol_short, Address, Env, Symbol};

mod impact_product;
mod marketplace;
mod ngo_profile;
mod royalties;
mod verification;

const ADMIN_KEY: Symbol = symbol_short!("ADMIN");
const COUNTER_KEY: Symbol = symbol_short!("COUNTER");
pub const MARKETPLACE_FEE: u32 = 10;

#[contract]
pub struct NGOContract;

#[contractimpl]
impl NGOContract {
    pub fn initialize(env: Env, admin: Address) {
        if env.storage().instance().has(&ADMIN_KEY) {
            panic!("Already initialized");
        }
        env.storage().instance().set(&ADMIN_KEY, &admin);
        env.storage().instance().set(&COUNTER_KEY, &0u32);
    }

    fn _check_admin(env: &Env, caller: &Address) {
        let admin: Address = env.storage().instance().get(&ADMIN_KEY).unwrap();
        if caller != &admin {
            panic!("Unauthorized");
        }
    }
}
