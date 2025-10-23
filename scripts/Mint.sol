// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {MilkiWay} from "../src/MilkiWay.sol";
import {TokenBridge} from "../src/TokenBridge.sol";

contract Mint is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address bridgeAddress = vm.envAddress("BRIDGE_ADDRESS");


        console.log("Deployer address:", deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        TokenBridge contractBridge = TokenBridge(bridgeAddress);
        contractBridge.mintToken(100 * 10**18);

        vm.stopBroadcast();

        console.log("Minted to:", bridgeAddress);
    }
}