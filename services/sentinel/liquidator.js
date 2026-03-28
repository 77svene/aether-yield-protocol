const { ethers } = require("ethers");

/**
 * @title LiquidatorService
 * @notice Handles the execution of liquidations with profitability guards and retry logic.
 */
class LiquidatorService {
    constructor(provider, wallet, vaultAddress, registryAddress, healthFactorAddress) {
        this.provider = provider;
        this.wallet = wallet.connect(provider);
        this.vault = new ethers.Contract(
            vaultAddress,
            ["function liquidate(address nft, uint256 tokenId) external returns (uint256)"],
            this.wallet
        );
        this.registry = new ethers.Contract(
            registryAddress,
            ["function liens(bytes32 lienId) external view returns (address, address, uint256, uint256, uint256, uint256, bool)"],
            this.provider
        );
        this.healthFactor = new ethers.Contract(
            healthFactorAddress,
            ["function isLiquidatable(address nft, uint256 tokenId) external view returns (bool)"],
            this.provider
        );
        this.minProfitEth = ethers.parseEther("0.01"); // Minimum profit threshold in ETH
    }

    /**
     * @notice Validates if an NFT is actually a registered collateral and is liquidatable.
     */
    async validateTarget(nftAddress, tokenId) {
        const lienId = ethers.solidityPackedKeccak256(["address", "uint256"], [nftAddress, tokenId]);
        const lien = await this.registry.liens(lienId);
        const isActive = lien[6]; // active boolean in struct
        if (!isActive) return false;

        const canLiquidate = await this.healthFactor.isLiquidatable(nftAddress, tokenId);
        return canLiquidate;
    }

    /**
     * @notice Estimates gas and checks if the liquidation incentive covers the cost.
     */
    async checkProfitability(nftAddress, tokenId) {
        try {
            const gasEstimate = await this.vault.liquidate.estimateGas(nftAddress, tokenId);
            const feeData = await this.provider.getFeeData();
            const gasCost = gasEstimate * (feeData.maxFeePerGas || feeData.gasPrice);
            
            // In a real scenario, we'd fetch the liquidation bonus from the vault.
            // For MVP, we assume a fixed 5% bonus on a floor price of 1 ETH (0.05 ETH).
            const estimatedIncentive = ethers.parseEther("0.05"); 
            
            return estimatedIncentive > (gasCost + this.minProfitEth);
        } catch (e) {
            console.error(`Profitability check failed: ${e.message}`);
            return false;
        }
    }

    /**
     * @notice Executes liquidation with manual nonce management and retries.
     */
    async executeLiquidation(nftAddress, tokenId, retries = 3) {
        if (!ethers.isAddress(nftAddress)) throw new Error("Invalid NFT address");
        
        const isEligible = await this.validateTarget(nftAddress, tokenId);
        if (!isEligible) {
            console.log(`Target ${nftAddress}:${tokenId} not eligible for liquidation.`);
            return null;
        }

        const isProfitable = await this.checkProfitability(nftAddress, tokenId);
        if (!isProfitable) {
            console.log(`Liquidation not profitable for ${tokenId}. Skipping.`);
            return null;
        }

        let attempt = 0;
        while (attempt < retries) {
            try {
                const nonce = await this.provider.getTransactionCount(this.wallet.address, "pending");
                const feeData = await this.provider.getFeeData();
                
                const tx = await this.vault.liquidate(nftAddress, tokenId, {
                    nonce,
                    maxFeePerGas: (feeData.maxFeePerGas * 120n) / 100n, // 20% bump for speed
                    maxPriorityFeePerGas: (feeData.maxPriorityFeePerGas * 120n) / 100n
                });

                console.log(`Liquidation tx sent: ${tx.hash} (Attempt ${attempt + 1})`);
                const receipt = await tx.wait(1);
                return receipt;
            } catch (error) {
                console.error(`Attempt ${attempt + 1} failed: ${error.message}`);
                attempt++;
                if (attempt >= retries) throw error;
                await new Promise(r => setTimeout(r, 2000)); // Wait 2s before retry
            }
        }
    }
}

module.exports = LiquidatorService;