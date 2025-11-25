// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/router/ProtocolRegistry.sol";

contract DeployRegistry is Script {
    function run() external returns (ProtocolRegistry registry) {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        registry = new ProtocolRegistry();
        console.log("ProtocolRegistry deployed at:", address(registry));

        vm.stopBroadcast();
    }
}
