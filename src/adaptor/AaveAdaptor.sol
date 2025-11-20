// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAdaptor} from "./IAdaptor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @notice Minimal Aave Pool interface (supply/withdraw signatures)
interface IAavePool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

/// @title AaveAdapter
/// @notice Adapter to deposit/withdraw from Aave (v3 compatible signatures)
contract AaveAdapter is IAdaptor, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Aave pool contract (e.g., Aave V3 pool address)
    address public pool;

    /// @notice Allowed callers (SmartWallets / VaultRouter / YieldRouter)
    mapping(address => bool) public allowedCaller;

    event Invested(address indexed caller, address indexed token, uint256 amount, address indexed onBehalf);
    event Divested(address indexed caller, address indexed token, uint256 amount, address indexed to);
    event Harvested(address indexed caller, address indexed token, uint256 amount);
    event AllowedCallerSet(address indexed who, bool allowed);
    event PoolSet(address indexed pool);

    constructor(address _pool) {
        require(_pool != address(0), "AaveAdapter: zero pool");
        pool = _pool;
    }

    modifier onlyAllowed() {
        require(allowedCaller[msg.sender] || msg.sender == owner(), "AaveAdapter: caller-not-allowed");
        _;
    }

    /// @notice Set new Aave pool address
    function setPool(address _pool) external onlyOwner {
        require(_pool != address(0), "AaveAdapter: zero pool");
        pool = _pool;
        emit PoolSet(_pool);
    }

    /// @notice Set allowed caller (SmartWallets, VaultRouter, etc.)
    function setAllowedCaller(address who, bool allowed) external onlyOwner {
        allowedCaller[who] = allowed;
        emit AllowedCallerSet(who, allowed);
    }

    /// @notice Invest `amount` of `token` into Aave on behalf of `onBehalf`.
    /// @dev Caller must have transferred `amount` of `token` to this adapter before calling.
    /// @param token Underlying token address (e.g., USDC)
    /// @param amount Amount of underlying present in adapter to supply
    /// @param data ABI-encoded extra params; expected: abi.encode(address onBehalf)
    function invest(address token, uint256 amount, bytes calldata data) external override nonReentrant onlyAllowed {
        require(amount > 0, "AaveAdapter: zero amount");
        require(pool != address(0), "AaveAdapter: pool-not-set");

        address onBehalf = _decodeRecipientOrDefault(data, msg.sender);

        // Approve pool
        IERC20(token).safeApprove(pool, 0); // reset
        IERC20(token).safeApprove(pool, amount);

        // Call Aave supply - pulls tokens from adapter and credits `onBehalf`
        IAavePool(pool).supply(token, amount, onBehalf, 0);

        // reset approval (optional but safer)
        IERC20(token).safeApprove(pool, 0);

        emit Invested(msg.sender, token, amount, onBehalf);
    }

    /// @notice Withdraw `amount` of `token` from Aave and send underlying to `to`.
    /// @param token Underlying token address
    /// @param amount Amount to withdraw (use type(uint256).max to withdraw all)
    /// @param data ABI-encoded extra params; expected: abi.encode(address to)
    function divest(address token, uint256 amount, bytes calldata data) external override nonReentrant onlyAllowed {
        require(pool != address(0), "AaveAdapter: pool-not-set");

        address to = _decodeRecipientOrDefault(data, msg.sender);

        // withdraw returns the amount withdrawn
        uint256 withdrawn = IAavePool(pool).withdraw(token, amount, to);

        emit Divested(msg.sender, token, withdrawn, to);
    }

    /// @notice Harvest rewards (if configured). For Aave this depends on incentives contract.
    /// Currently a no-op placeholder (returns 0). Extend if you wire incentives.
    function harvest(
        address token,
        bytes calldata /*data*/
    )
        external
        override
        nonReentrant
        onlyAllowed
        returns (uint256)
    {
        // Implement reward claiming (stkAAVE/other) if you wire Aave incentives contract.
        // Placeholder: return 0 until you implement reward logic.
        emit Harvested(msg.sender, token, 0);
        return 0;
    }

    /// @notice Rescue accidental ERC20 sent to this adapter
    function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
    }

    /// @dev Helper to decode recipient from calldata or default to caller
    function _decodeRecipientOrDefault(bytes calldata data, address defaultAddr) internal pure returns (address) {
        if (data.length >= 32) {
            // decode single address
            return abi.decode(data, (address));
        }
        return defaultAddr;
    }
}
