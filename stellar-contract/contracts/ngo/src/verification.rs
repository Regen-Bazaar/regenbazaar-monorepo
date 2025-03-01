#![no_std]
use soroban_sdk::{contracttype, Address, BytesN, Env, Symbol};

const VERIFICATION_QUEUE_KEY: Symbol = Symbol::short("VERIFY");

#[contracttype]
pub struct VerificationQueue {
    pub product_id: u32,
    pub status: Symbol, // "Pending", "Approved", "Rejected"
    pub verifier: Option<Address>,
}

pub fn submit_for_verification(env: &Env, product_id: u32) {
    let product = product_id.clone();
    let verification = VerificationQueue {
        product_id,
        status: Symbol::short("Pending"),
        verifier: None,
    };
    env.storage().persistent().set(&product, &verification);
}

pub fn approve_product(env: &Env, product_id: u32, verifier: Address) {
    let mut verification: VerificationQueue = env.storage().persistent().get(&product_id).unwrap();
    verification.status = Symbol::short("Approved");
    verification.verifier = Some(verifier);
    env.storage().persistent().set(&product_id, &verification);
}

pub fn reject_product(env: &Env, product_id: u32, verifier: Address) {
    let mut verification: VerificationQueue = env.storage().persistent().get(&product_id).unwrap();
    verification.status = Symbol::short("Rejected");
    verification.verifier = Some(verifier);
    env.storage().persistent().set(&product_id, &verification);
}

pub fn get_pending_products(env: &Env, product_id: u32) -> Option<VerificationQueue> {
    env.storage().persistent().get(&product_id)
}
