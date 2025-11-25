// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AaveAdaptor (Polygon Amoy Aave v3)
 * @notice Integrates your YieldRouter with Aave v3 lending pool.
 *         Implements: depositFrom(), withdrawTo(), totalAssets()
 *
 *         Adaptor Pattern:
 *          - Withdraw: adaptor withdraws from Aave and transfers underlying to router
 *          - Deposit: router approves adaptor, adaptor pulls tokens and supplies into Aave
 */

import {IAdaptor} from "./IAdaptor.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

contract AaveAdaptor is IAdaptor {
    using SafeERC20 for IERC20;

    address public immutable override asset; // underlying asset (e.g. USDC)
    IPool public immutable lendingPool; // Aave v3 Pool
    address public immutable aToken; // corresponding aToken

    constructor(address _asset, address _pool, address _aToken) {
        require(_asset != address(0), "AaveAdaptor: invalid asset");
        require(_pool != address(0), "AaveAdaptor: invalid pool");
        require(_aToken != address(0), "AaveAdaptor: invalid aToken");

        asset = _asset;
        lendingPool = IPool(_pool);
        aToken = _aToken;
    }

    /**
     * @notice Deposit underlying into Aave v3
     * @dev Router transfers underlying to this adaptor,
     *      so adaptor must pull the tokens via transferFrom.
     */
    function depositFrom(address sender, uint256 amount) external override {
        require(amount > 0, "AaveAdaptor: zero amount");

        // Pull tokens from the router (or sender)
        IERC20(asset).safeTransferFrom(sender, address(this), amount);

        // Approve lending pool
        IERC20(asset).safeIncreaseAllowance(address(lendingPool), 0);
        IERC20(asset).safeIncreaseAllowance(address(lendingPool), amount);

        // Supply into Aave
        lendingPool.supply(asset, amount, address(this), 0);

        emit Deposited(sender, amount, block.timestamp);
    }

    /**
     * @notice Withdraw underlying from Aave v3
     * @dev Sends funds into `recipient` (router)
     */
    function withdrawTo(address recipient, uint256 amount) external override {
        require(recipient != address(0), "AaveAdaptor: zero recipient");
        require(amount > 0, "AaveAdaptor: zero amount");

        // Withdraw from Aave directly to router
        lendingPool.withdraw(asset, amount, recipient);

        emit Withdrawn(recipient, amount, block.timestamp);
    }

    /**
     * @notice Returns total underlying assets managed by this adaptor (in Aave)
     */
    function totalAssets() external view override returns (uint256) {
        return IERC20(aToken).balanceOf(address(this));
    }
}
