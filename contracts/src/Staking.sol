// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title TieredStaking - Time-locked BLX Token Staking
 * @dev Stake BLX tokens for fixed periods to earn rewards based on lock duration
 */
contract TieredStaking is Ownable, ReentrancyGuard {
    IERC20 public stakingToken;
    IERC20 public rewardsToken;

    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lockDuration;
        uint256 apr; // in basis points (e.g. 500 = 5%)
        bool withdrawn;
    }

    mapping(address => StakeInfo[]) public stakes;

    // APR rates in basis points
    uint256 public constant APR_30D = 500;   // 5%
    uint256 public constant APR_90D = 1000;  // 10%
    uint256 public constant APR_365D = 2000; // 20%

    uint256 public totalRewards;

    // ==================== EVENTS ====================
    
    event Staked(address indexed user, uint256 amount, uint256 lockDuration, uint256 apr);
    event Withdrawn(address indexed user, uint256 amount, uint256 reward);
    event RewardsAdded(address indexed admin, uint256 amount);

    constructor(address _stakingToken, address _rewardsToken) {
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
    }

    // ==================== STAKING FUNCTIONS ====================

    /// @dev Stake tokens with chosen lock period for rewards
    function stake(uint256 amount, uint256 lockChoice) external nonReentrant {
        require(amount > 0, "Cannot stake 0");

        uint256 apr;
        if (lockChoice == 30 days) {
            apr = APR_30D;
        } else if (lockChoice == 90 days) {
            apr = APR_90D;
        } else if (lockChoice == 365 days) {
            apr = APR_365D;
        } else {
            revert("Invalid lock duration");
        }

        require(stakingToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        stakes[msg.sender].push(StakeInfo({
            amount: amount,
            startTime: block.timestamp,
            lockDuration: lockChoice,
            apr: apr,
            withdrawn: false
        }));

        emit Staked(msg.sender, amount, lockChoice, apr);
    }

    // ==================== ADMIN FUNCTIONS ====================

    /// @dev Add rewards to the contract pool (admin only)
    function addRewards(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        require(rewardsToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        totalRewards += amount;
        emit RewardsAdded(msg.sender, amount);
    }

    // ==================== VIEW FUNCTIONS ====================

    /// @dev Calculate pending rewards for a specific stake
    function pendingReward(address user, uint256 index) public view returns (uint256) {
        StakeInfo memory s = stakes[user][index];
        if (s.withdrawn) return 0;

        uint256 elapsed = block.timestamp - s.startTime;
        if (elapsed > s.lockDuration) {
            elapsed = s.lockDuration; // cap at lock duration
        }

        uint256 reward = s.amount * s.apr * elapsed / (365 days * 10000);

        // Cap reward by totalRewards available
        if (reward > totalRewards) {
            reward = totalRewards;
        }

        return reward;
    }

    // ==================== WITHDRAWAL FUNCTIONS ====================

    /// @dev Withdraw principal and rewards after lock period
    function withdraw(uint256 index) external nonReentrant {
        StakeInfo storage s = stakes[msg.sender][index];
        require(!s.withdrawn, "Already withdrawn");

        uint256 reward = 0;

        if (block.timestamp < s.startTime + s.lockDuration) {
            // Early withdraw → only return principal
            s.withdrawn = true;
            require(stakingToken.transfer(msg.sender, s.amount), "Transfer failed");
            emit Withdrawn(msg.sender, s.amount, 0);
        } else {
            // Full withdraw + rewards
            reward = pendingReward(msg.sender, index);
            require(reward <= totalRewards, "Not enough rewards");
            totalRewards -= reward;

            s.withdrawn = true;

            require(stakingToken.transfer(msg.sender, s.amount), "Transfer failed");
            require(rewardsToken.transfer(msg.sender, reward), "Reward transfer failed");

            emit Withdrawn(msg.sender, s.amount, reward);
        }
    }

    // ==================== EMERGENCY FUNCTIONS ====================

    /// @dev Emergency recovery of tokens (admin only)
    function recoverTokens(address token, uint256 amount) external onlyOwner {
        require(token != address(stakingToken), "Cannot recover staking token");
        IERC20(token).transfer(owner(), amount);
    }

    /// @dev Get total number of stakes for a user
    function stakesLength(address user) external view returns (uint256) {
        return stakes[user].length;
    }

    /// @dev Get all stake information for a user
    function getUserStakesInfo(address user) external view returns (StakeInfo[] memory){
        return stakes[user];
    }
}
