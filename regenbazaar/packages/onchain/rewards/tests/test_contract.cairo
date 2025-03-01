use rewards::REBAZ::{
    IBurnableDispatcher, IBurnableDispatcherTrait, IMintableDispatcher, IMintableDispatcherTrait,
    IDistributionDispatcher, IDistributionDispatcherTrait,
};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::{CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare};
use starknet::{ContractAddress, contract_address_const};

fn owner() -> ContractAddress {
    contract_address_const::<'owner'>()
}

fn alice() -> ContractAddress {
    contract_address_const::<'alice'>()
}

fn bob() -> ContractAddress {
    contract_address_const::<'bob'>()
}

fn carl() -> ContractAddress {
    contract_address_const::<'carl'>()
}

fn deploy_rebaz() -> ContractAddress {
    let owner = owner();
    let contract_class = declare("REBAZ").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append_serde(owner);

    // Default allocation percentages (in basis points, 10000 = 100%)
    // NGOs: 30%, Community: 40%, Validators: 20%, Ecosystem: 10%
    calldata.append_serde(3000_u256); // ngo_allocation
    calldata.append_serde(4000_u256); // community_allocation
    calldata.append_serde(2000_u256); // validator_allocation
    calldata.append_serde(1000_u256); // ecosystem_allocation
    calldata.append_serde(365_u64); // vesting_duration_days (1 year)

    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    contract_address
}

fn mint(contract_address: ContractAddress, recipient: ContractAddress, amount: u256) {
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    IMintableDispatcher { contract_address }.mint(recipient, amount);
}

#[test]
fn test_deployment_sets_correct_allocations() {
    let contract_address = deploy_rebaz();
    let distribution = IDistributionDispatcher { contract_address };

    let (ngo, community, validator, ecosystem, reward_pool) = distribution.get_distribution_info();

    assert(ngo == 3000, 'Wrong NGO allocation');
    assert(community == 4000, 'Wrong community allocation');
    assert(validator == 2000, 'Wrong validator allocation');
    assert(ecosystem == 1000, 'Wrong ecosystem allocation');
    assert(reward_pool == 0, 'Initial reward pool should be 0');
}

#[test]
fn test_owner_can_mint() {
    let alice = alice();
    let amount = 1000;
    let contract_address = deploy_rebaz();
    let erc20 = IERC20Dispatcher { contract_address };

    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    IMintableDispatcher { contract_address }.mint(alice, amount);

    let balance = erc20.balance_of(alice);
    assert(balance == amount, 'Wrong amount after mint');
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_only_owner_can_mint() {
    let alice = alice();
    let contract_address = deploy_rebaz();

    cheat_caller_address(contract_address, alice, CheatSpan::TargetCalls(1));
    IMintableDispatcher { contract_address }.mint(alice, 1000);
}

#[test]
fn test_user_can_burn() {
    let alice = alice();
    let amount = 1000;
    let contract_address = deploy_rebaz();
    let erc20 = IERC20Dispatcher { contract_address };

    mint(contract_address, alice, amount);
    let previous_balance = erc20.balance_of(alice);

    cheat_caller_address(contract_address, alice, CheatSpan::TargetCalls(1));
    IBurnableDispatcher { contract_address }.burn(amount);

    let balance = erc20.balance_of(alice);
    assert(previous_balance - balance == amount, 'Wrong amount after burn');
}

#[test]
fn test_reward_pool_management() {
    let contract_address = deploy_rebaz();
    let distribution = IDistributionDispatcher { contract_address };

    // Add to reward pool
    let pool_amount = 10000;
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    distribution.add_to_reward_pool(pool_amount);

    let pool_balance = distribution.get_reward_pool_balance();
    assert(pool_balance == pool_amount, 'Wrong reward pool balance');

    // Distribute rewards
    let recipient = alice();
    let reward_amount = 1000;
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    distribution.distribute_rewards(recipient, reward_amount);

    // Check updated pool balance
    let updated_pool = distribution.get_reward_pool_balance();
    assert(updated_pool == pool_amount - reward_amount, 'Wrong updated pool balance');

    // Check recipient received tokens
    let erc20 = IERC20Dispatcher { contract_address };
    let recipient_balance = erc20.balance_of(recipient);
    assert(recipient_balance == reward_amount, 'Recipient did not receive');

    // Check total distributed
    let total_distributed = distribution.get_total_distributed();
    assert(total_distributed == reward_amount, 'Wrong total distributed');
}

#[test]
#[should_panic(expected: 'Insufficient reward pool')]
fn test_cannot_distribute_more_than_pool() {
    let contract_address = deploy_rebaz();
    let distribution = IDistributionDispatcher { contract_address };

    // Add to reward pool
    let pool_amount = 1000;
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    distribution.add_to_reward_pool(pool_amount);

    // Try to distribute more than available
    let recipient = alice();
    let reward_amount = pool_amount + 1;
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    distribution.distribute_rewards(recipient, reward_amount);
}

#[test]
fn test_update_distribution_schedule() {
    let contract_address = deploy_rebaz();
    let distribution = IDistributionDispatcher { contract_address };

    // Update distribution schedule
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    distribution.set_distribution_schedule(2500, 2500, 2500, 2500); // Equal 25% distribution

    // Verify updated allocations
    let (ngo, community, validator, ecosystem, _) = distribution.get_distribution_info();
    assert(ngo == 2500, 'Wrong updated NGO allocation');
    assert(community == 2500, 'Wrong updated community alloc');
    assert(validator == 2500, 'Wrong updated validator alloc');
    assert(ecosystem == 2500, 'Wrong updated ecosystem alloc');
}

#[test]
#[should_panic(expected: 'Allocations must total 10000')]
fn test_allocation_must_total_100_percent() {
    let contract_address = deploy_rebaz();
    let distribution = IDistributionDispatcher { contract_address };

    // Try to set invalid allocations (don't add up to 10000)
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    distribution.set_distribution_schedule(2000, 2000, 2000, 2000); // Only 80%
}
