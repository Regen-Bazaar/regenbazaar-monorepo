// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/staking/ImpactProductStaking.sol";
import "../contracts/tokens/ImpactProductNFT.sol";
import "../contracts/tokens/REBAZToken.sol";
import "../contracts/interfaces/IImpactProductStaking.sol";

contract ImpactProductStakingTest is Test {
    ImpactProductStaking staking;
    ImpactProductNFT nft;
    REBAZToken token;
    
    address admin = address(1);
    address minter = address(2);
    address user1 = address(3);
    address user2 = address(4);
    address platformWallet = address(5);
    
    string baseTokenURI = "https://api.regenbazaar.com/metadata/";
    uint256 tokenId;
    uint256 initialSupply = 1_000_000 * 10**18;

    event NFTStaked(uint256 indexed tokenId, address indexed owner, uint256 lockPeriod, uint256 lockEndTime);
    event RewardsClaimed(uint256 indexed tokenId, address indexed owner, uint256 amount);
    event NFTUnstaked(uint256 indexed tokenId, address indexed owner, uint256 totalRewards);

    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy NFT contract
        nft = new ImpactProductNFT(platformWallet, baseTokenURI);
        
        // Deploy token contract
        token = new REBAZToken(initialSupply, admin);
        
        // Deploy staking contract
        staking = new ImpactProductStaking(address(nft), address(token));
        
        // Grant roles
        nft.grantRole(nft.MINTER_ROLE(), minter);
        token.grantRole(token.MINTER_ROLE(), address(staking));
        
        // Create an NFT to use in tests
        ImpactProductNFT.ImpactData memory impactData;
        impactData.category = "Reforestation";
        impactData.impactValue = 1000;
        impactData.location = "Amazon Rainforest";
        impactData.startDate = block.timestamp - 30 days;
        impactData.endDate = block.timestamp + 365 days;
        impactData.beneficiaries = "Local communities";
        impactData.verified = false;
        impactData.metadataURI = "ipfs://QmHash";
        
        vm.prank(minter);
        nft.createImpactProduct(user1, impactData, 1 ether, user1, 500);
        tokenId = 0;
        
        vm.stopPrank();
    }

    // Basic Functionality
    function testStakeNFT() public {
        uint256 lockPeriod = 30 days;
        
        // Approve staking contract to transfer NFT
        vm.prank(user1);
        nft.approve(address(staking), tokenId);
        
        // Stake the NFT
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit NFTStaked(tokenId, user1, lockPeriod, block.timestamp + lockPeriod);
        bool success = staking.stakeNFT(tokenId, lockPeriod);
        
        assertTrue(success);
        
        // Verify ownership transfer
        assertEq(nft.ownerOf(tokenId), address(staking));
        
        // Verify stake info
        IImpactProductStaking.NFTStake memory stake = staking.getStakeInfo(tokenId);
        assertEq(stake.tokenId, tokenId);
        assertEq(stake.owner, user1);
        assertEq(stake.startTime, block.timestamp);
        assertEq(stake.lockPeriod, lockPeriod);
        assertEq(stake.lockEndTime, block.timestamp + lockPeriod);
        assertEq(stake.lastClaimTime, block.timestamp);
        
        // Verify user's staked NFTs
        uint256[] memory stakedNFTs = staking.getStakedNFTs(user1);
        assertEq(stakedNFTs.length, 1);
        assertEq(stakedNFTs[0], tokenId);
    }
    
    function testClaimRewards() public {
        uint256 lockPeriod = 30 days;
        
        // Stake NFT
        vm.prank(user1);
        nft.approve(address(staking), tokenId);
        
        vm.prank(user1);
        staking.stakeNFT(tokenId, lockPeriod);
        
        // Fast forward time to accumulate rewards
        vm.warp(block.timestamp + 15 days);
        
        // Calculate pending rewards
        uint256 pendingRewards = staking.pendingRewards(tokenId);
        assertGt(pendingRewards, 0);
        
        // Claim rewards
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit RewardsClaimed(tokenId, user1, pendingRewards);
        uint256 claimedRewards = staking.claimRewards(tokenId);
        
        assertEq(claimedRewards, pendingRewards);
        assertEq(token.balanceOf(user1), pendingRewards);
        
        // Verify lastClaimTime updated
        IImpactProductStaking.NFTStake memory stake = staking.getStakeInfo(tokenId);
        assertEq(stake.lastClaimTime, block.timestamp);
    }
    
    function testUnstakeNFT() public {
        uint256 lockPeriod = 30 days;
        
        // Stake NFT
        vm.prank(user1);
        nft.approve(address(staking), tokenId);
        
        vm.prank(user1);
        staking.stakeNFT(tokenId, lockPeriod);
        
        // Fast forward past lock period
        vm.warp(block.timestamp + lockPeriod + 1);
        
        // Calculate pending rewards
        uint256 pendingRewards = staking.pendingRewards(tokenId);
        
        // Unstake NFT
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit NFTUnstaked(tokenId, user1, pendingRewards);
        uint256 rewards = staking.unstakeNFT(tokenId);
        
        assertEq(rewards, pendingRewards);
        assertEq(nft.ownerOf(tokenId), user1);
        assertEq(token.balanceOf(user1), pendingRewards);
        
        // Verify stake removed
        vm.expectRevert();
        staking.getStakeInfo(tokenId);
        
        // Verify user's staked NFTs updated
        uint256[] memory stakedNFTs = staking.getStakedNFTs(user1);
        assertEq(stakedNFTs.length, 0);
    }
    
    // Multipliers and Timing
    function testMultiplierCalculation() public view {
        // Test different lock periods
        uint256 shortPeriod = 14 days;
        uint256 tier1Period = 40 days; // > 30 days
        uint256 tier2Period = 100 days; // > 90 days
        uint256 tier3Period = 200 days; // > 180 days
        uint256 tier4Period = 370 days; // > 365 days
        
        uint256 baseMultiplier = 10000; // 100%
        
        uint256 shortMultiplier = staking.calculateMultiplier(shortPeriod);
        uint256 tier1Multiplier = staking.calculateMultiplier(tier1Period);
        uint256 tier2Multiplier = staking.calculateMultiplier(tier2Period);
        uint256 tier3Multiplier = staking.calculateMultiplier(tier3Period);
        uint256 tier4Multiplier = staking.calculateMultiplier(tier4Period);
        
        // Each tier should have a higher multiplier
        assertEq(shortMultiplier, baseMultiplier);
        assertGt(tier1Multiplier, shortMultiplier);
        assertGt(tier2Multiplier, tier1Multiplier);
        assertGt(tier3Multiplier, tier2Multiplier);
        assertGt(tier4Multiplier, tier3Multiplier);
    }
    
    function testStakingWithDifferentPeriods() public {
        // Create a second NFT
        ImpactProductNFT.ImpactData memory impactData;
        impactData.category = "Reforestation";
        impactData.impactValue = 1000;
        impactData.location = "Amazon Rainforest";
        impactData.startDate = block.timestamp - 30 days;
        impactData.endDate = block.timestamp + 365 days;
        impactData.beneficiaries = "Local communities";
        impactData.verified = false;
        impactData.metadataURI = "ipfs://QmHash";
        
        vm.prank(minter);
        nft.createImpactProduct(user1, impactData, 1 ether, user1, 500);
        uint256 tokenId2 = 1;
        
        // Stake two NFTs with different lock periods
        vm.startPrank(user1);
        nft.approve(address(staking), tokenId);
        nft.approve(address(staking), tokenId2);
        
        staking.stakeNFT(tokenId, 30 days);  // Short period
        staking.stakeNFT(tokenId2, 180 days); // Long period
        vm.stopPrank();
        
        // Fast forward
        vm.warp(block.timestamp + 90 days);
        
        // Compare rewards
        uint256 rewards1 = staking.pendingRewards(tokenId);
        uint256 rewards2 = staking.pendingRewards(tokenId2);
        
        // Longer lock period should have higher rewards
        assertGt(rewards2, rewards1);
    }
    
    function testRewardAccumulation() public {
        uint256 lockPeriod = 180 days;
        
        // Stake NFT
        vm.prank(user1);
        nft.approve(address(staking), tokenId);
        
        vm.prank(user1);
        staking.stakeNFT(tokenId, lockPeriod);
        
        // Check rewards at different times
        uint256 checkpoints = 6;
        uint256[] memory rewards = new uint256[](checkpoints);
        
        for (uint256 i = 0; i < checkpoints; i++) {
            // Move forward by 30 days each time
            vm.warp(block.timestamp + 30 days);
            rewards[i] = staking.pendingRewards(tokenId);
        }
        
        // Rewards should increase over time
        for (uint256 i = 1; i < checkpoints; i++) {
            assertGt(rewards[i], rewards[i-1]);
        }
    }
    
    // Access Control
    function testEarlyUnstaking() public {
        uint256 lockPeriod = 180 days;
        
        // Stake NFT
        vm.prank(user1);
        nft.approve(address(staking), tokenId);
        
        vm.prank(user1);
        staking.stakeNFT(tokenId, lockPeriod);
        
        // Try to unstake before lock period ends
        vm.prank(user1);
        vm.expectRevert();
        staking.unstakeNFT(tokenId);
        
        // Admin can force unstake
        vm.prank(admin);
        uint256 rewards = staking.unstakeNFT(tokenId);
        
        // NFT should be returned to original owner
        assertEq(nft.ownerOf(tokenId), user1);
        
        // Some rewards should be earned
        assertGt(rewards, 0);
    }
    
    function testUpdateParams() public {
        uint256 newBaseRate = 2000; // 20%
        uint256 newMinLock = 14 days;
        uint256 newMaxLock = 730 days;
        
        // Non-admin cannot update
        vm.prank(user1);
        vm.expectRevert();
        staking.updateStakingParams(newBaseRate, newMinLock, newMaxLock);
        
        // Admin can update
        vm.prank(admin);
        staking.updateStakingParams(newBaseRate, newMinLock, newMaxLock);
        
        // Verify params updated
        assertEq(staking.baseRewardRate(), newBaseRate);
        assertEq(staking.minLockPeriod(), newMinLock);
        assertEq(staking.maxLockPeriod(), newMaxLock);
    }
    
    // Edge Cases
    function testStakeNonexistentNFT() public {
        uint256 nonExistentTokenId = 999;
        
        vm.prank(user1);
        vm.expectRevert();
        staking.stakeNFT(nonExistentTokenId, 30 days);
    }
    
    function testClaimingZeroRewards() public {
        uint256 lockPeriod = 30 days;
        
        // Stake NFT
        vm.prank(user1);
        nft.approve(address(staking), tokenId);
        
        vm.prank(user1);
        staking.stakeNFT(tokenId, lockPeriod);
        
        // Try to claim immediately (no rewards accumulated)
        vm.prank(user1);
        uint256 rewards = staking.claimRewards(tokenId);
        
        // Should be zero
        assertEq(rewards, 0);
    }
    
    function testStakingAlreadyStakedNFT() public {
        uint256 lockPeriod = 30 days;
        
        // Stake NFT
        vm.prank(user1);
        nft.approve(address(staking), tokenId);
        
        vm.prank(user1);
        staking.stakeNFT(tokenId, lockPeriod);
        
        // Try to stake already staked NFT
        vm.prank(user1);
        vm.expectRevert();
        staking.stakeNFT(tokenId, lockPeriod);
    }
    
    function testUnstakingNonexistentStake() public {
        uint256 nonExistentTokenId = 999;
        
        vm.prank(user1);
        vm.expectRevert();
        staking.unstakeNFT(nonExistentTokenId);
    }
    
    function testStakingWithMaxLockPeriod() public {
        uint256 maxLockPeriod = staking.maxLockPeriod();
        
        // Stake with max lock period
        vm.prank(user1);
        nft.approve(address(staking), tokenId);
        
        vm.prank(user1);
        bool success = staking.stakeNFT(tokenId, maxLockPeriod);
        
        assertTrue(success);
        
        // Verify multiplier is at maximum tier
        IImpactProductStaking.NFTStake memory stake = staking.getStakeInfo(tokenId);
        assertEq(stake.multiplier, 15000); // 150%
    }
    
    // Fuzz Testing
    function testFuzzStakingDuration(uint256 lockPeriod) public {
        // Bound to valid range
        lockPeriod = bound(lockPeriod, staking.minLockPeriod(), staking.maxLockPeriod());
        
        // Stake with random duration
        vm.prank(user1);
        nft.approve(address(staking), tokenId);
        
        vm.prank(user1);
        bool success = staking.stakeNFT(tokenId, lockPeriod);
        
        assertTrue(success);
        
        // Fast forward past lock period
        vm.warp(block.timestamp + lockPeriod + 1);
        
        // Unstake
        vm.prank(user1);
        uint256 rewards = staking.unstakeNFT(tokenId);
        
        // Should have earned some rewards
        assertGt(rewards, 0);
    }
}