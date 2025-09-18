import { useState, useEffect } from 'react'
import { useAccount, useBalance, useReadContract, useWriteContract, useWaitForTransactionReceipt, useChainId, useSwitchChain } from 'wagmi'
import { parseUnits, formatUnits, type Address } from 'viem'
import { CONTRACT_ADDRESSES, DEVELOPMENT_CHAIN_ID } from '../config/wagmi'
import { ERC20_ABI } from '../contracts/ERC20'
import { Card, Button } from '../components/ui'
import {
  useVaultBalance,
  useUserDeposits,
  useVaultDeposit,
  useVaultWithdraw,
  useToggleAutoStake,
  useVaultConstants,
  useTotalVaultBalance,
  useCalculateWithdrawalAmount,
  useIsDepositLocked
} from '../hooks/useVault'

interface Deposit {
  amount: bigint
  depositTime: bigint
  lockUntil: bigint
  autoStake: boolean
  withdrawn: boolean
}

export function VaultPage() {
  const { address: userAddress, isConnected } = useAccount()
  const chainId = useChainId()
  const { switchChain } = useSwitchChain()
  const [depositAmount, setDepositAmount] = useState('')
  const [selectedLockPeriod, setSelectedLockPeriod] = useState<number>(0)
  const [autoStakeEnabled, setAutoStakeEnabled] = useState(false)
  const [depositAfterApproval, setDepositAfterApproval] = useState(false)

  const isCorrectNetwork = chainId === DEVELOPMENT_CHAIN_ID
  
  const handleSwitchToAnvil = () => {
    switchChain({ chainId: DEVELOPMENT_CHAIN_ID })
  }

  // Token balance and allowance
  const { data: blxBalance } = useBalance({
    address: userAddress,
    token: CONTRACT_ADDRESSES.BLX_TOKEN as Address,
  })

  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: CONTRACT_ADDRESSES.BLX_TOKEN as Address,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: userAddress ? [userAddress, CONTRACT_ADDRESSES.BLX_VAULT as Address] : undefined,
    query: {
      enabled: !!userAddress,
    },
  })

  const { writeContract: approveToken, isPending: isApprovePending, data: approveHash } = useWriteContract()
  
  // Wait for approval transaction
  const { isLoading: isApproveConfirming, isSuccess: isApproveConfirmed } = useWaitForTransactionReceipt({
    hash: approveHash,
  })
  
  // Vault hooks
  const { data: vaultBalance } = useVaultBalance(userAddress)
  const { data: userDeposits } = useUserDeposits(userAddress)
  const { data: totalVaultBalance } = useTotalVaultBalance()
  const { NO_LOCK, LOCK_7_DAYS, LOCK_30_DAYS, LOCK_90_DAYS } = useVaultConstants()
  
  const {
    deposit,
    isPending: isDepositPending,
    error: depositError
  } = useVaultDeposit()
  
  const {
    withdraw,
    isPending: isWithdrawPending,
  } = useVaultWithdraw()
  
  const { toggleAutoStake } = useToggleAutoStake()

  // Refresh allowance and auto-deposit after approval is confirmed
  useEffect(() => {
    if (isApproveConfirmed) {
      refetchAllowance()
      
      // Auto-deposit after approval
      if (depositAfterApproval && depositAmount && userAddress) {
        const executeDeposit = async () => {
          try {
            const amount = parseUnits(depositAmount, 18)
            const lockPeriod = getLockPeriodValue(selectedLockPeriod)
            console.log('Auto-depositing after approval...', { amount, lockPeriod, autoStakeEnabled })
            await deposit(amount, lockPeriod, autoStakeEnabled)
            setDepositAmount('')
          } catch (error) {
            console.error('Auto-deposit after approval failed:', error)
          } finally {
            setDepositAfterApproval(false)
          }
        }
        executeDeposit()
      }
    }
  }, [isApproveConfirmed, refetchAllowance, depositAfterApproval, depositAmount, userAddress, selectedLockPeriod, autoStakeEnabled, deposit])

  // Lock period options
  const lockPeriods = [
    { value: 0, label: 'No Lock', description: 'Withdraw anytime' },
    { value: 1, label: '7 Days', description: '3% bonus rewards' },
    { value: 2, label: '30 Days', description: '12% bonus rewards' },
    { value: 3, label: '90 Days', description: '30% bonus rewards' }
  ]

  const getLockPeriodValue = (index: number): bigint => {
    switch (index) {
      case 0: return NO_LOCK || 0n
      case 1: return LOCK_7_DAYS || 604800n
      case 2: return LOCK_30_DAYS || 2592000n
      case 3: return LOCK_90_DAYS || 7776000n
      default: return NO_LOCK || 0n
    }
  }

  const handleDeposit = async () => {
    if (!depositAmount || !userAddress) return

    try {
      const amount = parseUnits(depositAmount, 18)
      
      // Check if we need approval first
      if (needsApproval()) {
        console.log('Approval needed, will auto-deposit after approval...')
        setDepositAfterApproval(true)
        
        // Approve only the exact amount needed
        await approveToken({
          address: CONTRACT_ADDRESSES.BLX_TOKEN as Address,
          abi: ERC20_ABI,
          functionName: 'approve',
          args: [CONTRACT_ADDRESSES.BLX_VAULT as Address, amount],
        })
        // The useEffect will handle deposit after approval confirmation
        return
      }
      
      // If we have sufficient approval, proceed with deposit immediately
      const lockPeriod = getLockPeriodValue(selectedLockPeriod)
      console.log('Proceeding with deposit...', { amount, lockPeriod, autoStakeEnabled })
      await deposit(amount, lockPeriod, autoStakeEnabled)
      setDepositAmount('')
    } catch (error) {
      console.error('Deposit failed:', error)
      setDepositAfterApproval(false)
    }
  }

  const handleWithdraw = (depositIndex: number) => {
    withdraw(depositIndex)
  }

  const formatAmount = (amount: bigint) => {
    return parseFloat(formatUnits(amount, 18)).toFixed(4)
  }

  const isAmountValid = () => {
    if (!depositAmount || !blxBalance) return false
    const amount = parseUnits(depositAmount, 18)
    return amount > 0n && amount <= blxBalance.value
  }

  const needsApproval = () => {
    if (!depositAmount) return false
    try {
      const amount = parseUnits(depositAmount, 18)
      // If allowance is undefined, null, or 0, we definitely need approval
      if (allowance === undefined || allowance === null || allowance === 0n) {
        console.log('No allowance found, approval needed')
        return true
      }
      // If allowance is less than amount, we need approval
      const needsApprove = allowance < amount
      console.log(`Allowance: ${allowance}, Amount: ${amount}, Needs approval: ${needsApprove}`)
      return needsApprove
    } catch (error) {
      console.error('Error in needsApproval:', error)
      return true // If there's an error, require approval to be safe
    }
  }

  return (
    <div className="min-h-screen bg-gray-950">
      <div className="max-w-4xl mx-auto px-4 py-8">
        {/* Header */}
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold mb-4">
            BLX Vault
          </h1>
          <p className="text-gray-400">
            Deposit BLX tokens to automatically stake and earn rewards with time-locked vaults
          </p>
          {!isCorrectNetwork && isConnected && (
            <div className="mt-4 p-3 bg-red-900/20 border border-red-500/20 rounded-lg">
              <p className="text-red-400 text-sm mb-2">⚠️ Wrong network detected. Please switch to Anvil (Chain ID: {DEVELOPMENT_CHAIN_ID})</p>
              <Button onClick={handleSwitchToAnvil} size="sm" variant="outline">
                Switch to Anvil
              </Button>
            </div>
          )}
        </div>

        {/* Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <Card className="text-center">
            <h3 className="text-sm font-medium text-gray-400 mb-2">Your Vault Balance</h3>
            <p className="text-2xl font-bold">
              {vaultBalance ? formatAmount(vaultBalance) : '0.0000'} BLX
            </p>
          </Card>
          
          <Card className="text-center">
            <h3 className="text-sm font-medium text-gray-400 mb-2">Total Vault TVL</h3>
            <p className="text-2xl font-bold">
              {totalVaultBalance ? formatAmount(totalVaultBalance) : '0.0000'} BLX
            </p>
          </Card>
          
          <Card className="text-center">
            <h3 className="text-sm font-medium text-gray-400 mb-2">Your Wallet Balance</h3>
            <p className="text-2xl font-bold">
              {blxBalance ? formatAmount(blxBalance.value) : '0.0000'} BLX
            </p>
          </Card>
        </div>

        {!isConnected ? (
          <div className="text-center py-12">
            <Card className="text-center max-w-md mx-auto">
              <h2 className="text-2xl font-bold mb-4">Connect Your Wallet</h2>
              <p className="text-gray-400 mb-6">
                Please connect your wallet to access the BLX Vault
              </p>
              <Button className="w-full">Connect Wallet</Button>
            </Card>
          </div>
        ) : (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
            {/* Deposit Section */}
            <Card>
              <h2 className="text-xl font-bold mb-6">New Deposit</h2>
                
                <div className="space-y-6">
                  {/* Amount Input */}
                  <div>
                    <label className="block text-sm font-medium text-gray-400 mb-2">
                      Deposit Amount
                    </label>
                    <div className="relative">
                      <input
                        type="number"
                        value={depositAmount}
                        onChange={(e) => setDepositAmount(e.target.value)}
                        placeholder="0.0"
                        className="w-full px-4 py-3 bg-gray-800 border border-gray-600 rounded-lg placeholder-gray-400 focus:border-blue-400 focus:outline-none"
                      />
                      <span className="absolute right-3 top-3 text-gray-400">BLX</span>
                    </div>
                    <div className="flex justify-between items-center mt-2">
                      <button
                        onClick={() => setDepositAmount(blxBalance ? formatUnits(blxBalance.value, 18) : '0')}
                        className="text-sm text-blue-400 hover:text-blue-300"
                      >
                        Use Max: {blxBalance ? formatAmount(blxBalance.value) : '0.0000'} BLX
                      </button>
                      {allowance && (
                        <div className="text-xs text-gray-500">
                          Approved: {formatAmount(allowance)} BLX
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Lock Period Selection */}
                  <div>
                    <label className="block text-sm font-medium text-gray-400 mb-3">
                      Lock Period (Higher locks = Better rewards)
                    </label>
                    <div className="grid grid-cols-2 gap-3">
                      {lockPeriods.map((period, index) => (
                        <button
                          key={index}
                          onClick={() => setSelectedLockPeriod(index)}
                          className={`p-3 rounded-lg border text-left transition-all ${
                            selectedLockPeriod === index
                              ? 'border-blue-400 bg-blue-400/20'
                              : 'border-gray-600 bg-gray-800 hover:border-gray-500'
                          }`}
                        >
                          <div className="font-medium">{period.label}</div>
                          <div className="text-xs text-gray-400">{period.description}</div>
                        </button>
                      ))}
                    </div>
                  </div>

                  {/* Auto-Stake Toggle */}
                  <div className="flex items-center justify-between p-4 bg-gray-800 rounded-lg">
                    <div>
                      <div className="font-medium">Auto-Stake Rewards</div>
                      <div className="text-sm text-gray-400">Automatically stake earned rewards</div>
                    </div>
                    <button
                      onClick={() => setAutoStakeEnabled(!autoStakeEnabled)}
                      className={`relative w-12 h-6 rounded-full transition-colors ${
                        autoStakeEnabled ? 'bg-blue-500' : 'bg-gray-600'
                      }`}
                    >
                      <div
                        className={`absolute w-4 h-4 bg-white rounded-full top-1 transition-transform ${
                          autoStakeEnabled ? 'translate-x-7' : 'translate-x-1'
                        }`}
                      />
                    </button>
                  </div>

                  {/* Debug Info - Remove in production */}
                  {depositAmount && (
                    <div className="p-3 bg-yellow-900/20 border border-yellow-600 rounded-lg text-sm">
                      <div>Debug Info:</div>
                      <div>Deposit Amount: {depositAmount} BLX</div>
                      <div>Current Allowance: {allowance ? formatAmount(allowance) : 'Loading...'} BLX</div>
                      <div>Needs Approval: {needsApproval() ? 'YES' : 'NO'}</div>
                      <div>Vault Address: {CONTRACT_ADDRESSES.BLX_VAULT}</div>
                      <div>BLX Address: {CONTRACT_ADDRESSES.BLX_TOKEN}</div>
                    </div>
                  )}

                  {/* Deposit Button */}
                  <div className="space-y-3">
                    <Button
                      onClick={handleDeposit}
                      disabled={!isAmountValid() || isDepositPending || isApprovePending || isApproveConfirming || depositAfterApproval}
                      className="w-full"
                    >
                      {isApprovePending && depositAfterApproval ? 'Approving...' : 
                       isApproveConfirming && depositAfterApproval ? 'Confirming Approval...' :
                       isDepositPending && depositAfterApproval ? 'Depositing...' :
                       isDepositPending ? 'Depositing...' :
                       isApprovePending ? 'Processing...' :
                       needsApproval() ? 'Approve & Deposit' : 'Deposit to Vault'}
                    </Button>
                  </div>

                  {depositError && (
                    <div className="text-red-400 text-sm">
                      Error: {depositError.message}
                    </div>
                  )}
                </div>
            </Card>

            {/* Manage Deposits Section */}
            <Card>
              <h2 className="text-xl font-bold mb-6">Your Deposits</h2>
                
                <div className="space-y-4">
                  {userDeposits && userDeposits.length > 0 ? (
                    userDeposits.map((deposit: Deposit, index: number) => (
                      <DepositCard
                        key={index}
                        deposit={deposit}
                        index={index}
                        onWithdraw={handleWithdraw}
                        onToggleAutoStake={toggleAutoStake}
                        userAddress={userAddress!}
                        isWithdrawPending={isWithdrawPending}
                      />
                    ))
                  ) : (
                    <div className="text-center py-8 text-gray-400">
                      <p>No deposits found</p>
                      <p className="text-sm">Make your first deposit to get started</p>
                    </div>
                  )}
                </div>
            </Card>
          </div>
        )}
      </div>
    </div>
  )
}

interface DepositCardProps {
  deposit: Deposit
  index: number
  onWithdraw: (index: number) => void
  onToggleAutoStake: (index: number) => void
  userAddress: Address
  isWithdrawPending: boolean
}

function DepositCard({ deposit, index, onWithdraw, onToggleAutoStake, userAddress, isWithdrawPending }: DepositCardProps) {
  const { data: isLocked } = useIsDepositLocked(userAddress, index)
  const { data: withdrawalInfo } = useCalculateWithdrawalAmount(userAddress, index)
  
  const isWithdrawable = !deposit.withdrawn && !isLocked
  const lockUntilDate = new Date(Number(deposit.lockUntil) * 1000)
  const isExpired = Date.now() > lockUntilDate.getTime()

  return (
    <Card>
      <div className="flex justify-between items-start mb-3">
        <div>
          <div className="font-medium">
            {parseFloat(formatUnits(deposit.amount, 18)).toFixed(4)} BLX
          </div>
          <div className="text-sm text-gray-400">
            Deposited: {new Date(Number(deposit.depositTime) * 1000).toLocaleDateString()}
          </div>
        </div>
        <div className="text-right">
          <div className={`text-sm font-medium ${deposit.autoStake ? 'text-green-400' : 'text-gray-400'}`}>
            {deposit.autoStake ? 'Auto-Stake ON' : 'Auto-Stake OFF'}
          </div>
          {deposit.lockUntil > 0 && (
            <div className={`text-xs ${isExpired ? 'text-green-400' : 'text-yellow-400'}`}>
              {isExpired ? 'Lock Expired' : `Locked until ${lockUntilDate.toLocaleDateString()}`}
            </div>
          )}
        </div>
      </div>

      {withdrawalInfo && (
        <div className="mb-3 p-2 bg-gray-800 rounded text-sm">
          <div>Withdrawal Amount: {formatUnits(withdrawalInfo[0], 18)} BLX</div>
          {withdrawalInfo[1] > 0n && (
            <div className="text-red-400">Fee: {formatUnits(withdrawalInfo[1], 18)} BLX</div>
          )}
        </div>
      )}

      <div className="flex gap-2">
        <Button
          onClick={() => onWithdraw(index)}
          disabled={!isWithdrawable || deposit.withdrawn || isWithdrawPending}
          variant="secondary"
          size="sm"
          className="flex-1 bg-red-600 hover:bg-red-700"
        >
          {deposit.withdrawn ? 'Withdrawn' : 'Withdraw'}
        </Button>
        
        <Button
          onClick={() => onToggleAutoStake(index)}
          disabled={deposit.withdrawn}
          size="sm"
          className="px-4"
        >
          Toggle Stake
        </Button>
      </div>
    </Card>
  )
}
