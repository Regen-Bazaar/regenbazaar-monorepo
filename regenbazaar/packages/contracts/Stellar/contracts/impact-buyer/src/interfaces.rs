use soroban_sdk::{contractclient, Address, Env, String};

/// This trait defines the expected interface for NFT contracts
/// that our impact buyer contract will interact with.
///
/// It's based on a simple NFT standard that includes ownership
/// and transfer capabilities, which are the minimum required
/// functions for our impact marketplace.
#[contractclient(name = "NftClient")]
pub trait NftInterface {
    /// Initialize the NFT contract with basic metadata
    fn initialize(env: Env, admin: Address, name: String, symbol: String);

    /// Returns the owner of a specific NFT token
    fn owner(env: Env, token_id: String) -> Address;

    /// Transfers an NFT from one address to another
    /// Requires authorization from the 'from' address
    fn transfer(env: Env, from: Address, to: Address, token_id: String);

    /// Balance of tokens owned by an address (may not be relevant for all NFTs)
    /// For standard NFTs, this should return the count of NFTs owned
    fn balance(env: Env, owner: Address) -> i128;

    /// Mints an NFT to a specific address
    fn mint(env: Env, to: Address, token_id: String);

    /// Returns true if an address is authorized to manage a specific token
    /// This is useful for marketplaces and other contracts that need to
    /// transfer NFTs on behalf of users
    fn is_authorized(env: Env, owner: Address, spender: Address, token_id: String) -> bool;

    /// Optional: Get metadata for a specific token
    /// Returns a string that might contain JSON or other encoded metadata
    fn token_metadata(env: Env, token_id: String) -> String;
}

/// Standard token interface for payment tokens
/// This follows the common fungible token interface pattern
/// used by most tokens on Stellar
#[contractclient(name = "TokenClient")]
pub trait TokenInterface {
    /// Returns the balance of tokens owned by an address
    fn balance(env: Env, owner: Address) -> i128;

    /// Transfers tokens from one address to another
    /// Requires authorization from the 'from' address
    fn transfer(env: Env, from: Address, to: Address, amount: i128);

    /// Approves another address to spend tokens on behalf of the owner
    /// Requires authorization from the 'from' address
    fn approve(env: Env, from: Address, spender: Address, amount: i128);

    /// Returns the allowance of tokens that a spender can use on behalf of the owner
    fn allowance(env: Env, owner: Address, spender: Address) -> i128;

    /// Optional: Returns the total supply of the token
    fn total_supply(env: Env) -> i128;

    /// Optional: Returns the number of decimals the token uses
    fn decimals(env: Env) -> u32;

    /// Optional: Returns the name of the token
    fn name(env: Env) -> String;

    /// Optional: Returns the symbol of the token
    fn symbol(env: Env) -> String;
}
