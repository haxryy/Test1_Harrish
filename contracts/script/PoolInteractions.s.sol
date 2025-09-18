// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/BLX.sol";
import "../src/BLXPool.sol";

// Mock ERC20 for testing
contract MockERC20 is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Mock WETH for testing
contract MockWETH is ERC20 {
    constructor() ERC20("Wrapped Ether", "WETH") {}

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
    }

    receive() external payable {}
}

//  address public constant BLX_TOKEN_ADDRESS = address(0x09635F643e140090A9A8Dcd712eD6285858ceBef); // Set after deployment
//     address public constant USDC_TOKEN_ADDRESS = address(0xc5a5C42992dECbae36851359345FE25997F5C42d); // Set after deployment
//     address payable public constant WETH_ADDRESS = payable(address(0xE6E340D132b5f46d1e472DebcD681B2aBc16e57E)); // Set after deployment
//     address public constant BLX_USDC_POOL_ADDRESS = address(0xc3e53F4d16Ae77Db1c982e75a937B9f60FE63690); // Set after deployment
//     address public constant BLX_WETH_POOL_ADDRESS = address(0x84eA74d481Ee0A5332c457a4d796187F6Ba67fEB); 

contract PoolInteractionsScript is Script {
    // You'll need to set these addresses after deployment
    // Or read them from environment variables
    address public constant BLX_TOKEN_ADDRESS = address(0); // Set after deployment
    address public constant USDC_TOKEN_ADDRESS = address(0); // Set after deployment
    address payable public constant WETH_ADDRESS = payable(address(0)); // Set after deployment
    address public constant BLX_USDC_POOL_ADDRESS = address(0); // Set after deployment
    address public constant BLX_WETH_POOL_ADDRESS = address(0); // Set after deployment

    BLXToken public blxToken;
    MockERC20 public usdcToken;
    MockWETH public weth;
    BLXPool public blxUsdcPool;
    BLXPool public blxWethPool;
    address public user;

    function setUp() public {
        console.log("\n=== Contract Setup ===");
        
        // Initialize contracts - you can either:
        // 1. Use hardcoded addresses from deployment
        // 2. Read from environment variables
        // 3. Deploy new instances for testing

        if (BLX_TOKEN_ADDRESS != address(0)) {
            console.log("Using existing deployed contracts:");
            console.log("- BLX Token:", BLX_TOKEN_ADDRESS);
            console.log("- USDC Token:", USDC_TOKEN_ADDRESS);
            console.log("- WETH:", WETH_ADDRESS);
            console.log("- BLX-USDC Pool:", BLX_USDC_POOL_ADDRESS);
            console.log("- BLX-WETH Pool:", BLX_WETH_POOL_ADDRESS);
            
            // Use existing deployment
            blxToken = BLXToken(BLX_TOKEN_ADDRESS);
            usdcToken = MockERC20(USDC_TOKEN_ADDRESS);
            weth = MockWETH(WETH_ADDRESS);
            blxUsdcPool = BLXPool(BLX_USDC_POOL_ADDRESS);
            blxWethPool = BLXPool(BLX_WETH_POOL_ADDRESS);
            
            // Verify contracts are working
            
        } else {
            console.log("No hardcoded addresses found, deploying new contracts...");
            // Deploy new instances for testing
            deployTestTokensAndPools();
        }
    }

    function deployTestTokensAndPools() internal {
        console.log("Deploying test tokens and pools...");
        
        // Deploy tokens
        blxToken = new BLXToken("BLUME Token", "BLX", 1_000_000 * 1e18);
        usdcToken = new MockERC20("USD Coin", "USDC", 1_000_000 * 1e18);
        weth = new MockWETH();
        
        console.log("BLX Token deployed at:", address(blxToken));
        console.log("USDC Token deployed at:", address(usdcToken));
        console.log("WETH deployed at:", address(weth));
        
        // Deploy pools
        address token0_usdc = address(blxToken) < address(usdcToken) ? address(blxToken) : address(usdcToken);
        address token1_usdc = address(blxToken) < address(usdcToken) ? address(usdcToken) : address(blxToken);
        
        blxUsdcPool = new BLXPool(
            token0_usdc,
            token1_usdc,
            "BLX-USDC LP",
            "BLX-USDC"
        );
        
        address token0_weth = address(blxToken) < address(weth) ? address(blxToken) : address(weth);
        address token1_weth = address(blxToken) < address(weth) ? address(weth) : address(blxToken);
        
        blxWethPool = new BLXPool(
            token0_weth,
            token1_weth,
            "BLX-WETH LP",
            "BLX-WETH"
        );
        
        console.log("BLX-USDC Pool deployed at:", address(blxUsdcPool));
        console.log("BLX-WETH Pool deployed at:", address(blxWethPool));
        
        // Log deployment summary
        logDeploymentSummary();
    }

    // ==================== MAIN INTERACTION FUNCTIONS ====================

    function run() external {
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY");
        user = vm.addr(userPrivateKey);
        
        console.log("Running pool interactions with user:", user);
        console.log("User balance:", user.balance);

        vm.startBroadcast(userPrivateKey);

        setUp();
        
        // Perform interactions
        addLiquidityToUSDCPool();
        addLiquidityToWETHPool();
        // performSwaps();
         removeLiquidityExample();

        vm.stopBroadcast();
    }

    // ==================== ADD LIQUIDITY FUNCTIONS ====================

    function addLiquidityToUSDCPool() public {
        console.log("\n=== Adding Liquidity to BLX-USDC Pool ===");
        
        uint256 blxAmount = 500 * 1e18;  // 500 BLX (18 decimals)
        uint256 usdcAmount = 500 * 1e18;   // 500 USDC (6 decimals)
        
        // Approve pool to spend tokens
        blxToken.approve(address(blxUsdcPool), blxAmount);
        usdcToken.approve(address(blxUsdcPool), usdcAmount);
        
        // Check token ordering
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
        
        // Add liquidity
        (uint256 amount0, uint256 amount1, uint256 liquidity) = blxUsdcPool.addLiquidity(
            amount0Desired,
            amount1Desired,
            0, // min amount0
            0, // min amount1
            user
        );
        
        console.log("Added liquidity to BLX-USDC pool:");
        console.log("- Amount0:", amount0);
        console.log("- Amount1:", amount1);
        console.log("- LP tokens received:", liquidity);
        console.log("- User LP balance:", blxUsdcPool.balanceOf(user));
    }

    function addLiquidityToWETHPool() public {
        console.log("\n=== Adding Liquidity to BLX-WETH Pool ===");
        
        uint256 blxAmount = 500 * 1e18;  // 500 BLX
        uint256 wethAmount = 0.5 * 1e18; // 0.5 WETH
        
        // Wrap ETH to WETH
        weth.deposit{value: wethAmount}();
        
        // Approve pool to spend tokens
        blxToken.approve(address(blxWethPool), blxAmount);
        weth.approve(address(blxWethPool), wethAmount);
        
        // Check token ordering
        address poolToken0 = address(blxWethPool.token0());
        uint256 amount0Desired;
        uint256 amount1Desired;
        
        if (poolToken0 == address(blxToken)) {
            amount0Desired = blxAmount;
            amount1Desired = wethAmount;
        } else {
            amount0Desired = wethAmount;
            amount1Desired = blxAmount;
        }
        
        // Add liquidity
        (uint256 amount0, uint256 amount1, uint256 liquidity) = blxWethPool.addLiquidity(
            amount0Desired,
            amount1Desired,
            0, // min amount0
            0, // min amount1
            user
        );
        
        console.log("Added liquidity to BLX-WETH pool:");
        console.log("- Amount0:", amount0);
        console.log("- Amount1:", amount1);
        console.log("- LP tokens received:", liquidity);
        console.log("- User LP balance:", blxWethPool.balanceOf(user));
    }

    // ==================== SWAP FUNCTIONS ====================

    function performSwaps() public {
        console.log("\n=== Performing Swaps ===");
        
        swapBLXForUSDC();
        swapUSDCForBLX();
        swapBLXForWETH();
        swapWETHForBLX();
    }

    function swapBLXForUSDC() public {
        console.log("\n--- Swapping BLX for USDC ---");
        
        uint256 blxAmountIn = 100 * 1e18; // 100 BLX
        
        // Check if user has enough BLX
        uint256 currentBLXBalance = blxToken.balanceOf(user);
        console.log("Current BLX balance:", currentBLXBalance);
        require(currentBLXBalance >= blxAmountIn, "Insufficient BLX balance for swap");
        
        // Get expected output
        (uint112 reserve0, uint112 reserve1,) = blxUsdcPool.getReserves();
        address token0 = address(blxUsdcPool.token0());
        
        uint256 expectedUSDCOut;
        bool token0ToToken1;
        
        if (token0 == address(blxToken)) {
            // BLX is token0, USDC is token1
            expectedUSDCOut = blxUsdcPool.getAmountOut(blxAmountIn, reserve0, reserve1);
            token0ToToken1 = true;
        } else {
            // USDC is token0, BLX is token1
            expectedUSDCOut = blxUsdcPool.getAmountOut(blxAmountIn, reserve1, reserve0);
            token0ToToken1 = false;
        }
        
        console.log("Expected USDC output:", expectedUSDCOut);
        
        // Approve and swap
        blxToken.approve(address(blxUsdcPool), blxAmountIn);
        
        uint256 usdcBefore = usdcToken.balanceOf(user);
        uint256 actualUSDCOut = blxUsdcPool.swapExactTokensForTokens(
            blxAmountIn,
            expectedUSDCOut * 95 / 100, // 5% slippage tolerance
            token0ToToken1,
            user
        );
        uint256 usdcAfter = usdcToken.balanceOf(user);
        
        console.log("Swapped BLX for USDC:");
        console.log("- BLX amount in:", blxAmountIn);
        console.log("- USDC amount out:", actualUSDCOut);
        console.log("USDC balance change:", usdcAfter - usdcBefore);
    }

    function swapUSDCForBLX() public {
        console.log("\n--- Swapping USDC for BLX ---");
        
        uint256 usdcAmountIn = 50 * 1e18; // 50 USDC (6 decimals)
        
        // Check if user has enough USDC
        uint256 currentUSDCBalance = usdcToken.balanceOf(user);
        console.log("Current USDC balance:", currentUSDCBalance);
        require(currentUSDCBalance >= usdcAmountIn, "Insufficient USDC balance for swap");
        
        // Get expected output
        (uint112 reserve0, uint112 reserve1,) = blxUsdcPool.getReserves();
        address token0 = address(blxUsdcPool.token0());
        
        uint256 expectedBLXOut;
        bool token0ToToken1;
        
        if (token0 == address(usdcToken)) {
            // USDC is token0, BLX is token1
            expectedBLXOut = blxUsdcPool.getAmountOut(usdcAmountIn, reserve0, reserve1);
            token0ToToken1 = true;
        } else {
            // BLX is token0, USDC is token1
            expectedBLXOut = blxUsdcPool.getAmountOut(usdcAmountIn, reserve1, reserve0);
            token0ToToken1 = false;
        }
        
        console.log("Expected BLX output:", expectedBLXOut);
        
        // Approve and swap
        usdcToken.approve(address(blxUsdcPool), usdcAmountIn);
        
        uint256 blxBefore = blxToken.balanceOf(user);
        uint256 actualBLXOut = blxUsdcPool.swapExactTokensForTokens(
            usdcAmountIn,
            expectedBLXOut * 95 / 100, // 5% slippage tolerance
            token0ToToken1,
            user
        );
        uint256 blxAfter = blxToken.balanceOf(user);
        
        console.log("Swapped USDC for BLX:");
        console.log("- USDC amount in:", usdcAmountIn);
        console.log("- BLX amount out:", actualBLXOut);
        console.log("BLX balance change:", blxAfter - blxBefore);
    }

    function swapBLXForWETH() public {
        console.log("\n--- Swapping BLX for WETH ---");
        
        uint256 blxAmountIn = 100 * 1e18; // 100 BLX
        
        // Check if user has enough BLX
        uint256 currentBLXBalance = blxToken.balanceOf(user);
        console.log("Current BLX balance:", currentBLXBalance);
        require(currentBLXBalance >= blxAmountIn, "Insufficient BLX balance for swap");
        
        // Get expected output
        (uint112 reserve0, uint112 reserve1,) = blxWethPool.getReserves();
        address token0 = address(blxWethPool.token0());
        
        uint256 expectedWETHOut;
        bool token0ToToken1;
        
        if (token0 == address(blxToken)) {
            // BLX is token0, WETH is token1
            expectedWETHOut = blxWethPool.getAmountOut(blxAmountIn, reserve0, reserve1);
            token0ToToken1 = true;
        } else {
            // WETH is token0, BLX is token1
            expectedWETHOut = blxWethPool.getAmountOut(blxAmountIn, reserve1, reserve0);
            token0ToToken1 = false;
        }
        
        console.log("Expected WETH output:", expectedWETHOut);
        
        // Approve and swap
        blxToken.approve(address(blxWethPool), blxAmountIn);
        
        uint256 wethBefore = weth.balanceOf(user);
        uint256 actualWETHOut = blxWethPool.swapExactTokensForTokens(
            blxAmountIn,
            expectedWETHOut * 95 / 100, // 5% slippage tolerance
            token0ToToken1,
            user
        );
        uint256 wethAfter = weth.balanceOf(user);
        
        console.log("Swapped BLX for WETH:");
        console.log("- BLX amount in:", blxAmountIn);
        console.log("- WETH amount out:", actualWETHOut);
        console.log("WETH balance change:", wethAfter - wethBefore);
    }

    function swapWETHForBLX() public {
        console.log("\n--- Swapping WETH for BLX ---");
        
        uint256 wethAmountIn = 0.1 * 1e18; // 0.1 WETH
        
        // Check if user has enough WETH, if not, deposit some ETH
        uint256 currentWETHBalance = weth.balanceOf(user);
        console.log("Current WETH balance:", currentWETHBalance);
        
        if (currentWETHBalance < wethAmountIn) {
            uint256 ethToDeposit = wethAmountIn - currentWETHBalance;
            console.log("Need to deposit ETH for WETH. ETH amount:", ethToDeposit);
            require(user.balance >= ethToDeposit, "Insufficient ETH balance");
            weth.deposit{value: ethToDeposit}();
            console.log("Deposited ETH to get WETH");
        }
        
        // Get expected output
        (uint112 reserve0, uint112 reserve1,) = blxWethPool.getReserves();
        address token0 = address(blxWethPool.token0());
        
        uint256 expectedBLXOut;
        bool token0ToToken1;
        
        if (token0 == address(weth)) {
            // WETH is token0, BLX is token1
            expectedBLXOut = blxWethPool.getAmountOut(wethAmountIn, reserve0, reserve1);
            token0ToToken1 = true;
        } else {
            // BLX is token0, WETH is token1
            expectedBLXOut = blxWethPool.getAmountOut(wethAmountIn, reserve1, reserve0);
            token0ToToken1 = false;
        }
        
        console.log("Expected BLX output:", expectedBLXOut);
        
        // Approve and swap
        weth.approve(address(blxWethPool), wethAmountIn);
        
        uint256 blxBefore = blxToken.balanceOf(user);
        uint256 actualBLXOut = blxWethPool.swapExactTokensForTokens(
            wethAmountIn,
            expectedBLXOut * 95 / 100, // 5% slippage tolerance
            token0ToToken1,
            user
        );
        uint256 blxAfter = blxToken.balanceOf(user);
        
        console.log("Swapped WETH for BLX:");
        console.log("- WETH amount in:", wethAmountIn);
        console.log("- BLX amount out:", actualBLXOut);
        console.log("BLX balance change:", blxAfter - blxBefore);
    }

    // ==================== REMOVE LIQUIDITY FUNCTION ====================

    function removeLiquidityExample() public {
        console.log("\n=== Removing Liquidity ===");
        
        uint256 lpBalance = blxUsdcPool.balanceOf(user);
        if (lpBalance == 0) {
            console.log("No LP tokens to remove");
            return;
        }
        
        // Remove 50% of LP tokens
        uint256 liquidityToRemove = lpBalance / 2;
        
        console.log("Removing", liquidityToRemove, "LP tokens");
        console.log("Total LP balance:", lpBalance);
        
        uint256 blxBefore = blxToken.balanceOf(user);
        uint256 usdcBefore = usdcToken.balanceOf(user);
        
        (uint256 amount0, uint256 amount1) = blxUsdcPool.removeLiquidity(
            liquidityToRemove,
            0, // min amount0
            0, // min amount1
            user
        );
        
        uint256 blxAfter = blxToken.balanceOf(user);
        uint256 usdcAfter = usdcToken.balanceOf(user);
        
        console.log("Removed liquidity:");
        console.log("- Amount0:", amount0);
        console.log("- Amount1:", amount1);
        console.log("- BLX balance change:", blxAfter - blxBefore);
        console.log("- USDC balance change:", usdcAfter - usdcBefore);
        console.log("- Remaining LP tokens:", blxUsdcPool.balanceOf(user));
    }

    // ==================== UTILITY FUNCTIONS ====================

    function checkPoolReserves() public view {
        console.log("\n=== Pool Reserves ===");
        
        (uint112 reserve0_usdc, uint112 reserve1_usdc,) = blxUsdcPool.getReserves();
        console.log("BLX-USDC Pool:");
        console.log("- Reserve0:", reserve0_usdc);
        console.log("- Reserve1:", reserve1_usdc);
        
        (uint112 reserve0_weth, uint112 reserve1_weth,) = blxWethPool.getReserves();
        console.log("BLX-WETH Pool:");
        console.log("- Reserve0:", reserve0_weth);
        console.log("- Reserve1:", reserve1_weth);
    }

    function checkUserBalances() public view {
        console.log("\n=== User Balances ===");
        console.log("BLX:", blxToken.balanceOf(user));
        console.log("USDC:", usdcToken.balanceOf(user));
        console.log("WETH:", weth.balanceOf(user));
        console.log("ETH:", user.balance);
        console.log("BLX-USDC LP:", blxUsdcPool.balanceOf(user));
        console.log("BLX-WETH LP:", blxWethPool.balanceOf(user));
    }

    // ==================== INDIVIDUAL FUNCTIONS FOR TESTING ====================

    function addLiquidityOnly() external {
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY");
        user = vm.addr(userPrivateKey);
        
        vm.startBroadcast(userPrivateKey);
        setUp();
        addLiquidityToUSDCPool();
        vm.stopBroadcast();
    }

    function swapOnly() external {
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY");
        user = vm.addr(userPrivateKey);
        
        vm.startBroadcast(userPrivateKey);
        setUp();
        swapBLXForUSDC();
        vm.stopBroadcast();
    }

    function removeLiquidityOnly() external {
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY");
        user = vm.addr(userPrivateKey);
        
        vm.startBroadcast(userPrivateKey);
        setUp();
        removeLiquidityExample();
        vm.stopBroadcast();
    }

    function logDeploymentSummary() internal view {
        console.log("\n==========================================");
        console.log("DEPLOYMENT SUMMARY & CONTRACT VERIFICATION");
        console.log("==========================================");
        
        // Token Contract Addresses
        // console.log("\n--- TOKEN CONTRACTS ---");
        // console.log("BLX Token:");
        // console.log(address(blxToken));
        // console.log("USDC Token:");
        // console.log(address(usdcToken));
        // console.log("WETH:");
        // console.log(address(weth));
        
        // // Pool Contract Addresses
        // console.log("\n--- POOL CONTRACTS ---");
        // console.log("BLX-USDC Pool:");
        // console.log(address(blxUsdcPool));
        // console.log("BLX-WETH Pool:");
        // console.log(address(blxWethPool));
        
        // // Contract Verification
        // console.log("\n--- CONTRACT VERIFICATION ---");
        // console.log("BLX Token bytecode length:");
        // console.log(address(blxToken).code.length);
        // console.log("USDC Token bytecode length:");
        // console.log(address(usdcToken).code.length);
        // console.log("WETH bytecode length:");
        // console.log(address(weth).code.length);
        // console.log("BLX-USDC Pool bytecode length:");
        // console.log(address(blxUsdcPool).code.length);
        // console.log("BLX-WETH Pool bytecode length:");
        // console.log(address(blxWethPool).code.length);
        
        // // Pool Token Information
        // console.log("\n--- POOL TOKEN CONFIGURATION ---");
        // console.log("BLX-USDC Pool Token0:");
        // console.logAddress(blxUsdcPool.token0());
        // console.log("BLX-USDC Pool Token1:");
        // console.logAddress(blxUsdcPool.token1());
        // console.log("BLX-WETH Pool Token0:");
        // console.logAddress(blxWethPool.token0());
        // console.log("BLX-WETH Pool Token1:");
        // console.logAddress(blxWethPool.token1());
        
        // // Reserve Information
        // console.log("\n--- INITIAL RESERVES ---");
        // (uint256 reserve0_usdc, uint256 reserve1_usdc,) = blxUsdcPool.getReserves();
        // (uint256 reserve0_weth, uint256 reserve1_weth,) = blxWethPool.getReserves();
        // console.log("BLX-USDC Pool Reserves:");
        // console.log("Reserve0:", reserve0_usdc);
        // console.log("Reserve1:", reserve1_usdc);
        // console.log("BLX-WETH Pool Reserves:");
        // console.log("Reserve0:", reserve0_weth);
        // console.log("Reserve1:", reserve1_weth);
        
        // // Important Function Signatures
        // console.log("\n--- FUNCTION SIGNATURES FOR FRONTEND ---");
        // console.log("getReserves(): 0x0902f1ac");
        // console.log("swap(uint256,uint256,address,bytes): 0x022c0d9f");
        // console.log("addLiquidity(uint256,uint256): varies by implementation");
        // console.log("balanceOf(address): 0x70a08231");
        // console.log("transfer(address,uint256): 0xa9059cbb");
        // console.log("approve(address,uint256): 0x095ea7b3");
        
        // console.log("\n==========================================");
        // console.log("Copy these addresses to your frontend wagmi config!");
        // console.log("==========================================\n");
    }
}
