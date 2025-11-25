// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Smart Wallet for Gasless User Actions (Meta-Wallet)
 * @notice Every user gets one Wallet. It does NOT store long-term funds.
 *         It mainly:
 *           - Executes gasless meta-transactions signed by the user
 *           - Allows deposits/withdrawals into the global Vault
 *           - Allows relayer/TEE AI agent to perform actions on user's behalf
 *             (ONLY with valid EIP-712 signature)
 */

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IVault {
    function asset() external view returns (address);
    function deposit(uint256 amount, address to) external returns (uint256 shares);
    function withdraw(uint256 shares, address to) external returns (uint256 amount);
}

contract Wallet {
    using ECDSA for bytes32;

    address public owner; // the user
    address public relayer; // trusted relayer (your x402 server)
    uint256 public nonce; // meta-tx nonce for replay protection

    event Executed(address indexed signer, bytes data, uint256 nonce);
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event RelayerSet(address relayer);

    modifier onlyOwner() {
        require(msg.sender == owner, "Wallet: not owner");
        _;
    }

    constructor(address _owner) {
        require(_owner != address(0), "zero owner");
        owner = _owner;
    }

    /* ============= CONFIG ============= */

    function setRelayer(address _relayer) external onlyOwner {
        relayer = _relayer;
        emit RelayerSet(_relayer);
    }

    function changeOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero owner");
        emit OwnerChanged(owner, newOwner);
        owner = newOwner;
    }

    /* ============= META-TX EXECUTION (EIP-712 like) ============= */

    bytes32 public constant META_TX_TYPEHASH =
        keccak256("MetaTx(address target,bytes data,uint256 value,uint256 nonce,uint256 deadline)");

    /// @notice execute any call on behalf of the user IF signed with valid EIP-712 signature
    /// @dev relayer or TEE agent calls this, passing user signature
    function executeMetaTx(
        address target,
        bytes calldata data,
        uint256 value,
        uint256 deadline,
        bytes calldata signature
    ) external returns (bytes memory result) {
        require(block.timestamp <= deadline, "meta-tx expired");
        require(msg.sender == relayer, "Not authorized relayer");

        // reconstruct signed payload
        bytes32 structHash = keccak256(abi.encode(META_TX_TYPEHASH, target, keccak256(data), value, nonce, deadline));

        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", structHash));

        address recovered = digest.recover(signature);
        require(recovered == owner, "Invalid signer");

        // increment nonce
        nonce++;

        // low-level call
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        require(success, "Meta-tx call failed");

        emit Executed(owner, data, nonce - 1);

        return returndata;
    }

    /* ============= DIRECT ACTIONS ============= */

    /// @notice User deposits into vault (normal tx, not meta)
    function depositIntoVault(IVault vault, uint256 amount) external onlyOwner {
        IERC20 token = IERC20(vault.asset());
        require(token.transferFrom(owner, address(this), amount), "transferFrom failed");
        token.approve(address(vault), amount);
        vault.deposit(amount, owner);
    }

    /// @notice User withdraws from vault (normal)
    function withdrawFromVault(IVault vault, uint256 shares) external onlyOwner {
        vault.withdraw(shares, owner);
    }

    /* ============= ALLOW RECEIVING ETH (future AA) ============= */

    receive() external payable {}
}
