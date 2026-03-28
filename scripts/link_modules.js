const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  const deploymentsPath = path.join(__dirname, "../deployments.json");
  if (!fs.existsSync(deploymentsPath)) {
    console.error("Deployments file not found. Run deploy_core.js first.");
    process.exit(1);
  }

  const deployments = JSON.parse(fs.readFileSync(deploymentsPath, "utf8"));
  const [deployer] = await ethers.getSigners();

  console.log("Linking modules for AetherYield...");

  // 1. Link RiskOracle to AetherVault
  const RiskOracle = await ethers.getContractAt("RiskOracle", deployments.riskOracle, deployer);
  const currentVault = await RiskOracle.vault();
  
  if (currentVault !== deployments.vault) {
    console.log(`Setting Vault on RiskOracle to ${deployments.vault}...`);
    const tx = await RiskOracle.setVault(deployments.vault);
    await tx.wait();
    console.log("Vault linked to RiskOracle.");
  } else {
    console.log("RiskOracle already linked to Vault.");
  }

  // 2. Authorize Vault in LienRegistry
  const LienRegistry = await ethers.getContractAt("LienRegistry", deployments.lienRegistry, deployer);
  const isAuth = await LienRegistry.authorizedVaults(deployments.vault);
  
  if (!isAuth) {
    console.log(`Authorizing Vault ${deployments.vault} in LienRegistry...`);
    const tx = await LienRegistry.setAuthorizedVault(deployments.vault, true);
    await tx.wait();
    console.log("Vault authorized in LienRegistry.");
  } else {
    console.log("Vault already authorized in LienRegistry.");
  }

  // 3. Configure HealthFactor with Oracle
  const HealthFactor = await ethers.getContractAt("HealthFactor", deployments.healthFactor, deployer);
  const currentOracle = await HealthFactor.riskOracle();
  
  if (currentOracle !== deployments.riskOracle) {
    console.log(`Setting RiskOracle on HealthFactor to ${deployments.riskOracle}...`);
    const tx = await HealthFactor.setRiskOracle(deployments.riskOracle);
    await tx.wait();
    console.log("RiskOracle linked to HealthFactor.");
  } else {
    console.log("HealthFactor already linked to RiskOracle.");
  }

  console.log("Module linking complete.");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });