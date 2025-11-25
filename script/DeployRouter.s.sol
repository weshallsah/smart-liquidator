// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/router/YieldRouter.sol";
import "../src/router/ProtocolRegistry.sol";
import "../src/contracts/Vault.sol";

contract DeployRouter is Script {
    function run() external returns (YieldRouter router) {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Replace with deployed addresses
        address registry = vm.envAddress("REGISTRY");
        address vault = vm.envAddress("VAULT");

        router = new YieldRouter(ProtocolRegistry(registry), Vault(vault));
        console.log("YieldRouter deployed at:", address(router));

        vm.stopBroadcast();
    }
}
