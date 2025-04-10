// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title IREBAZ
 * @author Regen Bazaar
 * @notice Interface for the REBAZ token which serves as the utility and governance token
 * @custom:security-contact security@regenbazaar.com
 */
interface IREBAZ is IERC20, IAccessControl {
    /// @notice Event emitted when staking settings are updated
    event StakingSettingsUpdated(uint256 minStakeDuration, uint256 maxStakeDuration, uint256 baseRewardRate);

    /// @notice Event emitted when tokens are staked
    event TokensStaked(address indexed user, uint256 amount, uint256 duration, uint256 unlockTime);

    /// @notice Event emitted when staked tokens are withdrawn
    event StakeWithdrawn(address indexed user, uint256 amount, uint256 reward);

    /// @notice Event emitted when tokens are slashed from a validator
    event ValidatorSlashed(address indexed validator, address reporter, uint256 amount, string reason);

    /// @notice Event emitted when governance parameters are updated
    event GovernanceParamsUpdated(uint256 proposalThreshold, uint256 votingPeriod, uint256 votingDelay);

    /// @dev Role for entities permitted to slash validator stakes
    function SLASHER_ROLE() external pure returns (bytes32);

    /// @dev Role for governance management
    function GOVERNANCE_ROLE() external pure returns (bytes32);

    /**
     * @notice Stake tokens for a specific duration
     * @param amount Amount of tokens to stake
     * @param duration Duration in seconds to stake the tokens
     * @return success Boolean indicating if the operation was successful
     */
    function stake(uint256 amount, uint256 duration) external returns (bool success);

    /**
     * @notice Withdraw staked tokens along with any earned rewards
     * @param stakeId ID of the stake to withdraw
     * @return amount Amount of tokens withdrawn
     * @return reward Amount of reward tokens received
     */
    function withdraw(uint256 stakeId) external returns (uint256 amount, uint256 reward);

    /**
     * @notice Get the current stake information for a user
     * @param user Address of the user
     * @param stakeId ID of the stake
     * @return amount Amount staked
     * @return startTime When the stake began
     * @return endTime When the stake will unlock
     * @return currentReward Current accumulated reward
     */
    function getStakeInfo(address user, uint256 stakeId)
        external
        view
        returns (uint256 amount, uint256 startTime, uint256 endTime, uint256 currentReward);

    /**
     * @notice Get the total amount of tokens staked by a user
     * @param user Address of the user
     * @return totalStaked Total amount staked across all active stakes
     */
    function getTotalStaked(address user) external view returns (uint256 totalStaked);

    /**
     * @notice Get the voting power of a user based on their token balance and stakes
     * @param user Address of the user
     * @return votingPower The user's voting power
     */
    function getVotingPower(address user) external view returns (uint256 votingPower);

    /**
     * @notice Slash tokens from a validator due to malicious/incorrect validations
     * @param validator Address of the validator to slash
     * @param amount Amount of tokens to slash
     * @param reason Reason for the slashing
     * @return success Boolean indicating if the operation was successful
     */
    function slashValidator(address validator, uint256 amount, string calldata reason)
        external
        returns (bool success);

    /**
     * @notice Update the staking parameters
     * @param minStakeDuration Minimum duration for staking
     * @param maxStakeDuration Maximum duration for staking
     * @param baseRewardRate Base annual rate for rewards (in basis points)
     */
    function updateStakingParams(uint256 minStakeDuration, uint256 maxStakeDuration, uint256 baseRewardRate) external;

    /**
     * @notice Update governance parameters
     * @param proposalThreshold Minimum tokens required to create a proposal
     * @param votingPeriod Duration of voting in blocks
     * @param votingDelay Delay before voting starts in blocks
     */
    function updateGovernanceParams(uint256 proposalThreshold, uint256 votingPeriod, uint256 votingDelay) external;
}
