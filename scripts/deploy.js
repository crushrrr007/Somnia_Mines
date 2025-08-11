const { ethers } = require("hardhat");

async function main() {
    console.log("🚀 Deploying Somnia Mines contracts...");
    
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with account:", deployer.address);
    
    // Fix for ethers v6
    const balance = await ethers.provider.getBalance(deployer.address);
    console.log("Account balance:", ethers.formatEther(balance), "STT");
    
    if (balance < ethers.parseEther("0.1")) {
        console.log("⚠️  Warning: Low balance. You might need more STT from faucet.");
    }
    
    // Prepare EIP-1559 fees
    const latestBlock = await ethers.provider.getBlock("latest");
    const baseFee = latestBlock.baseFeePerGas ?? 0n;
    const maxPriorityFeePerGas = ethers.parseUnits(process.env.PRIORITY_FEE_GWEI || "1", "gwei");
    const maxFeePerGas = baseFee + maxPriorityFeePerGas;

    // Deploy GEM Token
    console.log("\n📄 Deploying GEM Token...");
    const GEMToken = await ethers.getContractFactory("GEMToken");
    // Use conservative gas settings to avoid RPC overestimation on Somnia
    const gemToken = await GEMToken.deploy({
        maxFeePerGas,
        maxPriorityFeePerGas
    });
    await gemToken.waitForDeployment();
    const gemTokenAddress = await gemToken.getAddress();
    
    console.log("✅ GEM Token deployed to:", gemTokenAddress);
    
    // Deploy Somnia Mines Game
    console.log("\n🎮 Deploying Somnia Mines Game...");
    const SomniaMines = await ethers.getContractFactory("SomniaMines");
    const minesGame = await SomniaMines.deploy(gemTokenAddress, {
        maxFeePerGas,
        maxPriorityFeePerGas
    });
    await minesGame.waitForDeployment();
    const minesGameAddress = await minesGame.getAddress();
    
    console.log("✅ Somnia Mines deployed to:", minesGameAddress);
    
    // Set up permissions
    console.log("\n🔐 Setting up permissions...");
    const tx = await gemToken.transferOwnership(minesGameAddress);
    await tx.wait();
    console.log("✅ Ownership transferred to Mines contract");
    
    // Contract summary
    console.log("\n📋 Contract Summary:");
    console.log("=====================");
    console.log("GEM Token Address:    ", gemTokenAddress);
    console.log("Mines Game Address:   ", minesGameAddress);
    console.log("Deployer Address:     ", deployer.address);
    console.log("Network:              Somnia Testnet (Chain ID: 50312)");
    
    // Create deployments directory and save info
    const fs = require('fs');
    const path = require('path');
    
    // Create deployments directory if it doesn't exist
    const deploymentsDir = path.join(__dirname, '..', 'deployments');
    if (!fs.existsSync(deploymentsDir)) {
        fs.mkdirSync(deploymentsDir, { recursive: true });
    }
    
    const deploymentInfo = {
        network: "Somnia Testnet",
        chainId: 50312,
        timestamp: new Date().toISOString(),
        deployer: deployer.address,
        contracts: {
            GEMToken: {
                address: gemTokenAddress,
                blockNumber: await ethers.provider.getBlockNumber()
            },
            SomniaMines: {
                address: minesGameAddress,
                blockNumber: await ethers.provider.getBlockNumber()
            }
        },
        explorer: {
            gemToken: `https://shannon-explorer.somnia.network/address/${gemTokenAddress}`,
            minesGame: `https://shannon-explorer.somnia.network/address/${minesGameAddress}`
        }
    };
    
    // Write deployment info to file
    fs.writeFileSync(
        path.join(deploymentsDir, 'somnia-testnet.json'),
        JSON.stringify(deploymentInfo, null, 2)
    );
    
    console.log("\n💾 Deployment info saved to deployments/somnia-testnet.json");
    
    // Test basic functionality
    console.log("\n🧪 Running basic tests...");
    
    const tokenName = await gemToken.name();
    const tokenSymbol = await gemToken.symbol();
    const tokenDecimals = await gemToken.decimals();
    console.log(`Token: ${tokenName} (${tokenSymbol}) with ${tokenDecimals} decimals`);
    
    // Test purchase quote
    const purchaseAmount = ethers.parseEther("0.01"); // 0.01 STT
    const expectedGems = await gemToken.getPurchaseQuote(purchaseAmount);
    console.log(`Quote: ${ethers.formatEther(purchaseAmount)} STT = ${ethers.formatEther(expectedGems)} GEM`);
    
    console.log("\n🎉 Deployment completed successfully!");
    console.log("\n📝 Next steps:");
    console.log("1. Update frontend with these contract addresses:");
    console.log(`   GEM Token: ${gemTokenAddress}`);
    console.log(`   Mines Game: ${minesGameAddress}`);
    console.log("2. Get STT tokens from faucet if needed");
    console.log("3. Test token purchasing and game functionality");
    
    return {
        gemToken: gemTokenAddress,
        minesGame: minesGameAddress
    };
}

main()
    .then((contracts) => {
        console.log("\n✨ All contracts deployed:", contracts);
        process.exit(0);
    })
    .catch((error) => {
        console.error("❌ Deployment failed:", error);
        process.exit(1);
    });