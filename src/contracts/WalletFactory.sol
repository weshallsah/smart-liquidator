// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Wallet} from "./Wallet.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title WalletFactory - deploys per-user Wallet contracts
/// @notice Each user gets a single Wallet instance. Factory prevents duplicates.
/// @dev Simple `new Wallet(owner)` deployment. For gas-optimizations we can switch to
///      minimal proxies (Clones) later. This factory is ownerless / open: anyone can call
///      createWallet for themselves or for other users (useful for onboarding UX).
contract WalletFactory {
    /// @notice owner => wallet address
    mapping(address => address) public wallets;

    /// @notice list of all wallets
    address[] public allWallets;

    event WalletCreated(address indexed owner, address indexed wallet);


    /// @notice create a wallet for msg.sender if not exists
    function createWallet() external returns (address walletAddr) {
        return createWalletFor(msg.sender);
    }

    /// @notice create wallet for a specified owner (useful for relayer-assisted onboarding)
    /// @dev If a wallet already exists for `owner`, returns the existing wallet address.
    function createWalletFor(address owner) public returns (address walletAddr) {
        require(owner != address(0), "WalletFactory: zero owner");

        walletAddr = wallets[owner];
        if (walletAddr != address(0)) {
            return walletAddr; // already exists
        }

        Wallet wallet = new Wallet(owner);
        walletAddr = address(wallet);

        wallets[owner] = walletAddr;
        allWallets.push(walletAddr);

        emit WalletCreated(owner, walletAddr);
    }

    /// @notice view helper: get number of deployed wallets
    function totalWallets() external view returns (uint256) {
        return allWallets.length;
    }

}
