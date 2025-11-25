// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAdaptor} from "./IAdaptor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title MockAdaptor - simple adaptor for local testing
/// @notice Simulates deposit/withdraw flows. Uses ERC20 transferFrom for depositFrom
///         and direct transfer for withdrawTo (simulating protocol withdrawal).
contract MockAdaptor is IAdaptor {
    address public immutable override asset;
    string public name;

    constructor(address _asset, string memory _name) {
        require(_asset != address(0), "MockAdaptor: zero asset");
        asset = _asset;
        name = _name;
    }

    /// @notice deposit: adaptor pulls tokens from `sender` into adaptor address (simulate deposit)
    /// @dev caller must have approved this adaptor to pull tokens from `sender`.
    function depositFrom(address sender, uint256 amount) external override {
        require(amount > 0, "MockAdaptor: zero");
        bool ok = IERC20(asset).transferFrom(sender, address(this), amount);
        require(ok, "MockAdaptor: transferFrom failed");
        emit Deposited(sender, amount, block.timestamp);
    }

    /// @notice withdraw: adaptor transfers tokens it holds to `recipient` (simulate withdraw)
    function withdrawTo(address recipient, uint256 amount) external override {
        require(recipient != address(0), "MockAdaptor: zero recipient");
        require(amount > 0, "MockAdaptor: zero amount");
        uint256 bal = IERC20(asset).balanceOf(address(this));
        require(bal >= amount, "MockAdaptor: insufficient balance");
        bool ok = IERC20(asset).transfer(recipient, amount);
        require(ok, "MockAdaptor: transfer failed");
        emit Withdrawn(recipient, amount, block.timestamp);
    }

    function totalAssets() external view override returns (uint256) {
        return IERC20(asset).balanceOf(address(this));
    }
}
