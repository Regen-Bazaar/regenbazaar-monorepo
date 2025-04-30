// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "../../contracts/staking/ImpactProductStaking.sol";
import "./DeploymentConfig.s.sol";
import "../../contracts/tokens/REBAZToken.sol";

/**
 * @title DeployImpactProductStaking
 * @dev Deploys the Impact Product Staking contract (step 3)
 */
contract DeployImpactProductStaking is DeploymentConfig {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function run() public {
        initialize();
        
        console.log("Step 3: Deploying ImpactProductStaking...");
        
        require(rebazTokenAddress != address(0), "REBAZToken not deployed");
        require(impactNFTAddress != address(0), "ImpactProductNFT not deployed");
        
        // if (stakingAddress != address(0)) {
        //     console.log("ImpactProductStaking already deployed at:", stakingAddress);
        //     return;
        // }
        
        vm.startBroadcast();
        
        ImpactProductStaking staking = new ImpactProductStaking(impactNFTAddress, rebazTokenAddress);
        stakingAddress = address(staking);
        
        // Grant staking contract permission to mint reward tokens
        REBAZToken rebazToken = REBAZToken(rebazTokenAddress);
        rebazToken.grantRole(MINTER_ROLE, stakingAddress);
        
        vm.stopBroadcast();
        
        console.log("ImpactProductStaking deployed at:", stakingAddress);
        
        // Save updated addresses
        saveDeployedAddresses();
    }
} 