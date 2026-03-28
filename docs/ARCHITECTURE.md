# AetherYield Architecture: Non-Custodial NFT Credit Layer

AetherYield decouples NFT ownership from its financial utility. It allows users to borrow against their NFTs while retaining the ability to use them for governance, airdrops, and utility via a Proxy-Lien architecture.

## 1. Core Components

### 1.1 LienRegistry.sol
The source of truth for all encumbered assets. It does not hold the NFT but tracks the "Lien" (the right to seize).
- **Lien State**: Tracks principal, interest rate, and the `borrower`.
- **Authorization**: Only registered `AetherVaults` can create or resolve liens.
- **Enforcement**: In the MVP, the NFT is held in a `LienProxy` (a per-user or per-asset contract) that checks the `LienRegistry` before allowing any `transferFrom` calls.

### 1.2 AetherVault.sol (ERC-4626)
The liquidity pool where LPs deposit USDC/WETH to earn interest from NFT borrowers.
- **Borrowing**: Issues loans based on the `maxLTV` (e.g., 60%) of the verified floor price.
- **Repayment**: Updates the `LienRegistry` to reduce debt or release the lien.

### 1.3 HealthFactor.sol
Calculates the solvency of a position:
`Health Factor = (Floor Price * Liquidation Threshold) / Total Debt`
- If `< 1.0`, the position is eligible for liquidation.

## 2. ZK-Underwriting Flow

To prevent oracle manipulation and protect sensitive volume data, AetherYield uses ZK-Proofs for floor price verification.

1. **Oracle Signature**: A trusted price oracle signs a message: `Poseidon(AssetID, FloorPrice, Timestamp)`.
2. **Proof Generation**: The user generates a ZK-proof (via `floorProof.circom`) showing:
    - The signature is valid (EdDSA).
    - The `FloorPrice` inside the signature is `>= X` (where X is the value used for the loan).
    - The `Timestamp` is within the last 30 minutes.
3. **Verification**: The `AetherVault` calls `FloorVerifier.sol`. If valid, the `X` value is treated as the "Verified Floor Price" for the Health Factor calculation.

## 3. Liquidation & The Uniswap Integration

### 3.1 Seizure
When a Health Factor drops below 1.0, a liquidator calls `liquidate()`. The `LienRegistry` authorizes the transfer of the NFT from the `LienProxy` to the `AetherVault` or a designated `Swapper`.

### 3.2 UniswapSwapper.sol
**Note**: Uniswap V3 handles fungible tokens. The liquidation flow is:
1. NFT is sold on a secondary marketplace (e.g., OpenSea/Blur) for a base asset (WETH).
2. The `UniswapSwapper` is used to convert that WETH into the Vault's underlying asset (e.g., USDC) if they differ, ensuring the Vault remains whole.
3. Any excess funds after debt + penalty are returned to the borrower.

## 4. Security & Non-Custodial Enforcement

The "Non-Custodial" claim is achieved through **Restricted Proxies**:
- The user's NFT is moved to a `LienProxy` (ERC-6551 compatible).
- The `LienProxy` implements `transferFrom` logic that reverts if `LienRegistry.isEncumbered(tokenId)` is true.
- This allows the user to sign messages (governance) or claim airdrops via the Proxy, but prevents them from selling the collateral while a debt is active.