const { ethers } = require("ethers");
require("dotenv").config();

// Minimal ABIs for monitoring
const LIEN_REGISTRY_ABI = [
    "event LienCreated(bytes32 indexed lienId, address indexed borrower, address nft, uint256 tokenId, uint256 principal)",
    "function liens(bytes32) view returns (address borrower, address nftContract, uint256 tokenId, uint256 principal, uint256 interestRate, uint256 lastUpdateTimestamp, bool active)"
];

const HEALTH_FACTOR_ABI = [
    "function isLiquidatable(address nft, uint256 tokenId, uint256 debt) view returns (bool)"
];

class SentinelMonitor {
    constructor(rpcUrl, registryAddr, healthFactorAddr) {
        this.provider = new ethers.JsonRpcProvider(rpcUrl);
        this.registry = new ethers.Contract(registryAddr, LIEN_REGISTRY_ABI, this.provider);
        this.healthFactor = new ethers.Contract(healthFactorAddr, HEALTH_FACTOR_ABI, this.provider);
        this.activeLiens = new Set();
        this.isScanning = false;
    }

    async init() {
        console.log("Initializing Sentinel Monitor...");
        // In a real production app, we'd sync from a database or indexer.
        // For MVP, we fetch recent events to populate the set.
        const filter = this.registry.filters.LienCreated();
        const events = await this.registry.queryFilter(filter, -1000); // Last 1000 blocks
        for (const event of events) {
            this.activeLiens.add(event.args.lienId);
        }
        
        // Listen for new liens
        this.registry.on("LienCreated", (lienId) => {
            console.log(`New Lien detected: ${lienId}`);
            this.activeLiens.add(lienId);
        });

        console.log(`Monitoring ${this.activeLiens.size} active liens.`);
    }

    async checkAllHealth() {
        if (this.isScanning) return [];
        this.isScanning = true;
        const liquidatable = [];

        try {
            for (const lienId of this.activeLiens) {
                const lien = await this.registry.liens(lienId);
                if (!lien.active) {
                    this.activeLiens.delete(lienId);
                    continue;
                }

                // Calculate current debt (simplified for monitor, contract handles precision)
                const timeElapsed = BigInt(Math.floor(Date.now() / 1000)) - lien.lastUpdateTimestamp;
                const interest = (lien.principal * lien.interestRate * timeElapsed) / (365n * 24n * 3600n * 10000n);
                const currentDebt = lien.principal + interest;

                const canLiquidate = await this.healthFactor.isLiquidatable(
                    lien.nftContract,
                    lien.tokenId,
                    currentDebt
                );

                if (canLiquidate) {
                    console.warn(` LIQUIDATION TRIGGERED for Lien: ${lienId}`);
                    liquidatable.push({
                        lienId,
                        nft: lien.nftContract,
                        tokenId: lien.tokenId.toString(),
                        debt: currentDebt.toString()
                    });
                }
            }
        } catch (err) {
            console.error("Monitor scan error:", err);
        } finally {
            this.isScanning = false;
        }
        return liquidatable;
    }
}

module.exports = SentinelMonitor;