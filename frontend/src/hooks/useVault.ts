import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { BLX_VAULT_ABI } from '../contracts/BLXVault'
import { CONTRACT_ADDRESSES } from '../config/wagmi'
import type { Address } from 'viem'

// Read hooks
export function useVaultBalance(userAddress?: Address) {
  return useReadContract({
    address: CONTRACT_ADDRESSES.BLX_VAULT as Address,
    abi: BLX_VAULT_ABI,
    functionName: 'totalUserBalance',
    args: userAddress ? [userAddress] : undefined,
    query: {
      enabled: !!userAddress,
    },
  })
}

export function useUserDeposits(userAddress?: Address) {
  return useReadContract({
    address: CONTRACT_ADDRESSES.BLX_VAULT as Address,
    abi: BLX_VAULT_ABI,
    functionName: 'getUserDeposits',
    args: userAddress ? [userAddress] : undefined,
    query: {
      enabled: !!userAddress,
    },
  })
}

export function useUserDepositCount(userAddress?: Address) {
  return useReadContract({
    address: CONTRACT_ADDRESSES.BLX_VAULT as Address,
    abi: BLX_VAULT_ABI,
    functionName: 'getUserDepositCount',
    args: userAddress ? [userAddress] : undefined,
    query: {
      enabled: !!userAddress,
    },
  })
}

export function useIsDepositLocked(userAddress?: Address, depositIndex?: number) {
  return useReadContract({
    address: CONTRACT_ADDRESSES.BLX_VAULT as Address,
    abi: BLX_VAULT_ABI,
    functionName: 'isDepositLocked',
    args: userAddress && typeof depositIndex === 'number' ? [userAddress, BigInt(depositIndex)] : undefined,
    query: {
      enabled: !!userAddress && typeof depositIndex === 'number',
    },
  })
}

export function useCalculateWithdrawalAmount(userAddress?: Address, depositIndex?: number) {
  return useReadContract({
    address: CONTRACT_ADDRESSES.BLX_VAULT as Address,
    abi: BLX_VAULT_ABI,
    functionName: 'calculateWithdrawalAmount',
    args: userAddress && typeof depositIndex === 'number' ? [userAddress, BigInt(depositIndex)] : undefined,
    query: {
      enabled: !!userAddress && typeof depositIndex === 'number',
    },
  })
}

export function useVaultConstants() {
  const { data: noLock } = useReadContract({
    address: CONTRACT_ADDRESSES.BLX_VAULT as Address,
    abi: BLX_VAULT_ABI,
    functionName: 'NO_LOCK',
  })

  const { data: lock7Days } = useReadContract({
    address: CONTRACT_ADDRESSES.BLX_VAULT as Address,
    abi: BLX_VAULT_ABI,
    functionName: 'LOCK_7_DAYS',
  })

  const { data: lock30Days } = useReadContract({
    address: CONTRACT_ADDRESSES.BLX_VAULT as Address,
    abi: BLX_VAULT_ABI,
    functionName: 'LOCK_30_DAYS',
  })

  const { data: lock90Days } = useReadContract({
    address: CONTRACT_ADDRESSES.BLX_VAULT as Address,
    abi: BLX_VAULT_ABI,
    functionName: 'LOCK_90_DAYS',
  })

  return {
    NO_LOCK: noLock,
    LOCK_7_DAYS: lock7Days,
    LOCK_30_DAYS: lock30Days,
    LOCK_90_DAYS: lock90Days,
  }
}

export function useTotalVaultBalance() {
  return useReadContract({
    address: CONTRACT_ADDRESSES.BLX_VAULT as Address,
    abi: BLX_VAULT_ABI,
    functionName: 'totalVaultBalance',
  })
}

export function useTotalAutoStaked() {
  return useReadContract({
    address: CONTRACT_ADDRESSES.BLX_VAULT as Address,
    abi: BLX_VAULT_ABI,
    functionName: 'totalAutoStaked',
  })
}

// Write hooks
export function useVaultDeposit() {
  const { writeContract, data: hash, error, isPending } = useWriteContract()

  const deposit = (amount: bigint, lockPeriod: bigint, autoStake: boolean) => {
    writeContract({
      address: CONTRACT_ADDRESSES.BLX_VAULT as Address,
      abi: BLX_VAULT_ABI,
      functionName: 'deposit',
      args: [amount, lockPeriod, autoStake],
    })
  }

  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash,
  })

  return {
    deposit,
    hash,
    error,
    isPending,
    isConfirming,
    isConfirmed,
  }
}

export function useVaultWithdraw() {
  const { writeContract, data: hash, error, isPending } = useWriteContract()

  const withdraw = (depositIndex: number) => {
    writeContract({
      address: CONTRACT_ADDRESSES.BLX_VAULT as Address,
      abi: BLX_VAULT_ABI,
      functionName: 'withdraw',
      args: [BigInt(depositIndex)],
    })
  }

  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash,
  })

  return {
    withdraw,
    hash,
    error,
    isPending,
    isConfirming,
    isConfirmed,
  }
}

export function useToggleAutoStake() {
  const { writeContract, data: hash, error, isPending } = useWriteContract()

  const toggleAutoStake = (depositIndex: number) => {
    writeContract({
      address: CONTRACT_ADDRESSES.BLX_VAULT as Address,
      abi: BLX_VAULT_ABI,
      functionName: 'toggleAutoStake',
      args: [BigInt(depositIndex)],
    })
  }

  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash,
  })

  return {
    toggleAutoStake,
    hash,
    error,
    isPending,
    isConfirming,
    isConfirmed,
  }
}

export function useEmergencyWithdraw() {
  const { writeContract, data: hash, error, isPending } = useWriteContract()

  const emergencyWithdraw = () => {
    writeContract({
      address: CONTRACT_ADDRESSES.BLX_VAULT as Address,
      abi: BLX_VAULT_ABI,
      functionName: 'emergencyWithdraw',
    })
  }

  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash,
  })

  return {
    emergencyWithdraw,
    hash,
    error,
    isPending,
    isConfirming,
    isConfirmed,
  }
}
