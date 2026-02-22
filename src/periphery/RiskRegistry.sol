/* SPDX-License-Identifier: MIT */
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DataTypes} from "../libraries/DataTypes.sol";

/**
 * @title RiskRegistry
 * @notice Per-asset risk parameter configuration.
 *         Owner sets LTV, liquidation threshold, liquidation bonus, and decimals.
 *
 *         Validation rules:
 *           - LTV <= liquidationThreshold <= 95%
 *           - liquidationBonus <= 20%
 */
contract RiskRegistry is Ownable {
    // Maximum liquidation threshold: 95% (9500 bps)
    uint16 public constant MAX_LIQUIDATION_THRESHOLD = 9500;

    // Maximum liquidation bonus: 20% (2000 bps)
    uint16 public constant MAX_LIQUIDATION_BONUS = 2000;

    // asset address => risk params
    mapping(address => DataTypes.RiskParams) public riskParams;

    // list of all registered assets
    address[] public assets;

    event RiskParamsUpdated(
        address indexed asset,
        uint16 ltvBps,
        uint16 liquidationThresholdBps,
        uint16 liquidationBonusBps,
        uint8 decimals
    );

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Set or update risk parameters for an asset
     * @param asset                   Token address
     * @param ltvBps                  Loan-to-value in basis points
     * @param liquidationThresholdBps Liquidation threshold in bps
     * @param liquidationBonusBps     Liquidation bonus in bps
     * @param decimals                Token decimals
     */
    function setRiskParams(
        address asset,
        uint16 ltvBps,
        uint16 liquidationThresholdBps,
        uint16 liquidationBonusBps,
        uint8 decimals
    ) external onlyOwner {
        require(ltvBps <= liquidationThresholdBps, "RiskRegistry: LTV > threshold");
        require(
            liquidationThresholdBps <= MAX_LIQUIDATION_THRESHOLD,
            "RiskRegistry: threshold > 95%"
        );
        require(
            liquidationBonusBps <= MAX_LIQUIDATION_BONUS,
            "RiskRegistry: bonus > 20%"
        );

        bool isNew = !riskParams[asset].isActive;

        riskParams[asset] = DataTypes.RiskParams({
            ltvBps: ltvBps,
            liquidationThresholdBps: liquidationThresholdBps,
            liquidationBonusBps: liquidationBonusBps,
            decimals: decimals,
            isActive: true
        });

        if (isNew) {
            assets.push(asset);
        }

        emit RiskParamsUpdated(asset, ltvBps, liquidationThresholdBps, liquidationBonusBps, decimals);
    }

    /**
     * @notice Get risk parameters for an asset
     * @param asset Token address
     * @return The RiskParams struct
     */
    function getRiskParams(address asset) external view returns (DataTypes.RiskParams memory) {
        require(riskParams[asset].isActive, "RiskRegistry: asset not configured");
        return riskParams[asset];
    }

    /**
     * @notice Get all registered asset addresses
     */
    function getAllAssets() external view returns (address[] memory) {
        return assets;
    }
}
