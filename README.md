# Blume Protocol

Blume is a comprehensive DeFi ecosystem built on Ethereum, offering automated market making, time-locked staking, liquid staking, and secure vault solutions. The protocol is designed with security-first principles and implements battle-tested mechanisms to ensure user funds remain safe while maximizing yield opportunities.

## Overview

Blume Protocol consists of five core smart contracts that work together to provide a complete DeFi experience:

- **BLX Token**: The native governance and utility token
- **BLX Pool**: Automated Market Maker (AMM) for token swaps and liquidity provision
- **Tiered Staking**: Time-locked staking with variable APR based on lock duration
- **Liquid Staking**: Liquid staking system that issues tradeable stBLX tokens
- **BLX Vault**: Secure time-locked vault with automated staking features

## Deployed Contracts (Sepolia Testnet)

| Contract | Address | Purpose |
|----------|---------|---------|
| BLX Token | `0x050F2D144cAdB54Ae304c234F273B0124a126dB5` | Native protocol token |
| BLX Pool | `0x5bCAE371B52A8a497f4Cb9178E14C137141B0c13` | AMM for BLX/USDC trading |
| USDC Token | `0x1D68BE240D1A9e527410B017075868bc543E7538` | Test USDC token |
| Tiered Staking | `0xFb3FaC0BDf5dB9c11857F6e0cBedC4f13147D06c` | Time-locked staking contract |
| Liquid Staking | `0x74534A5ca5793E338ccDB6De58dA5662B05070C5` | Liquid staking system |
| Staked BLX | `0xec16eE9362d310D42DF579AdA7e627fAf99F6FA7` | Liquid staking token (stBLX) |
| BLX Vault | `0x0C7468Bd1eca2BD7d39aE496234427cD7FEb8344` | Secure time-locked vault |

## Demo Transaction Hashes

The following transaction hashes demonstrate the protocol functionality as shown in the demo video:

- `0xf30f50c648df4feb49fbc9891678a62ba15e707639aaddc1938d95524d2a2302`
- `0x70095ab5eb18a9e4e458383217cae7678c235d46b9b50b3d22e6cfc598ab20aa`
- `0x2a56f2051131518855e8a5ef0eef0ff1b90fb8413282365bd25aa35b7e8c19e7`

## Core Features

### BLX Token
- **ERC20 Standard**: Fully compliant ERC20 token with mint/burn capabilities
- **Access Control**: Role-based permissions for minting operations
- **Pausable**: Emergency pause functionality for critical situations
- **Supply Management**: Controlled token supply with admin-only minting

### BLX Pool (AMM)
- **Constant Product Formula**: Based on proven Uniswap V2 mathematics
- **Fee Collection**: Configurable swap fees (default 0.3%)
- **Liquidity Mining**: Earn fees by providing liquidity to the pool
- **Price Oracle**: Cumulative price tracking for external integrations
- **Security Features**: Reentrancy protection, overflow checks, and emergency functions

### Tiered Staking System
- **Multiple Lock Periods**: Choose from 30, 90, or 365-day lock periods
- **Variable APR**: Higher returns for longer commitments
  - 30 days: 5% APR
  - 90 days: 10% APR  
  - 365 days: 20% APR
- **Early Withdrawal**: Option to withdraw early (principal only, no rewards)
- **Reward Pool**: Admin-funded reward distribution system

### Liquid Staking
- **Liquid Tokens**: Receive stBLX tokens representing your staked position
- **Tradeable**: stBLX tokens can be traded or used in other DeFi protocols
- **Flexible Redemption**: Redeem stBLX for BLX plus earned rewards
- **Dynamic Exchange Rate**: Token value appreciates based on staking rewards

### BLX Vault
- **Time-locked Security**: Multiple lock period options (0, 7, 30, 90 days)
- **Automated Staking**: Optional auto-staking of deposited tokens
- **Fee Structure**: 
  - Standard withdrawal: 1% fee
  - Early withdrawal: 5% penalty fee
- **Role-based Access**: Manager and emergency roles for administration
- **Emergency Functions**: Emergency withdrawal for authorized users

## Security Features

### Battle-tested Architecture
- **OpenZeppelin Integration**: Built on proven OpenZeppelin contracts
- **Reentrancy Protection**: All state-changing functions protected against reentrancy attacks
- **Access Control**: Role-based permissions with multi-signature potential
- **Integer Overflow Protection**: Solidity 0.8+ built-in overflow protection

### Security Mechanisms
- **Pausable Contracts**: Emergency pause functionality across all contracts
- **Minimum Liquidity Lock**: Prevents liquidity removal attacks in AMM
- **K-Invariant Protection**: Mathematical guarantees in swap calculations
- **Input Validation**: Comprehensive validation of all user inputs
- **Emergency Recovery**: Admin functions for emergency token recovery

### Audit Considerations
- **Formal Verification Ready**: Mathematical models suitable for formal verification
- **Clean Code Standards**: Consistent commenting and documentation
- **Gas Optimization**: Efficient storage packing and optimized calculations
- **Event Logging**: Comprehensive event emission for transparency and monitoring

## Testing and Security Auditing

### Comprehensive Testing Suite
- **Unit Tests**: Individual function testing for all smart contracts
- **Integration Tests**: Full workflow testing across contract interactions
- **Edge Case Testing**: Boundary condition and error state validation
- **Gas Optimization Tests**: Performance benchmarking and optimization verification
- **Foundry Framework**: Using Foundry for fast, reliable Solidity testing

### Static Analysis and Security Tools
- **Slither Integration**: Automated vulnerability detection and code analysis
- **Solhint**: Solidity linting for code quality and security best practices
- **Mythril**: Additional security analysis for common vulnerabilities
- **Manual Code Review**: Line-by-line security review by experienced developers

### Security Analysis Results
- **Slither Scans**: Regular automated scans for 90+ vulnerability patterns
- **Zero Critical Issues**: No critical vulnerabilities detected in latest scans
- **Optimization Recommendations**: Implemented gas optimization suggestions
- **Best Practices Compliance**: Adherence to Ethereum security standards

### Test Coverage Areas
- **Access Control**: Role-based permission testing
- **Reentrancy Protection**: Attack simulation and prevention verification
- **Mathematical Operations**: Precision and overflow testing
- **Emergency Functions**: Pause and recovery mechanism testing
- **Integration Flows**: Cross-contract interaction validation

## What Users Can Do on Blume

### Trading and Liquidity
- **Swap Tokens**: Trade BLX and USDC with low slippage
- **Provide Liquidity**: Earn trading fees by providing liquidity to the BLX/USDC pool
- **Remove Liquidity**: Withdraw your liquidity position at any time
- **Arbitrage**: Take advantage of price differences across platforms

### Staking Options
- **Tiered Staking**: Lock tokens for fixed periods to earn guaranteed returns
- **Liquid Staking**: Stake tokens while maintaining liquidity through stBLX
- **Flexible Terms**: Choose staking duration based on your investment timeline
- **Compound Rewards**: Reinvest rewards to maximize returns

### Vault Services
- **Secure Storage**: Store BLX tokens in time-locked vaults for enhanced security
- **Automated Strategies**: Enable auto-staking for hands-off yield generation
- **Multiple Timeframes**: Choose lock periods that match your investment goals
- **Emergency Access**: Authorized emergency withdrawal when needed

### Portfolio Management
- **Track Positions**: Monitor all your staking positions and vault deposits
- **Reward Tracking**: View real-time pending rewards across all positions
- **Historical Data**: Access complete transaction and reward history
- **Performance Analytics**: Analyze returns across different strategies

## Technical Specifications

### Smart Contract Standards
- **Solidity**: Version 0.8.16+ for latest security features
- **ERC20**: Full compliance for maximum compatibility
- **EIP-2612**: Permit functionality for gas-efficient approvals
- **Access Control**: Role-based permissions with OpenZeppelin standards

### Network Compatibility
- **Ethereum Mainnet**: Production deployment ready
- **Sepolia Testnet**: Current testing environment
- **Local Development**: Anvil/Hardhat compatibility

### Integration Support
- **Web3 Compatible**: Works with all major Web3 wallets
- **Frontend SDK**: React hooks and TypeScript support
- **API Integration**: Event-based monitoring and analytics
- **Browser Support**: Optimized for desktop browsers with Web3 wallet extensions

## Getting Started

### For Users
1. Connect your Web3 wallet (MetaMask, WalletConnect, etc.)
2. Switch to Sepolia testnet for testing
3. Get test tokens from faucets if needed
4. Start with small amounts to familiarize yourself with the platform
5. Explore different staking strategies based on your risk tolerance

### For Developers

#### Prerequisites
- Node.js (v16 or higher)
- Git
- A Web3 wallet (MetaMask recommended)
- Foundry (for smart contract development)

#### Setup Instructions

1. **Clone the repository**
```bash
git clone https://github.com/haxryy/Test1_Harrish.git
cd Test1_Harrish
```

2. **Install Foundry (if not already installed)**
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

3. **Setup Smart Contracts**
```bash
cd contracts
forge install
forge build
```

4. **Setup Frontend**
```bash
cd ../frontend
npm install
```

5. **Environment Configuration**
Copy the example environment files and configure them:
```bash
# For contracts
cp .env.example .env

# For frontend  
cd frontend
cp .env.example .env
```

Fill in the required values in both `.env` files (see Environment Variables section below).

#### Running Tests

**Smart Contract Tests:**
```bash
cd contracts

# Run all tests
forge test

# Run tests with verbosity
forge test -vvv

# Run specific test file
forge test --match-contract BLXPoolTest

# Run tests with gas reporting
forge test --gas-report

# Run tests with coverage
forge coverage
```

#### Running the Frontend

1. **Development Mode:**
```bash
cd frontend
npm run dev
```
The frontend will be available at `http://localhost:5173`

2. **Production Build:**
```bash
cd frontend
npm run build
npm run preview
```

3. **Linting and Formatting:**
```bash
# Check code formatting
npm run lint

# Fix formatting issues
npm run lint:fix

# Type checking
npm run type-check
```

#### Environment Variables

**Contracts (.env)**
```bash
# Required for deployment
PRIVATE_KEY=your_private_key_here
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/your_infura_key
ETHERSCAN_API_KEY=your_etherscan_api_key

# Optional
MAINNET_RPC_URL=https://mainnet.infura.io/v3/your_infura_key
```


#### Deployment

**Deploy to Sepolia:**
```bash
cd contracts

# Deploy all contracts
forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --verify

# Deploy individual contracts
forge script script/Deploy.s.sol:DeployScript --sig "deployBLXOnly()" --rpc-url sepolia --broadcast
```

**Local Development:**
```bash
# Start local Anvil node
anvil

# Deploy to local network
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

#### Security Analysis

**Run Slither:**
```bash
cd contracts
slither .
```



#### Troubleshooting

**Common Issues:**

1. **Foundry not found:**
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. **Node.js version issues:**
```bash
# Use Node Version Manager (nvm)
nvm install 18
nvm use 18
```

3. **Frontend build errors:**
```bash
# Clear node modules and reinstall
rm -rf node_modules package-lock.json
npm install
```

4. **Wallet connection issues:**
- Ensure you're on the correct network (Sepolia for testnet)
- Check that your wallet has sufficient ETH for gas fees

5. **Contract interaction failures:**
- Verify contract addresses in `.env` file
- Ensure contracts are deployed on the correct network
- Check that you have approved token spending if required

**Getting Test Tokens:**
- ETH (Sepolia): [Sepolia Faucet](https://sepoliafaucet.com/)
- Alternative ETH Faucet: [Alchemy Faucet](https://sepoliafaucet.com/)
- For USDC tokens, use the mock USDC contract deployed at the address in the contracts table

**Useful Commands:**
```bash
# Check Foundry installation
forge --version

# Update Foundry
foundryup

# Check Node.js version
node --version

# Check npm version  
npm --version

# Clear npm cache
npm cache clean --force
```

## Risk Considerations

### Smart Contract Risks
- **Code Risk**: Smart contracts may contain bugs despite thorough testing
- **Upgrade Risk**: Protocol upgrades may affect existing positions
- **Admin Risk**: Centralized admin functions exist for emergency situations

### Market Risks
- **Impermanent Loss**: Liquidity providers may experience impermanent loss
- **Price Volatility**: Token prices may fluctuate significantly
- **Liquidity Risk**: Large positions may experience slippage

### Operational Risks
- **Gas Fees**: Ethereum gas fees may be high during network congestion
- **Network Risk**: Ethereum network downtime or congestion
- **Wallet Risk**: User wallet security and private key management

## Future Roadmap

### Protocol Enhancements
- **Governance Token**: Transition to full DAO governance
- **Multi-asset Support**: Additional token pairs and staking options
- **Layer 2 Integration**: Deployment on Polygon, Arbitrum, and other L2s
- **Cross-chain Bridges**: Enable cross-chain asset movement

### Advanced Features
- **Automated Strategies**: AI-powered yield optimization
- **Insurance Integration**: Protocol insurance for user protection
- **Institutional Features**: Large-scale institutional investor tools
- **Mobile Application**: Native mobile app for better user experience

## Community and Support

### Documentation
- **Technical Docs**: Comprehensive API and contract documentation
- **User Guides**: Step-by-step tutorials for all features
- **Video Tutorials**: Educational content for visual learners
- **FAQ Section**: Common questions and troubleshooting

### Community Channels
- **Discord**: Real-time community support and discussions
- **Telegram**: Official announcements and updates
- **Twitter**: Latest news and protocol updates
- **GitHub**: Open source development and issue tracking

## License

This project is licensed under the MIT License. See the LICENSE file for details.

## Disclaimer

Blume Protocol is experimental software. Users interact with the protocol at their own risk. Past performance does not guarantee future results. Always do your own research and never invest more than you can afford to lose.
