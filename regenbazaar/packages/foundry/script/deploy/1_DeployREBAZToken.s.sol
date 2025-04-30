// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "../../contracts/tokens/REBAZToken.sol";
import "./DeploymentConfig.s.sol";

/**
 * @title DeployREBAZToken
 * @dev Deploys the REBAZ token contract (step 1)
 */
contract DeployREBAZToken is DeploymentConfig {
    function run() public {
        initialize();
        console.log("Step 1: Deploying REBAZToken...");
        // if (rebazTokenAddress != address(0)) {
        //     console.log("REBAZToken already deployed at:", rebazTokenAddress);
        //     return;
        // }
        vm.startBroadcast();
        REBAZToken rebazToken = new REBAZToken(initialTokenSupply, admin);
        rebazTokenAddress = address(rebazToken);
        vm.stopBroadcast();
        console.log("REBAZToken deployed at:", rebazTokenAddress);
        saveDeployedAddresses();
    }
}
