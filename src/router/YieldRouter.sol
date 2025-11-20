// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title YieldRouter - execute TEE-signed MOVE_FUNDS instructions
/// @notice Verifies EIP-712 signed "Move" instructions and executes an atomic
///         sequence: withdraw from `fromAdaptor` -> receive underlying -> deposit into `toAdaptor`.
/// @dev Adaptor conventions:
///      - withdrawTo(recipient, amount) : adaptor withdraws from protocol and transfers `amount` to `recipient`.
///      - depositFrom(sender, amount)   : adaptor expects `amount` tokens to be present (sender approved) and deposits into protocol.
///
/// Example flow:
/// 1) TEE signs Move(signer, from, to, amount, deadline, nonce)
/// 2) Relayer calls executeMove(..., sig)
/// 3) Router calls IAdaptor(from).withdrawTo(address(this), amount)
/// 4) Router approves `toAdaptor` and calls IAdaptor(to).depositFrom(address(this), amount)
/// 5) Router updates Vault.externalAssets with new reported total
///
/// For docs/diagram include: /mnt/data/d7678aa0-b09b-4900-b640-b2ad289a5216.png
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import "../adaptor/IAdaptor.sol";
import "../contracts/Vault.sol";
import "./ProtocolRegistry.sol";

contract YieldRouter is EIP712, Ownable {
    using ECDSA for bytes32;

    ProtocolRegistry public registry;
    Vault public immutable vault;
    address public relayer; // allowed submitter (relayer or 0 for public)
    bytes32 public constant MOVE_TYPEHASH = keccak256(
        "Move(address signer,address fromAdaptor,address toAdaptor,uint256 amount,uint256 deadline,uint256 nonce)"
    );

    /// per-signer nonce
    mapping(address => uint256) public nonces;

    event MoveExecuted(
        address indexed signer,
        address indexed fromAdaptor,
        address indexed toAdaptor,
        uint256 amount,
        uint256 nonce,
        bytes32 txRef
    );
    event RelayerSet(address indexed relayer);
    event RegistryUpdated(address indexed registry);

    constructor(ProtocolRegistry _registry, Vault _vault) EIP712("YieldRouter", "1") {
        require(address(_registry) != address(0), "zero registry");
        require(address(_vault) != address(0), "zero vault");
        registry = _registry;
        vault = _vault;
    }

    /* ========== ADMIN ========== */

    function setRelayer(address _relayer) external onlyOwner {
        relayer = _relayer;
        emit RelayerSet(_relayer);
    }

    function setRegistry(ProtocolRegistry _registry) external onlyOwner {
        require(address(_registry) != address(0), "zero registry");
        registry = _registry;
        emit RegistryUpdated(address(_registry));
    }

    /* ========== SIGNATURE HELPERS ========== */

    /// @notice Hash typed data (EIP-712) for Move
    function _hashMove(
        address signer,
        address fromAdaptor,
        address toAdaptor,
        uint256 amount,
        uint256 deadline,
        uint256 nonce
    ) internal view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(MOVE_TYPEHASH, signer, fromAdaptor, toAdaptor, amount, deadline, nonce)
        );
        return _hashTypedDataV4(structHash);
    }

    function _verifyMoveSig(
        address signer,
        address fromAdaptor,
        address toAdaptor,
        uint256 amount,
        uint256 deadline,
        uint256 nonce,
        bytes memory sig
    ) internal view returns (bool) {
        require(block.timestamp <= deadline, "YieldRouter: expired");
        require(nonces[signer] == nonce, "YieldRouter: bad nonce");
        bytes32 digest = _hashMove(signer, fromAdaptor, toAdaptor, amount, deadline, nonce);
        address recovered = ECDSA.recover(digest, sig);
        return recovered == signer;
    }

    /* ========== CORE: executeMove ========== */

    /// @notice Execute a signed move instruction (only relayer/owner or public if relayer==address(0))
    /// @param signer the address whose key signed the Move (typically TEE agent's public key)
    /// @param fromAdaptor adaptor to withdraw from (must be registered)
    /// @param toAdaptor adaptor to deposit into (must be registered)
    /// @param amount amount of underlying to move (in asset units)
    /// @param deadline signature expiry timestamp
    /// @param nonce signer nonce (must match on-chain)
    /// @param sig EIP-712 signature bytes
    /// @param newExternalAssets optional: new total externalAssets value to update Vault accounting after move
    function executeMove(
        address signer,
        address fromAdaptor,
        address toAdaptor,
        uint256 amount,
        uint256 deadline,
        uint256 nonce,
        bytes calldata sig,
        uint256 newExternalAssets
    ) external returns (bytes32) {
        // restrict who can submit: relayer OR owner OR public if relayer == address(0)
        require(
            relayer == address(0) || msg.sender == relayer || msg.sender == owner(), "YieldRouter: submit not allowed"
        );

        require(registry.isAdaptor(fromAdaptor), "YieldRouter: from adaptor not registered");
        require(registry.isAdaptor(toAdaptor), "YieldRouter: to adaptor not registered");
        require(amount > 0, "YieldRouter: zero amount");
        require(
            _verifyMoveSig(signer, fromAdaptor, toAdaptor, amount, deadline, nonce, sig), "YieldRouter: invalid sig"
        );

        // consume nonce
        nonces[signer] = nonces[signer] + 1;

        // Step 1: instruct fromAdaptor to withdraw underlying to this router
        IAdaptor(fromAdaptor).withdrawTo(address(this), amount);

        // Step 2: validate we received funds
        address asset = IAdaptor(fromAdaptor).asset();
        uint256 bal = IERC20(asset).balanceOf(address(this));
        require(bal >= amount, "YieldRouter: insufficient withdrawn amount");

        // Step 3: Approve toAdaptor and call depositFrom
        // Approve exactly amount (safer patterns: use SafeERC20 and reset allowance if needed)
        IERC20(asset).approve(toAdaptor, amount);

        // call depositFrom on toAdaptor which should deposit the tokens into the target protocol
        IAdaptor(toAdaptor).depositFrom(address(this), amount);

        // Step 4: update vault externalAssets (router provides authoritative view)
        // Router calls this so that Vault.totalAssets() becomes consistent after funds moved.
        // Only update if a non-zero value is provided (avoids accidental resets)
        if (newExternalAssets > 0) {
            // vault.updateExternalAssets is only callable by the router address — ensure this contract is authorized
            // The owner should set vault.setRouter(address(this)) after deployment.
            vault.updateExternalAssets(newExternalAssets);
        }

        // Emit MoveExecuted with a reference (blockhash previous for traceability)
        bytes32 txRef = keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp, signer, amount));
        emit MoveExecuted(signer, fromAdaptor, toAdaptor, amount, nonce, txRef);

        return txRef;
    }
}
