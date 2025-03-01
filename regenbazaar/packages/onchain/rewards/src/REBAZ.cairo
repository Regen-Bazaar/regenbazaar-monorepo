use starknet::ContractAddress;

// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts for Cairo ^0.20.0

#[starknet::interface]
pub trait IMintable<TContractState> {
    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256);
}

#[starknet::interface]
pub trait IBurnable<TContractState> {
    fn burn(ref self: TContractState, amount: u256);
}

#[starknet::interface]
pub trait IDistribution<TContractState> {
    fn get_distribution_info(self: @TContractState) -> (u256, u256, u256, u256, u256);
    fn add_to_reward_pool(ref self: TContractState, amount: u256);
    fn distribute_rewards(ref self: TContractState, recipient: ContractAddress, amount: u256);
    fn get_reward_pool_balance(self: @TContractState) -> u256;
    fn get_total_distributed(self: @TContractState) -> u256;
    fn set_distribution_schedule(
        ref self: TContractState,
        ngo_allocation: u256,
        community_allocation: u256,
        validator_allocation: u256,
        ecosystem_allocation: u256,
    );
}

#[starknet::contract]
pub mod REBAZ {
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin_upgrades::UpgradeableComponent;
    use openzeppelin_upgrades::interface::IUpgradeable;
    use starknet::{ClassHash, ContractAddress, get_caller_address, get_block_timestamp};
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    use super::{IBurnable, IMintable, IDistribution};
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // External
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    // Internal
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    // Max supply constants
    const MAX_SUPPLY: u256 =
        1_000_000_000_000_000_000_000_000_000; // 1 billion tokens with 18 decimals

    // Distribution events
    #[derive(Drop, starknet::Event)]
    struct RewardPoolAdded {
        amount: u256,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct RewardDistributed {
        recipient: ContractAddress,
        amount: u256,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct DistributionScheduleUpdated {
        ngo_allocation: u256,
        community_allocation: u256,
        validator_allocation: u256,
        ecosystem_allocation: u256,
        timestamp: u64,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        // Distribution and reward pool parameters
        reward_pool: u256,
        total_distributed: u256,
        // Distribution allocations (in percentage basis points, 10000 = 100%)
        ngo_allocation: u256,
        community_allocation: u256,
        validator_allocation: u256,
        ecosystem_allocation: u256,
        // Vesting and release schedules
        vesting_start_time: u64,
        vesting_duration: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        RewardPoolAdded: RewardPoolAdded,
        RewardDistributed: RewardDistributed,
        DistributionScheduleUpdated: DistributionScheduleUpdated,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        ngo_allocation: u256,
        community_allocation: u256,
        validator_allocation: u256,
        ecosystem_allocation: u256,
        vesting_duration_days: u64,
    ) {
        self.erc20.initializer("REBAZ Token", "REBAZ");
        self.ownable.initializer(owner);

        // Set default distribution parameters
        self.ngo_allocation.write(ngo_allocation);
        self.community_allocation.write(community_allocation);
        self.validator_allocation.write(validator_allocation);
        self.ecosystem_allocation.write(ecosystem_allocation);

        // Initialize reward pool and distribution tracking
        self.reward_pool.write(0);
        self.total_distributed.write(0);

        // Set up vesting schedule
        self.vesting_start_time.write(get_block_timestamp());
        self.vesting_duration.write(vesting_duration_days * 86400); // Convert days to seconds

        // Validate that allocations add up to 100%
        let total_allocation = ngo_allocation
            + community_allocation
            + validator_allocation
            + ecosystem_allocation;
        assert(total_allocation == 10000, 'Allocations must total 10000');
    }

    #[abi(embed_v0)]
    impl MintableImpl of IMintable<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.ownable.assert_only_owner();

            // Check if minting would exceed max supply
            let current_supply = self.erc20.total_supply();
            assert(current_supply + amount <= MAX_SUPPLY, 'Exceeds max supply');

            self.erc20.mint(recipient, amount);
        }
    }

    #[abi(embed_v0)]
    impl BurnableImpl of IBurnable<ContractState> {
        fn burn(ref self: ContractState, amount: u256) {
            let burner = get_caller_address();
            self.erc20.burn(burner, amount);
        }
    }

    #[abi(embed_v0)]
    impl DistributionImpl of IDistribution<ContractState> {
        fn get_distribution_info(self: @ContractState) -> (u256, u256, u256, u256, u256) {
            (
                self.ngo_allocation.read(),
                self.community_allocation.read(),
                self.validator_allocation.read(),
                self.ecosystem_allocation.read(),
                self.reward_pool.read(),
            )
        }

        fn add_to_reward_pool(ref self: ContractState, amount: u256) {
            self.ownable.assert_only_owner();

            // Add to reward pool
            let current_pool = self.reward_pool.read();
            self.reward_pool.write(current_pool + amount);

            // Emit event
            self.emit(RewardPoolAdded { amount, timestamp: get_block_timestamp() });
        }

        fn distribute_rewards(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.ownable.assert_only_owner();

            // Ensure reward pool has enough tokens
            let pool = self.reward_pool.read();
            assert(pool >= amount, 'Insufficient reward pool');

            // Update reward pool
            self.reward_pool.write(pool - amount);

            // Update distribution tracking
            let distributed = self.total_distributed.read();
            self.total_distributed.write(distributed + amount);

            // Transfer tokens
            self.erc20.mint(recipient, amount);

            // Emit event
            self.emit(RewardDistributed { recipient, amount, timestamp: get_block_timestamp() });
        }

        fn get_reward_pool_balance(self: @ContractState) -> u256 {
            self.reward_pool.read()
        }

        fn get_total_distributed(self: @ContractState) -> u256 {
            self.total_distributed.read()
        }

        fn set_distribution_schedule(
            ref self: ContractState,
            ngo_allocation: u256,
            community_allocation: u256,
            validator_allocation: u256,
            ecosystem_allocation: u256,
        ) {
            self.ownable.assert_only_owner();

            // Validate that allocations add up to 100%
            let total_allocation = ngo_allocation
                + community_allocation
                + validator_allocation
                + ecosystem_allocation;
            assert(total_allocation == 10000, 'Allocations must total 10000');

            // Update allocations
            self.ngo_allocation.write(ngo_allocation);
            self.community_allocation.write(community_allocation);
            self.validator_allocation.write(validator_allocation);
            self.ecosystem_allocation.write(ecosystem_allocation);

            // Emit event
            self
                .emit(
                    DistributionScheduleUpdated {
                        ngo_allocation,
                        community_allocation,
                        validator_allocation,
                        ecosystem_allocation,
                        timestamp: get_block_timestamp(),
                    },
                );
        }
    }

    //
    // Upgradeable
    //

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
