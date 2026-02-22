/* SPDX-License-Identifier: MIT */
pragma solidity ^0.8.20;

import {AssetVault} from "../core/AssetVault.sol";

/**
 * @title ILendingPool
 * @notice Minimal interface for LendingPool functions needed by LiquidationEngine.
 */
interface ILendingPool {
    /**
     * @notice Get the health factor for a user.
     * @param user The address to query
     * @return The health factor in WAD (1e18 = exactly at threshold)
     */
    function getHealthFactor(address user) external view returns (uint256);

    /**
     * @notice Get the current debt of a user including accrued interest.
     * @param user The address to query
     * @return The outstanding WETH debt amount
     */
    function getUserDebt(address user) external view returns (uint256);

    /**
     * @notice Get the AssetVault associated with a collateral token.
     * @param asset The collateral token address
     * @return The AssetVault contract for the given asset
     */
    function vaults(address asset) external view returns (AssetVault);

    /**
     * @notice Get the user's collateral receipt balance for a specific asset.
     * @param user  The address to query
     * @param asset The collateral token address
     * @return The receipt token balance held as collateral
     */
    function userCollateral(address user, address asset) external view returns (uint256);

    /**
     * @notice Reduce a borrower's debt. Only callable by LiquidationEngine.
     * @param borrower The borrower whose debt is reduced
     * @param amount   The WETH amount to reduce
     */
    function reduceDebt(address borrower, uint256 amount) external;

    /**
     * @notice Transfer collateral receipts from one user to another.
     *         Only callable by LiquidationEngine during liquidation.
     * @param from          The address to transfer collateral from
     * @param to            The address to transfer collateral to
     * @param asset         The collateral token address
     * @param receiptAmount The amount of receipt tokens to transfer
     */
    function transferCollateral(
        address from,
        address to,
        address asset,
        uint256 receiptAmount
    ) external;
}
