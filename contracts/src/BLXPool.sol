// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@uniswap/v2-core/contracts/libraries/UQ112x112.sol";

/**
 * @title BLXPool - AMM Liquidity Pool
 * @dev Standalone AMM implementation inspired by Uniswap V2 with security enhancements
 */
contract BLXPool is ERC20, ReentrancyGuard, Ownable {
    using Math for uint256;
    using UQ112x112 for uint224;

    // ==================== STATE VARIABLES ====================
    
    IERC20 public immutable token0;
    IERC20 public immutable token1;
    
    uint112 private reserve0;           // Packed into single storage slot
    uint112 private reserve1;           // Packed into single storage slot
    uint32 private blockTimestampLast;  // Packed into single storage slot
    
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast; // K value from last liquidity event
    
    uint256 public constant MINIMUM_LIQUIDITY = 10**3;
    uint256 private constant FEE_DENOMINATOR = 10000;
    uint256 public swapFee = 30; // 0.3% = 30/10000
    
    address public feeTo;
    bool public tradingEnabled = true;
    
    // ==================== EVENTS ====================
    
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
    
    // ==================== MODIFIERS ====================
    
    modifier tradingAllowed() {
        require(tradingEnabled, "BLXPool: Trading is paused");
        _;
    }
    
    modifier validAddress(address addr) {
        require(addr != address(0), "BLXPool: Zero address");
        _;
    }
    
    // ==================== CONSTRUCTOR ====================
    
    constructor(
        address _token0,
        address _token1,
        string memory _name,
        string memory _symbol
    ) 
        ERC20(_name, _symbol) 
        validAddress(_token0)
        validAddress(_token1)
    {
        require(_token0 != _token1, "BLXPool: Identical tokens");
        require(_token0 < _token1, "BLXPool: Tokens not sorted");
        
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    /// @dev Get current reserves and last block timestamp
    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }
    
    /// @dev Calculate output amount for given input amount
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) 
        public 
        view 
        returns (uint256 amountOut) 
    {
        require(amountIn > 0, "BLXPool: Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "BLXPool: Insufficient liquidity");
        
        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - swapFee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        amountOut = numerator / denominator;
    }
    
    /// @dev Calculate input amount required for given output amount
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) 
        public 
        view 
        returns (uint256 amountIn) 
    {
        require(amountOut > 0, "BLXPool: Insufficient output amount");
        require(reserveIn > 0 && reserveOut > 0, "BLXPool: Insufficient liquidity");
        require(amountOut < reserveOut, "BLXPool: Insufficient reserve");
        
        uint256 numerator = reserveIn * amountOut * FEE_DENOMINATOR;
        uint256 denominator = (reserveOut - amountOut) * (FEE_DENOMINATOR - swapFee);
        amountIn = (numerator / denominator) + 1;
    }
    
    /// @dev Quote amount B based on amount A and reserves  
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) 
        public 
        pure 
        returns (uint256 amountB) 
    {
        require(amountA > 0, "BLXPool: Insufficient amount");
        require(reserveA > 0 && reserveB > 0, "BLXPool: Insufficient liquidity");
        amountB = (amountA * reserveB) / reserveA;
    }
    
    // ==================== INTERNAL FUNCTIONS ====================
    
    function _safeTransfer(IERC20 token, address to, uint256 value) private {
        require(token.transfer(to, value), "BLXPool: Transfer failed");
    }
    
    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "BLXPool: Overflow");
        
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            unchecked {
                price0CumulativeLast += uint256(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
                price1CumulativeLast += uint256(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
            }
        }
        
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }
    
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast; // gas savings
        
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = Math.sqrt(uint256(_reserve0) * _reserve1);
                uint256 rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply() * (rootK - rootKLast);
                    uint256 denominator = (rootK * 5) + rootKLast;
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }
    
    // ==================== LIQUIDITY FUNCTIONS ====================
    
    function addLiquidity(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        address to
    ) 
        external 
        tradingAllowed 
        validAddress(to)
        returns (uint256 amount0, uint256 amount1, uint256 liquidity) 
    {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        
        if (_reserve0 == 0 && _reserve1 == 0) {
            // First liquidity provision
            amount0 = amount0Desired;
            amount1 = amount1Desired;
        } else {
            // Calculate optimal amounts
            uint256 amount1Optimal = quote(amount0Desired, _reserve0, _reserve1);
            if (amount1Optimal <= amount1Desired) {
                require(amount1Optimal >= amount1Min, "BLXPool: Insufficient amount1");
                amount0 = amount0Desired;
                amount1 = amount1Optimal;
            } else {
                uint256 amount0Optimal = quote(amount1Desired, _reserve1, _reserve0);
                assert(amount0Optimal <= amount0Desired);
                require(amount0Optimal >= amount0Min, "BLXPool: Insufficient amount0");
                amount0 = amount0Optimal;
                amount1 = amount1Desired;
            }
        }
        
        // Transfer tokens
        require(token0.transferFrom(msg.sender, address(this), amount0), "BLXPool: Transfer0 failed");
        require(token1.transferFrom(msg.sender, address(this), amount1), "BLXPool: Transfer1 failed");
        
        liquidity = mint(to);
        
        require(liquidity >= MINIMUM_LIQUIDITY, "BLXPool: Insufficient liquidity minted");
    }
    
    function mint(address to) internal nonReentrant returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;
        
        // Security: Ensure tokens were actually transferred
        require(amount0 > 0 && amount1 > 0, "BLXPool: No tokens transferred");
        
        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee
        
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0xdead), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min((amount0 * _totalSupply) / _reserve0, (amount1 * _totalSupply) / _reserve1);
        }
        
        require(liquidity > 0, "BLXPool: Insufficient liquidity minted");
        _mint(to, liquidity);
        
        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0) * reserve1; // reserve0 and reserve1 are up-to-date
        
        emit Mint(msg.sender, amount0, amount1, to);
    }
    
    function removeLiquidity(
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        address to
    ) 
        external  
        validAddress(to)
        returns (uint256 amount0, uint256 amount1) 
    {
        require(liquidity > 0, "BLXPool: Insufficient liquidity");
        require(balanceOf(msg.sender) >= liquidity, "BLXPool: Insufficient balance");
        
        // Transfer LP tokens to this contract
        _transfer(msg.sender, address(this), liquidity);
        
        (amount0, amount1) = burn(to);
        
        require(amount0 >= amount0Min, "BLXPool: Insufficient amount0");
        require(amount1 >= amount1Min, "BLXPool: Insufficient amount1");
    }
    
    function burn(address to) public nonReentrant returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        uint256 liquidity = balanceOf(address(this));
        
        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee
        
        amount0 = (liquidity * balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = (liquidity * balance1) / _totalSupply; // using balances ensures pro-rata distribution
        
        require(amount0 > 0 && amount1 > 0, "BLXPool: Insufficient liquidity burned");
        
        _burn(address(this), liquidity);
        _safeTransfer(token0, to, amount0);
        _safeTransfer(token1, to, amount1);
        
        balance0 = token0.balanceOf(address(this));
        balance1 = token1.balanceOf(address(this));
        
        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0) * reserve1; // reserve0 and reserve1 are up-to-date
        
        emit Burn(msg.sender, amount0, amount1, to);
    }
    
    // ==================== SWAP FUNCTIONS ====================
    
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        bool token0ToToken1, // true if swapping token0 for token1
        address to
    ) 
        external  
        tradingAllowed 
        validAddress(to)
        returns (uint256 amountOut) 
    {
        require(amountIn > 0, "BLXPool: Insufficient input amount");
        
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        
        if (token0ToToken1) {
            amountOut = getAmountOut(amountIn, _reserve0, _reserve1);
            require(amountOut >= amountOutMin, "BLXPool: Insufficient output amount");
            require(token0.transferFrom(msg.sender, address(this), amountIn), "BLXPool: Transfer failed");
            swap(0, amountOut, to);
        } else {
            amountOut = getAmountOut(amountIn, _reserve1, _reserve0);
            require(amountOut >= amountOutMin, "BLXPool: Insufficient output amount");
            require(token1.transferFrom(msg.sender, address(this), amountIn), "BLXPool: Transfer failed");
            swap(amountOut, 0, to);
        }
    }
    
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        bool token0ToToken1,
        address to
    ) 
        external 
        tradingAllowed 
        validAddress(to)
        returns (uint256 amountIn) 
    {
        require(amountOut > 0, "BLXPool: Insufficient output amount");
        
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        
        if (token0ToToken1) {
            amountIn = getAmountIn(amountOut, _reserve0, _reserve1);
            require(amountIn <= amountInMax, "BLXPool: Excessive input amount");
            require(token0.transferFrom(msg.sender, address(this), amountIn), "BLXPool: Transfer failed");
            swap(0, amountOut, to);
        } else {
            amountIn = getAmountIn(amountOut, _reserve1, _reserve0);
            require(amountIn <= amountInMax, "BLXPool: Excessive input amount");
            require(token1.transferFrom(msg.sender, address(this), amountIn), "BLXPool: Transfer failed");
            swap(amountOut, 0, to);
        }
    }
    
    function swap(uint256 amount0Out, uint256 amount1Out, address to) public nonReentrant tradingAllowed {
        require(amount0Out > 0 || amount1Out > 0, "BLXPool: Insufficient output amount");
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "BLXPool: Insufficient liquidity");
        
        uint256 balance0;
        uint256 balance1;
        
        require(to != address(token0) && to != address(token1), "BLXPool: Invalid to address");
        
        if (amount0Out > 0) _safeTransfer(token0, to, amount0Out);
        if (amount1Out > 0) _safeTransfer(token1, to, amount1Out);
        
        balance0 = token0.balanceOf(address(this));
        balance1 = token1.balanceOf(address(this));
        
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        
        require(amount0In > 0 || amount1In > 0, "BLXPool: Insufficient input amount");
        
        // Verify K invariant (with fee)
        uint256 balance0Adjusted = (balance0 * FEE_DENOMINATOR) - (amount0In * swapFee);
        uint256 balance1Adjusted = (balance1 * FEE_DENOMINATOR) - (amount1In * swapFee);
        require(
            balance0Adjusted * balance1Adjusted >= uint256(_reserve0) * _reserve1 * (FEE_DENOMINATOR ** 2),
            "BLXPool: K invariant violated"
        );
        
        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function setSwapFee(uint256 _swapFee) external onlyOwner {
        require(_swapFee <= 1000, "BLXPool: Fee too high"); // Max 10%
        uint256 oldFee = swapFee;
        swapFee = _swapFee;
        emit SwapFeeUpdated(oldFee, _swapFee);
    }
    
    function setFeeTo(address _feeTo) external onlyOwner {
        address oldFeeTo = feeTo;
        feeTo = _feeTo;
        emit FeeToUpdated(oldFeeTo, _feeTo);
    }
    
    function setTradingEnabled(bool _enabled) external onlyOwner {
        tradingEnabled = _enabled;
        emit TradingStatusChanged(_enabled);
    }
    
    // ==================== EMERGENCY FUNCTIONS ====================
    
    function skim(address to) external validAddress(to) {
        _safeTransfer(token0, to, token0.balanceOf(address(this)) - reserve0);
        _safeTransfer(token1, to, token1.balanceOf(address(this)) - reserve1);
    }
    
    function sync() external {
        _update(token0.balanceOf(address(this)), token1.balanceOf(address(this)), reserve0, reserve1);
    }
    
    // Emergency token recovery (only for tokens that are not pool tokens)
    function recoverToken(address _token, uint256 _amount) external onlyOwner {
        require(_token != address(token0) && _token != address(token1), "BLXPool: Cannot recover pool tokens");
        IERC20(_token).transfer(owner(), _amount);
    }
}


