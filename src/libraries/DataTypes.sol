/* SPDX-License-Identifier: MIT */
pragma solidity ^0.8.20;

library DataTypes {
    struct RiskParams {
        // Loan-to-value in basis points (e.g., 6500 = 65%)
        uint16 ltvBps;
        // Liquidation threshold in bps
        uint16 liquidationThresholdBps;
        // Liquidation bonus in bps (e.g., 500 = 5%)
        uint16 liquidationBonusBps;
        // Token decimals
        uint8 decimals;
        // Whether the asset is enabled
        bool isActive;
    }
}
