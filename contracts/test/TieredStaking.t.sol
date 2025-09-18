// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../src/Staking.sol";
import "../src/BLX.sol";

contract TieredStakingTest is Test {
    TieredStaking public staking;
    BLXToken public stakingToken;
    BLXToken public rewardsToken;
    
    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);
    
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 1e18;
    uint256 public constant STAKE_AMOUNT = 1000 * 1e18;
    uint256 public constant REWARDS_POOL = 100_000 * 1e18;
    
    // Time constants
    uint256 public constant THIRTY_DAYS = 30 days;
    uint256 public constant NINETY_DAYS = 90 days;
    uint256 public constant THREE_SIXTY_FIVE_DAYS = 365 days;
    
    event Staked(address indexed user, uint256 amount, uint256 lockDuration, uint256 apr);
    event Withdrawn(address indexed user, uint256 amount, uint256 reward);
    event RewardsAdded(address indexed admin, uint256 amount);

    function setUp() public {
        // Deploy tokens
        stakingToken = new BLXToken("Staking Token", "STK", INITIAL_SUPPLY);
        rewardsToken = new BLXToken("Rewards Token", "RWD", INITIAL_SUPPLY);
        
        // Deploy staking contract
        staking = new TieredStaking(address(stakingToken), address(rewardsToken));
        
        // Setup user balances
        stakingToken.transfer(user1, 10_000 * 1e18);
        stakingToken.transfer(user2, 10_000 * 1e18);
        stakingToken.transfer(user3, 10_000 * 1e18);
        
        // Setup rewards pool
        rewardsToken.approve(address(staking), REWARDS_POOL);
        staking.addRewards(REWARDS_POOL);
        
        // Approve staking contract for users
        vm.startPrank(user1);
        stakingToken.approve(address(staking), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(user2);
        stakingToken.approve(address(staking), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(user3);
        stakingToken.approve(address(staking), type(uint256).max);
        vm.stopPrank();
    }
    
    // ==================== CONSTRUCTOR TESTS ====================
    
    function testConstructor() public {
        assertEq(address(staking.stakingToken()), address(stakingToken));
        assertEq(address(staking.rewardsToken()), address(rewardsToken));
        assertEq(staking.owner(), owner);
        assertEq(staking.totalRewards(), REWARDS_POOL);
    }
    
    function testAPRConstants() public {
        assertEq(staking.APR_30D(), 500);   // 5%
        assertEq(staking.APR_90D(), 1000);  // 10%
        assertEq(staking.APR_365D(), 2000); // 20%
    }
    
    // ==================== STAKING TESTS ====================
    
    function testStake30Days() public {
        vm.startPrank(user1);
        
        vm.expectEmit(true, false, false, true);
        emit Staked(user1, STAKE_AMOUNT, THIRTY_DAYS, 500);
        
        staking.stake(STAKE_AMOUNT, THIRTY_DAYS);
        
        vm.stopPrank();
        
        assertEq(stakingToken.balanceOf(user1), 9000 * 1e18);
        assertEq(stakingToken.balanceOf(address(staking)), STAKE_AMOUNT);
        assertEq(staking.stakesLength(user1), 1);
        
        // Check stake info
        (uint256 amount, uint256 startTime, uint256 lockDuration, uint256 apr, bool withdrawn) = 
            staking.stakes(user1, 0);
        assertEq(amount, STAKE_AMOUNT);
        assertEq(startTime, block.timestamp);
        assertEq(lockDuration, THIRTY_DAYS);
        assertEq(apr, 500);
        assertFalse(withdrawn);
    }
    
    function testStake90Days() public {
        vm.startPrank(user1);
        staking.stake(STAKE_AMOUNT, NINETY_DAYS);
        vm.stopPrank();
        
        (uint256 amount, uint256 startTime, uint256 lockDuration, uint256 apr, bool withdrawn) = 
            staking.stakes(user1, 0);
        assertEq(amount, STAKE_AMOUNT);
        assertEq(lockDuration, NINETY_DAYS);
        assertEq(apr, 1000);
    }
    
    function testStake365Days() public {
        vm.startPrank(user1);
        staking.stake(STAKE_AMOUNT, THREE_SIXTY_FIVE_DAYS);
        vm.stopPrank();
        
        (uint256 amount, uint256 startTime, uint256 lockDuration, uint256 apr, bool withdrawn) = 
            staking.stakes(user1, 0);
        assertEq(amount, STAKE_AMOUNT);
        assertEq(lockDuration, THREE_SIXTY_FIVE_DAYS);
        assertEq(apr, 2000);
    }
    
    function testStakeFailsWithZeroAmount() public {
        vm.startPrank(user1);
        vm.expectRevert("Cannot stake 0");
        staking.stake(0, THIRTY_DAYS);
        vm.stopPrank();
    }
    
    function testStakeFailsWithInvalidLockDuration() public {
        vm.startPrank(user1);
        vm.expectRevert("Invalid lock duration");
        staking.stake(STAKE_AMOUNT, 15 days); // Invalid duration
        vm.stopPrank();
    }
    
    function testStakeFailsWithInsufficientBalance() public {
        vm.startPrank(user1);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        staking.stake(20_000 * 1e18, THIRTY_DAYS); // More than user has
        vm.stopPrank();
    }
    
    function testMultipleStakes() public {
        vm.startPrank(user1);
        
        staking.stake(500 * 1e18, THIRTY_DAYS);
        staking.stake(300 * 1e18, NINETY_DAYS);
        staking.stake(200 * 1e18, THREE_SIXTY_FIVE_DAYS);
        
        vm.stopPrank();
        
        assertEq(staking.stakesLength(user1), 3);
        assertEq(stakingToken.balanceOf(address(staking)), 1000 * 1e18);
        
        // Check each stake
        (uint256 amount0, , uint256 lockDuration0, uint256 apr0,) = staking.stakes(user1, 0);
        assertEq(amount0, 500 * 1e18);
        assertEq(lockDuration0, THIRTY_DAYS);
        assertEq(apr0, 500);
        
        (uint256 amount1, , uint256 lockDuration1, uint256 apr1,) = staking.stakes(user1, 1);
        assertEq(amount1, 300 * 1e18);
        assertEq(lockDuration1, NINETY_DAYS);
        assertEq(apr1, 1000);
        
        (uint256 amount2, , uint256 lockDuration2, uint256 apr2,) = staking.stakes(user1, 2);
        assertEq(amount2, 200 * 1e18);
        assertEq(lockDuration2, THREE_SIXTY_FIVE_DAYS);
        assertEq(apr2, 2000);
    }
    
    // ==================== REWARD CALCULATION TESTS ====================
    
    function testPendingRewardCalculation() public {
        vm.startPrank(user1);
        staking.stake(STAKE_AMOUNT, THIRTY_DAYS);
        vm.stopPrank();
        
        // Fast forward 15 days (half of lock period)
        vm.warp(block.timestamp + 15 days);
        
        uint256 pendingReward = staking.pendingReward(user1, 0);
        
        // Expected reward: amount * apr * elapsed / (365 days * 10000)
        // 1000e18 * 500 * 15 days / (365 days * 10000) = 1000e18 * 500 * 15 / (365 * 10000)
        uint256 expectedReward = (STAKE_AMOUNT * 500 * 15 days) / (365 days * 10000);
        
        assertEq(pendingReward, expectedReward);
    }
    
    function testPendingRewardCapAtLockDuration() public {
        vm.startPrank(user1);
        staking.stake(STAKE_AMOUNT, THIRTY_DAYS);
        vm.stopPrank();
        
        // Fast forward beyond lock period
        vm.warp(block.timestamp + 60 days);
        
        uint256 pendingReward = staking.pendingReward(user1, 0);
        
        // Reward should be capped at 30 days even though 60 days have passed
        uint256 expectedReward = (STAKE_AMOUNT * 500 * THIRTY_DAYS) / (365 days * 10000);
        
        assertEq(pendingReward, expectedReward);
    }
    
    function testPendingRewardForWithdrawnStake() public {
        vm.startPrank(user1);
        staking.stake(STAKE_AMOUNT, THIRTY_DAYS);
        
        // Fast forward and withdraw
        vm.warp(block.timestamp + THIRTY_DAYS);
        staking.withdraw(0);
        
        // Pending reward should be 0 after withdrawal
        uint256 pendingReward = staking.pendingReward(user1, 0);
        assertEq(pendingReward, 0);
        
        vm.stopPrank();
    }
    
    function testPendingRewardCapByTotalRewards() public {
        // Create a scenario where calculated reward exceeds total rewards
        vm.startPrank(user1);
        staking.stake(50_000 * 1e18, THREE_SIXTY_FIVE_DAYS); // Large stake
        vm.stopPrank();
        
        // Fast forward full year
        vm.warp(block.timestamp + THREE_SIXTY_FIVE_DAYS);
        
        uint256 pendingReward = staking.pendingReward(user1, 0);
        
        // Should be capped by totalRewards
        assertTrue(pendingReward <= REWARDS_POOL);
    }
    
    // ==================== WITHDRAWAL TESTS ====================
    
    function testEarlyWithdrawalNoPenalty() public {
        vm.startPrank(user1);
        staking.stake(STAKE_AMOUNT, THIRTY_DAYS);
        
        // Fast forward 15 days (before lock expires)
        vm.warp(block.timestamp + 15 days);
        
        uint256 balanceBefore = stakingToken.balanceOf(user1);
        
        vm.expectEmit(true, false, false, true);
        emit Withdrawn(user1, STAKE_AMOUNT, 0); // No rewards for early withdrawal
        
        staking.withdraw(0);
        
        vm.stopPrank();
        
        uint256 balanceAfter = stakingToken.balanceOf(user1);
        assertEq(balanceAfter - balanceBefore, STAKE_AMOUNT);
        
        // Check stake is marked as withdrawn
        (, , , , bool withdrawn) = staking.stakes(user1, 0);
        assertTrue(withdrawn);
    }
    
    function testWithdrawalAfterLockPeriod() public {
        vm.startPrank(user1);
        staking.stake(STAKE_AMOUNT, THIRTY_DAYS);
        vm.stopPrank();
        
        // Fast forward past lock period
        vm.warp(block.timestamp + THIRTY_DAYS + 1);
        
        uint256 expectedReward = (STAKE_AMOUNT * 500 * THIRTY_DAYS) / (365 days * 10000);
        uint256 stakingBalanceBefore = stakingToken.balanceOf(user1);
        uint256 rewardsBalanceBefore = rewardsToken.balanceOf(user1);
        uint256 totalRewardsBefore = staking.totalRewards();
        
        vm.startPrank(user1);
        
        vm.expectEmit(true, false, false, true);
        emit Withdrawn(user1, STAKE_AMOUNT, expectedReward);
        
        staking.withdraw(0);
        vm.stopPrank();
        
        // Check balances
        assertEq(stakingToken.balanceOf(user1) - stakingBalanceBefore, STAKE_AMOUNT);
        assertEq(rewardsToken.balanceOf(user1) - rewardsBalanceBefore, expectedReward);
        assertEq(totalRewardsBefore - staking.totalRewards(), expectedReward);
        
        // Check stake is marked as withdrawn
        (, , , , bool withdrawn) = staking.stakes(user1, 0);
        assertTrue(withdrawn);
    }
    
    function testWithdrawFailsIfAlreadyWithdrawn() public {
        vm.startPrank(user1);
        staking.stake(STAKE_AMOUNT, THIRTY_DAYS);
        
        // Fast forward and withdraw
        vm.warp(block.timestamp + THIRTY_DAYS);
        staking.withdraw(0);
        
        // Try to withdraw again
        vm.expectRevert("Already withdrawn");
        staking.withdraw(0);
        
        vm.stopPrank();
    }
    
    function testWithdrawFailsWithInsufficientRewards() public {
        // Drain most rewards first
        vm.startPrank(user2);
        staking.stake(10_000 * 1e18, THREE_SIXTY_FIVE_DAYS);
        vm.stopPrank();
        
        vm.warp(block.timestamp + THREE_SIXTY_FIVE_DAYS);
        
        vm.startPrank(user2);
        staking.withdraw(0); // This should consume most rewards
        vm.stopPrank();
        
        // Now user1 stakes and tries to withdraw
        vm.startPrank(user1);
        staking.stake(STAKE_AMOUNT, THREE_SIXTY_FIVE_DAYS);
        vm.stopPrank();
        
        vm.warp(block.timestamp + THREE_SIXTY_FIVE_DAYS);
        
        vm.startPrank(user1);
        vm.expectRevert("Not enough rewards");
        staking.withdraw(0);
        vm.stopPrank();
    }
    
    // ==================== ADMIN FUNCTION TESTS ====================
    
    function testAddRewards() public {
        uint256 additionalRewards = 50_000 * 1e18;
        uint256 totalRewardsBefore = staking.totalRewards();
        
        rewardsToken.approve(address(staking), additionalRewards);
        
        vm.expectEmit(true, false, false, true);
        emit RewardsAdded(owner, additionalRewards);
        
        staking.addRewards(additionalRewards);
        
        assertEq(staking.totalRewards(), totalRewardsBefore + additionalRewards);
    }
    
    function testAddRewardsFailsWithZeroAmount() public {
        vm.expectRevert("Amount must be > 0");
        staking.addRewards(0);
    }
    
    function testAddRewardsFailsFromNonOwner() public {
        vm.startPrank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        staking.addRewards(1000 * 1e18);
        vm.stopPrank();
    }
    
    function testRecoverTokens() public {
        // Deploy a different token and send it to staking contract
        BLXToken otherToken = new BLXToken("Other", "OTHER", 1000 * 1e18);
        otherToken.transfer(address(staking), 100 * 1e18);
        
        uint256 balanceBefore = otherToken.balanceOf(owner);
        
        staking.recoverTokens(address(otherToken), 100 * 1e18);
        
        uint256 balanceAfter = otherToken.balanceOf(owner);
        assertEq(balanceAfter - balanceBefore, 100 * 1e18);
    }
    
    function testRecoverTokensFailsForStakingToken() public {
        vm.expectRevert("Cannot recover staking token");
        staking.recoverTokens(address(stakingToken), 100 * 1e18);
    }
    
    function testRecoverTokensFailsFromNonOwner() public {
        vm.startPrank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        staking.recoverTokens(address(rewardsToken), 100 * 1e18);
        vm.stopPrank();
    }
    
    // ==================== VIEW FUNCTION TESTS ====================
    
    function testGetUserStakesInfo() public {
        vm.startPrank(user1);
        staking.stake(500 * 1e18, THIRTY_DAYS);
        staking.stake(300 * 1e18, NINETY_DAYS);
        vm.stopPrank();
        
        TieredStaking.StakeInfo[] memory stakes = staking.getUserStakesInfo(user1);
        
        assertEq(stakes.length, 2);
        assertEq(stakes[0].amount, 500 * 1e18);
        assertEq(stakes[0].lockDuration, THIRTY_DAYS);
        assertEq(stakes[1].amount, 300 * 1e18);
        assertEq(stakes[1].lockDuration, NINETY_DAYS);
    }
    
    // ==================== COMPLEX SCENARIO TESTS ====================
    
    function testMultipleUsersMultipleStakes() public {
        // User1: 30-day stake
        vm.startPrank(user1);
        staking.stake(1000 * 1e18, THIRTY_DAYS);
        vm.stopPrank();
        
        // User2: 90-day stake
        vm.startPrank(user2);
        staking.stake(2000 * 1e18, NINETY_DAYS);
        vm.stopPrank();
        
        // User3: 365-day stake
        vm.startPrank(user3);
        staking.stake(3000 * 1e18, THREE_SIXTY_FIVE_DAYS);
        vm.stopPrank();
        
        // Fast forward 30 days
        vm.warp(block.timestamp + THIRTY_DAYS);
        
        // User1 can withdraw with rewards
        vm.startPrank(user1);
        uint256 user1Reward = staking.pendingReward(user1, 0);
        staking.withdraw(0);
        vm.stopPrank();
        
        assertTrue(user1Reward > 0);
        
        // User2 and User3 still have pending rewards
        uint256 user2Reward = staking.pendingReward(user2, 0);
        uint256 user3Reward = staking.pendingReward(user3, 0);
        
        assertTrue(user2Reward > 0);
        assertTrue(user3Reward > 0);
        assertTrue(user2Reward > user1Reward); // Higher APR and longer time
        assertTrue(user3Reward > user2Reward); // Even higher APR
    }
    
    function testRewardAccrualOverTime() public {
        vm.startPrank(user1);
        staking.stake(STAKE_AMOUNT, NINETY_DAYS);
        vm.stopPrank();
        
        // Check rewards at different intervals
        vm.warp(block.timestamp + 30 days);
        uint256 reward30 = staking.pendingReward(user1, 0);
        
        vm.warp(block.timestamp + 30 days); // Total 60 days
        uint256 reward60 = staking.pendingReward(user1, 0);
        
        vm.warp(block.timestamp + 30 days); // Total 90 days
        uint256 reward90 = staking.pendingReward(user1, 0);
        
        // Rewards should increase linearly
        assertTrue(reward60 > reward30);
        assertTrue(reward90 > reward60);
        assertApproxEqRel(reward60, reward30 * 2, 0.01e18); // Allow 1% tolerance
        assertApproxEqRel(reward90, reward30 * 3, 0.01e18);
    }
    
    // ==================== EDGE CASE TESTS ====================
    
    function testZeroTimeElapsed() public {
        vm.startPrank(user1);
        staking.stake(STAKE_AMOUNT, THIRTY_DAYS);
        
        // Check reward immediately after staking
        uint256 reward = staking.pendingReward(user1, 0);
        assertEq(reward, 0);
        
        vm.stopPrank();
    }
    
    function testMaximumStakeAmount() public {
        uint256 maxAmount = stakingToken.balanceOf(user1);
        
        vm.startPrank(user1);
        staking.stake(maxAmount, THIRTY_DAYS);
        vm.stopPrank();
        
        assertEq(stakingToken.balanceOf(user1), 0);
        assertEq(stakingToken.balanceOf(address(staking)), maxAmount);
    }
    
    // ==================== FUZZ TESTS ====================
    
    function testFuzzStakeAmount(uint256 amount) public {
        amount = bound(amount, 1e18, 10_000 * 1e18); // 1 to 10,000 tokens
        
        vm.startPrank(user1);
        staking.stake(amount, THIRTY_DAYS);
        vm.stopPrank();
        
        (uint256 stakedAmount, , , ,) = staking.stakes(user1, 0);
        assertEq(stakedAmount, amount);
        assertEq(stakingToken.balanceOf(address(staking)), amount);
    }
    
    function testFuzzRewardCalculation(uint256 timeElapsed) public {
        timeElapsed = bound(timeElapsed, 1 days, THIRTY_DAYS);
        
        vm.startPrank(user1);
        staking.stake(STAKE_AMOUNT, THIRTY_DAYS);
        vm.stopPrank();
        
        vm.warp(block.timestamp + timeElapsed);
        
        uint256 reward = staking.pendingReward(user1, 0);
        uint256 expectedReward = (STAKE_AMOUNT * 500 * timeElapsed) / (365 days * 10000);
        
        assertEq(reward, expectedReward);
    }
}
