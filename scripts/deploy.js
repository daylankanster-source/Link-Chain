const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying LinkChain with account:", deployer.address);
  console.log("Balance:", (await hre.ethers.provider.getBalance(deployer.address)).toString());

  const LinkChain = await hre.ethers.getContractFactory("LinkChain");
  const c = await LinkChain.deploy();
  await c.waitForDeployment();

  const addr = await c.getAddress();
  console.log("LinkChain deployed to:", addr);
  console.log("\nNext steps:");
  console.log("1. Copy this address into frontend/index.html → CONTRACT_ADDRESS");
  console.log("2. If mainnet, also switch chainId/RPC/explorer in the same file");
}

main().catch((e) => { console.error(e); process.exit(1); });
