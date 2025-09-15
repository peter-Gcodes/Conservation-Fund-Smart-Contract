# Conservation Fund Smart Contract

A decentralized conservation funding platform built on the Stacks blockchain using Clarity smart contracts. This contract enables transparent funding of conservation projects through community governance and direct donations.

## Features

### Core Functionality
- **Decentralized Fund Management**: Community-driven fund for conservation projects
- **Project Creation**: Contributors can propose conservation initiatives
- **Governance System**: Voting mechanism based on contribution amounts
- **Direct Project Funding**: Users can donate directly to specific projects
- **Transparent Operations**: All transactions and votes are recorded on-chain

### Key Components
- **Minimum Donation**: 1 STX required for fund contributions
- **Voting Rights**: Contributors with ≥10 STX can vote on projects
- **Project Creation**: Requires ≥5 STX contribution to propose projects
- **Voting Period**: 10 days (~1440 blocks) for project approval
- **Emergency Controls**: Owner functions for contract management

## Contract Structure

### Data Storage
- `total-fund`: Total STX in the conservation fund
- `contributors`: Mapping of contributor addresses to donation amounts
- `projects`: Detailed project information including funding goals and voting results
- `project-votes`: Tracks voting participation to prevent double voting
- `project-donations`: Direct donations to specific projects

### Error Codes
- `u100`: Owner-only function access denied
- `u101`: Project not found
- `u102`: Insufficient funds
- `u103`: Invalid amount
- `u104`: Project inactive
- `u105`: Already voted
- `u106`: Voting period closed
- `u107`: Unauthorized access
- `u108`: Invalid input data

## Usage Guide

### For Contributors
1. **Donate to Fund**: `(donate-to-fund amount)`
   - Minimum 1 STX donation required
   - Increases your voting power

2. **Create Project**: `(create-project title description funding-goal)`
   - Requires 5 STX minimum contribution
   - Project enters 10-day voting period

3. **Vote on Projects**: `(vote-on-project project-id vote-for)`
   - Voting power based on contribution amount
   - One vote per project per contributor

### For Project Creators
1. **Withdraw Funds**: `(withdraw-project-funds project-id)`
   - Available when project reaches funding goal
   - Only project creator can withdraw

2. **Direct Donations**: `(donate-to-project project-id amount)`
   - Anyone can donate directly to active projects
   - Bypasses voting requirement

### Read-Only Functions
- `(get-total-fund)`: View current fund balance
- `(get-contributor-amount contributor)`: Check contribution amount
- `(get-project project-id)`: View project details
- `(get-voting-power contributor)`: Check voting power
- `(has-voted project-id voter)`: Verify voting status

### Admin Functions (Owner Only)
- `(set-min-donation new-min)`: Update minimum donation requirement
- `(set-voting-period new-period)`: Modify voting period duration
- `(deactivate-project project-id)`: Disable problematic projects
- `(emergency-withdraw amount)`: Emergency fund access

## Deployment

1. Deploy the contract to Stacks blockchain
2. The deployer becomes the contract owner
3. Set initial parameters if needed using admin functions
4. Contract is ready for community use

## Security Features

- **Input Validation**: All user inputs are validated before processing
- **Access Controls**: Role-based permissions for sensitive functions
- **Double-Voting Prevention**: Tracks voting participation
- **Fund Protection**: Emergency withdrawal only for contract owner
- **Transparent Governance**: All votes and funding decisions are public

## Technical Requirements

- **Blockchain**: Stacks
- **Language**: Clarity
- **Minimum STX**: 1 STX for donations, 5 STX for project creation
- **Contract Size**: Under 300 lines for optimal deployment

## Events Logged

The contract emits events for transparency:
- `donation`: Fund contributions
- `project-created`: New project proposals
- `vote-cast`: Governance votes
- `project-funded`: Successful project funding
- `project-donation`: Direct project donations
- `emergency-withdrawal`: Admin fund access

