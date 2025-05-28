// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

/**
 * @title DeploymentConfig
 * @dev Manages configuration and addresses for the deployment sequence
 */
contract DeploymentConfig is Script {
    // Configuration
    address public admin;
    address public platformWallet;
    uint256 public initialTokenSupply;
    string public baseTokenURI;
    
    // Deployed addresses
    address public rebazTokenAddress;
    address public impactNFTAddress;
    address public stakingAddress;
    address public marketplaceAddress; 
    address public factoryAddress;
    
    // Status tracking
    bool public initialized;
    
    function initialize() public virtual {
        require(!initialized, "Already initialized");
        
        // Default configuration
        admin = msg.sender;
        platformWallet = msg.sender;
        initialTokenSupply = 1_000_000 * 10**18;
        baseTokenURI = "https://api.regenbazaar.com/metadata/";
        
        // Override with env variables if available
        if (vm.envOr("ADMIN_ADDRESS", bytes("")).length > 0) {
            admin = vm.envAddress("ADMIN_ADDRESS");
        }
        
        if (vm.envOr("PLATFORM_WALLET", bytes("")).length > 0) {
            platformWallet = vm.envAddress("PLATFORM_WALLET");
        }
        
        if (vm.envOr("INITIAL_TOKEN_SUPPLY", bytes("")).length > 0) {
            initialTokenSupply = vm.envUint("INITIAL_TOKEN_SUPPLY");
        }
        
        if (vm.envOr("BASE_TOKEN_URI", bytes("")).length > 0) {
            baseTokenURI = vm.envString("BASE_TOKEN_URI");
        }
        
        // Load previously deployed addresses if available
        loadDeployedAddresses();
        
        initialized = true;
        
        console.log("Deployment configuration initialized:");
        console.log("  Admin:           ", admin);
        console.log("  Platform Wallet: ", platformWallet);
    }
    
    function loadDeployedAddresses() internal {
        string memory deploymentFile = "deployments/addresses.json";
        
        if (vm.exists(deploymentFile)) {
            string memory json = vm.readFile(deploymentFile);
            
            // Parse JSON and load addresses
            if (vm.parseJson(json, ".rebazToken").length > 0) {
                rebazTokenAddress = vm.parseJsonAddress(json, ".rebazToken");
            }
            
            if (vm.parseJson(json, ".impactNFT").length > 0) {
                impactNFTAddress = vm.parseJsonAddress(json, ".impactNFT");
            }
            
            if (vm.parseJson(json, ".staking").length > 0) {
                stakingAddress = vm.parseJsonAddress(json, ".staking");
            }
            
            if (vm.parseJson(json, ".marketplace").length > 0) {
                marketplaceAddress = vm.parseJsonAddress(json, ".marketplace");
            }
            
            if (vm.parseJson(json, ".factory").length > 0) {
                factoryAddress = vm.parseJsonAddress(json, ".factory");
            }
            
            console.log("Loaded deployed addresses from file");
        }
    }
    
    function saveDeployedAddresses() internal {
        // Create deployments directory if it doesn't exist
        if (!vm.exists("deployments/")) {
            vm.createDir("deployments", true);
        }
        
        // Construct JSON
        string memory json = '{"rebazToken":"';
        json = string.concat(json, vm.toString(rebazTokenAddress));
        json = string.concat(json, '","impactNFT":"');
        json = string.concat(json, vm.toString(impactNFTAddress));
        json = string.concat(json, '","staking":"');
        json = string.concat(json, vm.toString(stakingAddress));
        json = string.concat(json, '","marketplace":"');
        json = string.concat(json, vm.toString(marketplaceAddress));
        json = string.concat(json, '","factory":"');
        json = string.concat(json, vm.toString(factoryAddress));
        json = string.concat(json, '"}');
        
        // Write to file
        vm.writeFile("deployments/addresses.json", json);
        console.log("Saved deployed addresses to file");
    }
}