// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {MilkiWay} from "../src/MilkiWay.sol";
import {TokenBridge} from "../src/TokenBridge.sol";

contract Mint is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address bridgeAddress1 = vm.envAddress("BRIDGE_ADDRESS_1");
        address bridgeAddress2 = vm.envAddress("BRIDGE_ADDRESS_2");


        console.log("Deployer address:", deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        TokenBridge contractBridge1 = TokenBridge(bridgeAddress1);
        contractBridge1.mintToken(100 * 10**18);

        TokenBridge contractBridge2 = TokenBridge(bridgeAddress2);
        contractBridge2.mintToken(200 * 10**18);

        vm.stopBroadcast();

        console.log("Minted to:", bridgeAddress1);
        console.log("Minted to:", bridgeAddress2);
    }
}