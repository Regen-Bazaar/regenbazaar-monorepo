use snforge_std::DeclareResultTrait;
use starknet::{ContractAddress, contract_address_const};

use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::{declare, ContractClassTrait};

use marketplace::marketplace::{IMarketplaceDispatcher};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher};
use openzeppelin_token::erc721::interface::{IERC721Dispatcher};
use openzeppelin_token::erc1155::interface::{IERC1155Dispatcher};

pub const ONE_E18: u256 = 1000000000000000000_u256;

pub fn OWNER() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}

pub fn ALICE() -> ContractAddress {
    contract_address_const::<'ALICE'>()
}

pub fn BOB() -> ContractAddress {
    contract_address_const::<'BOB'>()
}

pub fn CHARLES() -> ContractAddress {
    contract_address_const::<'CHARLES'>()
}

pub fn ZERO_ADDRESS() -> ContractAddress {
    contract_address_const::<0>()
}

pub fn declare_and_deploy(contract_name: ByteArray, calldata: Array<felt252>) -> ContractAddress {
    let contract = declare(contract_name).unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

pub fn deploy_erc20() -> ContractAddress {
    let mut calldata = array![];
    let initial_supply: u256 = 1000_000_000_u256;
    let name: ByteArray = "DummyERC20";
    let symbol: ByteArray = "DUMMY";
    calldata.append_serde(initial_supply);
    calldata.append_serde(name);
    calldata.append_serde(symbol);
    let erc20_address = declare_and_deploy("FreeMintERC20", calldata);
    erc20_address
}

pub fn deploy_erc721() -> ContractAddress {
    let mut calldata = array![];
    let base_uri: ByteArray = "http://dummybaseuri.com";
    let name: ByteArray = "DummyERC721NFT";
    let symbol: ByteArray = "DUMMYNFT";
    calldata.append_serde(name);
    calldata.append_serde(symbol);
    calldata.append_serde(base_uri);
    let erc721_address = declare_and_deploy("FreeMintERC721", calldata);
    erc721_address
}


pub fn deploy_erc1155() -> ContractAddress {
    let mut calldata = array![];
    let base_uri: ByteArray = "http://dummybaseuri.com";
    calldata.append_serde(base_uri);
    let erc1155_address = declare_and_deploy("FreeMintERC1155", calldata);
    erc1155_address
}

pub fn deploy_marketplace_contract() -> ContractAddress {
    let mut calldata = array![];
    calldata.append_serde(OWNER());
    let marketplace_address = declare_and_deploy("Marketplace", calldata);
    marketplace_address
}

pub fn setup() -> (
    IMarketplaceDispatcher, IERC20Dispatcher, IERC721Dispatcher, IERC1155Dispatcher,
) {
    let erc20_address = deploy_erc20();
    let erc721_address = deploy_erc721();
    let erc1155_address = deploy_erc1155();
    let marketplace_address = deploy_marketplace_contract();
    let erc20_contract = IERC20Dispatcher { contract_address: erc20_address };
    let erc721_contract = IERC721Dispatcher { contract_address: erc721_address };
    let erc1155_contract = IERC1155Dispatcher { contract_address: erc1155_address };
    let marketplace_contract = IMarketplaceDispatcher { contract_address: marketplace_address };

    (marketplace_contract, erc20_contract, erc721_contract, erc1155_contract)
}
