export const TIERED_STAKING_ABI = [
  {
    "type": "constructor",
    "inputs": [
      { "name": "_stakingToken", "type": "address" },
      { "name": "_rewardsToken", "type": "address" }
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
    "name": "withdraw",
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
      { "name": "apr", "type": "uint256" },
      { "name": "withdrawn", "type": "bool" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "stakesLength",
    "inputs": [
      { "name": "user", "type": "address" }
    ],
    "outputs": [
      { "name": "", "type": "uint256" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getUserStakesInfo",
    "inputs": [
      { "name": "user", "type": "address" }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple[]",
        "components": [
          { "name": "amount", "type": "uint256" },
          { "name": "startTime", "type": "uint256" },
          { "name": "lockDuration", "type": "uint256" },
          { "name": "apr", "type": "uint256" },
          { "name": "withdrawn", "type": "bool" }
        ]
      }
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
    "name": "stakingToken",
    "inputs": [],
    "outputs": [
      { "name": "", "type": "address" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "rewardsToken",
    "inputs": [],
    "outputs": [
      { "name": "", "type": "address" }
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
      { "name": "lockDuration", "type": "uint256", "indexed": false },
      { "name": "apr", "type": "uint256", "indexed": false }
    ]
  },
  {
    "type": "event",
    "name": "Withdrawn",
    "inputs": [
      { "name": "user", "type": "address", "indexed": true },
      { "name": "amount", "type": "uint256", "indexed": false },
      { "name": "reward", "type": "uint256", "indexed": false }
    ]
  }
] as const
