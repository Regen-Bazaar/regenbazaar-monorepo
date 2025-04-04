use openzeppelin_token::erc20::interface::{IERC20DispatcherTrait};
use openzeppelin_token::erc721::interface::{IERC721DispatcherTrait};
// use openzeppelin_token::erc1155::interface::{IERC1155DispatcherTrait};
use marketplace::mocks::free_erc20::{IFreeMintERC20Dispatcher, IFreeMintERC20DispatcherTrait};
use marketplace::mocks::free_erc721::{IFreeMintERC721Dispatcher, IFreeMintERC721DispatcherTrait};
// use marketplace::mocks::free_erc1155::{IFreeMintERC1155Dispatcher,
// IFreeMintERC1155DispatcherTrait};
use snforge_std::{
    cheat_caller_address, CheatSpan, start_cheat_block_timestamp_global,
    stop_cheat_block_timestamp_global,
};
use marketplace::marketplace::IMarketplaceDispatcherTrait;
use crate::utils::*;


#[test]
fn test_init() {
    let _ = setup();
}
#[test]
fn test_create_listing_erc721() {
    let (market, erc20_token, erc721_token, _) = setup();
    start_cheat_block_timestamp_global(1697558532);
    let token_id = 0_u256;
    IFreeMintERC721Dispatcher { contract_address: erc721_token.contract_address }
        .mint(ALICE(), token_id);

    cheat_caller_address(erc721_token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    erc721_token.approve(market.contract_address, token_id);

    cheat_caller_address(market.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    market
        .create_listing(
            erc721_token.contract_address,
            token_id,
            0_u256,
            1807595297,
            10,
            1_u256,
            erc20_token.contract_address,
            0_u256,
        );
    stop_cheat_block_timestamp_global()
}

#[test]
fn test_cancel_direct_listing_erc721() {
    let (market, erc20_token, erc721_token, _) = setup();
    start_cheat_block_timestamp_global(1697558532);
    let token_id = 0_u256;
    IFreeMintERC721Dispatcher { contract_address: erc721_token.contract_address }
        .mint(ALICE(), token_id);

    cheat_caller_address(erc721_token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    erc721_token.approve(market.contract_address, token_id);

    cheat_caller_address(market.contract_address, ALICE(), CheatSpan::TargetCalls(2));
    market
        .create_listing(
            erc721_token.contract_address,
            token_id,
            0_u256,
            1807595297,
            10,
            1_u256,
            erc20_token.contract_address,
            0_u256,
        );
    market.cancel_direct_listing(token_id);
    stop_cheat_block_timestamp_global()
}


#[test]
fn test_buy_erc721() {
    let (market, erc20_token, erc721_token, _) = setup();
    start_cheat_block_timestamp_global(1697558532);
    let token_id = 0_u256;

    IFreeMintERC721Dispatcher { contract_address: erc721_token.contract_address }
        .mint(ALICE(), token_id);

    cheat_caller_address(erc721_token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    erc721_token.approve(market.contract_address, token_id);
    let startTime: u64 = 1807595297;

    cheat_caller_address(market.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    market
        .create_listing(
            erc721_token.contract_address,
            token_id,
            0_u256,
            startTime,
            10,
            1_u256,
            erc20_token.contract_address,
            100 * ONE_E18,
        );
    stop_cheat_block_timestamp_global();

    let amount = 10_000_u256 * ONE_E18;

    IFreeMintERC20Dispatcher { contract_address: erc20_token.contract_address }.mint(BOB(), amount);

    start_cheat_block_timestamp_global(startTime + 1);

    cheat_caller_address(erc20_token.contract_address, BOB(), CheatSpan::TargetCalls(1));
    erc20_token.approve(market.contract_address, 100 * ONE_E18);

    cheat_caller_address(market.contract_address, BOB(), CheatSpan::TargetCalls(1));
    market.buy(0, BOB(), 1, erc20_token.contract_address, 100 * ONE_E18);

    stop_cheat_block_timestamp_global();

    assert(erc721_token.owner_of(token_id) == BOB(), 'nft token transfer failed');
    assert(erc20_token.balance_of(ALICE()) == 100 * ONE_E18, 'currency transfer failed');
}

#[test]
fn test_offer_erc721() {
    let (market, erc20_token, erc721_token, _) = setup();
    start_cheat_block_timestamp_global(1697558532);
    let token_id = 0_u256;

    IFreeMintERC721Dispatcher { contract_address: erc721_token.contract_address }
        .mint(ALICE(), token_id);

    cheat_caller_address(erc721_token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    erc721_token.approve(market.contract_address, token_id);

    let startTime: u64 = 1807595297;

    cheat_caller_address(market.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    market
        .create_listing(
            erc721_token.contract_address,
            token_id,
            0_u256,
            startTime,
            3600,
            1_u256,
            erc20_token.contract_address,
            0_u256,
        );
    stop_cheat_block_timestamp_global();

    let amount = 10_000_u256 * ONE_E18;

    IFreeMintERC20Dispatcher { contract_address: erc20_token.contract_address }.mint(BOB(), amount);

    start_cheat_block_timestamp_global(startTime + 1);

    cheat_caller_address(erc20_token.contract_address, BOB(), CheatSpan::TargetCalls(1));
    erc20_token.approve(market.contract_address, 100 * ONE_E18);

    cheat_caller_address(market.contract_address, BOB(), CheatSpan::TargetCalls(1));
    market.offer(0, 1, erc20_token.contract_address, 90 * ONE_E18, (startTime + 3600).into());

    stop_cheat_block_timestamp_global();
}

#[test]
fn test_offer_deal_erc721() {
    let (market, erc20_token, erc721_token, _) = setup();
    start_cheat_block_timestamp_global(1697558532);
    let token_id = 0_u256;

    IFreeMintERC721Dispatcher { contract_address: erc721_token.contract_address }
        .mint(ALICE(), token_id);

    cheat_caller_address(erc721_token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    erc721_token.approve(market.contract_address, token_id);
    let startTime: u64 = 1807595297;

    cheat_caller_address(market.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    market
        .create_listing(
            erc721_token.contract_address,
            token_id,
            0_u256,
            startTime,
            3600,
            1_u256,
            erc20_token.contract_address,
            0_u256,
        );
    stop_cheat_block_timestamp_global();

    let amount = 10_000_u256 * ONE_E18;

    IFreeMintERC20Dispatcher { contract_address: erc20_token.contract_address }.mint(BOB(), amount);

    start_cheat_block_timestamp_global(startTime + 1);

    cheat_caller_address(erc20_token.contract_address, BOB(), CheatSpan::TargetCalls(1));
    erc20_token.approve(market.contract_address, 100 * ONE_E18);

    cheat_caller_address(market.contract_address, BOB(), CheatSpan::TargetCalls(1));
    market.offer(0, 1, erc20_token.contract_address, 90 * ONE_E18, (startTime + 300).into());

    cheat_caller_address(market.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    market.accept_offer(0, BOB(), erc20_token.contract_address, 90 * ONE_E18);

    stop_cheat_block_timestamp_global();

    assert(erc721_token.owner_of(token_id) == BOB(), 'nft token transfer failed');
    assert(erc20_token.balance_of(ALICE()) == 90 * ONE_E18, 'currency transfer failed');
}
// #[test]
// fn test_create_listing_erc1155() {
//     let (market, erc20_token, _, erc1155_token) = setup();
//     start_cheat_block_timestamp_global(1697558532);

//     let token_id = 0_u256;
//     let amount = 5_u256;

//     IFreeMintERC1155Dispatcher { contract_address: erc1155_token.contract_address }
//         .mint(ALICE(), token_id, amount);
//     cheat_caller_address(erc1155_token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
//     erc1155_token.set_approval_for_all(market.contract_address, true);

//     cheat_caller_address(market.contract_address, ALICE(), CheatSpan::TargetCalls(1));
//     market
//         .create_listing(
//             erc1155_token.contract_address,
//             token_id,
//             1_u256,
//             1807595297,
//             10,
//             1_u256,
//             erc20_token.contract_address,
//             0_u256,
//         );
//     stop_cheat_block_timestamp_global()
// }

// #[test]
// fn test_cancel_direct_listing_erc1155() {
//     let (market, erc20_token, _, erc1155_token) = setup();
//     start_cheat_block_timestamp_global(1697558532);

//     let token_id = 0_u256;
//     let amount = 5_u256;

//     IFreeMintERC1155Dispatcher { contract_address: erc1155_token.contract_address }
//         .mint(ALICE(), token_id, amount);

//     cheat_caller_address(erc1155_token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
//     erc1155_token.set_approval_for_all(market.contract_address, true);

//     cheat_caller_address(market.contract_address, ALICE(), CheatSpan::TargetCalls(2));
//     market
//         .create_listing(
//             erc1155_token.contract_address,
//             token_id,
//             1_u256,
//             1807595297,
//             10,
//             1_u256,
//             erc20_token.contract_address,
//             0_u256,
//         );
//     market.cancel_direct_listing(token_id);
//     stop_cheat_block_timestamp_global()
// }

// #[test]
// fn test_buy_erc1155() {
//     let (market, erc20_token, _, erc1155_token) = setup();
//     start_cheat_block_timestamp_global(1697558532);

//     let token_id = 0_u256;
//     let amount = 5_u256;

//     IFreeMintERC1155Dispatcher { contract_address: erc1155_token.contract_address }
//         .mint(ALICE(), token_id, amount);

//     cheat_caller_address(erc1155_token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
//     erc1155_token.set_approval_for_all(market.contract_address, true);
//     let startTime: u64 = 1807595297;

//     cheat_caller_address(market.contract_address, ALICE(), CheatSpan::TargetCalls(1));
//     market
//         .create_listing(
//             erc1155_token.contract_address,
//             token_id,
//             1_u256,
//             startTime,
//             10,
//             1_u256,
//             erc20_token.contract_address,
//             0_u256,
//         );
//     stop_cheat_block_timestamp_global();
//     let amount = 10_000_u256 * ONE_E18;

//     IFreeMintERC20Dispatcher { contract_address: erc20_token.contract_address }.mint(BOB(),
//     amount);

//     start_cheat_block_timestamp_global(startTime + 1);

//     cheat_caller_address(erc1155_token.contract_address, BOB(), CheatSpan::TargetCalls(1));
//     erc20_token.approve(market.contract_address, 100 * ONE_E18);

//     cheat_caller_address(market.contract_address, BOB(), CheatSpan::TargetCalls(1));
//     market.buy(0, BOB(), 1, erc20_token.contract_address, 100);

//     stop_cheat_block_timestamp_global();
//     assert(erc1155_token.balance_of(BOB(), token_id) == 1, 'nft token transfer failed 1');
//     assert(erc1155_token.balance_of(ALICE(), token_id) == 2, 'nft token transfer failed 2');
//     assert(erc20_token.balance_of(ALICE()) == 100, 'currency transfer failed');
// }

// #[test]
// fn test_offer_erc1155() {
//     let (market, erc20_token, _, erc1155_token) = setup();
//     start_cheat_block_timestamp_global(1697558532);

//     let token_id = 0_u256;
//     let amount = 5_u256;

//     IFreeMintERC1155Dispatcher { contract_address: erc1155_token.contract_address }
//         .mint(ALICE(), token_id, amount);

//     cheat_caller_address(erc1155_token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
//     erc1155_token.set_approval_for_all(market.contract_address, true);
//     let startTime: u64 = 1807595297;

//     cheat_caller_address(market.contract_address, ALICE(), CheatSpan::TargetCalls(1));
//     market
//         .create_listing(
//             erc1155_token.contract_address,
//             token_id,
//             1_u256,
//             startTime,
//             10,
//             1_u256,
//             erc20_token.contract_address,
//             0_u256,
//         );
//     stop_cheat_block_timestamp_global();
//     let amount = 10_000_u256 * ONE_E18;

//     IFreeMintERC20Dispatcher { contract_address: erc20_token.contract_address }.mint(BOB(),
//     amount);

//     start_cheat_block_timestamp_global(startTime + 1);
//     cheat_caller_address(erc1155_token.contract_address, BOB(), CheatSpan::TargetCalls(1));
//     erc20_token.approve(market.contract_address, 100 * ONE_E18);

//     cheat_caller_address(market.contract_address, BOB(), CheatSpan::TargetCalls(1));
//     market.offer(0, 1, erc20_token.contract_address, 90, (startTime + 3600).into());
//     stop_cheat_block_timestamp_global();
// }

// #[test]
// fn test_offer_deal_erc1155() {
//     let (market, erc20_token, _, erc1155_token) = setup();
//     start_cheat_block_timestamp_global(1697558532);

//     let token_id = 0_u256;
//     let amount = 5_u256;

//     IFreeMintERC1155Dispatcher { contract_address: erc1155_token.contract_address }
//         .mint(ALICE(), token_id, amount);

//     cheat_caller_address(erc1155_token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
//     erc1155_token.set_approval_for_all(market.contract_address, true);
//     let startTime: u64 = 1807595297;

//     cheat_caller_address(market.contract_address, ALICE(), CheatSpan::TargetCalls(1));
//     market
//         .create_listing(
//             erc1155_token.contract_address,
//             token_id,
//             1_u256,
//             startTime,
//             10,
//             1_u256,
//             erc20_token.contract_address,
//             0_u256,
//         );
//     stop_cheat_block_timestamp_global();
//     let amount = 10_000_u256 * ONE_E18;

//     IFreeMintERC20Dispatcher { contract_address: erc20_token.contract_address }.mint(BOB(),
//     amount);

//     start_cheat_block_timestamp_global(startTime + 1);
//     cheat_caller_address(erc1155_token.contract_address, BOB(), CheatSpan::TargetCalls(1));
//     erc20_token.approve(market.contract_address, 100 * ONE_E18);

//     cheat_caller_address(market.contract_address, BOB(), CheatSpan::TargetCalls(1));
//     market.offer(0, 1, erc20_token.contract_address, 90, (startTime + 3600).into());
//     stop_cheat_block_timestamp_global();

//     cheat_caller_address(market.contract_address, ALICE(), CheatSpan::TargetCalls(1));

//     market.accept_offer(0, BOB(), erc20_token.contract_address, 90);

//     assert(erc1155_token.balance_of(ALICE(), token_id) == 4, 'nft token transfer failed 1');
//     assert(erc1155_token.balance_of(BOB(), token_id) == 1, 'nft token transfer failed 2');
//     assert(erc20_token.balance_of(ALICE()) == 90, 'currency transfer failed');
// }


