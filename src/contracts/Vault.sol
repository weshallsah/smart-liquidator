// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title  Global Vault (ERC4626) for AI-driven fund allocation
/// @notice ERC4626-compatible vault that holds a single underlying asset.
///         The router (YieldRouter) is authorized to move funds from the vault
///         to protocol adaptors via `transferTo(...)`. The router is expected
///         to call adaptors which will deposit/withdraw into/from on-chain protocols.
/// @dev    For gas & simplicity the vault keeps an `externalAssets` uint that
///         the router updates after moving funds into adaptors. totalAssets()
///         returns vault balance + externalAssets. This avoids on-chain iteration
///         across adaptors and allows the router to report off-chain managed assets.
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Vault is ERC4626, Ownable {
    /// @notice address of the router allowed to pull/push funds for rebalancing
    address public router;

    /// @notice external assets tracked by the router (assets moved into adaptors/protocols)
    /// @dev router must call `updateExternalAssets` after a successful move
    uint256 public externalAssets;

    /// @notice event emitted when router is changed
    event RouterSet(address indexed previousRouter, address indexed newRouter);

    /// @notice event emitted when externalAssets updated
    event ExternalAssetsUpdated(uint256 previousValue, uint256 newValue);

    /// @param _asset underlying ERC20 token (e.g. USDC)
    /// @param _name vault share token name
    /// @param _symbol vault share token symbol
    constructor(IERC20 _asset, string memory _name, string memory _symbol)
        Ownable(msg.sender)
        ERC20(_name, _symbol)
        ERC4626(_asset)
    {}

    /* ========== MODIFIERS ========== */

    modifier onlyRouter() {
        require(msg.sender == router, "Vault: only router");
        _;
    }

    /* ========== ADMIN ========== */

    /// @notice set the router address (only owner)
    function setRouter(address _router) external onlyOwner {
        emit RouterSet(router, _router);
        router = _router;
    }

    /// @notice update router-reported external assets (only router)
    /// @dev router should sum the total underlying currently managed off-vault
    ///      by all adaptors and call this function to keep vault accounting accurate.
    function updateExternalAssets(uint256 _externalAssets) external onlyRouter {
        emit ExternalAssetsUpdated(externalAssets, _externalAssets);
        externalAssets = _externalAssets;
    }

    /* ========== ERC4626 OVERRIDES ========== */

    /// @notice total assets = asset balance held by vault + router-reported external assets
    function totalAssets() public view override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this)) + externalAssets;
    }

    /* ========== ROUTER HELPERS ========== */

    /// @notice transfer `amount` of the underlying asset from the vault to `recipient`
    /// @dev Only the router may instruct the vault to send funds to adaptors.
    function transferTo(address recipient, uint256 amount) external onlyRouter {
        require(recipient != address(0), "Vault: zero recipient");
        require(amount > 0, "Vault: zero amount");

        // ensure vault has enough liquid balance; router should manage externalAssets accordingly
        uint256 vaultBalance = IERC20(asset()).balanceOf(address(this));
        require(vaultBalance >= amount, "Vault: insufficient liquid balance");

        bool ok = IERC20(asset()).transfer(recipient, amount);
        require(ok, "Vault: transfer failed");
    }

    /* ========== EMERGENCY / RECOVERY ========== */

    /// @notice emergency withdraw: owner can pull tokens (useful for upgrades or emergency)
    /// @dev Highly privileged — restrict usage in production, consider timelock or multisig.
    function emergencyWithdraw(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Vault: zero address");
        bool ok = IERC20(asset()).transfer(to, amount);
        require(ok, "Vault: transfer failed");
    }

    /// @notice rescue any ERC20 accidentally sent to the vault (except the vault asset)
    function rescueToken(address token, address to, uint256 amount) external onlyOwner {
        require(token != address(asset()), "Vault: cannot rescue underlying asset");
        require(to != address(0), "Vault: zero address");
        IERC20(token).transfer(to, amount);
    }

    /// @notice Hook called after deposits (kept empty to allow router/adaptors to manage funds)
    /// @dev If you want automatic on-deposit actions, implement here.
    function _afterDeposit(uint256 assets, uint256) internal {
        // intentionally empty — router will decide where to allocate funds
    }

    /// @notice Hook called before withdraw (kept empty; router must ensure liquidity)
    function _beforeWithdraw(uint256 assets, uint256) internal {
        // intentionally empty — router is responsible to ensure liquidity or withdraw from adaptors
    }

    /* ========== VIEW HELPERS ========== */

    /// @notice view of vault's current liquid token balance (not including externalAssets)
    function liquidBalance() external view returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }
}
