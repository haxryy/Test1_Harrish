import { useReadContract, useWriteContract } from 'wagmi'
import { formatUnits, parseUnits } from 'viem'
import { TIERED_STAKING_ABI } from '../contracts/TieredStaking'
import { LIQUID_STAKING_ABI, STAKED_BLX_ABI } from '../contracts/LiquidStaking'
import { CONTRACT_ADDRESSES, TOKEN_CONFIG } from '../config/wagmi'

// Lock duration constants (in seconds)
export const LOCK_DURATIONS = {
  '30_DAYS': 30 * 24 * 60 * 60,
  '90_DAYS': 90 * 24 * 60 * 60,
  '365_DAYS': 365 * 24 * 60 * 60,
} as const

export const LOCK_OPTIONS = [
  { value: LOCK_DURATIONS['30_DAYS'], label: '30 Days', apr: '5%' },
  { value: LOCK_DURATIONS['90_DAYS'], label: '90 Days', apr: '10%' },
  { value: LOCK_DURATIONS['365_DAYS'], label: '365 Days', apr: '20%' },
] as const

// ==================== TIERED STAKING HOOKS ====================

// Hook to get user's stakes from tiered staking
export function useTieredStakes(userAddress?: `0x${string}`) {
  const { data: stakesLength } = useReadContract({
    address: CONTRACT_ADDRESSES.TIERED_STAKING as `0x${string}`,
    abi: TIERED_STAKING_ABI,
    functionName: 'stakesLength',
    args: userAddress ? [userAddress] : undefined,
    query: {
      enabled: !!userAddress 
    }
  })

  const { data: stakesData } = useReadContract({
    address: CONTRACT_ADDRESSES.TIERED_STAKING as `0x${string}`,
    abi: TIERED_STAKING_ABI,
    functionName: 'getUserStakesInfo',
    args: userAddress ? [userAddress] : undefined,
    query: {
      enabled: !!userAddress 
    }
  })

  return {
    stakesLength: stakesLength ? Number(stakesLength) : 0,
    stakes: stakesData || [],
    isLoading: !stakesData && !!userAddress
  }
}

// Hook to get pending rewards for a specific stake
export function useTieredPendingReward(userAddress?: `0x${string}`, stakeIndex?: number) {
  const { data: reward } = useReadContract({
    address: CONTRACT_ADDRESSES.TIERED_STAKING as `0x${string}`,
    abi: TIERED_STAKING_ABI,
    functionName: 'pendingReward',
    args: userAddress && stakeIndex !== undefined ? [userAddress, BigInt(stakeIndex)] : undefined,
    query: {
      enabled: !!userAddress && stakeIndex !== undefined 
    }
  })

  return {
    reward: reward ? formatUnits(reward, TOKEN_CONFIG.BLX.decimals) : '0',
    rewardRaw: reward
  }
}

// Hook for tiered staking operations
export function useTieredStaking() {
  const { writeContract, isPending, error } = useWriteContract()

  const stake = async (amount: string, lockDuration: number) => {
    try {
      await writeContract({
        address: CONTRACT_ADDRESSES.TIERED_STAKING as `0x${string}`,
        abi: TIERED_STAKING_ABI,
        functionName: 'stake',
        args: [parseUnits(amount, TOKEN_CONFIG.BLX.decimals), BigInt(lockDuration)]
      })
    } catch (err) {
      console.error('Tiered staking error:', err)
      throw err
    }
  }

  const withdraw = async (stakeIndex: number) => {
    try {
      await writeContract({
        address: CONTRACT_ADDRESSES.TIERED_STAKING as `0x${string}`,
        abi: TIERED_STAKING_ABI,
        functionName: 'withdraw',
        args: [BigInt(stakeIndex)]
      })
    } catch (err) {
      console.error('Withdraw error:', err)
      throw err
    }
  }

  return {
    stake,
    withdraw,
    isPending,
    error
  }
}

// ==================== LIQUID STAKING HOOKS ====================

// Hook to get liquid staking stats
export function useLiquidStakingStats() {
  const { data: totalStaked } = useReadContract({
    address: CONTRACT_ADDRESSES.LIQUID_STAKING as `0x${string}`,
    abi: LIQUID_STAKING_ABI,
    functionName: 'totalStaked',
    query: {
      enabled: String(CONTRACT_ADDRESSES.LIQUID_STAKING) !== '0x0000000000000000000000000000000000000000'
    }
  })

  const { data: totalRewards } = useReadContract({
    address: CONTRACT_ADDRESSES.LIQUID_STAKING as `0x${string}`,
    abi: LIQUID_STAKING_ABI,
    functionName: 'totalRewards',
    query: {
      enabled: String(CONTRACT_ADDRESSES.LIQUID_STAKING) !== '0x0000000000000000000000000000000000000000'
    }
  })

  const { data: stTokenAddress } = useReadContract({
    address: CONTRACT_ADDRESSES.LIQUID_STAKING as `0x${string}`,
    abi: LIQUID_STAKING_ABI,
    functionName: 'stToken',
    query: {
      enabled: String(CONTRACT_ADDRESSES.LIQUID_STAKING) !== '0x0000000000000000000000000000000000000000'
    }
  })

  return {
    totalStaked: totalStaked ? formatUnits(totalStaked, TOKEN_CONFIG.BLX.decimals) : '0',
    totalRewards: totalRewards ? formatUnits(totalRewards, TOKEN_CONFIG.BLX.decimals) : '0',
    stTokenAddress,
    totalStakedRaw: totalStaked,
    totalRewardsRaw: totalRewards
  }
}

// Hook to get user's stBLX balance
export function useStakedBLXBalance(userAddress?: `0x${string}`) {
  const { stTokenAddress } = useLiquidStakingStats()
  
  const { data: balance } = useReadContract({
    address: stTokenAddress as `0x${string}`,
    abi: STAKED_BLX_ABI,
    functionName: 'balanceOf',
    args: userAddress ? [userAddress] : undefined,
    query: {
      enabled: !!userAddress && !!stTokenAddress
    }
  })

  return {
    balance: balance ? formatUnits(balance, TOKEN_CONFIG.BLX.decimals) : '0',
    balanceRaw: balance
  }
}

// Hook for liquid staking operations
export function useLiquidStaking() {
  const { writeContract, isPending, error } = useWriteContract()

  const stake = async (amount: string, lockDuration: number) => {
    try {
      await writeContract({
        address: CONTRACT_ADDRESSES.LIQUID_STAKING as `0x${string}`,
        abi: LIQUID_STAKING_ABI,
        functionName: 'stake',
        args: [parseUnits(amount, TOKEN_CONFIG.BLX.decimals), BigInt(lockDuration)]
      })
    } catch (err) {
      console.error('Liquid staking error:', err)
      throw err
    }
  }

  const redeem = async (stakeIndex: number) => {
    try {
      await writeContract({
        address: CONTRACT_ADDRESSES.LIQUID_STAKING as `0x${string}`,
        abi: LIQUID_STAKING_ABI,
        functionName: 'redeem',
        args: [BigInt(stakeIndex)]
      })
    } catch (err) {
      console.error('Redeem error:', err)
      throw err
    }
  }

  return {
    stake,
    redeem,
    isPending,
    error
  }
}

// Hook to get user's liquid stakes
export function useLiquidStakes(_userAddress?: `0x${string}`) {
  // Since liquid staking uses the same stake structure, we can query individual stakes
  // For simplicity, we'll assume users typically have a small number of stakes
  const stakes: any[] = []
  
  // We would need to implement a way to track stake indices
  // For now, return empty array - this would need to be enhanced
  // to track user stake indices properly
  
  return {
    stakes,
    isLoading: false
  }
}

// Hook to get pending rewards for liquid staking
export function useLiquidPendingReward(userAddress?: `0x${string}`, stakeIndex?: number) {
  const { data: reward } = useReadContract({
    address: CONTRACT_ADDRESSES.LIQUID_STAKING as `0x${string}`,
    abi: LIQUID_STAKING_ABI,
    functionName: 'pendingReward',
    args: userAddress && stakeIndex !== undefined ? [userAddress, BigInt(stakeIndex)] : undefined,
    query: {
      enabled: !!userAddress && stakeIndex !== undefined && String(CONTRACT_ADDRESSES.LIQUID_STAKING) !== '0x0000000000000000000000000000000000000000'
    }
  })

  return {
    reward: reward ? formatUnits(reward, TOKEN_CONFIG.BLX.decimals) : '0',
    rewardRaw: reward
  }
}
