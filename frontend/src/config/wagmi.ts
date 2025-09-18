import { http, createConfig } from 'wagmi'
import { mainnet, sepolia, anvil } from 'wagmi/chains'
import { injected, metaMask } from 'wagmi/connectors'

export const config = createConfig({
  chains: [anvil, sepolia, mainnet],
  connectors: [
    injected(),
    metaMask(),
  ],
  transports: {
    [anvil.id]: http('http://127.0.0.1:8545'),
    [sepolia.id]: http(),
    [mainnet.id]: http(),
  },
})

// Default to Sepolia for production
export const DEVELOPMENT_CHAIN_ID = sepolia.id

export const CONTRACT_ADDRESSES = {
  BLX_POOL: '0x5bCAE371B52A8a497f4Cb9178E14C137141B0c13',
  BLX_TOKEN: '0x050F2D144cAdB54Ae304c234F273B0124a126dB5',
  USDC_TOKEN: '0x1D68BE240D1A9e527410B017075868bc543E7538',
  TIERED_STAKING: '0xFb3FaC0BDf5dB9c11857F6e0cBedC4f13147D06c',
  LIQUID_STAKING: '0x74534A5ca5793E338ccDB6De58dA5662B05070C5',
  STAKED_BLX: '0xec16eE9362d310D42DF579AdA7e627fAf99F6FA7',
  BLX_VAULT: '0x0C7468Bd1eca2BD7d39aE496234427cD7FEb8344',
} as const

// Token configurations
export const TOKEN_CONFIG = {
  BLX: {
    decimals: 18,
    symbol: 'BLX',
    name: 'BLUME Token'
  },
  USDC: {
    decimals: 18,
    symbol: 'USDC', 
    name: 'USD Coin'
  }
} as const
