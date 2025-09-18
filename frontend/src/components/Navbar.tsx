import { Link, useLocation } from 'react-router-dom'
import { useAccount, useConnect, useDisconnect } from 'wagmi'
import { Button } from './ui'
import { Wallet, Droplets } from 'lucide-react'

export function Navbar() {
  const location = useLocation()
  const { address, isConnected } = useAccount()
  const { connect, connectors } = useConnect()
  const { disconnect } = useDisconnect()

  const formatAddress = (addr: string) => {
    return `${addr.slice(0, 6)}...${addr.slice(-4)}`
  }

  const isActive = (path: string) => location.pathname === path

  return (
    <nav className="bg-gray-900 border-b border-gray-800">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center h-16">
          {/* Logo and Navigation Links (left) */}
          <div className="flex items-center space-x-8 flex-1">
            <Link to="/" className="flex items-center space-x-2">
              <Droplets className="w-8 h-8 text-blue-500" />
              <span className="text-2xl font-bold text-white">
                Blume
              </span>
            </Link>

            {/* Navigation Links */}
            <div className="hidden md:flex space-x-6">
              <Link
                to="/"
                className={`px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                  isActive('/') 
                    ? 'bg-blue-600 text-white' 
                    : 'text-gray-300 hover:text-white hover:bg-gray-800'
                }`}
              >
                Home
              </Link>
              <Link
                to="/pool"
                className={`px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                  isActive('/pool') 
                    ? 'bg-blue-600 text-white' 
                    : 'text-gray-300 hover:text-white hover:bg-gray-800'
                }`}
              >
                Pool
              </Link>
              <Link
                to="/staking"
                className={`px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                  isActive('/staking') 
                    ? 'bg-blue-600 text-white' 
                    : 'text-gray-300 hover:text-white hover:bg-gray-800'
                }`}
              >
                Staking
              </Link>
              <Link
                to="/vault"
                className={`px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                  isActive('/vault') 
                    ? 'bg-blue-600 text-white' 
                    : 'text-gray-300 hover:text-white hover:bg-gray-800'
                }`}
              >
                Vault
              </Link>
            </div>
          </div>

          {/* Wallet Connection (right) */}
          <div className="flex items-center space-x-4">
            {isConnected ? (
              <div className="flex items-center space-x-3">
                <div className="text-sm text-gray-300">
                  {formatAddress(address!)}
                </div>
                <Button 
                  onClick={() => disconnect()}
                  variant="outline"
                  size="sm"
                >
                  Disconnect
                </Button>
              </div>
            ) : (
              <Button
                onClick={() => connect({ connector: connectors[0] })}
                className="flex items-center space-x-2"
                size="sm"
              >
                <Wallet className="w-4 h-4" />
                <span>Connect Wallet</span>
              </Button>
            )}
          </div>
        </div>
      </div>
    </nav>
  )
}
