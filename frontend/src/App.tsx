import { BrowserRouter as Router, Routes, Route } from 'react-router-dom'
import { WagmiProvider } from 'wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { config } from './config/wagmi'
import { Navbar } from './components/Navbar'
import { HomePage } from './pages/HomePage'
import { PoolPage } from './pages/PoolPage'
import { StakingPage } from './pages/StakingPage'
import { VaultPage } from './pages/VaultPage'

const queryClient = new QueryClient()

function App() {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <Router>
          <div className="min-h-screen bg-gray-950">
            <Navbar />
            <Routes>
              <Route path="/" element={<HomePage />} />
              <Route path="/pool" element={<PoolPage />} />
              <Route path="/staking" element={<StakingPage />} />
              <Route path="/vault" element={<VaultPage />} />
            </Routes>
          </div>
        </Router>
      </QueryClientProvider>
    </WagmiProvider>
  )
}

export default App
