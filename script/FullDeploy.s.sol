// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/contracts/Vault.sol";
import "../src/router/ProtocolRegistry.sol";
import "../src/router/YieldRouter.sol";
import "../src/adaptor/AaveAdaptor.sol";

contract FullDeploy is Script {
    function run() external returns (Vault vault, ProtocolRegistry registry, YieldRouter router, AaveAdaptor adaptor) {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // USDC + Aave addresses
        address USDC = address(0x75a65186a06D3A468A914c5de53E62843258134f);
        address AAVE_POOL = address(0x5E52dEc931FFb32f609681B8438A51c675cc232d);
        address AAVE_USDC_ATOKEN = address(0xCCADDc5E3Abd44A10df91EDEBD8596F6b7000cE2);

        // deploy
        vault = new Vault(IERC20(USDC), "AI Liquidator Vault", "AILV");
        registry = new ProtocolRegistry();
        adaptor = new AaveAdaptor(USDC, AAVE_POOL, AAVE_USDC_ATOKEN);
        router = new YieldRouter(registry, vault);

        // wire
        vault.setRouter(address(router));
        registry.addAdaptor(address(adaptor));
        router.setRelayer(msg.sender);

        console.log("Vault:", address(vault));
        console.log("Registry:", address(registry));
        console.log("Adaptor:", address(adaptor));
        console.log("Router:", address(router));

        vm.stopBroadcast();
    }
}

