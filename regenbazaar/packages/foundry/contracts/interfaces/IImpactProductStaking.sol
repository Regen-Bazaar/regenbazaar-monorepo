// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IImpactProductStaking
 * @author Regen Bazaar
 * @notice Interface for staking Impact Product NFTs to earn REBAZ tokens
 * @custom:security-contact security@regenbazaar.com
 */
interface IImpactProductStaking {
    /**
     * @notice Struct containing NFT stake details
     * @param tokenId ID of the staked NFT
     * @param owner Original owner of the NFT
     * @param startTime When the stake began
     * @param lockPeriod Duration of the lock in seconds
     * @param lockEndTime When the lock period ends
     * @param lastClaimTime When rewards were last claimed
     * @param multiplier Reward multiplier based on lock period
     */
    struct NFTStake {
        uint256 tokenId;
        address owner;
        uint256 startTime;
        uint256 lockPeriod;
        uint256 lockEndTime;
        uint256 lastClaimTime;
        uint256 multiplier;
    }

    /// @notice Emitted when an NFT is staked
    event NFTStaked(
        uint256 indexed tokenId, 
        address indexed owner, 
        uint256 lockPeriod, 
        uint256 lockEndTime,
        uint256 multiplier
    );
    
    /// @notice Emitted when rewards are claimed
    event RewardsClaimed(uint256 indexed tokenId, address indexed owner, uint256 amount);
    
    /// @notice Emitted when an NFT is unstaked
    event NFTUnstaked(uint256 indexed tokenId, address indexed owner);
    
    /// @notice Emitted when staking parameters are updated
    event StakingParamsUpdated(
        uint256 baseRewardRate, 
        uint256 minLockPeriod, 
        uint256 maxLockPeriod
    );

    /**
     * @notice Stake an Impact Product NFT
     * @param tokenId ID of the Impact Product NFT
     * @param lockPeriod Time in seconds to lock the NFT
     * @return success Boolean indicating if the operation was successful
     */
    function stakeNFT(uint256 tokenId, uint256 lockPeriod) external returns (bool success);
    
    /**
     * @notice Claim rewards for a staked NFT without unstaking
     * @param tokenId ID of the staked NFT
     * @return rewardAmount Amount of REBAZ tokens claimed
     */
    function claimRewards(uint256 tokenId) external returns (uint256 rewardAmount);
    
    /**
     * @notice Unstake an NFT and claim any rewards
     * @param tokenId ID of the staked NFT
     * @return rewardAmount Amount of REBAZ tokens claimed
     */
    function unstakeNFT(uint256 tokenId) external returns (uint256 rewardAmount);
    
    /**
     * @notice Get all staked NFTs by an owner
     * @param owner Address of the NFT owner
     * @return tokenIds Array of staked token IDs
     */
    function getStakedNFTs(address owner) external view returns (uint256[] memory tokenIds);
    
    /**
     * @notice Get stake information for an NFT
     * @param tokenId ID of the NFT
     * @return stake The stake details
     */
    function getStakeInfo(uint256 tokenId) external view returns (NFTStake memory stake);
    
    /**
     * @notice Calculate pending rewards for a staked NFT
     * @param tokenId ID of the staked NFT
     * @return pendingRewards Amount of REBAZ tokens available to claim
     */
    function pendingRewards(uint256 tokenId) external view returns (uint256 pendingRewards);
    
    /**
     * @notice Calculate the reward multiplier based on lock period
     * @param lockPeriod Lock period in seconds
     * @return multiplier The reward multiplier (in basis points)
     */
    function calculateMultiplier(uint256 lockPeriod) external view returns (uint256 multiplier);
}