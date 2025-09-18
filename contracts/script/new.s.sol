// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import "../src/BLX.sol";
import "../src/BLXPool.sol";
import "../src/Staking.sol";
import "../src/LiquidStaking.sol";
import "../src/StakedBlx.sol";
import "../src/BLXVault.sol";
import "../src/MockErc20.sol";

contract DeployScript is Script {
    // Deployed contracts
    BLXToken public blxToken;
    BLXPool public blxUsdcPool;
    TieredStaking public stakingContract;
    LiquidStaking public liquidStaking;
    StakedBLX public stakedBlx;
    BLXVault public vault;
    MockERC20 public usdcToken;
    MockERC20 public rewardToken;
    address public deployer;

    // Configuration
    string constant BLX_NAME = "BLUME Token";
    string constant BLX_SYMBOL = "BLX";
    uint256 constant BLX_INITIAL_SUPPLY = 1_000_000 * 1e18;
    uint256 constant USDC_INITIAL_SUPPLY = 1_000_000 * 1e18;
    uint256 constant REWARD_INITIAL_SUPPLY = 100_000 * 1e18;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer_ = vm.addr(deployerPrivateKey);
        deployer = deployer_;
        
        console.log("Deploying contracts with deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        deployBLXToken();
        deployMockTokens();
        deployPool();
        deployStakedBLX();
        deployStakingContract();
        deployLiquidStaking();
        deployVault();
        setupInitialLiquidity();
        setupStaking();

        vm.stopBroadcast();

        logDeployedAddresses();
    }

    function logDeployedAddresses() public view {
        console.log("=== Deployment Summary ===");
        console.log("BLX Token:", address(blxToken));
        console.log("USDC Token:", address(usdcToken));
        console.log("BLX-USDC Pool:", address(blxUsdcPool));
        console.log("Staked BLX:", address(stakedBlx));
        console.log("Tiered Staking:", address(stakingContract));
        console.log("Liquid Staking:", address(liquidStaking));
        console.log("BLX Vault:", address(vault));
        console.log("========================");
    }

    // Deploy BLX token
    function deployBLXToken() public returns (address) {
        blxToken = new BLXToken(BLX_NAME, BLX_SYMBOL, BLX_INITIAL_SUPPLY);
        console.log("BLX Token deployed at:", address(blxToken));
        return address(blxToken);
    }

    // Deploy mock tokens
    function deployMockTokens() public returns (address, address) {
        usdcToken = new MockERC20("USD Coin", "USDC", USDC_INITIAL_SUPPLY);
        console.log("Mock USDC deployed at:", address(usdcToken));

        rewardToken = new MockERC20("Reward Token", "REWARD", REWARD_INITIAL_SUPPLY);
        console.log("Mock Reward Token deployed at:", address(rewardToken));

        return (address(usdcToken), address(rewardToken));
    }

    // Deploy BLX-USDC pool
    function deployPool() public returns (address) {
        require(address(blxToken) != address(0), "BLX Token not deployed");
        require(address(usdcToken) != address(0), "USDC not deployed");
        
        address token0 = address(blxToken) < address(usdcToken) ? address(blxToken) : address(usdcToken);
        address token1 = address(blxToken) < address(usdcToken) ? address(usdcToken) : address(blxToken);
        
        blxUsdcPool = new BLXPool(token0, token1, "BLX-USDC LP", "BLX-USDC");
        console.log("BLX-USDC Pool deployed at:", address(blxUsdcPool));
        
        return address(blxUsdcPool);
    }

    // Deploy StakedBLX token
    function deployStakedBLX() public returns (address) {
        stakedBlx = new StakedBLX();
        console.log("Staked BLX deployed at:", address(stakedBlx));
        return address(stakedBlx);
    }

    // Deploy tiered staking contract
    function deployStakingContract() public returns (address) {
        require(address(blxToken) != address(0), "BLX Token not deployed");
        require(address(rewardToken) != address(0), "Reward Token not deployed");
        
        stakingContract = new TieredStaking(address(blxToken), address(rewardToken));
        console.log("Tiered Staking Contract deployed at:", address(stakingContract));
        return address(stakingContract);
    }

    // Deploy liquid staking contract
    function deployLiquidStaking() public returns (address) {
        require(address(blxToken) != address(0), "BLX Token not deployed");
        require(address(stakedBlx) != address(0), "Staked BLX not deployed");
        
        liquidStaking = new LiquidStaking(address(blxToken), address(stakedBlx));
        
        // Transfer ownership of StakedBLX to LiquidStaking contract
        stakedBlx.transferOwnership(address(liquidStaking));
        
        console.log("Liquid Staking Contract deployed at:", address(liquidStaking));
        return address(liquidStaking);
    }

    // Deploy vault contract
    function deployVault() public returns (address) {
        require(address(blxToken) != address(0), "BLX Token not deployed");
        require(address(stakingContract) != address(0), "Staking contract not deployed");
        require(address(stakingContract) != address(0), "Staking contract not deployed");
        
        vault = new BLXVault(address(blxToken), address(stakingContract));
        console.log("BLX Vault deployed at:", address(vault));
        return address(vault);
    }

    // Setup initial liquidity for BLX-USDC pool
    function setupInitialLiquidity() public {
        require(address(blxUsdcPool) != address(0), "BLX-USDC Pool not deployed");
        
        blxToken.approve(address(blxUsdcPool), type(uint256).max);
        usdcToken.approve(address(blxUsdcPool), type(uint256).max);
        
        uint256 blxAmount = 1000 * 10**18;
        uint256 usdcAmount = 1000 * 10**18;
        
        address poolToken0 = address(blxUsdcPool.token0());
        
        uint256 amount0Desired;
        uint256 amount1Desired;
        
        if (poolToken0 == address(blxToken)) {
            amount0Desired = blxAmount;
            amount1Desired = usdcAmount;
        } else {
            amount0Desired = usdcAmount;
            amount1Desired = blxAmount;
        }
        
        blxUsdcPool.addLiquidity(amount0Desired, amount1Desired, 0, 0, deployer);
        console.log("Added liquidity to BLX-USDC pool");
    }

    // Setup staking rewards
    function setupStaking() public {
        require(address(stakingContract) != address(0), "Staking contract not deployed");
        require(address(liquidStaking) != address(0), "Liquid staking not deployed");
        require(address(rewardToken) != address(0), "Reward token not deployed");
        require(address(blxToken) != address(0), "BLX token not deployed");
        
        uint256 stakingRewards = 100 * 1e18;
        rewardToken.approve(address(stakingContract), stakingRewards);
        
        uint256 liquidRewards = 5_000 * 1e18;
        blxToken.approve(address(liquidStaking), liquidRewards);
        
        stakingContract.addRewards(stakingRewards);
        console.log("Added rewards to staking contract:", stakingRewards);
        
        liquidStaking.addRewards(liquidRewards);
        console.log("Added rewards to liquid staking:", liquidRewards);
    }

    // Individual deployment functions
    function deployBLXOnly() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        deployBLXToken();
        vm.stopBroadcast();
    }

    function deployStakingOnly() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        address blxAddress = vm.envAddress("BLX_TOKEN_ADDRESS");
        address rewardAddress = vm.envAddress("REWARD_TOKEN_ADDRESS");
        
        stakingContract = new TieredStaking(blxAddress, rewardAddress);
        console.log("Staking deployed at:", address(stakingContract));
        
        vm.stopBroadcast();
    }
}
