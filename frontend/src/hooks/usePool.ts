import { useReadContract, useWriteContract } from 'wagmi'
import { formatUnits, parseUnits } from 'viem'
import { BLX_POOL_ABI } from '../contracts/BLXPool'
import { CONTRACT_ADDRESSES, TOKEN_CONFIG } from '../config/wagmi'
import { useTokenApproval } from './useToken'

// Hook to fetch pool reserves
export function usePoolReserves() {
  console.log('usePoolReserves hook called')
  console.log('Contract address:', CONTRACT_ADDRESSES.BLX_POOL)
  
  const { data, error, isLoading } = useReadContract({
    address: CONTRACT_ADDRESSES.BLX_POOL as `0x${string}`,
    abi: BLX_POOL_ABI,
    functionName: 'getReserves',
  })

  console.log('usePoolReserves state:', { data, error, isLoading })

  // Debug logging
  if (data) {
    console.log('Raw reserves data:', {
      reserve0: data[0]?.toString(),
      reserve1: data[1]?.toString(),
      blockTimestampLast: data[2]?.toString()
    })
    
    // Format with correct decimals
    console.log('Formatted reserves:', {
      reserve0_formatted: formatUnits(data[0], TOKEN_CONFIG.BLX.decimals),
      reserve1_formatted: formatUnits(data[1], TOKEN_CONFIG.USDC.decimals)
    })
  }

  if (error) {
    console.error('usePoolReserves error:', error)
  }

  return {
    reserves: data ? {
      reserve0: data[0],
      reserve1: data[1],
      blockTimestampLast: data[2]
    } : null,
    error,
    isLoading
  }
}

// Hook to fetch total liquidity (LP token supply)
export function useTotalLiquidity() {
  const { data, error, isLoading } = useReadContract({
    address: CONTRACT_ADDRESSES.BLX_POOL as `0x${string}`,
    abi: BLX_POOL_ABI,
    functionName: 'totalSupply',
  })

  return {
    totalSupply: data ? formatUnits(data, TOKEN_CONFIG.BLX.decimals) : '0',
    totalSupplyRaw: data,
    error,
    isLoading
  }
}

// Hook to fetch user's LP token balance
export function useUserLPBalance(userAddress?: `0x${string}`) {
  const { data, error, isLoading } = useReadContract({
    address: CONTRACT_ADDRESSES.BLX_POOL as `0x${string}`,
    abi: BLX_POOL_ABI,
    functionName: 'balanceOf',
    args: userAddress ? [userAddress] : undefined,
    query: {
      enabled: !!userAddress
    }
  })

  return {
    balance: data ? formatUnits(data, TOKEN_CONFIG.BLX.decimals) : '0',
    balanceRaw: data,
    error,
    isLoading
  }
}

// Hook to fetch swap fee
export function useSwapFee() {
  const { data, error, isLoading } = useReadContract({
    address: CONTRACT_ADDRESSES.BLX_POOL as `0x${string}`,
    abi: BLX_POOL_ABI,
    functionName: 'swapFee',
  })

  return {
    swapFee: data ? Number(data) / 10000 : 0.3, // Convert basis points to percentage
    swapFeeRaw: data,
    error,
    isLoading
  }
}

// Hook to fetch trading status
export function useTradingEnabled() {
  const { data, error, isLoading } = useReadContract({
    address: CONTRACT_ADDRESSES.BLX_POOL as `0x${string}`,
    abi: BLX_POOL_ABI,
    functionName: 'tradingEnabled',
  })

  return {
    tradingEnabled: data ?? false,
    error,
    isLoading
  }
}

// Hook to get amount out for swaps
export function useGetAmountOut(amountIn: string, token0ToToken1: boolean) {
  const { reserves } = usePoolReserves()
  
  const { data, error, isLoading } = useReadContract({
    address: CONTRACT_ADDRESSES.BLX_POOL as `0x${string}`,
    abi: BLX_POOL_ABI,
    functionName: 'getAmountOut',
    args: amountIn && reserves ? [
      parseUnits(amountIn, TOKEN_CONFIG.BLX.decimals), // Both tokens use 18 decimals
      token0ToToken1 ? reserves.reserve0 : reserves.reserve1,
      token0ToToken1 ? reserves.reserve1 : reserves.reserve0
    ] : undefined,
    query: {
      enabled: !!(amountIn && reserves && Number(amountIn) > 0)
    }
  })

  return {
    amountOut: data ? formatUnits(data, TOKEN_CONFIG.BLX.decimals) : '0',
    amountOutRaw: data,
    error,
    isLoading
  }
}

// Hook for swap functionality
export function useSwap() {
  const { writeContract, isPending, error } = useWriteContract()

  const swap = async (
    amountIn: string,
    amountOutMin: string,
    token0ToToken1: boolean,
    to: `0x${string}`
  ) => {
    try {
      await writeContract({
        address: CONTRACT_ADDRESSES.BLX_POOL as `0x${string}`,
        abi: BLX_POOL_ABI,
        functionName: 'swapExactTokensForTokens',
        args: [
          parseUnits(amountIn, TOKEN_CONFIG.BLX.decimals), // Both tokens use 18 decimals
          parseUnits(amountOutMin, TOKEN_CONFIG.BLX.decimals),
          token0ToToken1,
          to
        ]
      })
    } catch (err) {
      console.error('Swap error:', err)
      throw err
    }
  }

  return {
    swap,
    isPending,
    error
  }
}

// Hook for add liquidity functionality
export function useAddLiquidity() {
  const { writeContract, isPending, error } = useWriteContract()

  const addLiquidity = async (
    amount0Desired: string,
    amount1Desired: string,
    amount0Min: string,
    amount1Min: string,
    to: `0x${string}`
  ) => {
    try {
      await writeContract({
        address: CONTRACT_ADDRESSES.BLX_POOL as `0x${string}`,
        abi: BLX_POOL_ABI,
        functionName: 'addLiquidity',
        args: [
          parseUnits(amount0Desired, TOKEN_CONFIG.BLX.decimals), // Both tokens use 18 decimals
          parseUnits(amount1Desired, TOKEN_CONFIG.USDC.decimals),
          parseUnits(amount0Min, TOKEN_CONFIG.BLX.decimals),
          parseUnits(amount1Min, TOKEN_CONFIG.USDC.decimals),
          to
        ]
      })
    } catch (err) {
      console.error('Add liquidity error:', err)
      throw err
    }
  }

  return {
    addLiquidity,
    isPending,
    error
  }
}

// Simple hook for token approval before add liquidity
export function useApproveTokens() {
  const { approve: approveToken, isPending, error } = useTokenApproval()

  const approveForAddLiquidity = async (
    token0Amount: string,
    token1Amount: string,
    userAddress: `0x${string}`
  ) => {
    try {
      const poolAddress = CONTRACT_ADDRESSES.BLX_POOL as `0x${string}`
      const blxTokenAddress = CONTRACT_ADDRESSES.BLX_TOKEN as `0x${string}`
      const usdcTokenAddress = CONTRACT_ADDRESSES.USDC_TOKEN as `0x${string}`

      console.log('Approving tokens for add liquidity...')
      
      // Approve BLX token
      console.log('Approving BLX token:', { amount: token0Amount, spender: poolAddress })
      await approveToken(blxTokenAddress, poolAddress, token0Amount)
      
      // Approve USDC token  
      console.log('Approving USDC token:', { amount: token1Amount, spender: poolAddress })
      await approveToken(usdcTokenAddress, poolAddress, token1Amount)
      
      console.log('Both tokens approved successfully')
    } catch (err) {
      console.error('Token approval error:', err)
      throw err
    }
  }

  return {
    approveForAddLiquidity,
    isPending,
    error
  }
}

// Combined hook for the full add liquidity flow
export function useAddLiquidityFlow() {
  const { approveForAddLiquidity, isPending: isApprovePending, error: approveError } = useApproveTokens()
  const { addLiquidity, isPending: isAddLiquidityPending, error: addLiquidityError } = useAddLiquidity()

  const executeAddLiquidity = async (
    amount0Desired: string,
    amount1Desired: string,
    amount0Min: string = '0',
    amount1Min: string = '0',
    to: `0x${string}`,
    shouldApprove: boolean = true
  ) => {
    try {
      // Step 1: Approve tokens if requested
      if (shouldApprove) {
        await approveForAddLiquidity(amount0Desired, amount1Desired, to)
      }
      
      // Step 2: Add liquidity
      await addLiquidity(amount0Desired, amount1Desired, amount0Min, amount1Min, to)
      
    } catch (err) {
      console.error('Add liquidity flow error:', err)
      throw err
    }
  }

  return {
    executeAddLiquidity,
    isPending: isApprovePending || isAddLiquidityPending,
    error: approveError || addLiquidityError
  }
}

// Hook for remove liquidity functionality  
export function useRemoveLiquidity() {
  const { writeContract, isPending, error } = useWriteContract()

  const removeLiquidity = async (
    liquidity: string,
    amount0Min: string,
    amount1Min: string,
    to: `0x${string}`
  ) => {
    try {
      await writeContract({
        address: CONTRACT_ADDRESSES.BLX_POOL as `0x${string}`,
        abi: BLX_POOL_ABI,
        functionName: 'removeLiquidity',
        args: [
          parseUnits(liquidity, TOKEN_CONFIG.BLX.decimals), // LP tokens use 18 decimals
          parseUnits(amount0Min, TOKEN_CONFIG.BLX.decimals),
          parseUnits(amount1Min, TOKEN_CONFIG.USDC.decimals),
          to
        ]
      })
    } catch (err) {
      console.error('Remove liquidity error:', err)
      throw err
    }
  }

  return {
    removeLiquidity,
    isPending,
    error
  }
}
