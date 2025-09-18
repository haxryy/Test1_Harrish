// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../src/BLXPool.sol";
import "../src/BLX.sol";

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

contract BLXPoolTest is Test {
    BLXPool public pool;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    BLXToken public blxToken;
    
    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public feeTo = address(0x3);
    
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 1e18;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Mint(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);
    event SwapFeeUpdated(uint256 oldFee, uint256 newFee);
    event TradingStatusChanged(bool enabled);
    event FeeToUpdated(address indexed oldFeeTo, address indexed newFeeTo);

    function setUp() public {
        // Deploy tokens
        tokenA = new MockERC20("Token A", "TKNA", INITIAL_SUPPLY);
        tokenB = new MockERC20("Token B", "TKNB", INITIAL_SUPPLY);
        blxToken = new BLXToken("BLX Token", "BLX", INITIAL_SUPPLY);
        
        // Ensure token ordering (token0 < token1)
        if (address(tokenA) > address(tokenB)) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }
        
        // Deploy pool
        pool = new BLXPool(
            address(tokenA),
            address(tokenB),
            "Test LP Token",
            "TLP"
        );
        
        // Setup initial balances
        deal(address(tokenA), user1, 100_000 * 1e18);
        deal(address(tokenA), user2, 100_000 * 1e18);
        deal(address(tokenB), user1, 100_000 * 1e18);
        deal(address(tokenB), user2, 100_000 * 1e18);
        
        // Approve pool to spend tokens
        vm.startPrank(user1);
        tokenA.approve(address(pool), type(uint256).max);
        tokenB.approve(address(pool), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(user2);
        tokenA.approve(address(pool), type(uint256).max);
        tokenB.approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }
    
    // ==================== CONSTRUCTOR TESTS ====================
    
    function testConstructor() public {
        assertEq(address(pool.token0()), address(tokenA));
        assertEq(address(pool.token1()), address(tokenB));
        assertEq(pool.name(), "Test LP Token");
        assertEq(pool.symbol(), "TLP");
        assertEq(pool.owner(), owner);
        assertEq(pool.swapFee(), 30); // 0.3%
        assertTrue(pool.tradingEnabled());
    }
    
    function testConstructorFailsWithIdenticalTokens() public {
        vm.expectRevert("BLXPool: Identical tokens");
        new BLXPool(
            address(tokenA),
            address(tokenA),
            "Test LP",
            "TLP"
        );
    }
    
    function testConstructorFailsWithUnsortedTokens() public {
        address token0 = address(0x1000);
        address token1 = address(0x2000);
        
        vm.expectRevert("BLXPool: Tokens not sorted");
        new BLXPool(
            token1, // Wrong order
            token0,
            "Test LP",
            "TLP"
        );
    }
    
    function testConstructorFailsWithZeroAddress() public {
        vm.expectRevert("BLXPool: Zero address");
        new BLXPool(
            address(0),
            address(tokenB),
            "Test LP",
            "TLP"
        );
    }
    
    // ==================== LIQUIDITY TESTS ====================
    
    function testFirstLiquidityProvision() public {
        uint256 amount0 = 1000 * 1e18;
        uint256 amount1 = 2000 * 1e18;
        
        vm.startPrank(user1);
        
        vm.expectEmit(true, false, false, true);
        emit Mint(user1, amount0, amount1, user1);
        
        (uint256 actualAmount0, uint256 actualAmount1, uint256 liquidity) = pool.addLiquidity(
            amount0,
            amount1,
            0,
            0,
            user1
        );
        
        vm.stopPrank();
        
        assertEq(actualAmount0, amount0);
        assertEq(actualAmount1, amount1);
        
        // Check liquidity calculation: sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY
        uint256 expectedLiquidity = sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
        assertEq(liquidity, expectedLiquidity);
        assertEq(pool.balanceOf(user1), expectedLiquidity);
        assertEq(pool.balanceOf(address(0xdead)), MINIMUM_LIQUIDITY);
        
        // Check reserves
        (uint112 reserve0, uint112 reserve1,) = pool.getReserves();
        assertEq(reserve0, amount0);
        assertEq(reserve1, amount1);
    }
    
    function testSubsequentLiquidityProvision() public {
        // First provision
        vm.startPrank(user1);
        pool.addLiquidity(1000 * 1e18, 2000 * 1e18, 0, 0, user1);
        vm.stopPrank();
        
        // Get the actual total supply after first provision
        uint256 totalSupplyAfterFirst = pool.totalSupply();
        (uint112 reserve0, uint112 reserve1,) = pool.getReserves();
        
        // Second provision with optimal ratio
        vm.startPrank(user2);
        (uint256 amount0, uint256 amount1, uint256 liquidity) = pool.addLiquidity(
            500 * 1e18,  // Will be optimal
            1000 * 1e18, // Will be optimal  
            0,
            0,
            user2
        );
        vm.stopPrank();
        
        assertEq(amount0, 500 * 1e18);
        assertEq(amount1, 1000 * 1e18);
        
        // Liquidity calculation: min((amount0 * totalSupply) / reserve0, (amount1 * totalSupply) / reserve1)
        uint256 expectedLiquidity0 = (500 * 1e18 * totalSupplyAfterFirst) / uint256(reserve0);
        uint256 expectedLiquidity1 = (1000 * 1e18 * totalSupplyAfterFirst) / uint256(reserve1);
        uint256 expectedLiquidity = expectedLiquidity0 < expectedLiquidity1 ? expectedLiquidity0 : expectedLiquidity1;
        
        assertEq(liquidity, expectedLiquidity);
    }
    
    function testLiquidityProvisionWithExcessToken1() public {
        // First provision
        vm.startPrank(user1);
        pool.addLiquidity(1000 * 1e18, 2000 * 1e18, 0, 0, user1);
        vm.stopPrank();
        
        // Second provision with excess token1
        vm.startPrank(user2);
        (uint256 amount0, uint256 amount1, uint256 liquidity) = pool.addLiquidity(
            500 * 1e18,   // Desired amount0
            1500 * 1e18,  // Excess token1, should be reduced to 1000
            0,
            0,
            user2
        );
        vm.stopPrank();
        
        assertEq(amount0, 500 * 1e18);
        assertEq(amount1, 1000 * 1e18); // Should be reduced to maintain ratio
    }
    
    function testLiquidityProvisionWithExcessToken0() public {
        // First provision
        vm.startPrank(user1);
        pool.addLiquidity(1000 * 1e18, 2000 * 1e18, 0, 0, user1);
        vm.stopPrank();
        
        // Second provision with excess token0
        vm.startPrank(user2);
        (uint256 amount0, uint256 amount1, uint256 liquidity) = pool.addLiquidity(
            1000 * 1e18,  // Excess token0, should be reduced
            1000 * 1e18,  // Desired amount1
            0,
            0,
            user2
        );
        vm.stopPrank();
        
        assertEq(amount0, 500 * 1e18); // Should be reduced to maintain ratio
        assertEq(amount1, 1000 * 1e18);
    }
    
    function testLiquidityProvisionFailsWithSlippage() public {
        // First provision
        vm.startPrank(user1);
        pool.addLiquidity(1000 * 1e18, 2000 * 1e18, 0, 0, user1);
        vm.stopPrank();
        
        // Second provision with high minimum amounts
        vm.startPrank(user2);
        vm.expectRevert("BLXPool: Insufficient amount1");
        pool.addLiquidity(
            500 * 1e18,
            1500 * 1e18,
            500 * 1e18,   // amount0Min
            1200 * 1e18,  // amount1Min - too high
            user2
        );
        vm.stopPrank();
    }
    
    function testRemoveLiquidity() public {
        // Add liquidity first
        vm.startPrank(user1);
        (, , uint256 liquidity) = pool.addLiquidity(1000 * 1e18, 2000 * 1e18, 0, 0, user1);
        
        // Remove half of the liquidity
        uint256 liquidityToRemove = liquidity / 2;
        
        (uint256 amount0, uint256 amount1) = pool.removeLiquidity(
            liquidityToRemove,
            0,
            0,
            user1
        );
        
        vm.stopPrank();
        
        // Check amounts are approximately correct (allowing for fees and rounding)
        assertApproxEqRel(amount0, 500 * 1e18, 0.01e18); // 1% tolerance
        assertApproxEqRel(amount1, 1000 * 1e18, 0.01e18); // 1% tolerance
        assertEq(pool.balanceOf(user1), liquidity - liquidityToRemove);
    }
    
    function testRemoveLiquidityFailsWithInsufficientBalance() public {
        vm.startPrank(user1);
        pool.addLiquidity(1000 * 1e18, 2000 * 1e18, 0, 0, user1);
        
        vm.expectRevert("BLXPool: Insufficient balance");
        pool.removeLiquidity(
            1000000 * 1e18, // More than user has
            0,
            0,
            user1
        );
        vm.stopPrank();
    }
    
    function testRemoveLiquidityFailsWithSlippage() public {
        vm.startPrank(user1);
        (, , uint256 liquidity) = pool.addLiquidity(1000 * 1e18, 2000 * 1e18, 0, 0, user1);
        
        vm.expectRevert("BLXPool: Insufficient amount0");
        pool.removeLiquidity(
            liquidity / 2,
            600 * 1e18, // amount0Min too high
            0,
            user1
        );
        vm.stopPrank();
    }
    
    // ==================== SWAP TESTS ====================
    
    function testSwapExactTokensForTokens() public {
        // Add liquidity first
        vm.startPrank(user1);
        pool.addLiquidity(1000 * 1e18, 2000 * 1e18, 0, 0, user1);
        vm.stopPrank();
        
        // Swap token0 for token1
        uint256 amountIn = 100 * 1e18;
        uint256 expectedAmountOut = pool.getAmountOut(amountIn, 1000 * 1e18, 2000 * 1e18);
        
        vm.startPrank(user2);
        
        vm.expectEmit(true, false, false, true);
        emit Swap(user2, amountIn, 0, 0, expectedAmountOut, user2);
        
        uint256 amountOut = pool.swapExactTokensForTokens(
            amountIn,
            0,
            true, // token0 to token1
            user2
        );
        
        vm.stopPrank();
        
        assertEq(amountOut, expectedAmountOut);
        
        // Check balances changed correctly
        (uint112 reserve0, uint112 reserve1,) = pool.getReserves();
        assertEq(reserve0, 1000 * 1e18 + amountIn);
        assertEq(reserve1, 2000 * 1e18 - amountOut);
    }
    
    function testSwapExactTokensForTokensReverse() public {
        // Add liquidity first
        vm.startPrank(user1);
        pool.addLiquidity(1000 * 1e18, 2000 * 1e18, 0, 0, user1);
        vm.stopPrank();
        
        // Swap token1 for token0
        uint256 amountIn = 200 * 1e18;
        uint256 expectedAmountOut = pool.getAmountOut(amountIn, 2000 * 1e18, 1000 * 1e18);
        
        vm.startPrank(user2);
        uint256 amountOut = pool.swapExactTokensForTokens(
            amountIn,
            0,
            false, // token1 to token0
            user2
        );
        vm.stopPrank();
        
        assertEq(amountOut, expectedAmountOut);
    }
    
    function testSwapTokensForExactTokens() public {
        // Add liquidity first
        vm.startPrank(user1);
        pool.addLiquidity(1000 * 1e18, 2000 * 1e18, 0, 0, user1);
        vm.stopPrank();
        
        // Swap for exact amount out
        uint256 amountOut = 100 * 1e18;
        uint256 expectedAmountIn = pool.getAmountIn(amountOut, 1000 * 1e18, 2000 * 1e18);
        
        vm.startPrank(user2);
        uint256 amountIn = pool.swapTokensForExactTokens(
            amountOut,
            type(uint256).max,
            true, // token0 to token1
            user2
        );
        vm.stopPrank();
        
        assertEq(amountIn, expectedAmountIn);
    }
    
    function testSwapFailsWithInsufficientLiquidity() public {
        // Add small liquidity
        vm.startPrank(user1);
        pool.addLiquidity(100 * 1e18, 200 * 1e18, 0, 0, user1);
        vm.stopPrank();
        
        // Try to swap for an amount that would cause insufficient output
        // When we request 200 * 1e18 as minimum output but reserves are only 200 * 1e18
        // The getAmountOut calculation will fail to meet minimum requirements
        vm.startPrank(user2);
        vm.expectRevert("BLXPool: Insufficient output amount");
        pool.swapExactTokensForTokens(
            1 * 1e18,      // Small input
            200 * 1e18,    // Demand all of reserve1 as minimum output  
            true,          // token0 to token1
            user2
        );
        vm.stopPrank();
    }
    
    function testSwapFailsWithInsufficientLiquidityInSwapFunction() public {
        // Add liquidity
        vm.startPrank(user1);
        pool.addLiquidity(100 * 1e18, 200 * 1e18, 0, 0, user1);
        vm.stopPrank();
        
        // Call swap function directly with amount larger than reserves
        vm.expectRevert("BLXPool: Insufficient liquidity");
        pool.swap(0, 201 * 1e18, user2); // Try to get more than reserve1
    }
    
    function testSwapFailsWithSlippage() public {
        vm.startPrank(user1);
        pool.addLiquidity(1000 * 1e18, 2000 * 1e18, 0, 0, user1);
        vm.stopPrank();
        
        uint256 amountIn = 100 * 1e18;
        uint256 expectedOut = pool.getAmountOut(amountIn, 1000 * 1e18, 2000 * 1e18);
        
        vm.startPrank(user2);
        vm.expectRevert("BLXPool: Insufficient output amount");
        pool.swapExactTokensForTokens(
            amountIn,
            expectedOut + 1, // Slightly more than possible
            true,
            user2
        );
        vm.stopPrank();
    }
    
    function testSwapFailsWhenTradingDisabled() public {
        vm.startPrank(user1);
        pool.addLiquidity(1000 * 1e18, 2000 * 1e18, 0, 0, user1);
        vm.stopPrank();
        
        // Disable trading
        pool.setTradingEnabled(false);
        
        vm.startPrank(user2);
        vm.expectRevert("BLXPool: Trading is paused");
        pool.swapExactTokensForTokens(100 * 1e18, 0, true, user2);
        vm.stopPrank();
    }
    
    // ==================== PRICING TESTS ====================
    
    function testGetAmountOut() public {
        uint256 amountIn = 100 * 1e18;
        uint256 reserveIn = 1000 * 1e18;
        uint256 reserveOut = 2000 * 1e18;
        
        uint256 amountOut = pool.getAmountOut(amountIn, reserveIn, reserveOut);
        
        // Manual calculation: (amountIn * 9970 * reserveOut) / (reserveIn * 10000 + amountIn * 9970)
        uint256 amountInWithFee = amountIn * 9970; // 0.3% fee
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;
        uint256 expected = numerator / denominator;
        
        assertEq(amountOut, expected);
    }
    
    function testGetAmountIn() public {
        uint256 amountOut = 100 * 1e18;
        uint256 reserveIn = 1000 * 1e18;
        uint256 reserveOut = 2000 * 1e18;
        
        uint256 amountIn = pool.getAmountIn(amountOut, reserveIn, reserveOut);
        
        // Manual calculation
        uint256 numerator = reserveIn * amountOut * 10000;
        uint256 denominator = (reserveOut - amountOut) * 9970;
        uint256 expected = (numerator / denominator) + 1;
        
        assertEq(amountIn, expected);
    }
    
    function testQuote() public {
        uint256 amountA = 100 * 1e18;
        uint256 reserveA = 1000 * 1e18;
        uint256 reserveB = 2000 * 1e18;
        
        uint256 amountB = pool.quote(amountA, reserveA, reserveB);
        uint256 expected = (amountA * reserveB) / reserveA;
        
        assertEq(amountB, expected);
    }
    
    // ==================== ADMIN FUNCTION TESTS ====================
    
    function testSetSwapFee() public {
        vm.expectEmit(false, false, false, true);
        emit SwapFeeUpdated(30, 50);
        
        pool.setSwapFee(50);
        assertEq(pool.swapFee(), 50);
    }
    
    function testSetSwapFeeFailsWithHighFee() public {
        vm.expectRevert("BLXPool: Fee too high");
        pool.setSwapFee(1001); // > 10%
    }
    
    function testSetSwapFeeFailsFromNonOwner() public {
        vm.startPrank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        pool.setSwapFee(50);
        vm.stopPrank();
    }
    
    function testSetFeeTo() public {
        vm.expectEmit(true, true, false, false);
        emit FeeToUpdated(address(0), feeTo);
        
        pool.setFeeTo(feeTo);
        assertEq(pool.feeTo(), feeTo);
    }
    
    function testSetTradingEnabled() public {
        vm.expectEmit(false, false, false, true);
        emit TradingStatusChanged(false);
        
        pool.setTradingEnabled(false);
        assertFalse(pool.tradingEnabled());
    }
    
    // ==================== EMERGENCY FUNCTION TESTS ====================
    
    function testSkim() public {
        // Add liquidity
        vm.startPrank(user1);
        pool.addLiquidity(1000 * 1e18, 2000 * 1e18, 0, 0, user1);
        vm.stopPrank();
        
        // Send extra tokens to pool
        uint256 extraAmount = 100 * 1e18;
        tokenA.transfer(address(pool), extraAmount);
        
        uint256 balanceBefore = tokenA.balanceOf(user2);
        
        // Skim excess tokens
        pool.skim(user2);
        
        uint256 balanceAfter = tokenA.balanceOf(user2);
        assertEq(balanceAfter - balanceBefore, extraAmount);
    }
    
    function testSync() public {
        // Add liquidity
        vm.startPrank(user1);
        pool.addLiquidity(1000 * 1e18, 2000 * 1e18, 0, 0, user1);
        vm.stopPrank();
        
        // Send tokens directly to pool (not through addLiquidity)
        tokenA.transfer(address(pool), 100 * 1e18);
        tokenB.transfer(address(pool), 200 * 1e18);
        
        vm.expectEmit(false, false, false, true);
        emit Sync(uint112(1100 * 1e18), uint112(2200 * 1e18));
        
        pool.sync();
        
        (uint112 reserve0, uint112 reserve1,) = pool.getReserves();
        assertEq(reserve0, 1100 * 1e18);
        assertEq(reserve1, 2200 * 1e18);
    }
    
    function testRecoverToken() public {
        // Deploy a different token
        MockERC20 otherToken = new MockERC20("Other", "OTHER", 1000 * 1e18);
        
        // Send some to the pool by mistake
        otherToken.transfer(address(pool), 100 * 1e18);
        
        uint256 balanceBefore = otherToken.balanceOf(owner);
        
        // Recover the token
        pool.recoverToken(address(otherToken), 100 * 1e18);
        
        uint256 balanceAfter = otherToken.balanceOf(owner);
        assertEq(balanceAfter - balanceBefore, 100 * 1e18);
    }
    
    function testRecoverTokenFailsForPoolTokens() public {
        vm.expectRevert("BLXPool: Cannot recover pool tokens");
        pool.recoverToken(address(tokenA), 100 * 1e18);
        
        vm.expectRevert("BLXPool: Cannot recover pool tokens");
        pool.recoverToken(address(tokenB), 100 * 1e18);
    }
    
    // ==================== EDGE CASE TESTS ====================
    
    function testMinimumLiquidityHandling() public {
        vm.startPrank(user1);
        
        // Add very small liquidity
        vm.expectRevert("BLXPool: Insufficient liquidity minted");
        pool.addLiquidity(
            1000, // Very small amounts
            2000,
            0,
            0,
            user1
        );
        
        vm.stopPrank();
    }
    
    function testLargeAmountSwap() public {
        // Add large liquidity
        vm.startPrank(user1);
        pool.addLiquidity(10000 * 1e18, 20000 * 1e18, 0, 0, user1);
        vm.stopPrank();
        
        // Large swap
        uint256 amountIn = 1000 * 1e18;
        
        vm.startPrank(user2);
        uint256 amountOut = pool.swapExactTokensForTokens(
            amountIn,
            0,
            true,
            user2
        );
        vm.stopPrank();
        
        assertTrue(amountOut > 0);
        
        // Verify K invariant is maintained (approximately, due to fees)
        (uint112 reserve0, uint112 reserve1,) = pool.getReserves();
        uint256 k = uint256(reserve0) * uint256(reserve1);
        assertTrue(k >= 10000 * 1e18 * 20000 * 1e18); // Should be at least initial K
    }
    
    function testPriceImpactOnLargeSwap() public {
        vm.startPrank(user1);
        pool.addLiquidity(1000 * 1e18, 1000 * 1e18, 0, 0, user1);
        vm.stopPrank();
        
        // Small swap
        uint256 smallAmountIn = 10 * 1e18;
        uint256 smallAmountOut = pool.getAmountOut(smallAmountIn, 1000 * 1e18, 1000 * 1e18);
        
        // Large swap
        uint256 largeAmountIn = 100 * 1e18;
        uint256 largeAmountOut = pool.getAmountOut(largeAmountIn, 1000 * 1e18, 1000 * 1e18);
        
        // Large swap should have worse rate due to price impact
        uint256 smallRate = (smallAmountOut * 1e18) / smallAmountIn;
        uint256 largeRate = (largeAmountOut * 1e18) / largeAmountIn;
        
        assertTrue(smallRate > largeRate, "Large swaps should have worse rates");
    }
    
    // ==================== HELPER FUNCTIONS ====================
    
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
    
    // ==================== FUZZ TESTS ====================
    
    function testFuzzSwap(uint256 amountIn) public {
        // Bound the input to reasonable values
        amountIn = bound(amountIn, 1e15, 100 * 1e18); // 0.001 to 100 tokens
        
        // Add liquidity first
        vm.startPrank(user1);
        pool.addLiquidity(1000 * 1e18, 2000 * 1e18, 0, 0, user1);
        vm.stopPrank();
        
        // Ensure user has enough tokens
        deal(address(tokenA), user2, amountIn);
        
        vm.startPrank(user2);
        tokenA.approve(address(pool), amountIn);
        
        uint256 amountOut = pool.swapExactTokensForTokens(
            amountIn,
            0,
            true,
            user2
        );
        vm.stopPrank();
        
        assertTrue(amountOut > 0, "Should always get some output");
        assertTrue(amountOut < 2000 * 1e18, "Output should be less than total reserve");
    }
    
    function testFuzzLiquidity(uint256 amount0, uint256 amount1) public {
        // Bound inputs to reasonable values
        amount0 = bound(amount0, 1e18, 1000 * 1e18);
        amount1 = bound(amount1, 1e18, 1000 * 1e18);
        
        // Ensure user has enough tokens
        deal(address(tokenA), user1, amount0);
        deal(address(tokenB), user1, amount1);
        
        vm.startPrank(user1);
        tokenA.approve(address(pool), amount0);
        tokenB.approve(address(pool), amount1);
        
        (uint256 actualAmount0, uint256 actualAmount1, uint256 liquidity) = pool.addLiquidity(
            amount0,
            amount1,
            0,
            0,
            user1
        );
        vm.stopPrank();
        
        assertTrue(actualAmount0 > 0, "Should use some amount0");
        assertTrue(actualAmount1 > 0, "Should use some amount1");
        assertTrue(liquidity > 0, "Should mint some liquidity");
        assertTrue(actualAmount0 <= amount0, "Should not use more than provided");
        assertTrue(actualAmount1 <= amount1, "Should not use more than provided");
    }
}
