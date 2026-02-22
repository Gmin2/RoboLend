/* SPDX-License-Identifier: MIT */
pragma solidity ^0.8.20;

import {WadRayMath} from "../libraries/WadRayMath.sol";
import {ArbPrecompiles} from "../libraries/ArbPrecompiles.sol";

/**
 * @title InterestRateModel
 * @notice Kinked utilization curve (Compound-style).
 *         Uses ArbSys.arbBlockNumber() for block timing on Orbit chains
 *         where L2 blocks tick every ~250ms.
 */
contract InterestRateModel {
    using WadRayMath for uint256;

    /**
     * 250ms blocks => 4 blocks/sec => 126_144_000 blocks/year
     * (365.25 days * 24 h * 60 min * 60 sec * 4)
     */
    uint256 public constant BLOCKS_PER_YEAR = 126_144_000;

    // Base borrow rate per year (WAD)
    uint256 public immutable baseRatePerYear;

    // Slope before the kink (WAD)
    uint256 public immutable multiplierPerYear;

    // Slope after the kink (WAD)
    uint256 public immutable jumpMultiplierPerYear;

    // Utilization percentage where the jump kicks in (WAD, e.g. 0.8e18 = 80%)
    uint256 public immutable kink;

    // Derived per-block rates
    uint256 public immutable baseRatePerBlock;
    uint256 public immutable multiplierPerBlock;
    uint256 public immutable jumpMultiplierPerBlock;

    event NewInterestParams(
        uint256 baseRatePerYear,
        uint256 multiplierPerYear,
        uint256 jumpMultiplierPerYear,
        uint256 kink
    );

    /**
     * @param _baseRatePerYear     Base rate (WAD). Default: 0.02e18 = 2%
     * @param _multiplierPerYear   Slope1 (WAD). Default: 0.10e18 = 10%
     * @param _jumpMultiplierPerYear Slope2 (WAD). Default: 3.00e18 = 300%
     * @param _kink                Kink point (WAD). Default: 0.80e18 = 80%
     */
    constructor(
        uint256 _baseRatePerYear,
        uint256 _multiplierPerYear,
        uint256 _jumpMultiplierPerYear,
        uint256 _kink
    ) {
        baseRatePerYear = _baseRatePerYear;
        multiplierPerYear = _multiplierPerYear;
        jumpMultiplierPerYear = _jumpMultiplierPerYear;
        kink = _kink;

        baseRatePerBlock = _baseRatePerYear / BLOCKS_PER_YEAR;
        multiplierPerBlock = _multiplierPerYear / BLOCKS_PER_YEAR;
        jumpMultiplierPerBlock = _jumpMultiplierPerYear / BLOCKS_PER_YEAR;

        emit NewInterestParams(
            _baseRatePerYear,
            _multiplierPerYear,
            _jumpMultiplierPerYear,
            _kink
        );
    }

    /**
     * @notice Calculate the utilization rate
     * @param cash     Available liquidity (WAD-scale)
     * @param borrows  Total borrows (WAD-scale)
     * @param reserves Protocol reserves (WAD-scale)
     * @return Utilization as a WAD (0 to 1e18)
     */
    function utilizationRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) public pure returns (uint256) {
        if (borrows == 0) return 0;
        return borrows.wadDiv(cash + borrows - reserves);
    }

    /**
     * @notice Get the per-block borrow rate
     * @param cash     Available liquidity
     * @param borrows  Total borrows
     * @param reserves Protocol reserves
     * @return Per-block borrow rate (WAD)
     */
    function getBorrowRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) public view returns (uint256) {
        uint256 util = utilizationRate(cash, borrows, reserves);

        if (util <= kink) {
            return baseRatePerBlock + util.wadMul(multiplierPerBlock);
        }

        uint256 normalRate = baseRatePerBlock + kink.wadMul(multiplierPerBlock);
        uint256 excessUtil = util - kink;
        return normalRate + excessUtil.wadMul(jumpMultiplierPerBlock);
    }

    /**
     * @notice Get the per-block supply rate
     * @param cash          Available liquidity
     * @param borrows       Total borrows
     * @param reserves      Protocol reserves
     * @param reserveFactor Fraction of interest that goes to reserves (WAD)
     * @return Per-block supply rate (WAD)
     */
    function getSupplyRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves,
        uint256 reserveFactor
    ) external view returns (uint256) {
        uint256 oneMinusReserveFactor = WadRayMath.WAD - reserveFactor;
        uint256 borrowRate = getBorrowRate(cash, borrows, reserves);
        uint256 rateToPool = borrowRate.wadMul(oneMinusReserveFactor);
        return utilizationRate(cash, borrows, reserves).wadMul(rateToPool);
    }

    /**
     * @notice Expose the current L2 block number from ArbSys precompile
     */
    function currentBlockNumber() external view returns (uint256) {
        return ArbPrecompiles.arbBlockNumber();
    }
}
