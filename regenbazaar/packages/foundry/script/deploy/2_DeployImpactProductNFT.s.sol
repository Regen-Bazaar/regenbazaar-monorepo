// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "../../contracts/tokens/ImpactProductNFT.sol";
import "./DeploymentConfig.s.sol";

/**
 * @title DeployImpactProductNFT
 * @dev Deploys the Impact Product NFT contract (step 2)
 */
contract DeployImpactProductNFT is DeploymentConfig {
    function run() public {
        initialize();
        console.log("Step 2: Deploying ImpactProductNFT...");
        require(platformWallet != address(0), "Platform wallet not set");
        // if (impactNFTAddress != address(0)) {
        //     console.log("ImpactProductNFT already deployed at:", impactNFTAddress);
        //     return;
        // }
        vm.startBroadcast();
        ImpactProductNFT impactNFT = new ImpactProductNFT(platformWallet, baseTokenURI);
        impactNFTAddress = address(impactNFT);
        vm.stopBroadcast();
        console.log("ImpactProductNFT deployed at:", impactNFTAddress);
        saveDeployedAddresses();
    }
} 