// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../src/BLXVault.sol";
import "../src/BLX.sol";
import "../src/Staking.sol";
import "../src/MockErc20.sol";

contract BLXVaultTest is Test {
    BLXVault vault;
    BLXToken blx;
    TieredStaking staking;
    MockERC20 usdc;
    
    address owner = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);
    address manager = address(0x4);
    address emergency = address(0x5);
    
    uint256 constant INITIAL_SUPPLY = 1000000e18;
    uint256 constant DEPOSIT_AMOUNT = 1000e18;
    
    function setUp() public {
        // Deploy BLX token
        vm.prank(owner);
        blx = new BLXToken("BLX Token", "BLX", INITIAL_SUPPLY);
        
        // Deploy USDC mock
        usdc = new MockERC20("USDC", "USDC", 6);
        usdc.mint(address(this), 1000000e6);
        
        // Deploy staking contract
        vm.prank(owner);
        staking = new TieredStaking(address(blx), address(blx));
        
        // Deploy vault
        vm.prank(owner);
        vault = new BLXVault(address(blx), address(staking));
        
        // Grant roles
        vm.startPrank(owner);
        vault.grantRole(vault.MANAGER_ROLE(), manager);
        vault.grantRole(vault.EMERGENCY_ROLE(), emergency);
        vm.stopPrank();
        
        // Distribute tokens
        vm.startPrank(owner);
        blx.transfer(user1, 10000e18);
        blx.transfer(user2, 10000e18);
        blx.transfer(emergency, 5000e18); // Give emergency role holder some tokens
        blx.transfer(address(vault), 1000e18); // For fees/emergencies
        vm.stopPrank();
        
        // Approve vault for users
        vm.prank(user1);
        blx.approve(address(vault), type(uint256).max);
        
        vm.prank(user2);
        blx.approve(address(vault), type(uint256).max);
        
        // Approve staking contract for vault (for auto-staking)
        vm.prank(address(vault));
        blx.approve(address(staking), type(uint256).max);
        
        // Approve emergency user for emergency withdraw test
        vm.prank(emergency);
        blx.approve(address(vault), type(uint256).max);
    }
    
    // ==================== CONSTRUCTOR TESTS ====================
    
    function testConstructor() public {
        assertEq(address(vault.blxToken()), address(blx));
        assertEq(address(vault.stakingContract()), address(staking));
        assertEq(vault.treasury(), owner); // Treasury initially set to deployer
        assertTrue(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(vault.hasRole(vault.MANAGER_ROLE(), manager));
        assertTrue(vault.hasRole(vault.EMERGENCY_ROLE(), emergency));
    }
    
    function testConstructorZeroAddress() public {
        vm.expectRevert("BLXVault: Zero address");
        new BLXVault(address(0), address(staking));
    }
    
    // ==================== DEPOSIT TESTS ====================
    
    function testBasicDeposit() public {
        vm.startPrank(user1);
        vault.deposit(DEPOSIT_AMOUNT, vault.NO_LOCK(), false);
        vm.stopPrank();
        
        assertEq(vault.totalUserBalance(user1), DEPOSIT_AMOUNT);
        assertEq(vault.totalVaultBalance(), DEPOSIT_AMOUNT);
        assertEq(vault.getUserDepositCount(user1), 1);
        
        (uint256 amount, uint256 depositTime, uint256 lockUntil, bool autoStake, bool withdrawn) = 
            vault.userDeposits(user1, 0);
            
        assertEq(amount, DEPOSIT_AMOUNT);
        assertEq(depositTime, block.timestamp);
        assertEq(lockUntil, 0);
        assertFalse(autoStake);
        assertFalse(withdrawn);
    }
    
    function testDepositWithTimeLock() public {
        vm.startPrank(user1);
        vault.deposit(DEPOSIT_AMOUNT, vault.LOCK_30_DAYS(), false);
        vm.stopPrank();
        
        (, , uint256 lockUntil, , ) = vault.userDeposits(user1, 0);
        assertEq(lockUntil, block.timestamp + vault.LOCK_30_DAYS());
        
        assertTrue(vault.isDepositLocked(user1, 0));
    }
    
    function testDepositWithAutoStake() public {
        vm.startPrank(user1);
                vault.deposit(DEPOSIT_AMOUNT / 2, vault.LOCK_30_DAYS(), true);
        vm.stopPrank();
        
        (, , , bool autoStake, ) = vault.userDeposits(user1, 0);
        assertTrue(autoStake);
        assertEq(vault.totalAutoStaked(), DEPOSIT_AMOUNT);
    }
    
    function testDepositZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert("BLXVault: Amount must be > 0");
        vault.deposit(0, vault.NO_LOCK(), false);
    }
    
    function testDepositInvalidLockPeriod() public {
        vm.prank(user1);
        vm.expectRevert("BLXVault: Invalid lock period");
        vault.deposit(DEPOSIT_AMOUNT, 15 days, false);
    }
    
    function testDepositInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vault.deposit(20000e18, vault.NO_LOCK(), false);
    }
    
    // ==================== WITHDRAWAL TESTS ====================
    
    function testBasicWithdrawal() public {
        // Deposit first
        vm.startPrank(user1);
        vault.deposit(DEPOSIT_AMOUNT, vault.NO_LOCK(), false);
        
        uint256 balanceBefore = blx.balanceOf(user1);
        
        // Withdraw
        vault.withdraw(0);
        vm.stopPrank();
        
        uint256 expectedFee = (DEPOSIT_AMOUNT * vault.withdrawalFee()) / 10000;
        uint256 expectedNet = DEPOSIT_AMOUNT - expectedFee;
        
        assertEq(blx.balanceOf(user1), balanceBefore + expectedNet);
        assertEq(vault.totalUserBalance(user1), 0);
        assertEq(vault.totalVaultBalance(), 0);
        
        (, , , , bool withdrawn) = vault.userDeposits(user1, 0);
        assertTrue(withdrawn);
    }
    
    function testEarlyWithdrawal() public {
        // Deposit with lock
        vm.prank(user1);
        vault.deposit(DEPOSIT_AMOUNT, vault.LOCK_30_DAYS(), false);
        
        uint256 balanceBefore = blx.balanceOf(user1);
        
        // Try to withdraw before lock expires (should apply early withdrawal fee)
        vm.prank(user1);
        vault.withdraw(0);
        
        uint256 expectedFee = (DEPOSIT_AMOUNT * vault.earlyWithdrawalFee()) / 10000;
        uint256 expectedNet = DEPOSIT_AMOUNT - expectedFee;
        
        assertEq(blx.balanceOf(user1), balanceBefore + expectedNet);
    }
    
    function testWithdrawalAfterLockExpires() public {
        // Deposit with lock
        vm.prank(user1);
        vault.deposit(DEPOSIT_AMOUNT, vault.LOCK_7_DAYS(), false);
        
        // Fast forward past lock period
        vm.warp(block.timestamp + vault.LOCK_7_DAYS() + 1);
        
        uint256 balanceBefore = blx.balanceOf(user1);
        
        // Withdraw (should use normal withdrawal fee, not early withdrawal fee)
        vm.prank(user1);
        vault.withdraw(0);
        
        uint256 expectedFee = (DEPOSIT_AMOUNT * vault.withdrawalFee()) / 10000;
        uint256 expectedNet = DEPOSIT_AMOUNT - expectedFee;
        
        assertEq(blx.balanceOf(user1), balanceBefore + expectedNet);
    }
    
    function testWithdrawInvalidIndex() public {
        vm.prank(user1);
        vm.expectRevert("BLXVault: Invalid deposit index");
        vault.withdraw(0);
    }
    
    function testWithdrawAlreadyWithdrawn() public {
        // Deposit and withdraw
        vm.prank(user1);
        vault.deposit(DEPOSIT_AMOUNT, vault.NO_LOCK(), false);
        
        vm.prank(user1);
        vault.withdraw(0);
        
        // Try to withdraw again
        vm.prank(user1);
        vm.expectRevert("BLXVault: Deposit already withdrawn");
        vault.withdraw(0);
    }
    
    // ==================== AUTO-YIELD TESTS ====================
    
    function testToggleAutoStake() public {
        // Deposit without auto-stake
        vm.prank(user1);
        vault.deposit(DEPOSIT_AMOUNT, vault.NO_LOCK(), false);
        
        // Toggle auto-stake on
        vm.prank(user1);
        vault.toggleAutoStake(0);
        
        (, , , bool autoStake, ) = vault.userDeposits(user1, 0);
        assertTrue(autoStake);
        assertEq(vault.totalAutoStaked(), DEPOSIT_AMOUNT);
        
        // Toggle auto-stake off
        vm.prank(user1);
        vault.toggleAutoStake(0);
        
        (, , , autoStake, ) = vault.userDeposits(user1, 0);
        assertFalse(autoStake);
        assertEq(vault.totalAutoStaked(), 0);
    }
    
    // ==================== EMERGENCY TESTS ====================
    
    function testEmergencyWithdraw() public {
        // Deposit from emergency role holder
        vm.prank(emergency);
        blx.approve(address(vault), DEPOSIT_AMOUNT);
        
        vm.prank(emergency);
        vault.deposit(DEPOSIT_AMOUNT, vault.LOCK_90_DAYS(), false);
        
        uint256 balanceBefore = blx.balanceOf(emergency);
        
        // Emergency withdraw
        vm.prank(emergency);
        vault.emergencyWithdraw();
        
        assertEq(blx.balanceOf(emergency), balanceBefore + DEPOSIT_AMOUNT);
        assertEq(vault.totalUserBalance(emergency), 0);
        
        (, , , , bool withdrawn) = vault.userDeposits(emergency, 0);
        assertTrue(withdrawn);
    }
    
    function testEmergencyWithdrawNoBalance() public {
        vm.prank(emergency);
        vm.expectRevert("BLXVault: No balance to withdraw");
        vault.emergencyWithdraw();
    }
    
    function testEmergencyWithdrawUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert();
        vault.emergencyWithdraw();
    }
    
    // ==================== ADMIN TESTS ====================
    
    function testSetWithdrawalFee() public {
        uint256 newFee = 200; // 2%
        
        vm.prank(manager);
        vault.setWithdrawalFee(newFee);
        
        assertEq(vault.withdrawalFee(), newFee);
    }
    
    function testSetWithdrawalFeeTooHigh() public {
        vm.prank(manager);
        vm.expectRevert("BLXVault: Fee too high");
        vault.setWithdrawalFee(1500); // 15% > 10% max
    }
    
    function testSetWithdrawalFeeUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert();
        vault.setWithdrawalFee(200);
    }
    
    function testSetEarlyWithdrawalFee() public {
        uint256 newFee = 800; // 8%
        
        vm.prank(manager);
        vault.setEarlyWithdrawalFee(newFee);
        
        assertEq(vault.earlyWithdrawalFee(), newFee);
    }
    
    function testUpdateContracts() public {
        address newStaking = address(0x123);
        
        vm.prank(owner);
        vault.updateContracts(newStaking);
        
        assertEq(address(vault.stakingContract()), newStaking);
    }
    
    function testUpdateContractsUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert();
        vault.updateContracts(address(0x123));
    }
    
    function testPauseUnpause() public {
        // Test pause
        vm.prank(owner);
        vault.pause();
        assertTrue(vault.paused());
        
        // Deposits should fail when paused
        vm.prank(user1);
        vm.expectRevert("Pausable: paused");
        vault.deposit(DEPOSIT_AMOUNT, vault.NO_LOCK(), false);
        
        // Test unpause
        vm.prank(owner);
        vault.unpause();
        assertFalse(vault.paused());
        
        // Deposits should work again
        vm.prank(user1);
        vault.deposit(DEPOSIT_AMOUNT, vault.NO_LOCK(), false);
        
        assertEq(vault.getUserDepositCount(user1), 1);
    }
    
    function testRecoverToken() public {
        // Deploy another token
        MockERC20 otherToken = new MockERC20("Other", "OTHER", 18);
        otherToken.mint(address(vault), 1000e18);
        
        uint256 balanceBefore = otherToken.balanceOf(owner);
        
        // Recover the token
        vm.prank(owner);
        vault.recoverToken(address(otherToken), 1000e18);
        
        assertEq(otherToken.balanceOf(owner), balanceBefore + 1000e18);
    }
    
    function testRecoverBLXToken() public {
        vm.prank(owner);
        vm.expectRevert("BLXVault: Cannot recover BLX");
        vault.recoverToken(address(blx), 1000e18);
    }
    
    function testSetTreasury() public {
        address newTreasury = address(0x999);
        
        vm.prank(owner);
        vault.setTreasury(newTreasury);
        
        assertEq(vault.treasury(), newTreasury);
    }
    
    function testSetTreasuryZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("BLXVault: Zero address");
        vault.setTreasury(address(0));
    }
    
    function testSetTreasuryUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert();
        vault.setTreasury(address(0x999));
    }
    
    // ==================== VIEW FUNCTION TESTS ====================
    
    function testGetUserDeposits() public {
        // Make multiple deposits
        vm.startPrank(user1);
        vault.deposit(DEPOSIT_AMOUNT, vault.NO_LOCK(), false);
        vault.deposit(DEPOSIT_AMOUNT / 2, vault.LOCK_30_DAYS(), true);
        vm.stopPrank();
        
        BLXVault.Deposit[] memory deposits = vault.getUserDeposits(user1);
        assertEq(deposits.length, 2);
        assertEq(deposits[0].amount, DEPOSIT_AMOUNT);
        assertEq(deposits[1].amount, DEPOSIT_AMOUNT / 2);
        assertTrue(deposits[1].autoStake);
    }
    
    function testCalculateWithdrawalAmount() public {
        // Deposit with lock
        vm.prank(user1);
        vault.deposit(DEPOSIT_AMOUNT, vault.LOCK_30_DAYS(), false);
        
        (uint256 netAmount, uint256 fee) = vault.calculateWithdrawalAmount(user1, 0);
        
        uint256 expectedFee = (DEPOSIT_AMOUNT * vault.earlyWithdrawalFee()) / 10000;
        uint256 expectedNet = DEPOSIT_AMOUNT - expectedFee;
        
        assertEq(fee, expectedFee);
        assertEq(netAmount, expectedNet);
    }
    
    function testIsDepositLocked() public {
        // Deposit without lock
        vm.prank(user1);
        vault.deposit(DEPOSIT_AMOUNT, vault.NO_LOCK(), false);
        
        // Deposit with lock
        vm.prank(user1);
        vault.deposit(DEPOSIT_AMOUNT, vault.LOCK_30_DAYS(), false);
        
        assertFalse(vault.isDepositLocked(user1, 0));
        assertTrue(vault.isDepositLocked(user1, 1));
        
        // Fast forward past lock
        vm.warp(block.timestamp + vault.LOCK_30_DAYS() + 1);
        assertFalse(vault.isDepositLocked(user1, 1));
    }
    
    // ==================== FUZZ TESTS ====================
    
    function testFuzzDeposit(uint256 amount) public {
        amount = bound(amount, 1e18, 5000e18); // Reasonable bounds
        
        vm.assume(amount <= blx.balanceOf(user1));
        
        vm.prank(user1);
        vault.deposit(amount, vault.NO_LOCK(), false);
        
        assertEq(vault.totalUserBalance(user1), amount);
        assertEq(vault.totalVaultBalance(), amount);
    }
    
    function testFuzzWithdrawal(uint256 depositAmount, uint256 lockChoice) public {
        depositAmount = bound(depositAmount, 1e18, 5000e18);
        
        uint256[] memory validLocks = new uint256[](4);
        validLocks[0] = vault.NO_LOCK();
        validLocks[1] = vault.LOCK_7_DAYS();
        validLocks[2] = vault.LOCK_30_DAYS();
        validLocks[3] = vault.LOCK_90_DAYS();
        
        uint256 lockPeriod = validLocks[lockChoice % 4];
        
        vm.assume(depositAmount <= blx.balanceOf(user1));
        
        vm.prank(user1);
        vault.deposit(depositAmount, lockPeriod, false);
        
        uint256 balanceBefore = blx.balanceOf(user1);
        
        vm.prank(user1);
        vault.withdraw(0);
        
        // Should have received something back (minus fees)
        assertGt(blx.balanceOf(user1), balanceBefore);
        assertEq(vault.totalUserBalance(user1), 0);
    }
}
