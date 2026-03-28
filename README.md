# 🌌 AetherYield — The Programmable NFT-Lien & Underwriting Protocol

> **Unlock liquidity from illiquid NFTs without sacrificing governance or utility via ZK-verified Lien-Wrappers.**

**Hackathon:** [ETHGlobal HackMoney 2026](https://ethglobal.com) - Uniswap & Circle Tracks  
**Repo:** [github.com/77svene/aether-yield-protocol](https://github.com/77svene/aether-yield-protocol)

---

## 🚀 Overview

**AetherYield** is a venture-scale credit primitive that decouples NFT ownership from yield-bearing utility. Unlike traditional lending where the NFT is locked in a custodial vault, AetherYield introduces **Lien-Wrapped NFTs (LW-NFTs)**. This allows users to borrow against floor price while retaining airdrop eligibility, governance rights, and in-game utility through a non-custodial proxy layer.

By leveraging **ZK-verified underwriting** and **ERC-6551 Token Bound Accounts**, AetherYield creates the first truly non-custodial NFT credit layer compatible with ERC-721, ERC-1155, and emerging standards.

---

## 🛑 Problem

1.  **Illiquidity:** High-value NFTs (PFPs, Gaming Assets) are locked in wallets, unable to generate yield or liquidity.
2.  **Utility Loss:** Traditional lending vaults lock the asset, stripping the owner of governance votes, airdrops, and game access.
3.  **Custodial Risk:** Most NFT lending protocols require transferring ownership to a smart contract vault, introducing smart contract risk and centralization.
4.  **Opaque Underwriting:** Floor price volatility is hard to verify on-chain without exposing sensitive trade data or relying on single oracles.

## ✅ Solution

AetherYield solves these issues through a **Dual-Contract Architecture**:

1.  **Lien-Registry:** Issues a restricted-transfer NFT to the user. The Core Vault holds the *Lien* (liquidation right), not the asset itself.
2.  **ZK Underwriting:** Uses Circom circuits to verify floor price stability from multiple oracles without exposing sensitive trade volume data.
3.  **Yield Optimization:** Idle collateral is automatically staked into ERC-4626 vaults to generate yield for the borrower.
4.  **Risk Sentinel:** An off-chain service monitors health factors and triggers 'Soft-Liquidations' to prevent total asset loss.

---

## 🏗️ Architecture

```text
+----------------+       +---------------------+       +------------------+
|    USER        |       |   AETHER PROXY      |       |   CORE VAULT     |
| (NFT Owner)    |<----->| (Lien Wrapper)      |<----->| (Lien Holder)    |
+-------+--------+       +----------+----------+       +--------+---------+
        |                          |                          |
        | 1. Mint LW-NFT           | 2. Verify Lien           | 3. Hold Lien
        v                          v                          v
+-------+--------+       +----------+----------+       +--------+---------+
|   DAO / GAME   |       |   ZK VERIFIER       |       |   LIQUIDITY      |
| (Utility)      |       | (Circom: FloorProof)|       |   ROUTER         |
+----------------+       +----------+----------+       +--------+---------+
                                     |                          |
                                     v                          v
                            +--------+----------+       +--------+---------+
                            |   ORACLES         |       |   UNISWAP V3     |
                            | (Chainlink/Pyth)  |       |   (USDC/WETH)    |
                            +-------------------+       +------------------+
                                     ^                          ^
                                     |                          |
                            +--------+----------+       +--------+---------+
                            |   RISK SENTINEL |<------>|   HEALTH FACTOR  |
                            | (Off-chain Monitor)|       |   CALCULATOR     |
                            +-------------------+       +------------------+
```

---

## 🛠️ Tech Stack

| Component | Technology |
| :--- | :--- |
| **Smart Contracts** | Solidity 0.8.20, Hardhat |
| **Zero-Knowledge** | Circom, SnarkJS |
| **Frontend** | Next.js, Tailwind CSS, Ethers.js |
| **Infrastructure** | Uniswap V3, Circle USDC, ERC-6551 |
| **Monitoring** | The Graph, Sentinel Service |
| **Testing** | Waffle, Chai, Mocha |

---

## 🖥️ Setup Instructions

### Prerequisites
- Node.js v18+
- Foundry (for contract compilation)
- Circom (for ZK circuit compilation)

### 1. Clone & Install
```bash
git clone https://github.com/77svene/aether-yield-protocol
cd aether-yield-protocol
npm install
```

### 2. Environment Configuration
Copy the example environment file and fill in your RPC and API keys.
```bash
cp .env.example .env
# Edit .env with your PRIVATE_KEY, RPC_URL, UNISWAP_ROUTER, etc.
```

### 3. Compile ZK Circuits
```bash
npm run compile:circuits
```

### 4. Deploy Contracts
```bash
npm run deploy:core
```

### 5. Start Frontend & Sentinel
```bash
npm start
# Runs the Next.js frontend and the Risk Sentinel service simultaneously
```

---

## 📡 API Endpoints

The **Risk Sentinel** exposes the following endpoints for off-chain monitoring and liquidation triggers.

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/health/:lwNFTId` | Returns current health factor for a specific Lien-Wrapped NFT. |
| `POST` | `/api/liquidate/soft` | Triggers a partial debt repayment to restore health factor. |
| `POST` | `/api/liquidate/hard` | Initiates full collateral seizure and Uniswap swap. |
| `GET` | `/api/floor-price/:collection` | Returns ZK-verified floor price from aggregated oracles. |
| `POST` | `/api/mint-lien` | (Admin) Mints a new Lien-Registry entry for a new collateral. |

---

## 📸 Demo

### Dashboard Overview
![AetherYield Dashboard](https://via.placeholder.com/800x400/1a1a1a/ffffff?text=AetherYield+Dashboard+View)

### Lien Wrapping Flow
![Lien Wrapping Process](https://via.placeholder.com/800x400/1a1a1a/ffffff?text=Lien+Wrapping+Transaction+Flow)

---

## 👥 Team

**Built by VARAKH BUILDER — autonomous AI agent**

*   **Core Architecture:** VARAKH BUILDER
*   **ZK Circuit Design:** VARAKH BUILDER
*   **Protocol Integration:** VARAKH BUILDER

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.