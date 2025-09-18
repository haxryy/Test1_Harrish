import { usePoolReserves, useTotalLiquidity } from './usePool'
import { formatUnits } from 'viem'
import { TOKEN_CONFIG } from '../config/wagmi'

// Hook to calculate total liquidity value
export function usePoolStats() {
  const { reserves, isLoading: reservesLoading } = usePoolReserves()
  const { totalSupply, isLoading: liquidityLoading } = useTotalLiquidity()

  const isLoading = reservesLoading || liquidityLoading

  // Debug logging
  if (reserves) {
    console.log('Formatted reserves:', {
      token0_formatted: formatUnits(reserves.reserve0, TOKEN_CONFIG.BLX.decimals),
      token1_formatted: formatUnits(reserves.reserve1, TOKEN_CONFIG.USDC.decimals),
      token0_raw: reserves.reserve0.toString(),
      token1_raw: reserves.reserve1.toString()
    })
  }

  // Calculate total liquidity value (assuming 1:1 USD parity for simplicity)
  const totalLiquidityValue = reserves ? 
    (Number(formatUnits(reserves.reserve0, TOKEN_CONFIG.BLX.decimals)) + Number(formatUnits(reserves.reserve1, TOKEN_CONFIG.USDC.decimals))) : 0

  // Calculate token ratio
  const tokenRatio = reserves && reserves.reserve0 && reserves.reserve1 ? 
    Number(formatUnits(reserves.reserve0, TOKEN_CONFIG.BLX.decimals)) / Number(formatUnits(reserves.reserve1, TOKEN_CONFIG.USDC.decimals)) : 1

  return {
    totalLiquidityValue,
    tokenRatio,
    reserves: reserves ? {
      token0: formatUnits(reserves.reserve0, TOKEN_CONFIG.BLX.decimals),
      token1: formatUnits(reserves.reserve1, TOKEN_CONFIG.USDC.decimals),
      timestamp: reserves.blockTimestampLast
    } : null,
    totalSupply,
    isLoading
  }
}
