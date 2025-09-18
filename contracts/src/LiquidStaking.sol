// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./StakedBlx.sol";

/**
 * @title LiquidStaking - Liquid Staking for BLX Tokens
 * @dev Stake BLX tokens and receive liquid stBLX tokens representing staked position
 */
contract LiquidStaking is Ownable, ReentrancyGuard {
    IERC20 public blxToken;
    StakedBLX public stToken;
    uint256 public totalStaked;
    uint256 public totalRewards;

    // APR rates in basis points
    uint256 public constant APR_30D = 500;   // 5%
    uint256 public constant APR_90D = 1000;  // 10%
    uint256 public constant APR_365D = 2000; // 20%

    struct StakeInfo {
        uint256 amount;       // BLX staked
        uint256 startTime;
        uint256 lockDuration; // chosen lock period
        uint256 apr;          // basis points
    }

    mapping(address => StakeInfo[]) public stakes;

    // ==================== EVENTS ====================
    
    event Staked(address indexed user, uint256 amount, uint256 stAmount, uint256 lockDuration, uint256 apr);
    event Redeemed(address indexed user, uint256 blxAmount, uint256 reward);

    constructor(address _blxToken, address _stToken) {
        blxToken = IERC20(_blxToken);
        stToken = StakedBLX(_stToken);
    }

    // ==================== STAKING FUNCTIONS ====================

    /// @dev Stake BLX tokens and mint liquid stBLX tokens
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

        // Transfer BLX to contract
        require(blxToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // Calculate stBLX to mint based on current exchange rate
        uint256 stAmount = totalStaked == 0 ? amount : (amount * stToken.totalSupply()) / totalStaked;

        stToken.mint(msg.sender, stAmount);

        totalStaked += amount;

        stakes[msg.sender].push(StakeInfo({
            amount: amount,
            startTime: block.timestamp,
            lockDuration: lockChoice,
            apr: apr
        }));

        emit Staked(msg.sender, amount, stAmount, lockChoice, apr);
    }

    // ==================== VIEW FUNCTIONS ====================

    /// @dev Calculate pending reward for a specific stake
    function pendingReward(address user, uint256 index) public view returns (uint256) {
        StakeInfo memory s = stakes[user][index];
        uint256 elapsed = block.timestamp - s.startTime;
        if (elapsed > s.lockDuration) elapsed = s.lockDuration;

        uint256 reward = s.amount * s.apr * elapsed / (365 days * 10000);
        if (reward > totalRewards) reward = totalRewards;
        return reward;
    }

    // ==================== REDEMPTION FUNCTIONS ====================

    /// @dev Redeem stBLX tokens for BLX plus earned rewards
    function redeem(uint256 index) external nonReentrant {
        StakeInfo storage s = stakes[msg.sender][index];
        uint256 reward = pendingReward(msg.sender, index);
        uint256 totalReturn = s.amount + reward;

        

        // Burn corresponding stBLX
        uint256 stAmount = (s.amount * stToken.totalSupply()) / totalStaked;

        require(stToken.balanceOf(msg.sender) >= stAmount, "Not enough stBLX to redeem");
        stToken.burn(msg.sender, stAmount);

        totalStaked -= s.amount;
        totalRewards -= reward;

        // Transfer BLX + reward
        require(blxToken.transfer(msg.sender, totalReturn), "Transfer failed");

        // Mark stake as withdrawn
        delete stakes[msg.sender][index];

        emit Redeemed(msg.sender, s.amount, reward);
    }

    // ==================== ADMIN FUNCTIONS ====================

    /// @dev Add rewards to the contract pool (admin only)
    function addRewards(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount > 0");
        require(blxToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        totalRewards += amount;
    }
}
