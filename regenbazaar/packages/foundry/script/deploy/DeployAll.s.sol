// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "./DeploymentConfig.s.sol";

/**
 * @title DeployAll
 * @dev Runs the complete deployment sequence for all contracts
 */
contract DeployAll is DeploymentConfig {
    function run() public {
        initialize();
        
        console.log("Starting complete deployment sequence...");
        
        // Deploy each contract in sequence
        // deployToken = new DeployREBAZToken();
        // deployToken.run();
        
        // deployNFT = new DeployImpactProductNFT();
        // deployNFT.run();
        
        // deployStaking = new DeployImpactProductStaking();
        // deployStaking.run();
        
        // deployMarketplace = new DeployMarketplace();
        // deployMarketplace.run();
        
        // deployFactory = new DeployImpactProductFactory();
        // deployFactory.run();
        
        // Output final deployment status
        outputDeploymentSummary();
    }
    
    function outputDeploymentSummary() internal view {
        console.log("--------------------------------------------------");
        console.log("REGEN BAZAAR DEPLOYMENT SUMMARY");
        console.log("--------------------------------------------------");
        console.log("REBAZToken:           ", rebazTokenAddress);
        console.log("ImpactProductNFT:     ", impactNFTAddress);
        console.log("ImpactProductStaking: ", stakingAddress);
        console.log("RegenMarketplace:     ", marketplaceAddress);
        console.log("ImpactProductFactory: ", factoryAddress);
        console.log("--------------------------------------------------");
        console.log("Admin:                ", admin);
        console.log("Platform Wallet:      ", platformWallet);
        console.log("--------------------------------------------------");
    }
} 