export const BLX_VAULT_ABI = [
  {
    "type": "constructor",
    "inputs": [
      { "name": "_blxToken", "type": "address" },
      { "name": "_stakingContract", "type": "address" }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "deposit",
    "inputs": [
      { "name": "amount", "type": "uint256" },
      { "name": "lockPeriod", "type": "uint256" },
      { "name": "autoStake", "type": "bool" }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "withdraw",
    "inputs": [
      { "name": "depositIndex", "type": "uint256" }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "emergencyWithdraw",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "toggleAutoStake",
    "inputs": [
      { "name": "depositIndex", "type": "uint256" }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "userDeposits",
    "inputs": [
      { "name": "user", "type": "address" },
      { "name": "index", "type": "uint256" }
    ],
    "outputs": [
      { "name": "amount", "type": "uint256" },
      { "name": "depositTime", "type": "uint256" },
      { "name": "lockUntil", "type": "uint256" },
      { "name": "autoStake", "type": "bool" },
      { "name": "withdrawn", "type": "bool" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getUserDeposits",
    "inputs": [
      { "name": "user", "type": "address" }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple[]",
        "components": [
          { "name": "amount", "type": "uint256" },
          { "name": "depositTime", "type": "uint256" },
          { "name": "lockUntil", "type": "uint256" },
          { "name": "autoStake", "type": "bool" },
          { "name": "withdrawn", "type": "bool" }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getUserDepositCount",
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
    "name": "calculateWithdrawalAmount",
    "inputs": [
      { "name": "user", "type": "address" },
      { "name": "depositIndex", "type": "uint256" }
    ],
    "outputs": [
      { "name": "netAmount", "type": "uint256" },
      { "name": "fee", "type": "uint256" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "isDepositLocked",
    "inputs": [
      { "name": "user", "type": "address" },
      { "name": "depositIndex", "type": "uint256" }
    ],
    "outputs": [
      { "name": "", "type": "bool" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "totalUserBalance",
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
    "name": "totalVaultBalance",
    "inputs": [],
    "outputs": [
      { "name": "", "type": "uint256" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "totalAutoStaked",
    "inputs": [],
    "outputs": [
      { "name": "", "type": "uint256" }
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
    "name": "stakingContract",
    "inputs": [],
    "outputs": [
      { "name": "", "type": "address" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "treasury",
    "inputs": [],
    "outputs": [
      { "name": "", "type": "address" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "withdrawalFee",
    "inputs": [],
    "outputs": [
      { "name": "", "type": "uint256" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "earlyWithdrawalFee",
    "inputs": [],
    "outputs": [
      { "name": "", "type": "uint256" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "NO_LOCK",
    "inputs": [],
    "outputs": [
      { "name": "", "type": "uint256" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "LOCK_7_DAYS",
    "inputs": [],
    "outputs": [
      { "name": "", "type": "uint256" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "LOCK_30_DAYS",
    "inputs": [],
    "outputs": [
      { "name": "", "type": "uint256" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "LOCK_90_DAYS",
    "inputs": [],
    "outputs": [
      { "name": "", "type": "uint256" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "paused",
    "inputs": [],
    "outputs": [
      { "name": "", "type": "bool" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "event",
    "name": "Deposited",
    "inputs": [
      { "name": "user", "type": "address", "indexed": true },
      { "name": "amount", "type": "uint256", "indexed": false },
      { "name": "lockUntil", "type": "uint256", "indexed": false },
      { "name": "autoStake", "type": "bool", "indexed": false }
    ]
  },
  {
    "type": "event",
    "name": "Withdrawn",
    "inputs": [
      { "name": "user", "type": "address", "indexed": true },
      { "name": "depositIndex", "type": "uint256", "indexed": false },
      { "name": "amount", "type": "uint256", "indexed": false },
      { "name": "fee", "type": "uint256", "indexed": false }
    ]
  },
  {
    "type": "event",
    "name": "AutoStakeToggled",
    "inputs": [
      { "name": "user", "type": "address", "indexed": true },
      { "name": "depositIndex", "type": "uint256", "indexed": false },
      { "name": "enabled", "type": "bool", "indexed": false }
    ]
  },
  {
    "type": "event",
    "name": "EmergencyWithdraw",
    "inputs": [
      { "name": "user", "type": "address", "indexed": true },
      { "name": "amount", "type": "uint256", "indexed": false }
    ]
  }
] as const
