# StackLoaner 💸

**Trustless Peer-to-Peer Microloans on Stacks**

StackLoaner is a decentralized lending platform built on the Stacks blockchain that facilitates both collateralized and undercollateralized microloans through smart contracts and on-chain reputation systems.

## Features

- **Flexible Loan Creation**: Support for both collateralized and undercollateralized loans
- **Smart Contract Automation**: Automated loan management with built-in repayment schedules
- **Credit Reputation System**: NFT-based credit badges for tracking borrower performance
- **Late Payment Penalties**: Automatic handling of overdue loans
- **Transparent Statistics**: On-chain tracking of borrower and lender performance
- **Platform Fee System**: Sustainable revenue model with configurable fees

## How It Works

### For Borrowers
1. Create a loan request specifying amount, interest rate, duration, and optional collateral
2. Wait for a lender to fund your loan
3. Receive funds directly to your wallet
4. Repay the loan within the specified timeframe
5. Earn credit reputation NFTs for successful repayments

### For Lenders
1. Browse available loan requests
2. Fund loans that match your risk tolerance
3. Automatically receive repayments with interest
4. Build lending statistics and reputation

## Smart Contract Functions

### Core Functions
- `create-loan(amount, interest-rate, duration, collateral-amount)` - Create a new loan request
- `fund-loan(loan-id)` - Fund an existing loan request
- `repay-loan(loan-id)` - Repay an active loan
- `apply-late-penalty(loan-id)` - Handle overdue loans

### Read-Only Functions
- `get-loan(loan-id)` - Retrieve loan details
- `get-borrower-stats(borrower)` - Get borrower statistics and credit score
- `get-lender-stats(lender)` - Get lender performance metrics
- `calculate-repayment-amount(amount, interest-rate)` - Calculate total repayment

## Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet (Hiro Wallet recommended)
- STX tokens for transactions

### Installation
```bash
git clone https://github.com/yourusername/stackloaner
cd stackloaner
clarinet check
```

### Testing
```bash
clarinet test
```

### Deployment
```bash
clarinet deploy
```

## Contract Parameters

- **Maximum Interest Rate**: 50% (5000 basis points)
- **Loan Duration Range**: 1 day to 1 year (144 to 52,560 blocks)
- **Platform Fee**: 2.5% (configurable by admin)
- **Credit Score Range**: 0-1000 points

## Risk Management

- **Collateral Support**: Optional collateral for secured loans
- **Credit Scoring**: Dynamic credit scores based on repayment history
- **Time-based Penalties**: Automatic handling of late payments
- **Platform Fees**: Sustainable revenue model for platform maintenance

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

**Built on Stacks • Secured by Bitcoin**