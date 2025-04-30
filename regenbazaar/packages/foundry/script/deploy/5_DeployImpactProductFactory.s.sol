// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "../../contracts/factory/ImpactProductFactory.sol";
import "../../contracts/tokens/ImpactProductNFT.sol";
import "./DeploymentConfig.s.sol";

/**
 * @title DeployImpactProductFactory
 * @dev Deploys the ImpactProductFactory contract (step 5)
 */
contract DeployImpactProductFactory is DeploymentConfig {
    // Define role constants directly
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    
    function run() public {
        initialize();
        
        console.log("Step 5: Deploying ImpactProductFactory...");
        
        require(impactNFTAddress != address(0), "ImpactProductNFT not deployed");
        require(platformWallet != address(0), "Platform wallet not set");
        
        // if (factoryAddress != address(0)) {
        //     console.log("ImpactProductFactory already deployed at:", factoryAddress);
        //     return;
        // }
        
        vm.startBroadcast();
        
        ImpactProductFactory factory = new ImpactProductFactory(impactNFTAddress, platformWallet);
        factoryAddress = address(factory);
        
        // Grant factory permission to mint NFTs
        ImpactProductNFT impactNFT = ImpactProductNFT(impactNFTAddress);
        impactNFT.grantRole(MINTER_ROLE, factoryAddress);
        impactNFT.grantRole(VERIFIER_ROLE, factoryAddress);
        
        // Add initial impact categories
        factory.addImpactCategory("Reforestation", 2500);
        factory.addImpactCategory("Renewable Energy", 3500);
        factory.addImpactCategory("Clean Water", 3000);
        factory.addImpactCategory("Biodiversity", 2800);
        // factory.addImpactCategory("Waste Management", 2000); // Comment this if already exists
        
        vm.stopBroadcast();
        
        console.log("ImpactProductFactory deployed at:", factoryAddress);
        
        // Save updated addresses
        saveDeployedAddresses();
    }
} 