// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title  IAdaptor - minimal adaptor interface for protocol integrations
/// @notice Adaptors are thin wrappers that let the YieldRouter move vault funds
///         into and out of external protocols (Aave, Morpho, Curve, etc.).
///         Adaptors MUST be registered in ProtocolRegistry before use.
/// @dev    Two important patterns:
///         1) withdrawTo(recipient, amount) - instruct adaptor to withdraw from the protocol
///            and send the underlying tokens to `recipient` (typically the YieldRouter or Vault).
///         2) depositFrom(sender, amount) - adaptor accepts tokens (already transferred) and deposits
///            into the protocol. This two-step design keeps token transfers explicit and atomic-friendly.
interface IAdaptor {
    /// @notice Underlying asset (ERC20) managed by this adaptor (e.g. USDC)
    function asset() external view returns (address);

    /// @notice Deposit `amount` of underlying from `sender` into the target protocol
    /// @dev The caller should transfer `amount` of `asset()` to adaptor address BEFORE calling depositFrom,
    ///      or use ERC20 permit/Permit2 to allow adaptor to pull tokens.
    /// @param sender address from which tokens were provided (for accounting / events)
    /// @param amount amount of underlying to deposit
    function depositFrom(address sender, uint256 amount) external;

    /// @notice Withdraw `amount` of underlying from the protocol and send to `recipient`
    /// @dev This function must ensure `amount` of `asset()` is transferred to `recipient` before returning.
    ///      Implementations should handle protocol-specific logic (unwrapping, claiming rewards, etc.)
    /// @param recipient address that should receive the withdrawn underlying
    /// @param amount amount of underlying to withdraw
    function withdrawTo(address recipient, uint256 amount) external;

    /// @notice View function returning total assets held by this adaptor in terms of the underlying asset
    /// @dev Should reflect both on-protocol positions and any token balance held locally
    function totalAssets() external view returns (uint256);

    /// @notice Optional helper: allow adaptor to accept an arbitrary token (for reward tokens, etc.)
    /// @dev Not required for basic flow; adaptors can implement additional helpers as needed.
    /// function acceptToken(address token, uint256 amount) external;

    /* ========== EVENTS ========== */

    /// @notice emitted when depositFrom is executed
    event Deposited(address indexed sender, uint256 amount, uint256 timestamp);

    /// @notice emitted when withdrawTo is executed
    event Withdrawn(address indexed recipient, uint256 amount, uint256 timestamp);

    /// @notice emitted when adaptor's internal accounting / config changes
    event AdaptorUpdated(address indexed adaptor);
}
