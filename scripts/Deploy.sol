// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {MilkiWay} from "../src/MilkiWay.sol";
import {TokenBridge} from "../src/TokenBridge.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.envAddress("ADDRESS");


        console.log("Deployer address:", deployerPrivateKey);
        console.log("Deploying contract...");

        vm.startBroadcast(deployerPrivateKey);

        MilkiWay contractToken = new MilkiWay(deployerAddress);

        TokenBridge contractBridge = new TokenBridge(address(contractToken));

        contractToken.transferOwnership(address(contractBridge));

        vm.stopBroadcast();

        console.log("MilkiWay deployed successfully!");
        console.log("Contract address:", address(contractToken));
        console.log("Transaction hash:", vm.toString(tx.origin));

        console.log();

        console.log("TokenBridge deployed successfully!");
        console.log("Contract address:", address(contractBridge));
        console.log("Transaction hash:", vm.toString(tx.origin));
    }
}