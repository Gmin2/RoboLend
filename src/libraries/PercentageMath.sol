/* SPDX-License-Identifier: MIT */
pragma solidity ^0.8.20;

/**
 * @title PercentageMath library
 * @notice Basis-point math helpers (BPS = 10_000)
 */
library PercentageMath {
    uint256 internal constant BPS = 10_000;
    uint256 internal constant HALF_BPS = 5_000;

    /**
     * @notice Multiply a value by a percentage expressed in bps
     * @param value The base value
     * @param bps The percentage in basis points
     * @return The result of value * bps / 10000, rounded half up
     */
    function percentMul(uint256 value, uint256 bps) internal pure returns (uint256) {
        if (value == 0 || bps == 0) return 0;
        return (value * bps + HALF_BPS) / BPS;
    }

    /**
     * @notice Divide a value by a percentage expressed in bps
     * @param value The base value
     * @param bps The percentage in basis points
     * @return The result of value * 10000 / bps, rounded half up
     */
    function percentDiv(uint256 value, uint256 bps) internal pure returns (uint256) {
        require(bps != 0, "PercentageMath: division by zero");
        return (value * BPS + bps / 2) / bps;
    }
}
