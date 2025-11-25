// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/contracts/Vault.sol";
import "../src/router/YieldRouter.sol";
import "../src/router/ProtocolRegistry.sol";
import "../src/adaptor/AaveAdaptor.sol";

contract SetupSystem is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        Vault vault = Vault(vm.envAddress("VAULT"));
        YieldRouter router = YieldRouter(vm.envAddress("ROUTER"));
        ProtocolRegistry registry = ProtocolRegistry(vm.envAddress("REGISTRY"));
        AaveAdaptor aaveAdaptor = AaveAdaptor(vm.envAddress("AAVE_ADAPTOR"));

        // set router in vault
        vault.setRouter(address(router));
        console.log("Set router in vault");

        // add adaptor to registry
        registry.addAdaptor(address(aaveAdaptor));
        console.log("Added Aave adaptor");

        // set router relayer (for now: owner)
        router.setRelayer(msg.sender);
        console.log("Router relayer set");

        vm.stopBroadcast();
    }
}

