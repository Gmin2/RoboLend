/* SPDX-License-Identifier: MIT */
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {WadRayMath} from "../libraries/WadRayMath.sol";
import {PercentageMath} from "../libraries/PercentageMath.sol";
import {ArbPrecompiles} from "../libraries/ArbPrecompiles.sol";
import {DataTypes} from "../libraries/DataTypes.sol";

import {MockPriceOracle} from "./MockPriceOracle.sol";
import {RiskRegistry} from "./RiskRegistry.sol";
import {AssetVault} from "../core/AssetVault.sol";
import {ILendingPool} from "../interfaces/ILendingPool.sol";

/**
 * @title LiquidationEngine
 * @notice Gas-aware liquidation engine using ArbGasInfo precompile.
 *         Called by LendingPool via delegatecall to liquidate
 *         undercollateralized positions. Exposes gas condition views
 *         for the frontend's GasInfoBanner component.
 */
contract LiquidationEngine {
    using SafeERC20 for IERC20;
    using WadRayMath for uint256;
    using PercentageMath for uint256;

    // Close factor: max 50% of debt can be repaid per liquidation
    uint256 public constant CLOSE_FACTOR = 0.50e18;

    /**
     * Estimated gas usage for a liquidation transaction.
     * Used to compute profitability.
     */
    uint256 public constant LIQUIDATION_GAS_ESTIMATE = 300_000;

    // Estimated L1 calldata bytes for a liquidation tx
    uint256 public constant LIQUIDATION_CALLDATA_BYTES = 512;

    // External protocol references
    address public immutable lendingPool;
    MockPriceOracle public immutable oracle;
    RiskRegistry public immutable riskRegistry;
    IERC20 public immutable weth;

    /**
     * @param _lendingPool LendingPool contract address
     * @param _oracle      MockPriceOracle address
     * @param _riskRegistry RiskRegistry address
     * @param _weth        WETH token address
     */
    constructor(
        address _lendingPool,
        address _oracle,
        address _riskRegistry,
        address _weth
    ) {
        lendingPool = _lendingPool;
        oracle = MockPriceOracle(_oracle);
        riskRegistry = RiskRegistry(_riskRegistry);
        weth = IERC20(_weth);
    }

    /**
     * @notice Execute a liquidation. Called by LendingPool only.
     * @param borrower        The undercollateralized borrower
     * @param collateralAsset The collateral token to seize
     * @param debtToRepay     Amount of WETH debt the liquidator is repaying
     * @param liquidator      The address performing the liquidation
     */
    function executeLiquidation(
        address borrower,
        address collateralAsset,
        uint256 debtToRepay,
        address liquidator
    ) external {
        require(msg.sender == lendingPool, "LiquidationEngine: caller not pool");

        /**
         * We read state from the LendingPool via interface.
         * In a delegatecall scenario the pool passes this data,
         * but here we use a direct-call pattern for clarity.
         */
        ILendingPool pool = ILendingPool(lendingPool);

        // Check that borrower is underwater
        uint256 healthFactor = pool.getHealthFactor(borrower);
        require(healthFactor < WadRayMath.WAD, "LiquidationEngine: healthy position");

        // Cap repayment at close factor (50% of debt)
        uint256 userDebt = pool.getUserDebt(borrower);
        uint256 maxRepay = userDebt.wadMul(CLOSE_FACTOR);
        if (debtToRepay > maxRepay) {
            debtToRepay = maxRepay;
        }

        // Calculate collateral to seize
        DataTypes.RiskParams memory risk = riskRegistry.getRiskParams(collateralAsset);
        uint256 collateralPrice = oracle.getPrice(collateralAsset);
        uint256 wethPrice = oracle.getPrice(address(weth));

        /**
         * debtValueUsd = debtToRepay * wethPrice / 1e18  (WETH is 18 decimals)
         * collateralToSeize = debtValueUsd * (1 + bonus) / collateralPrice * 10^collateralDecimals
         *
         * In precise terms (avoiding intermediate rounding):
         * seizeAmount = debtToRepay * wethPrice * (BPS + bonus) * 10^collDecimals
         *               / (collateralPrice * 10^18 * BPS)
         */
        uint256 seizeUnderlying = (debtToRepay * wethPrice *
            (PercentageMath.BPS + risk.liquidationBonusBps) *
            (10 ** risk.decimals)) /
            (collateralPrice * 1e18 * PercentageMath.BPS);

        // Convert underlying to receipt tokens via vault supply index
        AssetVault vault = pool.vaults(collateralAsset);
        uint256 seizeReceipts = (seizeUnderlying * WadRayMath.RAY) / vault.supplyIndex();

        // Verify borrower has enough collateral
        uint256 borrowerCollateral = pool.userCollateral(borrower, collateralAsset);
        require(
            borrowerCollateral >= seizeReceipts,
            "LiquidationEngine: insufficient collateral"
        );

        // Transfer WETH from liquidator (already held by pool) — reduce debt
        pool.reduceDebt(borrower, debtToRepay);

        /**
         * Move collateral receipts from borrower to liquidator.
         * We update the pool's userCollateral mapping via a callback.
         */
        pool.transferCollateral(borrower, liquidator, collateralAsset, seizeReceipts);
    }

    /**
     * @notice Estimate the gas cost of executing a liquidation (in wei)
     * @return gasCostWei Total estimated gas cost (L2 + L1 data posting)
     */
    function _estimateLiquidationGasCost() internal view returns (uint256 gasCostWei) {
        uint256 l2GasPrice = ArbPrecompiles.getMinimumGasPrice();
        uint256 l1BaseFee = ArbPrecompiles.getL1BaseFeeEstimate();

        uint256 l2Cost = LIQUIDATION_GAS_ESTIMATE * l2GasPrice;
        uint256 l1Cost = LIQUIDATION_CALLDATA_BYTES * l1BaseFee;

        gasCostWei = l2Cost + l1Cost;
    }

    /**
     * @notice Check if liquidating a position would be profitable
     * @param borrower        The borrower address
     * @param collateralAsset The collateral to seize
     * @param debtAmount      Amount of WETH debt to repay
     * @return isProfitable   Whether the bonus exceeds estimated gas cost
     * @return estimatedProfit Profit in wei (bonus - gas cost, or 0 if unprofitable)
     * @return gasCost        Estimated gas cost in wei
     * @return bonusValue     Liquidation bonus value in wei
     */
    function isLiquidationProfitable(
        address borrower,
        address collateralAsset,
        uint256 debtAmount
    )
        external
        view
        returns (
            bool isProfitable,
            uint256 estimatedProfit,
            uint256 gasCost,
            uint256 bonusValue
        )
    {
        ILendingPool pool = ILendingPool(lendingPool);
        uint256 healthFactor = pool.getHealthFactor(borrower);
        if (healthFactor >= WadRayMath.WAD) {
            return (false, 0, 0, 0);
        }

        DataTypes.RiskParams memory risk = riskRegistry.getRiskParams(collateralAsset);
        uint256 wethPrice = oracle.getPrice(address(weth));

        // bonus = debtAmount * bonusBps / BPS (in WETH terms)
        bonusValue = debtAmount.percentMul(risk.liquidationBonusBps);

        // Convert bonus from WETH to wei value: bonusValue is in WETH (18 dec)
        uint256 bonusWei = (bonusValue * wethPrice) / 1e8;

        gasCost = _estimateLiquidationGasCost();

        isProfitable = bonusWei > gasCost;
        estimatedProfit = isProfitable ? bonusWei - gasCost : 0;
    }

    /**
     * @notice Get current gas conditions from ArbGasInfo precompile
     * @return l2GasPrice  Minimum gas price on L2 (wei)
     * @return l1BaseFee   Estimated L1 base fee (wei)
     * @return estimatedLiqCost Estimated total liquidation cost (wei)
     */
    function getGasConditions()
        external
        view
        returns (
            uint256 l2GasPrice,
            uint256 l1BaseFee,
            uint256 estimatedLiqCost
        )
    {
        l2GasPrice = ArbPrecompiles.getMinimumGasPrice();
        l1BaseFee = ArbPrecompiles.getL1BaseFeeEstimate();
        estimatedLiqCost = _estimateLiquidationGasCost();
    }
}
