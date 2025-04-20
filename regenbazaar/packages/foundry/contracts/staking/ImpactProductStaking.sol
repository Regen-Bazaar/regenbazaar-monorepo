// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interfaces/IImpactProductNFT.sol";
import "../interfaces/IREBAZ.sol";
import "../interfaces/IImpactProductStaking.sol";

/**
 * @title ImpactProductStaking
 * @author Regen Bazaar
 * @notice Contract for staking Impact Product NFTs to earn REBAZ tokens
 * @custom:security-contact security@regenbazaar.com
 */
contract ImpactProductStaking is 
    IImpactProductStaking, 
    AccessControl, 
    Pausable, 
    ReentrancyGuard, 
    IERC721Receiver 
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    uint256 public baseRewardRate = 1000;
    uint256 public minLockPeriod = 7 days;
    uint256 public maxLockPeriod = 365 days;
    
    uint256 public constant TIER1_THRESHOLD = 30 days;
    uint256 public constant TIER2_THRESHOLD = 90 days;
    uint256 public constant TIER3_THRESHOLD = 180 days;
    uint256 public constant TIER4_THRESHOLD = 365 days;
    
    IImpactProductNFT public impactProductNFT;
    IREBAZ public rebazToken;
    
    mapping(uint256 => NFTStake) private _stakes;
    mapping(address => uint256[]) private _stakedTokens;
    mapping(uint256 => uint256) private _stakedTokenIndex;
    
    /**
     * @notice Constructor for the staking contract
     * @param impactNFT Address of the ImpactProductNFT contract
     * @param rebaz Address of the REBAZ token contract
     */
    constructor(address impactNFT, address rebaz) {
        require(impactNFT != address(0), "Invalid NFT address");
        require(rebaz != address(0), "Invalid token address");
        
        impactProductNFT = IImpactProductNFT(impactNFT);
        rebazToken = IREBAZ(rebaz);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @notice Pause staking operations
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause staking operations
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @notice Stake an Impact Product NFT
     * @param tokenId ID of the Impact Product NFT
     * @param lockPeriod Time in seconds to lock the NFT
     * @return success Boolean indicating if the operation was successful
     */
    function stakeNFT(uint256 tokenId, uint256 lockPeriod) 
        external 
        whenNotPaused 
        nonReentrant 
        returns (bool success) 
    {
        require(impactProductNFT.ownerOf(tokenId) == msg.sender, "Not the token owner");
        require(lockPeriod >= minLockPeriod, "Lock period too short");
        require(lockPeriod <= maxLockPeriod, "Lock period too long");
        require(_stakes[tokenId].tokenId == 0, "Already staked");
        
        uint256 multiplier = calculateMultiplier(lockPeriod);
        
        impactProductNFT.safeTransferFrom(msg.sender, address(this), tokenId);
        
        uint256 startTime = block.timestamp;
        uint256 lockEndTime = startTime + lockPeriod;
        
        _stakes[tokenId] = NFTStake({
            tokenId: tokenId,
            owner: msg.sender,
            startTime: startTime,
            lockPeriod: lockPeriod,
            lockEndTime: lockEndTime,
            lastClaimTime: startTime,
            multiplier: multiplier
        });
        
        _stakedTokens[msg.sender].push(tokenId);
        _stakedTokenIndex[tokenId] = _stakedTokens[msg.sender].length - 1;
        
        emit NFTStaked(tokenId, msg.sender, lockPeriod, lockEndTime, multiplier);
        return true;
    }
    
    /**
     * @notice Claim rewards for a staked NFT without unstaking
     * @param tokenId ID of the staked NFT
     * @return rewardAmount Amount of REBAZ tokens claimed
     */
    function claimRewards(uint256 tokenId) 
        external 
        nonReentrant 
        returns (uint256 rewardAmount) 
    {
        NFTStake storage stake = _stakes[tokenId];
        
        require(stake.tokenId > 0, "NFT not staked");
        require(stake.owner == msg.sender, "Not the stake owner");
        
        rewardAmount = _calculateRewards(tokenId);
        require(rewardAmount > 0, "No rewards to claim");
        
        stake.lastClaimTime = block.timestamp;
        
        rebazToken.mint(msg.sender, rewardAmount);
        
        emit RewardsClaimed(tokenId, msg.sender, rewardAmount);
        return rewardAmount;
    }
    
    /**
     * @notice Unstake an NFT and claim any rewards
     * @param tokenId ID of the staked NFT
     * @return rewardAmount Amount of REBAZ tokens claimed
     */
    function unstakeNFT(uint256 tokenId) 
        external 
        nonReentrant 
        returns (uint256 rewardAmount) 
    {
        NFTStake storage stake = _stakes[tokenId];
        
        require(stake.tokenId > 0, "NFT not staked");
        require(stake.owner == msg.sender, "Not the stake owner");
        
        if (block.timestamp < stake.lockEndTime) {
            require(hasRole(ADMIN_ROLE, msg.sender), "Lock period not ended");
        }
        
        rewardAmount = _calculateRewards(tokenId);
        
        uint256 lastTokenIndex = _stakedTokens[msg.sender].length - 1;
        uint256 tokenIndex = _stakedTokenIndex[tokenId];
        
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _stakedTokens[msg.sender][lastTokenIndex];
            _stakedTokens[msg.sender][tokenIndex] = lastTokenId;
            _stakedTokenIndex[lastTokenId] = tokenIndex;
        }
        
        _stakedTokens[msg.sender].pop();
        delete _stakedTokenIndex[tokenId];
        
        delete _stakes[tokenId];
        
        impactProductNFT.safeTransferFrom(address(this), msg.sender, tokenId);
        
        if (rewardAmount > 0) {
            rebazToken.mint(msg.sender, rewardAmount);
            emit RewardsClaimed(tokenId, msg.sender, rewardAmount);
        }
        
        emit NFTUnstaked(tokenId, msg.sender);
        return rewardAmount;
    }
    
    /**
     * @notice Get all staked NFTs by an owner
     * @param owner Address of the NFT owner
     * @return tokenIds Array of staked token IDs
     */
    function getStakedNFTs(address owner) 
        external 
        view 
        returns (uint256[] memory tokenIds) 
    {
        return _stakedTokens[owner];
    }
    
    /**
     * @notice Get stake information for an NFT
     * @param tokenId ID of the NFT
     * @return stake The stake details
     */
    function getStakeInfo(uint256 tokenId) 
        external 
        view 
        returns (NFTStake memory stake) 
    {
        return _stakes[tokenId];
    }
    
    /**
     * @notice Calculate pending rewards for a staked NFT
     * @param tokenId ID of the staked NFT
     * @return pendingRewards Amount of REBAZ tokens available to claim
     */
    function pendingRewards(uint256 tokenId) 
        external 
        view 
        returns (uint256 pendingRewards) 
    {
        return _calculateRewards(tokenId);
    }
    
    /**
     * @notice Calculate the reward multiplier based on lock period
     * @param lockPeriod Lock period in seconds
     * @return multiplier The reward multiplier (in basis points)
     */
    function calculateMultiplier(uint256 lockPeriod) 
        public 
        view 
        returns (uint256 multiplier) 
    {
        if (lockPeriod >= TIER4_THRESHOLD) {
            return 3000;
        } else if (lockPeriod >= TIER3_THRESHOLD) {
            return 2000;
        } else if (lockPeriod >= TIER2_THRESHOLD) {
            return 1500;
        } else if (lockPeriod >= TIER1_THRESHOLD) {
            return 1200;
        } else {
            return 1000;
        }
    }
    
    /**
     * @notice Update staking parameters
     * @param newBaseRewardRate New base reward rate in basis points
     * @param newMinLockPeriod New minimum lock period in seconds
     * @param newMaxLockPeriod New maximum lock period in seconds
     */
    function updateStakingParams(
        uint256 newBaseRewardRate,
        uint256 newMinLockPeriod,
        uint256 newMaxLockPeriod
    ) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(newBaseRewardRate <= 3000, "Base rate too high"); // Max 30%
        require(newMinLockPeriod <= newMaxLockPeriod, "Min must be <= max");
        
        baseRewardRate = newBaseRewardRate;
        minLockPeriod = newMinLockPeriod;
        maxLockPeriod = newMaxLockPeriod;
        
        emit StakingParamsUpdated(newBaseRewardRate, newMinLockPeriod, newMaxLockPeriod);
    }
    
    /**
     * @notice Internal function to calculate rewards for a staked NFT
     * @param tokenId ID of the staked NFT
     * @return rewards Amount of REBAZ tokens to be claimed
     */
    function _calculateRewards(uint256 tokenId) 
        internal 
        view 
        returns (uint256 rewards) 
    {
        NFTStake storage stake = _stakes[tokenId];
        
        if (stake.tokenId == 0 || stake.lastClaimTime >= block.timestamp) {
            return 0;
        }
        
        IImpactProductNFT.ImpactData memory impactData = impactProductNFT.getImpactData(tokenId);
        uint256 impactValue = impactData.impactValue;
        
        if (impactData.verified) {
            impactValue = (impactValue * 120) / 100;
        }
        
        uint256 stakingDuration = block.timestamp - stake.lastClaimTime;
        
        uint256 annualEquivalent = (stakingDuration * 10000) / 31536000;
        
        rewards = (impactValue * baseRewardRate * stake.multiplier * annualEquivalent) / (10000 * 10000);
        
        return rewards;
    }
    
    /**
     * @notice Implementation of IERC721Receiver.onERC721Received
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) 
        external 
        pure 
        override 
        returns (bytes4) 
    {
        return IERC721Receiver.onERC721Received.selector;
    }
}