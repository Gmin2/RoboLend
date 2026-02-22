/* SPDX-License-Identifier: MIT */
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {WadRayMath} from "../libraries/WadRayMath.sol";
import {PercentageMath} from "../libraries/PercentageMath.sol";
import {ArbPrecompiles} from "../libraries/ArbPrecompiles.sol";
import {DataTypes} from "../libraries/DataTypes.sol";

import {AssetVault} from "./AssetVault.sol";
import {MockPriceOracle} from "../periphery/MockPriceOracle.sol";
import {InterestRateModel} from "../periphery/InterestRateModel.sol";
import {RiskRegistry} from "../periphery/RiskRegistry.sol";
import {ILiquidationEngine} from "../interfaces/ILiquidationEngine.sol";

/**
 * @title LendingPool
 * @notice Main entry point for the Equities Money Market protocol.
 *         Users deposit tokenized equities as collateral and borrow WETH.
 *         Interest accrues using ArbSys.arbBlockNumber() for L2-native timing.
 */
contract LendingPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using WadRayMath for uint256;
    using PercentageMath for uint256;

    // ---- External references ----
    MockPriceOracle public oracle;
    InterestRateModel public interestRateModel;
    RiskRegistry public riskRegistry;
    address public liquidationEngine;

    // WETH token on Robinhood Chain
    IERC20 public immutable weth;

    // ---- Asset management ----

    // asset address => vault
    mapping(address => AssetVault) public vaults;

    // list of supported collateral assets
    address[] public supportedAssets;

    // ---- User state ----

    // user => asset => receipt token balance held as collateral
    mapping(address => mapping(address => uint256)) public userCollateral;

    // user => borrow shares
    mapping(address => uint256) public userBorrowShares;

    // ---- Global borrow state ----
    uint256 public totalBorrowShares;
    uint256 public totalBorrowAmount;
    uint256 public borrowIndex;
    uint256 public lastAccrualBlock;

    // Reserve factor: fraction of interest going to protocol (WAD). Default 10%
    uint256 public reserveFactor = 0.10e18;

    // Protocol reserves (WETH)
    uint256 public reserves;

    // ---- Constants ----

    // Health factor threshold (1.0 in WAD)
    uint256 public constant HEALTH_FACTOR_THRESHOLD = 1e18;

    // ---- Events ----
    event AssetAdded(address indexed asset, address indexed vault);
    event Deposited(address indexed user, address indexed asset, uint256 amount);
    event Withdrawn(address indexed user, address indexed asset, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event InterestAccrued(uint256 blockDelta, uint256 newBorrowIndex, uint256 interestEarned);
    event LiquidationEngineSet(address indexed engine);

    /**
     * @param _weth             WETH token address on Robinhood Chain
     * @param _oracle           MockPriceOracle address
     * @param _interestRateModel InterestRateModel address
     * @param _riskRegistry     RiskRegistry address
     */
    constructor(
        address _weth,
        address _oracle,
        address _interestRateModel,
        address _riskRegistry
    ) Ownable(msg.sender) {
        // Verify we are on Robinhood Chain (ID 46630)
        ArbPrecompiles.verifyChain();

        weth = IERC20(_weth);
        oracle = MockPriceOracle(_oracle);
        interestRateModel = InterestRateModel(_interestRateModel);
        riskRegistry = RiskRegistry(_riskRegistry);

        borrowIndex = WadRayMath.RAY;
        lastAccrualBlock = ArbPrecompiles.arbBlockNumber();
    }

    /**
     * @notice Register a new collateral asset + its vault
     * @param asset Token address
     * @param vault Deployed AssetVault for this token
     */
    function addAsset(address asset, address vault) external onlyOwner {
        require(address(vaults[asset]) == address(0), "LendingPool: asset exists");
        vaults[asset] = AssetVault(vault);
        supportedAssets.push(asset);
        emit AssetAdded(asset, vault);
    }

    /**
     * @notice Link the LiquidationEngine (one-time)
     */
    function setLiquidationEngine(address _engine) external onlyOwner {
        require(_engine != address(0), "LendingPool: zero address");
        liquidationEngine = _engine;
        emit LiquidationEngineSet(_engine);
    }

    /**
     * @notice Deposit collateral tokens into the protocol
     * @param asset  The collateral token address (TSLA, AMZN, etc.)
     * @param amount Amount of underlying tokens to deposit
     */
    function deposit(address asset, uint256 amount) external nonReentrant {
        _accrueInterest();

        AssetVault vault = vaults[asset];
        require(address(vault) != address(0), "LendingPool: unsupported asset");

        // Transfer tokens from user to this contract, then deposit into vault
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(address(vault), amount);
        uint256 receiptAmount = vault.deposit(amount, address(this));

        userCollateral[msg.sender][asset] += receiptAmount;

        emit Deposited(msg.sender, asset, amount);
    }

    /**
     * @notice Withdraw collateral tokens
     * @param asset         The collateral token address
     * @param receiptAmount Amount of receipt tokens to redeem
     */
    function withdraw(address asset, uint256 receiptAmount) external nonReentrant {
        _accrueInterest();

        require(
            userCollateral[msg.sender][asset] >= receiptAmount,
            "LendingPool: insufficient collateral"
        );

        AssetVault vault = vaults[asset];

        userCollateral[msg.sender][asset] -= receiptAmount;
        vault.withdraw(receiptAmount, msg.sender);

        // Ensure the user is still healthy after withdrawal
        if (userBorrowShares[msg.sender] > 0) {
            require(
                _healthFactor(msg.sender) >= HEALTH_FACTOR_THRESHOLD,
                "LendingPool: would be undercollateralized"
            );
        }

        emit Withdrawn(msg.sender, asset, receiptAmount);
    }

    /**
     * @notice Borrow WETH against deposited collateral
     * @param amount Amount of WETH to borrow
     */
    function borrow(uint256 amount) external nonReentrant {
        _accrueInterest();
        require(amount > 0, "LendingPool: zero borrow");

        // Calculate borrow shares
        uint256 shares;
        if (totalBorrowShares == 0) {
            shares = amount;
        } else {
            shares = (amount * totalBorrowShares) / totalBorrowAmount;
        }

        userBorrowShares[msg.sender] += shares;
        totalBorrowShares += shares;
        totalBorrowAmount += amount;

        // Check health factor after borrow
        require(
            _healthFactor(msg.sender) >= HEALTH_FACTOR_THRESHOLD,
            "LendingPool: undercollateralized"
        );

        weth.safeTransfer(msg.sender, amount);

        emit Borrowed(msg.sender, amount);
    }

    /**
     * @notice Repay borrowed WETH
     * @param amount Amount of WETH to repay
     */
    function repay(uint256 amount) external nonReentrant {
        _accrueInterest();

        uint256 userDebt = _userDebt(msg.sender);
        if (amount > userDebt) {
            amount = userDebt;
        }

        // Calculate shares to burn
        uint256 sharesToBurn = (amount * totalBorrowShares) / totalBorrowAmount;

        weth.safeTransferFrom(msg.sender, address(this), amount);

        userBorrowShares[msg.sender] -= sharesToBurn;
        totalBorrowShares -= sharesToBurn;
        totalBorrowAmount -= amount;

        emit Repaid(msg.sender, amount);
    }

    /**
     * @notice Liquidate an undercollateralized position.
     *         Transfers WETH from liquidator, then delegates to LiquidationEngine.
     * @param borrower        The borrower to liquidate
     * @param collateralAsset The collateral to seize
     * @param debtToRepay     Amount of WETH debt to repay
     */
    function liquidate(
        address borrower,
        address collateralAsset,
        uint256 debtToRepay
    ) external nonReentrant {
        _accrueInterest();
        require(liquidationEngine != address(0), "LendingPool: no liquidation engine");

        // Transfer WETH from liquidator to this contract
        weth.safeTransferFrom(msg.sender, address(this), debtToRepay);

        // Let the engine validate and execute
        ILiquidationEngine(liquidationEngine).executeLiquidation(
            borrower,
            collateralAsset,
            debtToRepay,
            msg.sender
        );
    }

    /**
     * @dev Accrue interest using L2 block numbers from ArbSys precompile.
     *      L2 blocks tick every ~250ms on Orbit chains.
     */
    function _accrueInterest() internal {
        uint256 currentBlock = ArbPrecompiles.arbBlockNumber();
        uint256 blockDelta = currentBlock - lastAccrualBlock;

        if (blockDelta == 0 || totalBorrowAmount == 0) {
            lastAccrualBlock = currentBlock;
            return;
        }

        // Get per-block borrow rate from the interest model
        uint256 wethVault = address(vaults[address(weth)]) != address(0)
            ? IERC20(address(weth)).balanceOf(address(vaults[address(weth)]))
            : weth.balanceOf(address(this));

        uint256 borrowRate = interestRateModel.getBorrowRate(
            wethVault,
            totalBorrowAmount,
            reserves
        );

        // Simple interest for the block delta
        uint256 interestFactor = borrowRate * blockDelta;
        uint256 interestEarned = totalBorrowAmount.wadMul(interestFactor);

        // Update reserves
        uint256 reserveIncrease = interestEarned.wadMul(reserveFactor);
        reserves += reserveIncrease;

        // Update borrow state
        totalBorrowAmount += interestEarned;
        borrowIndex = borrowIndex + borrowIndex.rayMul(
            WadRayMath.wadToRay(interestFactor)
        );

        lastAccrualBlock = currentBlock;

        emit InterestAccrued(blockDelta, borrowIndex, interestEarned);
    }

    /**
     * @dev Calculate the health factor for a user.
     *      healthFactor = sum(collateral_value * liq_threshold) / debt_value
     *      Returns type(uint256).max if no debt.
     */
    function _healthFactor(address user) internal view returns (uint256) {
        uint256 debt = _userDebt(user);
        if (debt == 0) return type(uint256).max;

        uint256 weightedCollateral = 0;

        for (uint256 i = 0; i < supportedAssets.length; i++) {
            address asset = supportedAssets[i];
            uint256 receiptBal = userCollateral[user][asset];
            if (receiptBal == 0) continue;

            AssetVault vault = vaults[asset];
            uint256 underlyingBal = receiptBal.rayMul(vault.supplyIndex());

            // Get price (8 decimals) and risk params
            uint256 price = oracle.getPrice(asset);
            DataTypes.RiskParams memory risk = riskRegistry.getRiskParams(asset);

            /**
             * collateralValueUsd = underlyingBal * price / 10^decimals
             * Normalize to WAD (18 decimals):
             *   value_wad = underlyingBal * price * 1e18 / (10^decimals * 10^8)
             */
            uint256 valueWad = (underlyingBal * price * 1e18) /
                (10 ** risk.decimals * 10 ** 8);

            // Weight by liquidation threshold
            weightedCollateral += valueWad.percentMul(risk.liquidationThresholdBps);
        }

        // Get WETH price to value the debt
        uint256 wethPrice = oracle.getPrice(address(weth));
        uint256 debtValueWad = (debt * wethPrice * 1e18) / (1e18 * 1e8);

        return weightedCollateral.wadDiv(debtValueWad);
    }

    /**
     * @dev Calculate user's current debt (including accrued interest)
     */
    function _userDebt(address user) internal view returns (uint256) {
        if (userBorrowShares[user] == 0 || totalBorrowShares == 0) return 0;
        return (userBorrowShares[user] * totalBorrowAmount) / totalBorrowShares;
    }

    /**
     * @notice Get the health factor for a user
     */
    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    /**
     * @notice Get the current debt of a user
     */
    function getUserDebt(address user) external view returns (uint256) {
        return _userDebt(user);
    }

    /**
     * @notice Get the maximum WETH a user can borrow given current collateral
     */
    function getMaxBorrow(address user) external view returns (uint256) {
        uint256 borrowCapUsd = 0;
        uint256 wethPrice = oracle.getPrice(address(weth));

        for (uint256 i = 0; i < supportedAssets.length; i++) {
            address asset = supportedAssets[i];
            uint256 receiptBal = userCollateral[user][asset];
            if (receiptBal == 0) continue;

            AssetVault vault = vaults[asset];
            uint256 underlyingBal = receiptBal.rayMul(vault.supplyIndex());

            uint256 price = oracle.getPrice(asset);
            DataTypes.RiskParams memory risk = riskRegistry.getRiskParams(asset);

            uint256 valueWad = (underlyingBal * price * 1e18) /
                (10 ** risk.decimals * 10 ** 8);

            borrowCapUsd += valueWad.percentMul(risk.ltvBps);
        }

        uint256 currentDebt = _userDebt(user);
        uint256 debtValueWad = (currentDebt * wethPrice * 1e18) / (1e18 * 1e8);

        if (borrowCapUsd <= debtValueWad) return 0;

        // Convert remaining USD capacity back to WETH amount
        uint256 remainingUsd = borrowCapUsd - debtValueWad;
        return (remainingUsd * 1e18 * 1e8) / (wethPrice * 1e18);
    }

    /**
     * @notice Get all supported collateral asset addresses
     */
    function getSupportedAssets() external view returns (address[] memory) {
        return supportedAssets;
    }

    /**
     * @notice Get the user's collateral receipt balance for a specific asset
     */
    function getUserCollateral(address user, address asset) external view returns (uint256) {
        return userCollateral[user][asset];
    }

    /**
     * @notice Reduce a borrower's debt. Only callable by LiquidationEngine.
     */
    function reduceDebt(address borrower, uint256 amount) external {
        require(msg.sender == liquidationEngine, "LendingPool: only liquidation engine");
        uint256 sharesToBurn = (amount * totalBorrowShares) / totalBorrowAmount;
        userBorrowShares[borrower] -= sharesToBurn;
        totalBorrowShares -= sharesToBurn;
        totalBorrowAmount -= amount;
    }

    /**
     * @notice Transfer collateral receipts from one user to another.
     *         Only callable by LiquidationEngine during liquidation.
     */
    function transferCollateral(
        address from,
        address to,
        address asset,
        uint256 receiptAmount
    ) external {
        require(msg.sender == liquidationEngine, "LendingPool: only liquidation engine");
        require(userCollateral[from][asset] >= receiptAmount, "LendingPool: insufficient collateral");
        userCollateral[from][asset] -= receiptAmount;
        userCollateral[to][asset] += receiptAmount;
    }
}
