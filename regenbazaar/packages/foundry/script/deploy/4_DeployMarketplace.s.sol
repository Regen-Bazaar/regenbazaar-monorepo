// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "../../contracts/marketplace/MarketPlace.sol";
import "./DeploymentConfig.s.sol";

/**
 * @title DeployMarketplace
 * @dev Deploys the RegenMarketplace contract (step 4)
 */
contract DeployMarketplace is DeploymentConfig {
    function run() public {
        initialize();
        
        console.log("Step 4: Deploying RegenMarketplace...");
        
        require(impactNFTAddress != address(0), "ImpactProductNFT not deployed");
        require(platformWallet != address(0), "Platform wallet not set");
        
        // if (marketplaceAddress != address(0)) {
        //     console.log("RegenMarketplace already deployed at:", marketplaceAddress);
        //     return;
        // }
        
        vm.startBroadcast();
        
        RegenMarketplace marketplace = new RegenMarketplace(impactNFTAddress, platformWallet);
        marketplaceAddress = address(marketplace);
        
        vm.stopBroadcast();
        
        console.log("RegenMarketplace deployed at:", marketplaceAddress);
        
        // Save updated addresses
        saveDeployedAddresses();
    }
} 