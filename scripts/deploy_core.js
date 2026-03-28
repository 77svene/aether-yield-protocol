const { ethers, network } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying AetherYield Core with account: ${deployer.address}`);

  // 1. Deploy or Identify Asset (USDC Mock for Testnets/Local)
  let assetAddress;
  if (network.name === "localhost" || network.name === "hardhat") {
    const MockERC20 = await ethers.getContractFactory("ERC20Mock");
    const mockUSDC = await MockERC20.deploy("Mock USDC", "USDC", 6);
    await mockUSDC.waitForDeployment();
    assetAddress = await mockUSDC.getAddress();
    console.log(`Deployed Mock USDC at: ${assetAddress}`);
  } else {
    // Use environment variable for non-local networks to avoid hardcoding
    assetAddress = process.env.ASSET_ADDRESS;
    if (!assetAddress) throw new Error("ASSET_ADDRESS not set in .env for non-local network");
  }

  // 2. Deploy LienRegistry
  const LienRegistry = await ethers.getContractFactory("LienRegistry");
  const registry = await LienRegistry.deploy();
  await registry.waitForDeployment();
  const registryAddress = await registry.getAddress();
  console.log(`LienRegistry deployed to: ${registryAddress}`);

  // 3. Deploy AetherVault
  const AetherVault = await ethers.getContractFactory("AetherVault");
  const vault = await AetherVault.deploy(
    assetAddress,
    registryAddress,
    "Aether Yield USDC Vault",
    "ayUSDC"
  );
  await vault.waitForDeployment();
  const vaultAddress = await vault.getAddress();
  console.log(`AetherVault deployed to: ${vaultAddress}`);

  // 4. Authorize Vault in Registry
  const authTx = await registry.authorizeVault(vaultAddress, true);
  await authTx.wait();
  console.log("Vault authorized in LienRegistry");

  // 5. Save Deployment State
  const deploymentData = {
    network: network.name,
    asset: assetAddress,
    registry: registryAddress,
    vault: vaultAddress,
    deployer: deployer.address,
    timestamp: new Date().toISOString()
  };

  const deploymentsDir = path.join(__dirname, "../deployments");
  try {
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir);
    }
    const filePath = path.join(deploymentsDir, `${network.name}.json`);
    fs.writeFileSync(filePath, JSON.stringify(deploymentData, null, 2));
    console.log(`Deployment manifest saved to: ${filePath}`);
  } catch (error) {
    console.error("Failed to save deployment manifest:", error.message);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });