/* SPDX-License-Identifier: MIT */
pragma solidity ^0.8.20;

/**
 * @title ILiquidationEngine
 * @notice Minimal interface for the LiquidationEngine, used by LendingPool
 *         to delegate liquidation execution.
 */
interface ILiquidationEngine {
    /**
     * @notice Execute a liquidation on an undercollateralized position.
     * @param borrower        The address of the borrower being liquidated
     * @param collateralAsset The collateral token to seize
     * @param debtToRepay     Amount of WETH debt the liquidator is repaying
     * @param liquidator      The address performing the liquidation
     */
    function executeLiquidation(
        address borrower,
        address collateralAsset,
        uint256 debtToRepay,
        address liquidator
    ) external;
}
