import { useState, useEffect } from 'react'
import { useAccount, useChainId, useSwitchChain, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseUnits, formatUnits } from 'viem'
import { Card } from '../components/ui'
import { Button } from '../components/ui'
import { Input } from '../components/ui'
import { Coins, TrendingUp, Lock, DollarSign } from 'lucide-react'
import { 
  useTieredStakes, 
  useTieredStaking, 
  useTieredPendingReward,
  useLiquidStaking,
  useLiquidStakingStats,
  useStakedBLXBalance,
  LOCK_OPTIONS 
} from '../hooks/useStaking'
import { useBLXBalance, useBLXAllowance } from '../hooks/useToken'
import { CONTRACT_ADDRESSES, DEVELOPMENT_CHAIN_ID } from '../config/wagmi'
import { ERC20_ABI } from '../contracts/ERC20'

type TabType = 'tiered' | 'liquid' | 'manage'

export function StakingPage() {
  const { address, isConnected } = useAccount()
  const chainId = useChainId()
  const { switchChain } = useSwitchChain()
  const [activeTab, setActiveTab] = useState<TabType>('tiered')
  
  // Staking state
  const [tieredAmount, setTieredAmount] = useState('')
  const [liquidAmount, setLiquidAmount] = useState('')
  const [selectedLockDuration, setSelectedLockDuration] = useState(LOCK_OPTIONS[0].value)
  const [pendingApprovalTx, setPendingApprovalTx] = useState<`0x${string}` | null>(null)
  const [stakingAfterApproval, setStakingAfterApproval] = useState<'tiered' | 'liquid' | null>(null)
  
  // Contract hooks
  const { balance: blxBalance } = useBLXBalance(address)
  const { stakes: tieredStakes, stakesLength, isLoading: tieredLoading } = useTieredStakes(address)
  const { stake: tieredStake, withdraw: tieredWithdraw, isPending: tieredPending } = useTieredStaking()
  const { stake: liquidStake, redeem: liquidRedeem, isPending: liquidPending } = useLiquidStaking()
  const { totalStaked, totalRewards, stTokenAddress } = useLiquidStakingStats()
  const { balance: stBLXBalance } = useStakedBLXBalance(address)

  // Approval hooks
  const { allowanceRaw: tieredAllowance } = useBLXAllowance(address, CONTRACT_ADDRESSES.TIERED_STAKING as `0x${string}`)
  const { allowanceRaw: liquidAllowance } = useBLXAllowance(address, CONTRACT_ADDRESSES.LIQUID_STAKING as `0x${string}`)
  const { writeContract: approveToken, isPending: isApprovePending, data: approvalHash } = useWriteContract()
  const { isSuccess: isApprovalConfirmed } = useWaitForTransactionReceipt({
    hash: approvalHash,
  })

  // Handle automatic staking after approval confirmation
  useEffect(() => {
    if (isApprovalConfirmed && stakingAfterApproval) {
      const executeStaking = async () => {
        try {
          if (stakingAfterApproval === 'tiered') {
            await tieredStake(tieredAmount, selectedLockDuration)
            setTieredAmount('')
          } else if (stakingAfterApproval === 'liquid') {
            await liquidStake(liquidAmount, selectedLockDuration)
            setLiquidAmount('')
          }
        } catch (error) {
          console.error('Auto-staking after approval failed:', error)
        } finally {
          setStakingAfterApproval(null)
          setPendingApprovalTx(null)
        }
      }
      executeStaking()
    }
  }, [isApprovalConfirmed, stakingAfterApproval, tieredStake, liquidStake, tieredAmount, liquidAmount, selectedLockDuration])

  // Check if we're on the correct network
  const isCorrectNetwork = chainId === DEVELOPMENT_CHAIN_ID

  const handleSwitchToAnvil = () => {
    switchChain({ chainId: DEVELOPMENT_CHAIN_ID })
  }

  const tabs = [
    { id: 'tiered', label: 'Tiered Staking', icon: Lock },
    { id: 'liquid', label: 'Liquid Staking', icon: TrendingUp },
    { id: 'manage', label: 'Manage Stakes', icon: Coins },
  ] as const

  const handleTieredStake = async () => {
    if (!address || !tieredAmount || Number(tieredAmount) <= 0) return
    
    try {
      const amount = parseUnits(tieredAmount, 18)
      
      // Check if approval is needed
      if (!tieredAllowance || tieredAllowance < amount) {
        console.log('Approval needed for tiered staking, will auto-stake after approval...')
        setPendingApprovalTx(null)
        setStakingAfterApproval('tiered')
        
        await approveToken({
          address: CONTRACT_ADDRESSES.BLX_TOKEN as `0x${string}`,
          abi: ERC20_ABI,
          functionName: 'approve',
          args: [CONTRACT_ADDRESSES.TIERED_STAKING as `0x${string}`, amount],
        })
        // The useEffect will handle staking after approval confirmation
        return
      }
      
      // If we have sufficient approval, proceed with staking immediately
      await tieredStake(tieredAmount, selectedLockDuration)
      setTieredAmount('')
    } catch (error) {
      console.error('Tiered staking failed:', error)
      setStakingAfterApproval(null)
      setPendingApprovalTx(null)
    }
  }

  const handleLiquidStake = async () => {
    if (!address || !liquidAmount || Number(liquidAmount) <= 0) return
    
    try {
      const amount = parseUnits(liquidAmount, 18)
      
      // Check if approval is needed
      if (!liquidAllowance || liquidAllowance < amount) {
        console.log('Approval needed for liquid staking, will auto-stake after approval...')
        setPendingApprovalTx(null)
        setStakingAfterApproval('liquid')
        
        await approveToken({
          address: CONTRACT_ADDRESSES.BLX_TOKEN as `0x${string}`,
          abi: ERC20_ABI,
          functionName: 'approve',
          args: [CONTRACT_ADDRESSES.LIQUID_STAKING as `0x${string}`, amount],
        })
        // The useEffect will handle staking after approval confirmation
        return
      }
      
      // If we have sufficient approval, proceed with staking immediately
      await liquidStake(liquidAmount, selectedLockDuration)
      setLiquidAmount('')
    } catch (error) {
      console.error('Liquid staking failed:', error)
      setStakingAfterApproval(null)
      setPendingApprovalTx(null)
    }
  }

  const handleWithdraw = async (stakeIndex: number) => {
    try {
      await tieredWithdraw(stakeIndex)
    } catch (error) {
      console.error('Withdraw failed:', error)
    }
  }

  const getSelectedLockOption = () => {
    return LOCK_OPTIONS.find(option => option.value === selectedLockDuration) || LOCK_OPTIONS[0]
  }

  const needsTieredApproval = () => {
    if (!tieredAmount || !tieredAllowance) return false
    try {
      const amount = parseUnits(tieredAmount, 18)
      return tieredAllowance < amount
    } catch {
      return false
    }
  }

  const needsLiquidApproval = () => {
    if (!liquidAmount || !liquidAllowance) return false
    try {
      const amount = parseUnits(liquidAmount, 18)
      return liquidAllowance < amount
    } catch {
      return false
    }
  }

  const formatTimeRemaining = (startTime: bigint, lockDuration: bigint) => {
    const now = Math.floor(Date.now() / 1000)
    const unlockTime = Number(startTime) + Number(lockDuration)
    const remaining = unlockTime - now
    
    if (remaining <= 0) return 'Unlocked'
    
    const days = Math.floor(remaining / (24 * 60 * 60))
    const hours = Math.floor((remaining % (24 * 60 * 60)) / (60 * 60))
    
    if (days > 0) return `${days}d ${hours}h`
    return `${hours}h`
  }

  if (!isConnected) {
    return (
      <div className="min-h-screen bg-gray-950 flex items-center justify-center">
        <Card className="text-center max-w-md">
          <h2 className="text-2xl font-bold mb-4">Connect Your Wallet</h2>
          <p className="text-gray-400 mb-6">
            Please connect your wallet to access BLX Staking
          </p>
          <Button className="w-full">Connect Wallet</Button>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-950">
      <div className="max-w-6xl mx-auto px-4 py-8">
        {/* Header */}
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold mb-4">
            BLX Staking
          </h1>
          <p className="text-gray-400">
            Stake your BLX tokens to earn rewards with flexible lock periods
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
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <Card className="text-center">
            <DollarSign className="w-8 h-8 text-green-500 mx-auto mb-2" />
            <div className="text-2xl font-bold">{blxBalance}</div>
            <div className="text-sm text-gray-400">BLX Balance</div>
          </Card>
          <Card className="text-center">
            <Coins className="w-8 h-8 text-blue-500 mx-auto mb-2" />
            <div className="text-2xl font-bold">{stakesLength}</div>
            <div className="text-sm text-gray-400">Active Stakes</div>
          </Card>
          <Card className="text-center">
            <TrendingUp className="w-8 h-8 text-purple-500 mx-auto mb-2" />
            <div className="text-2xl font-bold">{stBLXBalance}</div>
            <div className="text-sm text-gray-400">stBLX Balance</div>
          </Card>
          <Card className="text-center">
            <Lock className="w-8 h-8 text-orange-500 mx-auto mb-2" />
            <div className="text-2xl font-bold">{totalStaked}</div>
            <div className="text-sm text-gray-400">Total Staked</div>
          </Card>
        </div>

        {/* Tab Navigation */}
        <div className="flex justify-center mb-8">
          <div className="bg-gray-800 rounded-lg p-1 flex space-x-1">
            {tabs.map((tab) => {
              const Icon = tab.icon
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  className={`flex items-center space-x-2 px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                    activeTab === tab.id
                      ? 'bg-blue-600 text-white'
                      : 'text-gray-400 hover:text-white hover:bg-gray-700'
                  }`}
                >
                  <Icon className="w-4 h-4" />
                  <span>{tab.label}</span>
                </button>
              )
            })}
          </div>
        </div>

        {/* Tab Content */}
        <div className="max-w-2xl mx-auto">
          {activeTab === 'tiered' && (
            <Card>
              <h3 className="text-lg font-semibold mb-6">Tiered Staking</h3>
              <p className="text-gray-400 text-sm mb-6">
                Lock your BLX tokens for fixed periods to earn guaranteed rewards. Longer lock periods offer higher APRs.
              </p>
              
              <div className="space-y-6">
                {/* Lock Duration Selection */}
                <div>
                  <label className="block text-sm text-gray-400 mb-3">Choose Lock Period</label>
                  <div className="grid grid-cols-3 gap-3">
                    {LOCK_OPTIONS.map((option) => (
                      <button
                        key={option.value}
                        onClick={() => setSelectedLockDuration(option.value)}
                        className={`p-4 rounded-lg border text-center transition-colors ${
                          selectedLockDuration === option.value
                            ? 'border-blue-500 bg-blue-500/10 text-blue-400'
                            : 'border-gray-700 hover:border-gray-600'
                        }`}
                      >
                        <div className="font-medium">{option.label}</div>
                        <div className="text-sm text-gray-400">APR: {option.apr}</div>
                      </button>
                    ))}
                  </div>
                </div>

                {/* Amount Input */}
                <div>
                  <div className="flex justify-between items-center mb-2">
                    <label className="text-sm text-gray-400">Amount to Stake</label>
                    <span className="text-xs text-gray-400">Balance: {blxBalance} BLX</span>
                  </div>
                  <Input
                    placeholder="0.0"
                    value={tieredAmount}
                    onChange={(e) => setTieredAmount(e.target.value)}
                  />
                </div>

                {/* Staking Info */}
                {tieredAmount && Number(tieredAmount) > 0 && (
                  <div className="bg-gray-800 rounded-lg p-4 space-y-2">
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-400">Lock Period:</span>
                      <span>{getSelectedLockOption().label}</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-400">APR:</span>
                      <span className="text-green-400">{getSelectedLockOption().apr}</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-400">Est. Rewards:</span>
                      <span>
                        {(Number(tieredAmount) * (parseInt(getSelectedLockOption().apr) / 100)).toFixed(4)} BLX
                      </span>
                    </div>
                  </div>
                )}

                <Button
                  onClick={handleTieredStake}
                  className="w-full"
                  disabled={!tieredAmount || Number(tieredAmount) <= 0 || tieredPending || isApprovePending || stakingAfterApproval === 'tiered'}
                >
                  {isApprovePending && stakingAfterApproval === 'tiered' ? 'Approving...' :
                   tieredPending && stakingAfterApproval === 'tiered' ? 'Staking...' :
                   tieredPending ? 'Staking...' :
                   isApprovePending ? 'Processing...' :
                   needsTieredApproval() ? 'Approve & Stake' : 'Stake BLX'}
                </Button>
              </div>
            </Card>
          )}

          {activeTab === 'liquid' && (
            <Card>
              <h3 className="text-lg font-semibold mb-6">Liquid Staking</h3>
              <p className="text-gray-400 text-sm mb-6">
                Stake BLX and receive stBLX tokens that represent your staked position. You can trade stBLX while earning rewards.
              </p>
              
              <div className="space-y-6">
                {/* Protocol Stats */}
                <div className="grid grid-cols-2 gap-4">
                  <div className="bg-gray-800 rounded-lg p-4 text-center">
                    <div className="text-xl font-bold">{totalStaked}</div>
                    <div className="text-sm text-gray-400">Total Staked</div>
                  </div>
                  <div className="bg-gray-800 rounded-lg p-4 text-center">
                    <div className="text-xl font-bold">{totalRewards}</div>
                    <div className="text-sm text-gray-400">Total Rewards</div>
                  </div>
                </div>

                {/* Lock Duration Selection */}
                <div>
                  <label className="block text-sm text-gray-400 mb-3">Choose Lock Period</label>
                  <div className="grid grid-cols-3 gap-3">
                    {LOCK_OPTIONS.map((option) => (
                      <button
                        key={option.value}
                        onClick={() => setSelectedLockDuration(option.value)}
                        className={`p-4 rounded-lg border text-center transition-colors ${
                          selectedLockDuration === option.value
                            ? 'border-blue-500 bg-blue-500/10 text-blue-400'
                            : 'border-gray-700 hover:border-gray-600'
                        }`}
                      >
                        <div className="font-medium">{option.label}</div>
                        <div className="text-sm text-gray-400">APR: {option.apr}</div>
                      </button>
                    ))}
                  </div>
                </div>

                {/* Amount Input */}
                <div>
                  <div className="flex justify-between items-center mb-2">
                    <label className="text-sm text-gray-400">Amount to Stake</label>
                    <span className="text-xs text-gray-400">Balance: {blxBalance} BLX</span>
                  </div>
                  <Input
                    placeholder="0.0"
                    value={liquidAmount}
                    onChange={(e) => setLiquidAmount(e.target.value)}
                  />
                </div>

                {/* Liquid Staking Info */}
                {liquidAmount && Number(liquidAmount) > 0 && (
                  <div className="bg-gray-800 rounded-lg p-4 space-y-2">
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-400">You will receive:</span>
                      <span>~{liquidAmount} stBLX</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-400">Exchange Rate:</span>
                      <span>1 BLX = 1 stBLX</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-400">APR:</span>
                      <span className="text-green-400">{getSelectedLockOption().apr}</span>
                    </div>
                  </div>
                )}

                <Button
                  onClick={handleLiquidStake}
                  className="w-full"
                  disabled={!liquidAmount || Number(liquidAmount) <= 0 || liquidPending || isApprovePending || stakingAfterApproval === 'liquid'}
                >
                  {isApprovePending && stakingAfterApproval === 'liquid' ? 'Approving...' :
                   liquidPending && stakingAfterApproval === 'liquid' ? 'Staking...' :
                   liquidPending ? 'Staking...' :
                   isApprovePending ? 'Processing...' :
                   needsLiquidApproval() ? 'Approve & Stake' : 'Stake for stBLX'}
                </Button>
              </div>
            </Card>
          )}

          {activeTab === 'manage' && (
            <div className="space-y-6">
              <Card>
                <h3 className="text-lg font-semibold mb-6">Your Tiered Stakes</h3>
                
                {tieredLoading ? (
                  <div className="text-center py-8">
                    <div className="text-gray-400">Loading stakes...</div>
                  </div>
                ) : stakesLength === 0 ? (
                  <div className="text-center py-8">
                    <Coins className="w-12 h-12 text-gray-600 mx-auto mb-4" />
                    <div className="text-gray-400">No stakes found</div>
                    <p className="text-sm text-gray-500 mt-2">
                      Start staking to see your positions here
                    </p>
                  </div>
                ) : (
                  <div className="space-y-4">
                    {tieredStakes.map((stake: any, index: number) => {
                      const StakeRewardComponent = () => {
                        const { reward } = useTieredPendingReward(address, index)
                        return <span>{reward} BLX</span>
                      }

                      return (
                        <div key={index} className="border border-gray-700 rounded-lg p-4">
                          <div className="flex justify-between items-start mb-4">
                            <div>
                              <div className="font-medium">
                                {formatUnits(stake.amount, 18)} BLX
                              </div>
                              <div className="text-sm text-gray-400">
                                APR: {Number(stake.apr) / 100}%
                              </div>
                            </div>
                            <div className="text-right">
                              <div className="text-sm text-gray-400">Status</div>
                              <div className={`text-sm ${
                                stake.withdrawn 
                                  ? 'text-red-400' 
                                  : Date.now() / 1000 > Number(stake.startTime) + Number(stake.lockDuration)
                                    ? 'text-green-400'
                                    : 'text-yellow-400'
                              }`}>
                                {stake.withdrawn 
                                  ? 'Withdrawn' 
                                  : Date.now() / 1000 > Number(stake.startTime) + Number(stake.lockDuration)
                                    ? 'Unlocked'
                                    : 'Locked'
                                }
                              </div>
                            </div>
                          </div>
                          
                          <div className="grid grid-cols-2 gap-4 text-sm mb-4">
                            <div>
                              <span className="text-gray-400">Time Remaining:</span>
                              <div>{formatTimeRemaining(stake.startTime, stake.lockDuration)}</div>
                            </div>
                            <div>
                              <span className="text-gray-400">Pending Rewards:</span>
                              <div><StakeRewardComponent /></div>
                            </div>
                          </div>

                          {!stake.withdrawn && (
                            <Button
                              onClick={() => handleWithdraw(index)}
                              variant="outline"
                              size="sm"
                              disabled={tieredPending}
                              className="w-full"
                            >
                              {tieredPending ? 'Processing...' : 'Withdraw'}
                            </Button>
                          )}
                        </div>
                      )
                    })}
                  </div>
                )}
              </Card>

              <Card>
                <h3 className="text-lg font-semibold mb-6">Your Liquid Staking</h3>
                
                <div className="space-y-4">
                  <div className="flex justify-between items-center">
                    <span className="text-gray-400">stBLX Balance:</span>
                    <span className="font-medium">{stBLXBalance} stBLX</span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-gray-400">stBLX Token Address:</span>
                    <span className="text-sm font-mono">
                      {stTokenAddress ? `${stTokenAddress.slice(0, 6)}...${stTokenAddress.slice(-4)}` : '-'}
                    </span>
                  </div>
                  
                  {Number(stBLXBalance) > 0 && (
                    <div className="bg-blue-900/20 border border-blue-500/20 rounded-lg p-3">
                      <p className="text-blue-400 text-sm">
                        💡 You can trade your stBLX tokens while earning staking rewards!
                      </p>
                    </div>
                  )}
                </div>
              </Card>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
