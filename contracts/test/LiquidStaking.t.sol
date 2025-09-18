// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../src/LiquidStaking.sol";
import "../src/StakedBlx.sol";
import "../src/BLX.sol";

contract LiquidStakingTest is Test {
    LiquidStaking public liquidStaking;
    StakedBLX public stToken;
    BLXToken public blxToken;
    
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
    
    event Staked(address indexed user, uint256 amount, uint256 stAmount, uint256 lockDuration, uint256 apr);
    event Redeemed(address indexed user, uint256 blxAmount, uint256 reward);

    function setUp() public {
        // Deploy BLX token
        blxToken = new BLXToken("BLX Token", "BLX", INITIAL_SUPPLY);
        
        // Deploy StakedBLX token
        stToken = new StakedBLX();
        
        // Deploy liquid staking contract
        liquidStaking = new LiquidStaking(address(blxToken), address(stToken));
        
        // Transfer ownership of StakedBLX to LiquidStaking contract
        stToken.transferOwnership(address(liquidStaking));
        
        // Setup user balances
        blxToken.transfer(user1, 10_000 * 1e18);
        blxToken.transfer(user2, 10_000 * 1e18);
        blxToken.transfer(user3, 10_000 * 1e18);
        
        // Setup rewards pool
        blxToken.approve(address(liquidStaking), REWARDS_POOL);
        liquidStaking.addRewards(REWARDS_POOL);
        
        // Approve liquid staking contract for users
        vm.startPrank(user1);
        blxToken.approve(address(liquidStaking), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(user2);
        blxToken.approve(address(liquidStaking), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(user3);
        blxToken.approve(address(liquidStaking), type(uint256).max);
        vm.stopPrank();
    }
    
    // ==================== CONSTRUCTOR TESTS ====================
    
    function testConstructor() public {
        assertEq(address(liquidStaking.blxToken()), address(blxToken));
        assertEq(address(liquidStaking.stToken()), address(stToken));
        assertEq(liquidStaking.owner(), owner);
        assertEq(liquidStaking.totalStaked(), 0);
        assertEq(liquidStaking.totalRewards(), REWARDS_POOL);
    }
    
    function testStTokenProperties() public {
        assertEq(stToken.name(), "Staked BLX");
        assertEq(stToken.symbol(), "stBLX");
        assertEq(stToken.owner(), address(liquidStaking));
        assertEq(stToken.totalSupply(), 0);
    }
    
    function testAPRConstants() public {
        assertEq(liquidStaking.APR_30D(), 500);   // 5%
        assertEq(liquidStaking.APR_90D(), 1000);  // 10%
        assertEq(liquidStaking.APR_365D(), 2000); // 20%
    }
    
    // ==================== STAKING TESTS ====================
    
    function testFirstStake() public {
        vm.startPrank(user1);
        
        vm.expectEmit(true, false, false, true);
        emit Staked(user1, STAKE_AMOUNT, STAKE_AMOUNT, THIRTY_DAYS, 500);
        
        liquidStaking.stake(STAKE_AMOUNT, THIRTY_DAYS);
        
        vm.stopPrank();
        
        // Check balances
        assertEq(blxToken.balanceOf(user1), 9000 * 1e18);
        assertEq(blxToken.balanceOf(address(liquidStaking)), STAKE_AMOUNT + REWARDS_POOL);
        assertEq(stToken.balanceOf(user1), STAKE_AMOUNT); // 1:1 ratio for first stake
        assertEq(stToken.totalSupply(), STAKE_AMOUNT);
        assertEq(liquidStaking.totalStaked(), STAKE_AMOUNT);
        
        // Check stake info
        (uint256 amount, uint256 startTime, uint256 lockDuration, uint256 apr) = 
            liquidStaking.stakes(user1, 0);
        assertEq(amount, STAKE_AMOUNT);
        assertEq(startTime, block.timestamp);
        assertEq(lockDuration, THIRTY_DAYS);
        assertEq(apr, 500);
    }
    
    function testStakeWith90Days() public {
        vm.startPrank(user1);
        liquidStaking.stake(STAKE_AMOUNT, NINETY_DAYS);
        vm.stopPrank();
        
        (uint256 amount, uint256 startTime, uint256 lockDuration, uint256 apr) = 
            liquidStaking.stakes(user1, 0);
        assertEq(amount, STAKE_AMOUNT);
        assertEq(lockDuration, NINETY_DAYS);
        assertEq(apr, 1000);
    }
    
    function testStakeWith365Days() public {
        vm.startPrank(user1);
        liquidStaking.stake(STAKE_AMOUNT, THREE_SIXTY_FIVE_DAYS);
        vm.stopPrank();
        
        (uint256 amount, uint256 startTime, uint256 lockDuration, uint256 apr) = 
            liquidStaking.stakes(user1, 0);
        assertEq(amount, STAKE_AMOUNT);
        assertEq(lockDuration, THREE_SIXTY_FIVE_DAYS);
        assertEq(apr, 2000);
    }
    
    function testSubsequentStakeExchangeRate() public {
        // First user stakes
        vm.startPrank(user1);
        liquidStaking.stake(1000 * 1e18, THIRTY_DAYS);
        vm.stopPrank();
        
        // Simulate some rewards accumulation by artificially increasing totalStaked
        // This would happen naturally through rewards, but we'll simulate it
        // In practice, rewards would be added through the addRewards function
        
        // Second user stakes - should get stBLX based on exchange rate
        vm.startPrank(user2);
        liquidStaking.stake(500 * 1e18, THIRTY_DAYS);
        vm.stopPrank();
        
        // With equal totalStaked and totalSupply, exchange rate should be 1:1
        assertEq(stToken.balanceOf(user2), 500 * 1e18);
        assertEq(liquidStaking.totalStaked(), 1500 * 1e18);
        assertEq(stToken.totalSupply(), 1500 * 1e18);
    }
    
    function testStakeFailsWithZeroAmount() public {
        vm.startPrank(user1);
        vm.expectRevert("Cannot stake 0");
        liquidStaking.stake(0, THIRTY_DAYS);
        vm.stopPrank();
    }
    
    function testStakeFailsWithInvalidLockDuration() public {
        vm.startPrank(user1);
        vm.expectRevert("Invalid lock duration");
        liquidStaking.stake(STAKE_AMOUNT, 15 days);
        vm.stopPrank();
    }
    
    function testStakeFailsWithInsufficientBalance() public {
        vm.startPrank(user1);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        liquidStaking.stake(20_000 * 1e18, THIRTY_DAYS);
        vm.stopPrank();
    }
    
    // ==================== REWARD CALCULATION TESTS ====================
    
    function testPendingRewardCalculation() public {
        vm.startPrank(user1);
        liquidStaking.stake(STAKE_AMOUNT, THIRTY_DAYS);
        vm.stopPrank();
        
        // Fast forward 15 days
        vm.warp(block.timestamp + 15 days);
        
        uint256 pendingReward = liquidStaking.pendingReward(user1, 0);
        
        // Expected reward: amount * apr * elapsed / (365 days * 10000)
        uint256 expectedReward = (STAKE_AMOUNT * 500 * 15 days) / (365 days * 10000);
        
        assertEq(pendingReward, expectedReward);
    }
    
    function testPendingRewardCapAtLockDuration() public {
        vm.startPrank(user1);
        liquidStaking.stake(STAKE_AMOUNT, THIRTY_DAYS);
        vm.stopPrank();
        
        // Fast forward beyond lock period
        vm.warp(block.timestamp + 60 days);
        
        uint256 pendingReward = liquidStaking.pendingReward(user1, 0);
        
        // Should be capped at 30 days
        uint256 expectedReward = (STAKE_AMOUNT * 500 * THIRTY_DAYS) / (365 days * 10000);
        
        assertEq(pendingReward, expectedReward);
    }
    
    function testPendingRewardCapByTotalRewards() public {
        vm.startPrank(user1);
        liquidStaking.stake(50_000 * 1e18, THREE_SIXTY_FIVE_DAYS);
        vm.stopPrank();
        
        vm.warp(block.timestamp + THREE_SIXTY_FIVE_DAYS);
        
        uint256 pendingReward = liquidStaking.pendingReward(user1, 0);
        
        // Should be capped by totalRewards
        assertTrue(pendingReward <= REWARDS_POOL);
    }
    
    // ==================== REDEMPTION TESTS ====================
    
    function testRedeemAfterLockPeriod() public {
        vm.startPrank(user1);
        liquidStaking.stake(STAKE_AMOUNT, THIRTY_DAYS);
        vm.stopPrank();
        
        // Fast forward past lock period
        vm.warp(block.timestamp + THIRTY_DAYS + 1);
        
        uint256 expectedReward = (STAKE_AMOUNT * 500 * THIRTY_DAYS) / (365 days * 10000);
        uint256 blxBalanceBefore = blxToken.balanceOf(user1);
        uint256 stTokenBalanceBefore = stToken.balanceOf(user1);
        uint256 totalStakedBefore = liquidStaking.totalStaked();
        uint256 totalRewardsBefore = liquidStaking.totalRewards();
        
        vm.startPrank(user1);
        
        vm.expectEmit(true, false, false, true);
        emit Redeemed(user1, STAKE_AMOUNT, expectedReward);
        
        liquidStaking.redeem(0);
        vm.stopPrank();
        
        // Check balances
        uint256 expectedReturn = STAKE_AMOUNT + expectedReward;
        assertEq(blxToken.balanceOf(user1) - blxBalanceBefore, expectedReturn);
        assertEq(stTokenBalanceBefore - stToken.balanceOf(user1), STAKE_AMOUNT); // stBLX burned
        assertEq(totalStakedBefore - liquidStaking.totalStaked(), STAKE_AMOUNT);
        assertEq(totalRewardsBefore - liquidStaking.totalRewards(), expectedReward);
    }
    
    function testRedeemBeforeLockPeriod() public {
        vm.startPrank(user1);
        liquidStaking.stake(STAKE_AMOUNT, THIRTY_DAYS);
        
        // Fast forward 15 days (before lock expires)
        vm.warp(block.timestamp + 15 days);
        
        uint256 expectedReward = (STAKE_AMOUNT * 500 * 15 days) / (365 days * 10000);
        uint256 blxBalanceBefore = blxToken.balanceOf(user1);
        
        liquidStaking.redeem(0);
        vm.stopPrank();
        
        // Should get partial rewards for time staked
        uint256 expectedReturn = STAKE_AMOUNT + expectedReward;
        assertEq(blxToken.balanceOf(user1) - blxBalanceBefore, expectedReturn);
    }
    
    function testRedeemFailsWithInsufficientStTokens() public {
        vm.startPrank(user1);
        liquidStaking.stake(STAKE_AMOUNT, THIRTY_DAYS);
        
        // Transfer away some stBLX tokens
        stToken.transfer(user2, 500 * 1e18);
        
        vm.expectRevert("Not enough stBLX to redeem");
        liquidStaking.redeem(0);
        vm.stopPrank();
    }
    
    // ==================== STOKEN FUNCTIONALITY TESTS ====================
    
    function testStTokenTransfer() public {
        vm.startPrank(user1);
        liquidStaking.stake(STAKE_AMOUNT, THIRTY_DAYS);
        
        // Transfer stBLX to user2
        stToken.transfer(user2, 500 * 1e18);
        vm.stopPrank();
        
        assertEq(stToken.balanceOf(user1), 500 * 1e18);
        assertEq(stToken.balanceOf(user2), 500 * 1e18);
    }
    
    function testStTokenBurn() public {
        vm.startPrank(user1);
        liquidStaking.stake(STAKE_AMOUNT, THIRTY_DAYS);
        
        // User can burn their own stBLX
        stToken.burn(user1, 100 * 1e18);
        vm.stopPrank();
        
        assertEq(stToken.balanceOf(user1), 900 * 1e18);
        assertEq(stToken.totalSupply(), 900 * 1e18);
    }
    
    function testStTokenMintOnlyByOwner() public {
        vm.startPrank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        stToken.mint(user1, 100 * 1e18);
        vm.stopPrank();
    }
    
    // ==================== ADMIN FUNCTION TESTS ====================
    
    function testAddRewards() public {
        uint256 additionalRewards = 50_000 * 1e18;
        uint256 totalRewardsBefore = liquidStaking.totalRewards();
        
        blxToken.approve(address(liquidStaking), additionalRewards);
        liquidStaking.addRewards(additionalRewards);
        
        assertEq(liquidStaking.totalRewards(), totalRewardsBefore + additionalRewards);
    }
    
    function testAddRewardsFailsWithZeroAmount() public {
        vm.expectRevert("Amount > 0");
        liquidStaking.addRewards(0);
    }
    
    function testAddRewardsFailsFromNonOwner() public {
        vm.startPrank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        liquidStaking.addRewards(1000 * 1e18);
        vm.stopPrank();
    }
    
    // ==================== COMPLEX SCENARIO TESTS ====================
    
    function testMultipleUsersStakingAndRedeeming() public {
        // User1 stakes for 30 days
        vm.startPrank(user1);
        liquidStaking.stake(1000 * 1e18, THIRTY_DAYS);
        vm.stopPrank();
        
        // User2 stakes for 90 days
        vm.startPrank(user2);
        liquidStaking.stake(2000 * 1e18, NINETY_DAYS);
        vm.stopPrank();
        
        // User3 stakes for 365 days
        vm.startPrank(user3);
        liquidStaking.stake(3000 * 1e18, THREE_SIXTY_FIVE_DAYS);
        vm.stopPrank();
        
        // Fast forward 30 days
        vm.warp(block.timestamp + THIRTY_DAYS);
        
        // User1 redeems
        vm.startPrank(user1);
        uint256 user1BalanceBefore = blxToken.balanceOf(user1);
        liquidStaking.redeem(0);
        uint256 user1Gained = blxToken.balanceOf(user1) - user1BalanceBefore;
        vm.stopPrank();
        
        assertTrue(user1Gained > 1000 * 1e18); // Should have gained rewards
        
        // Fast forward another 60 days (total 90)
        vm.warp(block.timestamp + 60 days);
        
        // User2 redeems
        vm.startPrank(user2);
        uint256 user2BalanceBefore = blxToken.balanceOf(user2);
        liquidStaking.redeem(0);
        uint256 user2Gained = blxToken.balanceOf(user2) - user2BalanceBefore;
        vm.stopPrank();
        
        assertTrue(user2Gained > 2000 * 1e18); // Should have gained more rewards (higher APR)
    }
    
    function testStTokenExchangeRateWithMultipleStakes() public {
        // First stake establishes 1:1 ratio
        vm.startPrank(user1);
        liquidStaking.stake(1000 * 1e18, THIRTY_DAYS);
        vm.stopPrank();
        
        assertEq(stToken.balanceOf(user1), 1000 * 1e18);
        
        // Second stake should maintain ratio
        vm.startPrank(user2);
        liquidStaking.stake(500 * 1e18, THIRTY_DAYS);
        vm.stopPrank();
        
        // Should get proportional stBLX
        uint256 expectedStTokens = (500 * 1e18 * stToken.totalSupply()) / liquidStaking.totalStaked();
        // Since no rewards have been distributed yet, this should be close to 500 * 1e18
        assertApproxEqRel(stToken.balanceOf(user2), 500 * 1e18, 0.01e18);
    }
    
    function testPartialRedemption() public {
        vm.startPrank(user1);
        liquidStaking.stake(2000 * 1e18, THIRTY_DAYS);
        liquidStaking.stake(1000 * 1e18, NINETY_DAYS);
        vm.stopPrank();
        
        // Fast forward 30 days and redeem first stake
        vm.warp(block.timestamp + THIRTY_DAYS);
        
        vm.startPrank(user1);
        uint256 balanceBefore = blxToken.balanceOf(user1);
        liquidStaking.redeem(0);
        uint256 gained = blxToken.balanceOf(user1) - balanceBefore;
        vm.stopPrank();
        
        // Should have redeemed only first stake plus rewards
        assertTrue(gained > 2000 * 1e18);
        assertTrue(gained < 3000 * 1e18); // Shouldn't include second stake
        
        // Second stake should still be active
        (uint256 amount, , ,) = liquidStaking.stakes(user1, 1);
        assertEq(amount, 1000 * 1e18);
    }
    
    // ==================== EDGE CASE TESTS ====================
    
    function testRedeemImmediatelyAfterStaking() public {
        vm.startPrank(user1);
        liquidStaking.stake(STAKE_AMOUNT, THIRTY_DAYS);
        
        // Redeem immediately (0 time elapsed)
        uint256 balanceBefore = blxToken.balanceOf(user1);
        liquidStaking.redeem(0);
        uint256 gained = blxToken.balanceOf(user1) - balanceBefore;
        vm.stopPrank();
        
        // Should get back exactly what was staked (no rewards)
        assertEq(gained, STAKE_AMOUNT);
    }
    
    function testMaximumStakeAmount() public {
        uint256 maxAmount = blxToken.balanceOf(user1);
        
        vm.startPrank(user1);
        liquidStaking.stake(maxAmount, THIRTY_DAYS);
        vm.stopPrank();
        
        assertEq(blxToken.balanceOf(user1), 0);
        assertEq(stToken.balanceOf(user1), maxAmount);
        assertEq(liquidStaking.totalStaked(), maxAmount);
    }
    
    function testStakeDeletedAfterRedemption() public {
        vm.startPrank(user1);
        liquidStaking.stake(STAKE_AMOUNT, THIRTY_DAYS);
        
        vm.warp(block.timestamp + THIRTY_DAYS);
        liquidStaking.redeem(0);
        vm.stopPrank();
        
        // Stake should be deleted (all values reset to 0)
        (uint256 amount, uint256 startTime, uint256 lockDuration, uint256 apr) = 
            liquidStaking.stakes(user1, 0);
        assertEq(amount, 0);
        assertEq(startTime, 0);
        assertEq(lockDuration, 0);
        assertEq(apr, 0);
    }
    
    // ==================== FUZZ TESTS ====================
    
    function testFuzzStakeAmount(uint256 amount) public {
        amount = bound(amount, 1e18, 10_000 * 1e18);
        
        vm.startPrank(user1);
        liquidStaking.stake(amount, THIRTY_DAYS);
        vm.stopPrank();
        
        assertEq(stToken.balanceOf(user1), amount); // 1:1 for first stake
        assertEq(liquidStaking.totalStaked(), amount);
        
        (uint256 stakedAmount, , ,) = liquidStaking.stakes(user1, 0);
        assertEq(stakedAmount, amount);
    }
    
    function testFuzzRewardCalculation(uint256 timeElapsed) public {
        timeElapsed = bound(timeElapsed, 1 days, THIRTY_DAYS);
        
        vm.startPrank(user1);
        liquidStaking.stake(STAKE_AMOUNT, THIRTY_DAYS);
        vm.stopPrank();
        
        vm.warp(block.timestamp + timeElapsed);
        
        uint256 reward = liquidStaking.pendingReward(user1, 0);
        uint256 expectedReward = (STAKE_AMOUNT * 500 * timeElapsed) / (365 days * 10000);
        
        assertEq(reward, expectedReward);
    }
    
    function testFuzzMultipleStakes(uint8 numStakes) public {
        numStakes = uint8(bound(numStakes, 1, 10));
        uint256 stakeAmount = 100 * 1e18;
        
        vm.startPrank(user1);
        for (uint8 i = 0; i < numStakes; i++) {
            liquidStaking.stake(stakeAmount, THIRTY_DAYS);
        }
        vm.stopPrank();
        
        assertEq(stToken.balanceOf(user1), stakeAmount * numStakes);
        assertEq(liquidStaking.totalStaked(), stakeAmount * numStakes);
    }
}
