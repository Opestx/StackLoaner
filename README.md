# StackLoaner 💸

**Trustless Peer-to-Peer Multi-Asset Microloans on Stacks**

StackLoaner is a decentralized lending platform built on the Stacks blockchain that facilitates both collateralized and undercollateralized microloans using STX and SIP-010 tokens through smart contracts and on-chain reputation systems.

## 🚀 New Features

- **Multi-Asset Support**: Create loans in STX or any supported SIP-010 token
- **Flexible Collateral**: Use STX or SIP-010 tokens as collateral 
- **Cross-Asset Loans**: Borrow one token type with another as collateral
- **Token Whitelist**: Admin-managed list of supported tokens for security

## Features

- **Flexible Loan Creation**: Support for both collateralized and undercollateralized loans
- **Multi-Asset Support**: Loan in STX or supported SIP-010 tokens with flexible collateral options
- **Smart Contract Automation**: Automated loan management with built-in repayment schedules
- **Credit Reputation System**: NFT-based credit badges for tracking borrower performance
- **Late Payment Penalties**: Automatic handling of overdue loans
- **Transparent Statistics**: On-chain tracking of borrower and lender performance
- **Platform Fee System**: Sustainable revenue model with configurable fees
- **Token Management**: Admin controls for adding/removing supported tokens

## How It Works

### For Borrowers
1. **Create Loan Request**: 
   - STX loans: Use `create-stx-loan(amount, interest-rate, duration, collateral-amount)`
   - Token loans: Use `create-token-loan(amount, interest-rate, duration, collateral-amount, loan-token, collateral-token, is-stx-collateral)`
2. **Wait for Funding**: Lenders can fund your loan request
3. **Receive Funds**: Get loan amount directly in your wallet
4. **Repay on Time**: Use the appropriate repay function within the timeframe
5. **Build Credit**: Earn reputation NFTs for successful repayments

### For Lenders
1. **Browse Loans**: View available loan requests in various tokens
2. **Fund Loans**: 
   - STX loans: Use `fund-stx-loan(loan-id)`
   - Token loans: Use `fund-token-loan(loan-id, loan-token)`
3. **Earn Interest**: Automatically receive repayments with interest
4. **Track Performance**: Build lending statistics and reputation

## Smart Contract Functions

### Loan Creation
- `create-stx-loan(amount, interest-rate, duration, collateral-amount)` - Create STX loan
- `create-token-loan(amount, interest-rate, duration, collateral-amount, loan-token, collateral-token, is-stx-collateral)` - Create SIP-010 token loan

### Loan Funding
- `fund-stx-loan(loan-id)` - Fund an STX loan
- `fund-token-loan(loan-id, loan-token)` - Fund a SIP-010 token loan

### Loan Repayment
- `repay-stx-loan(loan-id)` - Repay STX loan
- `repay-token-loan(loan-id, loan-token, collateral-token)` - Repay SIP-010 token loan

### Token Management (Admin Only)
- `add-supported-token(token-contract)` - Add a new supported token
- `remove-supported-token(token-contract)` - Remove token support

### Utility Functions
- `apply-late-penalty(loan-id)` - Handle overdue loans
- `is-supported-token(token-contract)` - Check if token is supported

### Read-Only Functions
- `get-loan(loan-id)` - Retrieve loan details including token information
- `get-borrower-stats(borrower)` - Get borrower statistics and credit score
- `get-lender-stats(lender)` - Get lender performance metrics
- `calculate-repayment-amount(amount, interest-rate)` - Calculate total repayment

## Multi-Asset Examples

### Creating a Token Loan
```clarity
;; Borrow USDA tokens with STX as collateral
(create-token-loan 
  u1000000 ;; 1 USDA (assuming 6 decimals)
  u1000    ;; 10% interest
  u1440    ;; 10 days duration
  u500000  ;; 0.5 STX collateral
  .usda-token ;; Loan token contract
  .dummy-token ;; Collateral token (unused since STX collateral)
  true     ;; Using STX as collateral
)

;; Borrow STX with USDA as collateral  
(create-token-loan
  u1000000 ;; 1 STX
  u800     ;; 8% interest  
  u2160    ;; 15 days duration
  u1200000 ;; 1.2 USDA collateral
  .dummy-token ;; Loan token (unused since STX loan via create-stx-loan)
  .usda-token ;; Collateral token
  false    ;; Using SIP-010 token as collateral
)
```

### Funding Different Loan Types
```clarity
;; Fund an STX loan
(fund-stx-loan u1)

;; Fund a USDA token loan
(fund-token-loan u2 .usda-token)
```

## Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet (Hiro Wallet recommended)
- STX tokens and/or supported SIP-010 tokens for transactions

### Installation
```bash
git clone https://github.com/yourusername/stackloaner
cd stackloaner
clarinet check
```

### Testing Multi-Asset Features
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
- **Platform Fee**: 2.5% (configurable by admin, max 10%)
- **Credit Score Range**: 0-1000 points
- **Supported Tokens**: Admin-managed whitelist for security

## Risk Management

- **Collateral Support**: Optional collateral in STX or supported SIP-010 tokens
- **Cross-Asset Collateral**: Borrow one asset with another as collateral
- **Credit Scoring**: Dynamic credit scores based on repayment history
- **Time-based Penalties**: Automatic handling of late payments
- **Platform Fees**: Sustainable revenue model for platform maintenance
- **Token Whitelist**: Only approved tokens can be used for loans

## Token Support

### Adding New Tokens
Only contract admins can add new supported tokens:
```clarity
(add-supported-token .new-token-contract)
```

### Supported Token Requirements
- Must implement SIP-010 standard
- Must be approved by contract admin
- Should have reliable liquidity and price discovery

## Security Considerations

- **Token Validation**: All token operations validate contract addresses
- **Proper Error Handling**: Comprehensive error checking prevents invalid operations
- **Admin Controls**: Token support is managed by trusted admins
- **Transfer Safety**: Safe transfer functions prevent common vulnerabilities

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality, especially multi-asset features
5. Ensure `clarinet check` passes without warnings
6. Submit a pull request

## Changelog

### Multi-Asset Update
- ✅ Added SIP-010 token trait support
- ✅ Implemented multi-asset loan creation and funding
- ✅ Added cross-asset collateral functionality
- ✅ Created token whitelist management system
- ✅ Enhanced error handling and validation
- ✅ Updated emergency withdrawal for tokens

**Built on Stacks • Secured by Bitcoin • Powered by Multi-Asset DeFi**