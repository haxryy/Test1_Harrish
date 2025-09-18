export const LIQUID_STAKING_ABI = [
  {
    "type": "constructor",
    "inputs": [
      { "name": "_blxToken", "type": "address" }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "stake",
    "inputs": [
      { "name": "amount", "type": "uint256" },
      { "name": "lockChoice", "type": "uint256" }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "redeem",
    "inputs": [
      { "name": "index", "type": "uint256" }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "pendingReward",
    "inputs": [
      { "name": "user", "type": "address" },
      { "name": "index", "type": "uint256" }
    ],
    "outputs": [
      { "name": "", "type": "uint256" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "stakes",
    "inputs": [
      { "name": "user", "type": "address" },
      { "name": "index", "type": "uint256" }
    ],
    "outputs": [
      { "name": "amount", "type": "uint256" },
      { "name": "startTime", "type": "uint256" },
      { "name": "lockDuration", "type": "uint256" },
      { "name": "apr", "type": "uint256" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "blxToken",
    "inputs": [],
    "outputs": [
      { "name": "", "type": "address" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "stToken",
    "inputs": [],
    "outputs": [
      { "name": "", "type": "address" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "totalStaked",
    "inputs": [],
    "outputs": [
      { "name": "", "type": "uint256" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "totalRewards",
    "inputs": [],
    "outputs": [
      { "name": "", "type": "uint256" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "addRewards",
    "inputs": [
      { "name": "amount", "type": "uint256" }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "APR_30D",
    "inputs": [],
    "outputs": [
      { "name": "", "type": "uint256" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "APR_90D",
    "inputs": [],
    "outputs": [
      { "name": "", "type": "uint256" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "APR_365D",
    "inputs": [],
    "outputs": [
      { "name": "", "type": "uint256" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "event",
    "name": "Staked",
    "inputs": [
      { "name": "user", "type": "address", "indexed": true },
      { "name": "amount", "type": "uint256", "indexed": false },
      { "name": "stAmount", "type": "uint256", "indexed": false },
      { "name": "lockDuration", "type": "uint256", "indexed": false },
      { "name": "apr", "type": "uint256", "indexed": false }
    ]
  },
  {
    "type": "event",
    "name": "Redeemed",
    "inputs": [
      { "name": "user", "type": "address", "indexed": true },
      { "name": "blxAmount", "type": "uint256", "indexed": false },
      { "name": "reward", "type": "uint256", "indexed": false }
    ]
  }
] as const

export const STAKED_BLX_ABI = [
  {
    "type": "function",
    "name": "balanceOf",
    "inputs": [
      { "name": "account", "type": "address" }
    ],
    "outputs": [
      { "name": "", "type": "uint256" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "totalSupply",
    "inputs": [],
    "outputs": [
      { "name": "", "type": "uint256" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "name",
    "inputs": [],
    "outputs": [
      { "name": "", "type": "string" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "symbol",
    "inputs": [],
    "outputs": [
      { "name": "", "type": "string" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "decimals",
    "inputs": [],
    "outputs": [
      { "name": "", "type": "uint8" }
    ],
    "stateMutability": "view"
  }
] as const
