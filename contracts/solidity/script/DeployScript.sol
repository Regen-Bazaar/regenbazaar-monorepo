// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {RegenBazaar} from "src/RegenBazaar.sol";

contract DeployContract is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy your contract
        RegenBazaar contractInstance = new RegenBazaar();

        vm.stopBroadcast();
    }
}
