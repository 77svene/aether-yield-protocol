# AetherYield API Specification v1.0

This document defines the technical interfaces for the AetherYield protocol, covering Smart Contracts, ZK-Circuits, and Off-chain Monitoring Services.

## 1. Smart Contract Interfaces

### AetherVault.sol (ERC-4626)
The primary entry point for Liquidity Providers (LPs) and Borrowers.

| Function | Access | Description |
|:---|:---|:---|
| `deposit(uint256 assets, address receiver)` | Public | Deposits USDC/WETH to mint yield-bearing vault shares. |
| `borrow(address nft, uint256 id, uint256 amount)` | Public | Issues a loan against an NFT. Requires `LienRegistry` approval. |
| `repay(bytes32 lienId, uint256 amount)` | Public | Repays debt and reduces the lien principal. |
| `liquidate(bytes32 lienId)` | External | Seizes NFT if `HealthFactor < 1.0`. Only callable by `RiskSentinel`. |

### LienRegistry.sol
The source of truth for NFT encumbrance.

| Function | Access | Description |
|:---|:---|:---|
| `createLien(...)` | Vault Only | Records a new debt position against a specific NFT `(contract, tokenId)`. |
| `getDebt(bytes32 lienId)` | View | Returns `principal + accrued interest` based on block timestamp. |
| `isEncumbered(address nft, uint256 id)` | View | Returns `true` if the NFT has an active lien, blocking transfers. |

---

## 2. ZK-Underwriting Proofs

AetherYield uses Groth16 proofs generated via Circom to verify collateral quality without revealing sensitive user data.

### FloorPriceVerifier (`floorProof.circom`)
**Public Inputs:**
- `minRequiredPrice`: The minimum floor price (in Wei) required for the requested loan.
- `oraclePubKeyX/Y`: The EdDSA public key of the authorized Aether Oracle.
- `currentTimestamp`: Current block time to prevent replay of old price data.
- `maxDelay`: Maximum allowed age of the signature (e.g., 3600s).

**Private Inputs:**
- `actualPrice`: The real floor price signed by the oracle.
- `assetId`: Keccak256 hash of the NFT contract address.
- `signature (R8x, R8y, S)`: The EdDSA signature from the oracle.

### CreditScoreVerifier (`creditScore.circom`)
**Public Inputs:**
- `minRequiredScore`: Threshold for "Prime" interest rates.
- `scoreCommitment`: `Poseidon(actualScore, salt)`.

**Private Inputs:**
- `actualScore`: Sum of verified wallet balances.
- `walletBalances[]`: Array of individual wallet balances used for the sum.
- `salt`: Randomness to prevent brute-forcing the commitment.

---

## 3. Risk Sentinel (Off-chain)

The Sentinel monitors the health of all active liens and triggers liquidations.

### Health Monitor Service
- **Endpoint:** `GET /api/v1/health/:lienId`
- **Response:**
  ```json
  {
    "lienId": "0x...",
    "healthFactor": "1.25",
    "isLiquidatable": false,
    "collateralValue": "10.5 ETH",
    "totalDebt": "8.4 ETH"
  }