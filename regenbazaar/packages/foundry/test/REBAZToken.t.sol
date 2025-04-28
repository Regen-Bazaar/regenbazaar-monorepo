// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/tokens/REBAZToken.sol";
import "../contracts/interfaces/IREBAZ.sol";

contract REBAZTokenTest is Test {
    REBAZToken token;
    address admin = address(1);
    address minter = address(2);
    address pauser = address(3);
    address slasher = address(4);
    address user1 = address(5);
    address user2 = address(6);
    
    uint256 initialSupply = 1_000_000 * 10**18;

    event TokensStaked(address indexed user, uint256 amount, uint256 duration, uint256 unlockTime);
    event StakeWithdrawn(address indexed user, uint256 amount, uint256 reward);
    event ValidatorSlashed(address indexed validator, address reporter, uint256 amount, string reason);

    function setUp() public {
        vm.prank(admin);
        token = new REBAZToken(initialSupply, admin);
        
        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.PAUSER_ROLE(), pauser);
        token.grantRole(token.SLASHER_ROLE(), slasher);
        
        // Initialize staking parameters
        token.updateStakingParams(7 days, 365 days, 1000); // 10% base rate
        vm.stopPrank();
    }

    // Basic Functionality Tests
    function testDeployment() public {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter));
        assertTrue(token.hasRole(token.PAUSER_ROLE(), pauser));
        assertTrue(token.hasRole(token.SLASHER_ROLE(), slasher));
        assertEq(token.balanceOf(admin), initialSupply);
        assertEq(token.totalSupply(), initialSupply);
    }

    function testMint() public {
        uint256 mintAmount = 100 * 10**18;
        vm.prank(minter);
        token.mint(user1, mintAmount);
        
        assertEq(token.balanceOf(user1), mintAmount);
        assertEq(token.totalSupply(), initialSupply + mintAmount);
    }

    function testBurn() public {
        uint256 burnAmount = 100 * 10**18;
        
        // First transfer some tokens to user1
        vm.prank(admin);
        token.transfer(user1, burnAmount);
        
        // Then burn them
        vm.prank(user1);
        token.burn(burnAmount);
        
        assertEq(token.balanceOf(user1), 0);
        assertEq(token.totalSupply(), initialSupply - burnAmount);
    }

    function testTransfer() public {
        uint256 transferAmount = 100 * 10**18;
        
        vm.prank(admin);
        token.transfer(user1, transferAmount);
        
        assertEq(token.balanceOf(user1), transferAmount);
        assertEq(token.balanceOf(admin), initialSupply - transferAmount);
    }

    // Staking Tests
    function testStake() public {
        uint256 stakeAmount = 100 * 10**18;
        uint256 stakeDuration = 30 days;
        
        // Transfer tokens to user1
        vm.prank(admin);
        token.transfer(user1, stakeAmount);
        
        // Approve staking contract (it's the token contract itself in this design)
        vm.prank(user1);
        token.approve(address(token), stakeAmount);
        
        // Stake tokens
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit TokensStaked(user1, stakeAmount, stakeDuration, block.timestamp + stakeDuration);
        bool success = token.stake(stakeAmount, stakeDuration);
        
        assertTrue(success);
        
        // Check user balance reduced
        assertEq(token.balanceOf(user1), 0);
        
        // Check total staked
        assertEq(token.getTotalStaked(user1), stakeAmount);
        
        // Verify stake info
        (uint256 amount, uint256 startTime, uint256 endTime, uint256 reward) = token.getStakeInfo(user1, 0);
        assertEq(amount, stakeAmount);
        assertEq(startTime, block.timestamp);
        assertEq(endTime, block.timestamp + stakeDuration);
    }
    
    function testWithdraw() public {
        uint256 stakeAmount = 100 * 10**18;
        uint256 stakeDuration = 30 days;
        
        // Setup stake
        vm.prank(admin);
        token.transfer(user1, stakeAmount);
        
        vm.prank(user1);
        token.approve(address(token), stakeAmount);
        
        vm.prank(user1);
        token.stake(stakeAmount, stakeDuration);
        
        // Warp to end of stake period
        vm.warp(block.timestamp + stakeDuration + 1);
        
        // Withdraw stake
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit StakeWithdrawn(user1, stakeAmount, 0); // Reward will be > 0 but we don't check exact value
        (uint256 withdrawnAmount, uint256 reward) = token.withdraw(0);
        
        assertEq(withdrawnAmount, stakeAmount);
        assertGt(reward, 0);
        assertEq(token.balanceOf(user1), stakeAmount + reward);
    }
    
    // Reward Calculation Tests
    function testRewardCalculation() public {
        uint256 stakeAmount = 1000 * 10**18;
        uint256 stakeDuration = 365 days; // 1 year
        uint256 baseRate = 1000; // 10%
        
        // Expected reward for 1 year at 10% = 100 tokens
        uint256 expectedReward = (stakeAmount * baseRate) / 10000;
        
        // Setup stake
        vm.prank(admin);
        token.transfer(user1, stakeAmount);
        
        vm.prank(user1);
        token.approve(address(token), stakeAmount);
        
        vm.prank(user1);
        token.stake(stakeAmount, stakeDuration);
        
        // Move forward 1 year
        vm.warp(block.timestamp + stakeDuration);
        
        // Check reward calculation
        (,,,uint256 currentReward) = token.getStakeInfo(user1, 0);
        
        // We allow a small margin of error due to block timestamp variations
        assertApproxEqRel(currentReward, expectedReward, 0.01e18); // Within 1%
    }
    
    function testRewardTiers() public {
        uint256 stakeAmount = 100 * 10**18;
        
        // Transfer tokens to user
        vm.prank(admin);
        token.transfer(user1, stakeAmount * 3);
        
        vm.startPrank(user1);
        token.approve(address(token), stakeAmount * 3);
        
        // Stake for different durations to test reward tiers
        uint256 shortDuration = 30 days;
        uint256 mediumDuration = 180 days;
        uint256 longDuration = 365 days;
        
        token.stake(stakeAmount, shortDuration);  // Tier 1
        token.stake(stakeAmount, mediumDuration); // Tier 3
        token.stake(stakeAmount, longDuration);   // Tier 4
        vm.stopPrank();
        
        // Fast forward to end of all staking periods
        vm.warp(block.timestamp + longDuration + 1);
        
        // Withdraw all stakes and compare rewards
        vm.startPrank(user1);
        (,uint256 shortReward) = token.withdraw(0);
        (,uint256 mediumReward) = token.withdraw(1);
        (,uint256 longReward) = token.withdraw(2);
        vm.stopPrank();
        
        // Higher tiers should give higher rewards
        assertLt(shortReward, mediumReward);
        assertLt(mediumReward, longReward);
    }
    
    // Access Control Tests
    function testRoleFunctionality() public {
        uint256 mintAmount = 100 * 10**18;
        
        // Non-minter cannot mint
        vm.prank(user1);
        vm.expectRevert();
        token.mint(user2, mintAmount);
        
        // Admin can grant minter role
        vm.prank(admin);
        token.grantRole(token.MINTER_ROLE(), user1);
        
        // Now user1 can mint
        vm.prank(user1);
        token.mint(user2, mintAmount);
        assertEq(token.balanceOf(user2), mintAmount);
    }
    
    function testSlashingMechanism() public {
        uint256 slashAmount = 100 * 10**18;
        
        // Setup a validator with tokens
        vm.prank(admin);
        token.transfer(user1, slashAmount * 2);
        
        // Slash the validator
        vm.prank(slasher);
        vm.expectEmit(true, true, false, true);
        emit ValidatorSlashed(user1, slasher, slashAmount, "Malicious validation");
        bool success = token.slashValidator(user1, slashAmount, "Malicious validation");
        
        assertTrue(success);
        assertEq(token.balanceOf(user1), slashAmount);
    }
    
    function testUnauthorizedSlashing() public {
        // Non-slasher tries to slash
        vm.prank(user2);
        vm.expectRevert();
        token.slashValidator(user1, 100 * 10**18, "Unauthorized slashing attempt");
    }
    
    // Edge Cases
    function testMinStakeDuration() public {
        uint256 stakeAmount = 100 * 10**18;
        uint256 minDuration = token.minStakeDuration();
        
        // Transfer tokens to user
        vm.prank(admin);
        token.transfer(user1, stakeAmount);
        
        vm.prank(user1);
        token.approve(address(token), stakeAmount);
        
        // Try staking for less than min duration
        vm.prank(user1);
        vm.expectRevert();
        token.stake(stakeAmount, minDuration - 1);
        
        // Stake with exact min duration
        vm.prank(user1);
        bool success = token.stake(stakeAmount, minDuration);
        assertTrue(success);
    }
    
    function testMaxStakeDuration() public {
        uint256 stakeAmount = 100 * 10**18;
        uint256 maxDuration = token.maxStakeDuration();
        
        // Transfer tokens to user
        vm.prank(admin);
        token.transfer(user1, stakeAmount);
        
        vm.prank(user1);
        token.approve(address(token), stakeAmount);
        
        // Try staking for more than max duration
        vm.prank(user1);
        vm.expectRevert();
        token.stake(stakeAmount, maxDuration + 1);
        
        // Stake with exact max duration
        vm.prank(user1);
        bool success = token.stake(stakeAmount, maxDuration);
        assertTrue(success);
    }
    
    function testZeroStake() public {
        // Try staking zero tokens
        vm.prank(user1);
        vm.expectRevert();
        token.stake(0, 30 days);
    }
    
    // Fuzz Testing
    function testFuzzStaking(uint256 amount, uint256 duration) public {
        // Bound values to reasonable ranges
        amount = bound(amount, 1, 1_000_000 * 10**18);
        duration = bound(duration, token.minStakeDuration(), token.maxStakeDuration());
        
        // Transfer tokens to user
        vm.prank(admin);
        token.transfer(user1, amount);
        
        vm.prank(user1);
        token.approve(address(token), amount);
        
        // Stake tokens
        vm.prank(user1);
        bool success = token.stake(amount, duration);
        assertTrue(success);
        
        // Warp time to end of stake
        vm.warp(block.timestamp + duration + 1);
        
        // Withdraw stake
        vm.prank(user1);
        (uint256 withdrawnAmount, uint256 reward) = token.withdraw(0);
        
        // Verify
        assertEq(withdrawnAmount, amount);
        assertGt(reward, 0);
        assertEq(token.balanceOf(user1), amount + reward);
    }
}