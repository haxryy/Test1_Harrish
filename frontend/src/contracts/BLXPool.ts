// BLXPool contract ABI
export const BLX_POOL_ABI = [
  {
    "type": "function",
    "name": "getReserves",
    "inputs": [],
    "outputs": [
      { "name": "_reserve0", "type": "uint112", "internalType": "uint112" },
      { "name": "_reserve1", "type": "uint112", "internalType": "uint112" },
      { "name": "_blockTimestampLast", "type": "uint32", "internalType": "uint32" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "totalSupply",
    "inputs": [],
    "outputs": [{ "name": "", "type": "uint256", "internalType": "uint256" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "balanceOf",
    "inputs": [{ "name": "account", "type": "address", "internalType": "address" }],
    "outputs": [{ "name": "", "type": "uint256", "internalType": "uint256" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "token0",
    "inputs": [],
    "outputs": [{ "name": "", "type": "address", "internalType": "contract IERC20" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "token1",
    "inputs": [],
    "outputs": [{ "name": "", "type": "address", "internalType": "contract IERC20" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "swapFee",
    "inputs": [],
    "outputs": [{ "name": "", "type": "uint256", "internalType": "uint256" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "tradingEnabled",
    "inputs": [],
    "outputs": [{ "name": "", "type": "bool", "internalType": "bool" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getAmountOut",
    "inputs": [
      { "name": "amountIn", "type": "uint256", "internalType": "uint256" },
      { "name": "reserveIn", "type": "uint256", "internalType": "uint256" },
      { "name": "reserveOut", "type": "uint256", "internalType": "uint256" }
    ],
    "outputs": [{ "name": "amountOut", "type": "uint256", "internalType": "uint256" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "swapExactTokensForTokens",
    "inputs": [
      { "name": "amountIn", "type": "uint256", "internalType": "uint256" },
      { "name": "amountOutMin", "type": "uint256", "internalType": "uint256" },
      { "name": "token0ToToken1", "type": "bool", "internalType": "bool" },
      { "name": "to", "type": "address", "internalType": "address" }
    ],
    "outputs": [{ "name": "amountOut", "type": "uint256", "internalType": "uint256" }],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "addLiquidity",
    "inputs": [
      { "name": "amount0Desired", "type": "uint256", "internalType": "uint256" },
      { "name": "amount1Desired", "type": "uint256", "internalType": "uint256" },
      { "name": "amount0Min", "type": "uint256", "internalType": "uint256" },
      { "name": "amount1Min", "type": "uint256", "internalType": "uint256" },
      { "name": "to", "type": "address", "internalType": "address" }
    ],
    "outputs": [
      { "name": "amount0", "type": "uint256", "internalType": "uint256" },
      { "name": "amount1", "type": "uint256", "internalType": "uint256" },
      { "name": "liquidity", "type": "uint256", "internalType": "uint256" }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "removeLiquidity",
    "inputs": [
      { "name": "liquidity", "type": "uint256", "internalType": "uint256" },
      { "name": "amount0Min", "type": "uint256", "internalType": "uint256" },
      { "name": "amount1Min", "type": "uint256", "internalType": "uint256" },
      { "name": "to", "type": "address", "internalType": "address" }
    ],
    "outputs": [
      { "name": "amount0", "type": "uint256", "internalType": "uint256" },
      { "name": "amount1", "type": "uint256", "internalType": "uint256" }
    ],
    "stateMutability": "nonpayable"
  }
] as const
