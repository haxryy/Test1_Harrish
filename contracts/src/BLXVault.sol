// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./Staking.sol";

/**
 * @title BLXVault - Time-locked Token Vault
 * @dev Secure vault with time-locking, automated staking, and fee management
 */
contract BLXVault is AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    IERC20 public immutable blxToken;
    TieredStaking public stakingContract;
    address public treasury; // Address to receive fees

    struct Deposit {
        uint256 amount;
        uint256 depositTime;
        uint256 lockUntil;
        bool autoStake;
        bool withdrawn;
    }

    mapping(address => Deposit[]) public userDeposits;
    mapping(address => uint256) public totalUserBalance;
    
    uint256 public totalVaultBalance;
    uint256 public totalAutoStaked;
    
    // Lock periods
    uint256 public constant NO_LOCK = 0;
    uint256 public constant LOCK_7_DAYS = 7 days;
    uint256 public constant LOCK_30_DAYS = 30 days;
    uint256 public constant LOCK_90_DAYS = 90 days;
    
    // Fee structure (in basis points)
    uint256 public withdrawalFee = 100; // 1%
    uint256 public earlyWithdrawalFee = 500; // 5%
    uint256 public maxWithdrawalFee = 1000; // 10% max
    
    // ==================== EVENTS ====================
    
    event Deposited(address indexed user, uint256 amount, uint256 lockUntil, bool autoStake);
    event Withdrawn(address indexed user, uint256 depositIndex, uint256 amount, uint256 fee);
    event AutoStakeToggled(address indexed user, uint256 depositIndex, bool enabled);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event FeeUpdated(string feeType, uint256 oldFee, uint256 newFee);
    event ContractsUpdated(address staking);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    
    // ==================== MODIFIERS ====================
    
    modifier validDepositIndex(address user, uint256 index) {
        require(index < userDeposits[user].length, "BLXVault: Invalid deposit index");
        require(!userDeposits[user][index].withdrawn, "BLXVault: Deposit already withdrawn");
        _;
    }
    
    // ==================== CONSTRUCTOR ====================
    
    constructor(
        address _blxToken,
        address _stakingContract
    ) {
        require(_blxToken != address(0), "BLXVault: Zero address");
        
        blxToken = IERC20(_blxToken);
        stakingContract = TieredStaking(_stakingContract);
        treasury = msg.sender; // Initially set deployer as treasury
        
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, msg.sender);
        _setupRole(EMERGENCY_ROLE, msg.sender);
    }
    
    // ==================== DEPOSIT FUNCTIONS ====================
    
    /// @dev Deposit BLX tokens with optional time-locking and auto-staking
    function deposit(
        uint256 amount,
        uint256 lockPeriod,
        bool autoStake
    ) external whenNotPaused {
        require(amount > 0, "BLXVault: Amount must be > 0");
        require(
            lockPeriod == NO_LOCK || 
            lockPeriod == LOCK_7_DAYS || 
            lockPeriod == LOCK_30_DAYS || 
            lockPeriod == LOCK_90_DAYS,
            "BLXVault: Invalid lock period"
        );
        
        // Transfer BLX tokens to vault
        require(blxToken.transferFrom(msg.sender, address(this), amount), "BLXVault: Transfer failed");
        
        uint256 lockUntil = lockPeriod == NO_LOCK ? 0 : block.timestamp + lockPeriod;
        
        // Create deposit record
        userDeposits[msg.sender].push(Deposit({
            amount: amount,
            depositTime: block.timestamp,
            lockUntil: lockUntil,
            autoStake: autoStake,
            withdrawn: false
        }));
        
        totalUserBalance[msg.sender] += amount;
        totalVaultBalance += amount;
        
        // Handle automated staking
        if (autoStake && address(stakingContract) != address(0)) {
            _autoStake(amount, lockPeriod);
        }
        
        emit Deposited(msg.sender, amount, lockUntil, autoStake);
    }
    
    // ==================== WITHDRAWAL FUNCTIONS ====================
    
    /// @dev Withdraw deposit with applicable fees
    function withdraw(uint256 depositIndex) external nonReentrant validDepositIndex(msg.sender, depositIndex) {
        Deposit storage userDeposit = userDeposits[msg.sender][depositIndex];
        
        uint256 amount = userDeposit.amount;
        uint256 fee = _calculateWithdrawalFee(userDeposit);
        uint256 netAmount = amount - fee;
        
        // Mark as withdrawn
        userDeposit.withdrawn = true;
        totalUserBalance[msg.sender] -= amount;
        totalVaultBalance -= amount;
        
        // Handle automated positions
        if (userDeposit.autoStake) {
            totalAutoStaked -= amount;
        }
        
        // Transfer tokens (net of fees)
        require(blxToken.transfer(msg.sender, netAmount), "BLXVault: Transfer failed");
        
        // Transfer fee to treasury (admin) - for simplicity, send to contract owner
        if (fee > 0) {
            require(blxToken.transfer(treasury, fee), "BLXVault: Fee transfer failed");
        }
        
        emit Withdrawn(msg.sender, depositIndex, netAmount, fee);
    }
    
    /// @dev Emergency withdrawal for privileged users
    function emergencyWithdraw() external nonReentrant onlyRole(EMERGENCY_ROLE) {
        uint256 userBalance = totalUserBalance[msg.sender];
        require(userBalance > 0, "BLXVault: No balance to withdraw");
        
        // Mark all user deposits as withdrawn
        for (uint i = 0; i < userDeposits[msg.sender].length; i++) {
            if (!userDeposits[msg.sender][i].withdrawn) {
                userDeposits[msg.sender][i].withdrawn = true;
            }
        }
        
        totalUserBalance[msg.sender] = 0;
        totalVaultBalance -= userBalance;
        
        require(blxToken.transfer(msg.sender, userBalance), "BLXVault: Emergency transfer failed");
        
        emit EmergencyWithdraw(msg.sender, userBalance);
    }
    
    // ==================== AUTO-STAKING FUNCTIONS ====================
    
    /// @dev Toggle auto-staking for a specific deposit
    function toggleAutoStake(uint256 depositIndex) external validDepositIndex(msg.sender, depositIndex) {
        Deposit storage userDeposit = userDeposits[msg.sender][depositIndex];
        
        userDeposit.autoStake = !userDeposit.autoStake;
        
        if (userDeposit.autoStake) {
            totalAutoStaked += userDeposit.amount;
            _autoStake(userDeposit.amount, userDeposit.lockUntil > 0 ? userDeposit.lockUntil - block.timestamp : LOCK_30_DAYS);
        } else {
            totalAutoStaked -= userDeposit.amount;
        }
        
        emit AutoStakeToggled(msg.sender, depositIndex, userDeposit.autoStake);
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    /// @dev Get all deposits for a user
    function getUserDeposits(address user) external view returns (Deposit[] memory) {
        return userDeposits[user];
    }
    
    /// @dev Get total number of deposits for a user
    function getUserDepositCount(address user) external view returns (uint256) {
        return userDeposits[user].length;
    }
    
    /// @dev Calculate net withdrawal amount and fees
    function calculateWithdrawalAmount(address user, uint256 depositIndex) 
        external 
        view 
        validDepositIndex(user, depositIndex) 
        returns (uint256 netAmount, uint256 fee) 
    {
        Deposit memory userDeposit = userDeposits[user][depositIndex];
        fee = _calculateWithdrawalFee(userDeposit);
        netAmount = userDeposit.amount - fee;
    }
    
    /// @dev Check if a deposit is currently time-locked
    function isDepositLocked(address user, uint256 depositIndex) 
        external 
        view 
        validDepositIndex(user, depositIndex) 
        returns (bool) 
    {
        return block.timestamp < userDeposits[user][depositIndex].lockUntil;
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    /// @dev Set withdrawal fee (manager only)
    function setWithdrawalFee(uint256 _fee) external onlyRole(MANAGER_ROLE) {
        require(_fee <= maxWithdrawalFee, "BLXVault: Fee too high");
        uint256 oldFee = withdrawalFee;
        withdrawalFee = _fee;
        emit FeeUpdated("withdrawal", oldFee, _fee);
    }
    
    /// @dev Set early withdrawal penalty fee (manager only)
    function setEarlyWithdrawalFee(uint256 _fee) external onlyRole(MANAGER_ROLE) {
        require(_fee <= maxWithdrawalFee, "BLXVault: Fee too high");
        uint256 oldFee = earlyWithdrawalFee;
        earlyWithdrawalFee = _fee;
        emit FeeUpdated("earlyWithdrawal", oldFee, _fee);
    }
    
    /// @dev Update staking contract address (admin only)
    function updateContracts(address _stakingContract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        stakingContract = TieredStaking(_stakingContract);
        emit ContractsUpdated(_stakingContract);
    }
    
    /// @dev Set treasury address for fee collection (admin only)
    function setTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasury != address(0), "BLXVault: Zero address");
        address oldTreasury = treasury;
        treasury = _treasury;
        emit TreasuryUpdated(oldTreasury, _treasury);
    }
    
    /// @dev Pause contract operations (admin only)
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /// @dev Unpause contract operations (admin only)
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    /// @dev Emergency token recovery (admin only)
    function recoverToken(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(blxToken), "BLXVault: Cannot recover BLX");
        IERC20(token).transfer(msg.sender, amount);
    }
    
    // ==================== INTERNAL FUNCTIONS ====================
    
    function _calculateWithdrawalFee(Deposit memory userDeposit) internal view returns (uint256) {
        uint256 fee = withdrawalFee;
        
        // Apply early withdrawal penalty if still locked
        if (block.timestamp < userDeposit.lockUntil) {
            fee = earlyWithdrawalFee;
        }
        
        return (userDeposit.amount * fee) / 10000;
    }
    
    function _autoStake(uint256 amount, uint256 lockPeriod) internal {
        if (address(stakingContract) == address(0)) return;
        
        // Approve staking contract
        blxToken.approve(address(stakingContract), amount);
        
        // Determine appropriate lock period for staking
        uint256 stakeLockPeriod = LOCK_30_DAYS;
        if (lockPeriod >= LOCK_90_DAYS) {
            stakeLockPeriod = LOCK_90_DAYS;
        }
        
        // Stake tokens
        stakingContract.stake(amount, stakeLockPeriod);
    }
}
