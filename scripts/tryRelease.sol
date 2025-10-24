// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {MilkiWay} from "../src/MilkiWay.sol";
import {TokenBridge} from "../src/TokenBridge.sol";

contract TryRelease is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address bridgeAddress = vm.envAddress("BRIDGE_DEPOSIT");
        address deployerAddress = vm.envAddress("ADDRESS");

        console.log("Deployer address:", deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        TokenBridge contractBridge = TokenBridge(bridgeAddress);

        contractBridge.release(bytes32("1"), deployerAddress,  1 * 10**18, 11155111);

        vm.stopBroadcast();

        console.log("Release called from contract", bridgeAddress);
    }
}