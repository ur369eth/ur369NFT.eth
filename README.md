# ur369NFT Collection

## Overview
UR369 is a unique NFT collection consisting of 44,280 NFTs divided into 4 batches. Each NFT is soulbound (non-transferable) and features (A) utility for the ur369 ecosystem (to begin a 36.9% refund when using urLegacy and (B) a unique claim mechanism for minters.

## Collection Structure
- **Total Supply**: 44,280 NFTs
- **Batch Structure**:
  - 4 Super Batches
  - Each Super Batch: 11,070 NFTs
  - Each Super Batch divided into 30 Sub-batches
  - Each Sub-batch: 369 NFTs

## Mint Event Structure
Each batch has its own minting denomination:
1. First Batch: 0.0369 ETH
2. Second Batch: 0.0963 ETH
3. Third Batch: 0.1845 ETH
4. Fourth Batch: 0.369 ETH

## Key Features

### 1. Soulbound NFTs
- NFTs are non-transferable (soulbound)
- Each address can only mint one NFT
- NFTs cannot be sold on the markets

### 2. Reward Mechanism
- Each mint contributes 36.9% to the Claim Pool
- Claim amounts are distributed in sub-batches
- Claim window: 3 days, 6 hours, and 9 minutes
- Winners are selected randomly from eligible minters

#### Claimer Selection Mechanism
The current claimer selection process uses a deterministic approach:
1. Creates a seed using:
   - Active super batch ID
   - Active sub-batch ID
   - Last NFT minted timestamp
   - A fixed string for consistent hashing
2. Uses this seed to select a random index from eligible minters
3. Returns the minter at that index as the claimer

### 3. Fee Distribution
Fees from each mint are distributed as follows:
- 36.9% to the claim pool
- 3.69% to public goods funding
- 46.9% to ur369NFT-devs.eth (to help develop the Space Map)
- 12.51% to ur369NFTETH

### 4. Metadata Structure
- Each batch has its own metadata URI
- Metadata is stored on IPFS
- Each NFT's metadata is accessible via its token ID

### 5. Referral System
- Users can refer others during minting
- Referrers are tracked and counted
- Referral relationships are recorded on-chain

## Technical Details

### Contract Architecture
The contract inherits from:
- ERC721: Standard NFT functionality
- Ownable: Access control
- ReentrancyGuard: Security against reentrancy attacks
- AutomationCompatibleInterface: Chainlink Keeper integration

### Key Functions

#### Minting
```solidity
function mint(address referrer) external payable
```
- Mints a new NFT
- Requires correct ETH amount
- Records referral if provided
- Distributes fees according to percentages

#### Claiming Mechanisnm
```solidity
function claimReward() external nonReentrant
```
- Claims ETH for eligible minters
- Verifies claim window
- Transfers claimed amount to minter/claimer
- Marks batches as claimed

#### Metadata
```solidity
function tokenURI(uint256 tokenId) public view returns (string memory)
```
- Returns metadata URI for each token
- Uses batch-specific base URIs
- Includes actual token ID in URI

### Automation
- Chainlink Keepers monitor the contract
- Automatically transfers unclaimed funds to final recipient
- Triggers when all batches are completed and claim window expires

## Fee Recipients
- Public Good Funds: 0xC4ef4EDACF31217B810B04702197EE2a0A13C4E3
- Dev Funds: 0x58b1F6623e6b7dfe78b588d8F1645e5bc1e19807
- urNFTETH: 0xC1A9F71A47448010c9ac58bDEb7b5e154dDD848d
- Final Recipient: 0x1b38B0e5a461836C664418e5f19402FD9c6721a3

## Security Features
1. ReentrancyGuard for minting and claiming
2. Ownable for administrative functions
3. Input validation for all parameters
4. Proper access control for sensitive functions
5. Safe math operations
6. Emergency fund recovery mechanisms

## Testing
The contract includes comprehensive test cases for:
- Metadata URI generation
- Minting functionality
- Reward claiming
- Fee distribution
- Referral system
- Access control
- Edge cases

## Deployment
1. Deploy the contract
2. Set initial metadata URIs
3. Configure fee recipients
4. Begin minting

## Maintenance
The contract owner can:
- Update metadata URIs
- Update fee recipients
- Adjust fee distribution percentages
- Set final recipient address

## Important Notes
1. NFTs are soulbound and cannot be transferred
2. Each address can only mint one NFT
3. Rewards must be claimed within the claim window
4. Unclaimed rewards are transferred to the final recipient
5. All fees are distributed immediately upon minting

## License
MIT License
