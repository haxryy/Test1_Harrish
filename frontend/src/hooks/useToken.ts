import { useReadContract, useWriteContract } from 'wagmi'
import { formatUnits, parseUnits } from 'viem'
import { ERC20_ABI } from '../contracts/ERC20'
import { CONTRACT_ADDRESSES, TOKEN_CONFIG } from '../config/wagmi'

// Hook to get token balance
export function useTokenBalance(tokenAddress: `0x${string}`, userAddress?: `0x${string}`) {
  const { data, error, isLoading } = useReadContract({
    address: tokenAddress,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: userAddress ? [userAddress] : undefined,
    query: {
      enabled: !!userAddress
    }
  })

  // Determine decimals based on token address
  const decimals = tokenAddress.toLowerCase() === CONTRACT_ADDRESSES.BLX_TOKEN.toLowerCase() 
    ? TOKEN_CONFIG.BLX.decimals 
    : TOKEN_CONFIG.USDC.decimals

  return {
    balance: data ? formatUnits(data, decimals) : '0',
    balanceRaw: data,
    error,
    isLoading
  }
}

// Hook to get token allowance
export function useTokenAllowance(
  tokenAddress: `0x${string}`, 
  ownerAddress?: `0x${string}`, 
  spenderAddress?: `0x${string}`
) {
  const { data, error, isLoading } = useReadContract({
    address: tokenAddress,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: ownerAddress && spenderAddress ? [ownerAddress, spenderAddress] : undefined,
    query: {
      enabled: !!(ownerAddress && spenderAddress)
    }
  })

  // Determine decimals based on token address
  const decimals = tokenAddress.toLowerCase() === CONTRACT_ADDRESSES.BLX_TOKEN.toLowerCase() 
    ? TOKEN_CONFIG.BLX.decimals 
    : TOKEN_CONFIG.USDC.decimals

  return {
    allowance: data ? formatUnits(data, decimals) : '0',
    allowanceRaw: data,
    error,
    isLoading
  }
}

// Hook for token approval
export function useTokenApproval() {
  const { writeContract, isPending, error } = useWriteContract()

  const approve = async (
    tokenAddress: `0x${string}`,
    spenderAddress: `0x${string}`,
    amount: string
  ) => {
    try {
      // Determine decimals based on token address
      const decimals = tokenAddress.toLowerCase() === CONTRACT_ADDRESSES.BLX_TOKEN.toLowerCase() 
        ? TOKEN_CONFIG.BLX.decimals 
        : TOKEN_CONFIG.USDC.decimals

      await writeContract({
        address: tokenAddress,
        abi: ERC20_ABI,
        functionName: 'approve',
        args: [spenderAddress, parseUnits(amount, decimals)]
      })
    } catch (err) {
      console.error('Approval error:', err)
      throw err
    }
  }

  return {
    approve,
    isPending,
    error
  }
}

// Hook to check if approval is needed for a specific amount
export function useNeedsApproval(
  tokenAddress: `0x${string}`,
  ownerAddress?: `0x${string}`,
  spenderAddress?: `0x${string}`,
  requiredAmount?: string
) {
  const { allowance, allowanceRaw } = useTokenAllowance(tokenAddress, ownerAddress, spenderAddress)
  
  if (!allowanceRaw || !requiredAmount) {
    return { needsApproval: false, currentAllowance: '0' }
  }

  // Determine decimals based on token address
  const decimals = tokenAddress.toLowerCase() === CONTRACT_ADDRESSES.BLX_TOKEN.toLowerCase() 
    ? TOKEN_CONFIG.BLX.decimals 
    : TOKEN_CONFIG.USDC.decimals

  const requiredAmountWei = parseUnits(requiredAmount, decimals)
  const needsApproval = allowanceRaw < requiredAmountWei

  return {
    needsApproval,
    currentAllowance: allowance,
    currentAllowanceRaw: allowanceRaw
  }
}

// Convenience hooks for specific tokens
export function useBLXBalance(userAddress?: `0x${string}`) {
  return useTokenBalance(CONTRACT_ADDRESSES.BLX_TOKEN as `0x${string}`, userAddress)
}

export function useUSDCBalance(userAddress?: `0x${string}`) {
  return useTokenBalance(CONTRACT_ADDRESSES.USDC_TOKEN as `0x${string}`, userAddress)
}

export function useBLXAllowance(ownerAddress?: `0x${string}`, spenderAddress?: `0x${string}`) {
  return useTokenAllowance(CONTRACT_ADDRESSES.BLX_TOKEN as `0x${string}`, ownerAddress, spenderAddress)
}

export function useUSDCAllowance(ownerAddress?: `0x${string}`, spenderAddress?: `0x${string}`) {
  return useTokenAllowance(CONTRACT_ADDRESSES.USDC_TOKEN as `0x${string}`, ownerAddress, spenderAddress)
}
