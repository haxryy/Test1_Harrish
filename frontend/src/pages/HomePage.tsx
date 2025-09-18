import { useAccount } from 'wagmi'
import { Card, Button } from '../components/ui'
import { Link } from 'react-router-dom'
import { Droplets, ArrowRightLeft, Plus, Minus, TrendingUp } from 'lucide-react'

export function HomePage() {
  const { isConnected } = useAccount()

  return (
    <div className="min-h-screen bg-gray-950">
      <div className="max-w-6xl mx-auto px-4 py-12">
        {/* Hero Section */}
        <div className="text-center mb-10">
          <h1 className="text-6xl font-bold mb-6">
            Welcome to Blume
          </h1>
          <p className="text-xl text-gray-400 mb-8 max-w-2xl mx-auto">
            A decentralized platform for seamless token swapping, staking, and vaults. Trade, earn, and participate in DeFi with ease.
          </p>
          {!isConnected ? (
            <div className="bg-yellow-500/10 border border-yellow-500/20 rounded-lg p-4 max-w-md mx-auto">
              <p className="text-yellow-400 text-sm">
                Connect your wallet to start exploring Blume
              </p>
            </div>
          ) : (
            <Link to="/pool">
              <Button size="lg" className="text-lg px-8 py-4">
                Launch App
              </Button>
            </Link>
          )}
        </div>

        {/* About Section */}
        <div className="mb-16 max-w-3xl mx-auto text-center">
          <h2 className="text-2xl font-semibold mb-2 text-white">About Blume</h2>
          <p className="text-gray-400 text-base">
            Blume is your all-in-one DeFi platform. Swap tokens, provide liquidity in pools, stake your assets to earn rewards, and utilize vaults for advanced yield strategies—all in one place.
          </p>
        </div>

        {/* Features Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-16">
          <Card className="text-center">
            <div className="flex items-center justify-center w-12 h-12 bg-blue-600 rounded-full mx-auto mb-4">
              <ArrowRightLeft className="w-6 h-6 text-white" />
            </div>
            <h3 className="text-lg font-semibold mb-2">Pools</h3>
            <p className="text-gray-400 text-sm">
              Trade tokens instantly and provide liquidity to earn fees in our secure pools.
            </p>
          </Card>

          <Card className="text-center">
            <div className="flex items-center justify-center w-12 h-12 bg-green-600 rounded-full mx-auto mb-4">
              <TrendingUp className="w-6 h-6 text-white" />
            </div>
            <h3 className="text-lg font-semibold mb-2">Staking</h3>
            <p className="text-gray-400 text-sm">
              Stake your tokens to earn additional rewards and participate in protocol growth.
            </p>
          </Card>

          <Card className="text-center">
            <div className="flex items-center justify-center w-12 h-12 bg-purple-600 rounded-full mx-auto mb-4">
              <Droplets className="w-6 h-6 text-white" />
            </div>
            <h3 className="text-lg font-semibold mb-2">Vaults</h3>
            <p className="text-gray-400 text-sm">
              Deposit assets into vaults for automated yield strategies and optimized returns.
            </p>
          </Card>

          <Card className="text-center">
            <div className="flex items-center justify-center w-12 h-12 bg-yellow-600 rounded-full mx-auto mb-4">
              <Plus className="w-6 h-6 text-white" />
            </div>
            <h3 className="text-lg font-semibold mb-2">All-in-One DeFi</h3>
            <p className="text-gray-400 text-sm">
              Access pools, staking, and vaults from a single, easy-to-use interface.
            </p>
          </Card>
        </div>

        {/* Stats Section */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <Card className="text-center">
            <div className="flex items-center justify-center w-16 h-16 bg-gradient-to-r from-blue-500 to-purple-600 rounded-full mx-auto mb-4">
              <Droplets className="w-8 h-8 text-white" />
            </div>
            <h3 className="text-2xl font-bold mb-2">$0</h3>
            <p className="text-gray-400">Total Value Locked</p>
          </Card>

          <Card className="text-center">
            <div className="flex items-center justify-center w-16 h-16 bg-gradient-to-r from-green-500 to-blue-600 rounded-full mx-auto mb-4">
              <ArrowRightLeft className="w-8 h-8 text-white" />
            </div>
            <h3 className="text-2xl font-bold mb-2">0</h3>
            <p className="text-gray-400">Total Trades</p>
          </Card>

          <Card className="text-center">
            <div className="flex items-center justify-center w-16 h-16 bg-gradient-to-r from-purple-500 to-pink-600 rounded-full mx-auto mb-4">
              <TrendingUp className="w-8 h-8 text-white" />
            </div>
            <h3 className="text-2xl font-bold mb-2">0%</h3>
            <p className="text-gray-400">Average APY</p>
          </Card>
        </div>
      </div>
    </div>
  )
}
