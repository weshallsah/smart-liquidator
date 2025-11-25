// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Vault} from "../src/contracts/Vault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";

contract DeployVault is Script {
    function run() external returns (Vault vault) {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        address USDC = 0x75a65186a06D3A468A914c5de53E62843258134f;

        vault = new Vault(IERC20(USDC), "AI Liquidator Vault", "AILV");

        console.log("Vault deployed at:", address(vault));

        vm.stopBroadcast();
    }
}
