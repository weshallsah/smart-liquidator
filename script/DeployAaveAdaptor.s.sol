// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/adaptor/AaveAdaptor.sol";

contract DeployAaveAdaptor is Script {
    function run() external returns (AaveAdaptor adaptor) {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        address USDC = address(0x75a65186a06D3A468A914c5de53E62843258134f);
        address AAVE_POOL = address(0x5E52dEc931FFb32f609681B8438A51c675cc232d);
        address AAVE_USDC_ATOKEN = address(0xCCADDc5E3Abd44A10df91EDEBD8596F6b7000cE2);

        adaptor = new AaveAdaptor(USDC, AAVE_POOL, AAVE_USDC_ATOKEN);

        console.log("AaveAdaptor deployed at:", address(adaptor));

        vm.stopBroadcast();
    }
}
