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

        MilkiWay contractToken1 = new MilkiWay(deployerAddress);

        TokenBridge contractBridge1 = new TokenBridge(address(contractToken1));

        contractToken1.transferOwnership(address(contractBridge1));

        MilkiWay contractToken2 = new MilkiWay(deployerAddress);

        TokenBridge contractBridge2 = new TokenBridge(address(contractToken2));

        contractToken2.transferOwnership(address(contractBridge2));

        vm.stopBroadcast();

        console.log("MilkiWay 1 deployed successfully!");
        console.log("Contract address:", address(contractToken1));
        console.log("Transaction hash:", vm.toString(tx.origin));

        console.log();

        console.log("TokenBridge 1 deployed successfully!");
        console.log("Contract address:", address(contractBridge1));
        console.log("Transaction hash:", vm.toString(tx.origin));

        console.log();
        console.log();

        console.log("MilkiWay 2 deployed successfully!");
        console.log("Contract address:", address(contractToken2));
        console.log("Transaction hash:", vm.toString(tx.origin));

        console.log();

        console.log("TokenBridge 2 deployed successfully!");
        console.log("Contract address:", address(contractBridge2));
        console.log("Transaction hash:", vm.toString(tx.origin));
    }
}