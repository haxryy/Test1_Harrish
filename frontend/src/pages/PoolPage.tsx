import { useState } from 'react'
import { useAccount, useChainId, useSwitchChain } from 'wagmi'
import { Card } from '../components/ui'
import { Button } from '../components/ui'
import { Input } from '../components/ui'
import { BarChart3, Droplets, Plus, Minus, ArrowRightLeft } from 'lucide-react'
import { usePoolStats } from '../hooks/usePoolStats'
import { useUserLPBalance, useSwapFee, useTradingEnabled, useGetAmountOut, useSwap, useAddLiquidityFlow, useRemoveLiquidity } from '../hooks/usePool'
import { useBLXBalance, useUSDCBalance } from '../hooks/useToken'
import { DEVELOPMENT_CHAIN_ID } from '../config/wagmi'
import { anvil } from 'wagmi/chains'

type TabType = 'swap' | 'add' | 'remove' | 'stats'

export function PoolPage() {
  const { address, isConnected } = useAccount()
  const chainId = useChainId()
  const { switchChain } = useSwitchChain()
  const [activeTab, setActiveTab] = useState<TabType>('swap')
  
  // Debug logging
  console.log('PoolPage render:', { address, isConnected, chainId })
  
  // Swap state
  const [fromToken, setFromToken] = useState('BLX')
  const [toToken, setToToken] = useState('USDC')
  const [fromAmount, setFromAmount] = useState('')
  const [toAmount, setToAmount] = useState('')
  
  // Liquidity state
  const [token0Amount, setToken0Amount] = useState('')
  const [token1Amount, setToken1Amount] = useState('')
  const [removePercentage, setRemovePercentage] = useState('25')

  // Contract hooks
  const { totalLiquidityValue, tokenRatio, reserves, totalSupply, isLoading: statsLoading } = usePoolStats()
  const { balance: lpBalance, isLoading: balanceLoading } = useUserLPBalance(address)
  const { balance: blxBalance } = useBLXBalance(address)
  const { balance: usdcBalance } = useUSDCBalance(address)
  const { swapFee } = useSwapFee()
  const { tradingEnabled } = useTradingEnabled()
  const { amountOut } = useGetAmountOut(fromAmount, fromToken === 'BLX')
  const { swap, isPending: swapPending } = useSwap()
  const { executeAddLiquidity, isPending: addPending } = useAddLiquidityFlow()
  const { removeLiquidity, isPending: removePending } = useRemoveLiquidity()

  // Debug contract hook results
  console.log('Contract hooks results:', {
    totalLiquidityValue,
    tokenRatio,
    reserves,
    totalSupply,
    lpBalance,
    swapFee,
    tradingEnabled,
    statsLoading,
    balanceLoading
  })

  // Check if we're on the correct network
  const isCorrectNetwork = chainId === DEVELOPMENT_CHAIN_ID

  const handleSwitchToAnvil = () => {
    switchChain({ chainId: DEVELOPMENT_CHAIN_ID })
  }

  const tabs = [
    { id: 'swap', label: 'Swap', icon: ArrowRightLeft },
    { id: 'add', label: 'Add Liquidity', icon: Plus },
    { id: 'remove', label: 'Remove Liquidity', icon: Minus },
    { id: 'stats', label: 'Pool Stats', icon: BarChart3 },
  ] as const

  const handleSwap = async () => {
    if (!address || !fromAmount || !amountOut) return
    
    try {
      await swap(
        fromAmount,
        (Number(amountOut) * 0.99).toString(), // 1% slippage
        fromToken === 'BLX',
        address
      )
    } catch (error) {
      console.error('Swap failed:', error)
    }
  }

  const handleAddLiquidity = async () => {
    if (!address || !token0Amount || !token1Amount) return
    
    try {
      await executeAddLiquidity(
        token0Amount,
        token1Amount,
        (Number(token0Amount) * 0.99).toString(), // 1% slippage
        (Number(token1Amount) * 0.99).toString(),
        address,
        false // shouldApprove - don't auto-approve
      )
    } catch (error) {
      console.error('Add liquidity failed:', error)
    }
  }

  const handleRemoveLiquidity = async () => {
    if (!address || !lpBalance) return
    
    const liquidityToRemove = (Number(lpBalance) * Number(removePercentage) / 100).toString()
    
    try {
      await removeLiquidity(
        liquidityToRemove,
        '0', // Min amounts - should calculate properly
        '0',
        address
      )
    } catch (error) {
      console.error('Remove liquidity failed:', error)
    }
  }

  const swapTokens = () => {
    setFromToken(toToken)
    setToToken(fromToken)
    setFromAmount(toAmount)
    setToAmount(fromAmount)
  }

  // Update toAmount when fromAmount changes
  if (fromAmount && amountOut && toAmount !== amountOut) {
    setToAmount(amountOut)
  }

  if (!isConnected) {
    return (
      <div className="min-h-screen bg-gray-950 flex items-center justify-center">
        <Card className="text-center max-w-md">
          <h2 className="text-2xl font-bold mb-4">Connect Your Wallet</h2>
          <p className="text-gray-400 mb-6">
            Please connect your wallet to access the BLX Pool
          </p>
          <Button className="w-full">Connect Wallet</Button>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-950">
      <div className="max-w-4xl mx-auto px-4 py-8">
        {/* Header */}
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold mb-4">
            BLX Pool
          </h1>
          <p className="text-gray-400">
            Trade tokens and provide liquidity to earn fees
          </p>
          {!isCorrectNetwork && isConnected && (
            <div className="mt-4 p-3 bg-red-900/20 border border-red-500/20 rounded-lg">
              <p className="text-red-400 text-sm mb-2">⚠️ Wrong network detected. Please switch to Anvil (Chain ID: {DEVELOPMENT_CHAIN_ID})</p>
              <Button onClick={handleSwitchToAnvil} size="sm" variant="outline">
                Switch to Anvil
              </Button>
            </div>
          )}
          {!tradingEnabled && (
            <div className="mt-4 p-3 bg-yellow-900/20 border border-yellow-500/20 rounded-lg">
              <p className="text-yellow-400 text-sm">⚠️ Trading is currently disabled</p>
            </div>
          )}
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
        <div className="max-w-md mx-auto">
          {activeTab === 'swap' && (
            <Card>
              <h3 className="text-lg font-semibold mb-6">Swap Tokens</h3>
              
              <div className="space-y-4">
                {/* From Token */}
                <div>
                  <div className="flex justify-between items-center mb-2">
                    <label className="text-sm text-gray-400">From</label>
                    <span className="text-sm text-gray-400">
                      Balance: {fromToken === 'BLX' ? blxBalance : usdcBalance}
                    </span>
                  </div>
                  <div className="flex space-x-2">
                    <Input
                      placeholder="0.0"
                      value={fromAmount}
                      onChange={(e) => setFromAmount(e.target.value)}
                      className="flex-1"
                    />
                    <select 
                      value={fromToken}
                      onChange={(e) => setFromToken(e.target.value)}
                      className="bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white"
                    >
                      <option value="BLX">BLX</option>
                      <option value="USDC">USDC</option>
                    </select>
                  </div>
                </div>

                {/* Swap Button */}
                <div className="flex justify-center">
                  <button
                    onClick={swapTokens}
                    className="bg-gray-800 hover:bg-gray-700 rounded-full p-2 transition-colors"
                  >
                    <ArrowRightLeft className="w-4 h-4" />
                  </button>
                </div>

                {/* To Token */}
                <div>
                  <div className="flex justify-between items-center mb-2">
                    <label className="text-sm text-gray-400">To</label>
                    <span className="text-sm text-gray-400">
                      Balance: {toToken === 'BLX' ? blxBalance : usdcBalance}
                    </span>
                  </div>
                  <div className="flex space-x-2">
                    <Input
                      placeholder="0.0"
                      value={toAmount}
                      onChange={(e) => setToAmount(e.target.value)}
                      className="flex-1"
                      readOnly
                    />
                    <select 
                      value={toToken}
                      onChange={(e) => setToToken(e.target.value)}
                      className="bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white"
                    >
                      <option value="BLX">BLX</option>
                      <option value="USDC">USDC</option>
                    </select>
                  </div>
                </div>

                {/* Swap Info */}
                {fromAmount && amountOut && (
                  <div className="bg-gray-800 rounded-lg p-3 text-sm">
                    <div className="flex justify-between">
                      <span className="text-gray-400">Rate:</span>
                      <span>1 {fromToken} = {(Number(amountOut) / Number(fromAmount)).toFixed(6)} {toToken}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-400">Fee:</span>
                      <span>{swapFee}%</span>
                    </div>
                  </div>
                )}

                <Button
                  onClick={handleSwap}
                  className="w-full"
                  disabled={!fromAmount || !toAmount || swapPending || !tradingEnabled}
                >
                  {swapPending ? 'Swapping...' : 'Swap'}
                </Button>
              </div>
            </Card>
          )}

          {activeTab === 'add' && (
            <Card>
              <h3 className="text-lg font-semibold mb-6">Add Liquidity</h3>
              
              <div className="space-y-4">
                <div>
                  <div className="flex justify-between items-center mb-2">
                    <label className="text-sm text-gray-400">BLX Amount</label>
                    <span className="text-xs text-gray-400">Balance: {blxBalance}</span>
                  </div>
                  <Input
                    placeholder="0.0"
                    value={token0Amount}
                    onChange={(e) => setToken0Amount(e.target.value)}
                  />
                </div>
                
                <div>
                  <div className="flex justify-between items-center mb-2">
                    <label className="text-sm text-gray-400">USDC Amount</label>
                    <span className="text-xs text-gray-400">Balance: {usdcBalance}</span>
                  </div>
                  <Input
                    placeholder="0.0"
                    value={token1Amount}
                    onChange={(e) => setToken1Amount(e.target.value)}
                  />
                </div>

                <div className="bg-gray-800 rounded-lg p-4">
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-400">Pool Ratio:</span>
                    <span>{tokenRatio.toFixed(4)} BLX/USDC</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-400">Your LP Tokens:</span>
                    <span>{balanceLoading ? 'Loading...' : lpBalance}</span>
                  </div>
                </div>

                <div className="bg-blue-900/20 border border-blue-500/20 rounded-lg p-3">
                  <p className="text-blue-400 text-sm">
                    ℹ️ Make sure to approve tokens before adding liquidity
                  </p>
                </div>

                <Button
                  onClick={handleAddLiquidity}
                  className="w-full"
                  disabled={!token0Amount || !token1Amount || addPending}
                >
                  {addPending ? 'Processing...' : 'Add Liquidity'}
                </Button>
              </div>
            </Card>
          )}

          {activeTab === 'remove' && (
            <Card>
              <h3 className="text-lg font-semibold mb-6">Remove Liquidity</h3>
              
              <div className="space-y-4">
                <div>
                  <label className="block text-sm text-gray-400 mb-2">
                    Amount to Remove: {removePercentage}%
                  </label>
                  <input
                    type="range"
                    min="1"
                    max="100"
                    value={removePercentage}
                    onChange={(e) => setRemovePercentage(e.target.value)}
                    className="w-full"
                  />
                  <div className="flex justify-between text-xs text-gray-400 mt-1">
                    <span>1%</span>
                    <span>25%</span>
                    <span>50%</span>
                    <span>75%</span>
                    <span>100%</span>
                  </div>
                </div>

                <div className="grid grid-cols-4 gap-2">
                  {['25', '50', '75', '100'].map((percentage) => (
                    <Button
                      key={percentage}
                      variant="outline"
                      size="sm"
                      onClick={() => setRemovePercentage(percentage)}
                      className={removePercentage === percentage ? 'bg-blue-600 border-blue-600' : ''}
                    >
                      {percentage}%
                    </Button>
                  ))}
                </div>

                <div className="bg-gray-800 rounded-lg p-4 space-y-2">
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-400">Your LP Balance:</span>
                    <span>{balanceLoading ? 'Loading...' : `${lpBalance} LP`}</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-400">LP to Remove:</span>
                    <span>{((Number(lpBalance || 0) * Number(removePercentage)) / 100).toFixed(6)} LP</span>
                  </div>
                </div>

                <Button
                  onClick={handleRemoveLiquidity}
                  variant="secondary"
                  className="w-full"
                  disabled={removePending || Number(lpBalance || 0) === 0}
                >
                  {removePending ? 'Removing...' : 'Remove Liquidity'}
                </Button>
              </div>
            </Card>
          )}

          {activeTab === 'stats' && (
            <Card>
              <h3 className="text-lg font-semibold mb-6">Pool Statistics</h3>
              
              <div className="space-y-6">
                <div className="text-center">
                  <Droplets className="w-16 h-16 text-blue-500 mx-auto mb-4" />
                  <h4 className="text-xl font-semibold mb-2">BLX/USDC Pool</h4>
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div className="bg-gray-800 rounded-lg p-4 text-center">
                    <div className="text-2xl font-bold">
                      {statsLoading ? '...' : `$${totalLiquidityValue.toFixed(2)}`}
                    </div>
                    <div className="text-sm text-gray-400">Total Liquidity</div>
                  </div>
                  <div className="bg-gray-800 rounded-lg p-4 text-center">
                    <div className="text-2xl font-bold">{swapFee}%</div>
                    <div className="text-sm text-gray-400">Trading Fee</div>
                  </div>
                </div>

                <div className="space-y-3">
                  <div className="flex justify-between">
                    <span className="text-gray-400">BLX Reserve:</span>
                    <span>{statsLoading ? 'Loading...' : `${reserves?.token0 || '0'} BLX`}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-400">USDC Reserve:</span>
                    <span>{statsLoading ? 'Loading...' : `${reserves?.token1 || '0'} USDC`}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-400">Pool Ratio:</span>
                    <span>{statsLoading ? 'Loading...' : `${(tokenRatio * 100 / (tokenRatio + 1)).toFixed(1)}% BLX / ${(100 / (tokenRatio + 1)).toFixed(1)}% USDC`}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-400">Total LP Supply:</span>
                    <span>{statsLoading ? 'Loading...' : `${totalSupply} LP`}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-400">Your LP Tokens:</span>
                    <span>{balanceLoading ? 'Loading...' : `${lpBalance} LP`}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-400">Your Pool Share:</span>
                    <span>
                      {balanceLoading || statsLoading 
                        ? 'Loading...' 
                        : `${((Number(lpBalance || 0) / Number(totalSupply || 1)) * 100).toFixed(4)}%`
                      }
                    </span>
                  </div>
                </div>
              </div>
            </Card>
          )}
        </div>
      </div>
    </div>
  )
}
