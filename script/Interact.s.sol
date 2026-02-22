/* SPDX-License-Identifier: MIT */
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MockPriceOracle} from "../src/periphery/MockPriceOracle.sol";
import {LendingPool} from "../src/core/LendingPool.sol";
import {LiquidationEngine} from "../src/periphery/LiquidationEngine.sol";

/**
 * @title Interact
 * @notice On-chain smoke tests for the Equities Money Market protocol
 *         deployed on Robinhood Chain Testnet (chain ID 46630).
 *
 *   # Full lending lifecycle (deposit → borrow → repay → withdraw)
 *   forge script script/Interact.s.sol:Interact \
 *     --sig "run()" \
 *     --rpc-url https://rpc.testnet.chain.robinhood.com \
 *     --private-key $PRIVATE_KEY \
 *     --broadcast -vvvv
 *
 *   # Liquidation flow
 *   forge script script/Interact.s.sol:Interact \
 *     --sig "runLiquidation()" \
 *     --rpc-url https://rpc.testnet.chain.robinhood.com \
 *     --private-key $PRIVATE_KEY \
 *     --broadcast -vvvv
 */
contract Interact is Script {
    // ── Robinhood Chain Testnet token addresses (same as Deploy.s.sol) ──
    address constant WETH = 0x7943e237c7F95DA44E0301572D358911207852Fa;
    address constant TSLA = 0xC9f9c86933092BbbfFF3CCb4b105A4A94bf3Bd4E;
    address constant AMZN = 0x5884aD2f920c162CFBbACc88C9C51AA75eC09E02;
    address constant PLTR = 0x1FBE1a0e43594b3455993B5dE5Fd0A7A266298d0;
    address constant NFLX = 0x3b8262A63d25f0477c4DDE23F83cfe22Cb768C93;
    address constant AMD  = 0x71178BAc73cBeb415514eB542a8995b82669778d;

    // ── Initial oracle prices (8 decimals, Chainlink convention) ──
    uint256 constant PRICE_TSLA = 250_00000000;  // $250
    uint256 constant PRICE_AMZN = 185_00000000;  // $185
    uint256 constant PRICE_PLTR =  80_00000000;  // $80
    uint256 constant PRICE_NFLX = 950_00000000;  // $950
    uint256 constant PRICE_AMD  = 120_00000000;  // $120
    uint256 constant PRICE_WETH = 2500_00000000; // $2500

    // ── Deployed contract addresses (loaded from .env) ──
    MockPriceOracle oracle;
    LendingPool pool;
    LiquidationEngine engine;

    function _loadEnv() internal {
        oracle = MockPriceOracle(vm.envAddress("ORACLE"));
        pool   = LendingPool(vm.envAddress("LENDING_POOL"));
        engine = LiquidationEngine(vm.envAddress("LIQUIDATION_ENGINE"));
    }

    /**
     * @notice Refresh all 6 oracle prices to reset the staleness timer.
     */
    function _refreshPrices() internal {
        address[] memory assets = new address[](6);
        uint256[] memory priceValues = new uint256[](6);

        assets[0] = TSLA;  priceValues[0] = PRICE_TSLA;
        assets[1] = AMZN;  priceValues[1] = PRICE_AMZN;
        assets[2] = PLTR;  priceValues[2] = PRICE_PLTR;
        assets[3] = NFLX;  priceValues[3] = PRICE_NFLX;
        assets[4] = AMD;   priceValues[4] = PRICE_AMD;
        assets[5] = WETH;  priceValues[5] = PRICE_WETH;

        oracle.setPrices(assets, priceValues);
        console.log("Oracle prices refreshed (staleness timer reset)");
    }

    /**
     * @notice Seed the pool with 5 WETH if its balance is below 1 WETH.
     *         borrow() transfers WETH from the pool's own balance, so someone
     *         must send WETH directly to the pool contract.
     */
    function _seedPoolIfNeeded() internal {
        uint256 poolWeth = IERC20(WETH).balanceOf(address(pool));
        console.log("Pool WETH balance:", poolWeth);

        if (poolWeth < 1e18) {
            IERC20(WETH).transfer(address(pool), 5e18);
            console.log("Seeded pool with 5 WETH");
        } else {
            console.log("Pool already has sufficient WETH, skipping seed");
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  run() — Full lending lifecycle
    // ═══════════════════════════════════════════════════════════════════

    function run() external {
        _loadEnv();

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        // ── Pre-flight checks (before broadcast, clear error messages) ──
        uint256 tslaBalance = IERC20(TSLA).balanceOf(deployer);
        uint256 wethBalance = IERC20(WETH).balanceOf(deployer);
        console.log("Deployer:", deployer);
        console.log("TSLA balance:", tslaBalance);
        console.log("WETH balance:", wethBalance);

        require(tslaBalance >= 10e18, "NEED TSLA: deployer must hold >= 10 TSLA tokens");
        require(wethBalance >= 5e18,  "NEED WETH: deployer must hold >= 5 WETH for pool seeding + repayment");

        vm.startBroadcast(deployerKey);

        // ── Step 1: Refresh oracle prices ──
        console.log("\n=== Step 1: Refresh oracle prices ===");
        _refreshPrices();

        // ── Step 2: Seed pool with WETH if needed ──
        console.log("\n=== Step 2: Seed pool with WETH ===");
        _seedPoolIfNeeded();

        // ── Step 3: Deposit 10 TSLA as collateral ──
        console.log("\n=== Step 3: Deposit 10 TSLA as collateral ===");
        IERC20(TSLA).approve(address(pool), 10e18);
        pool.deposit(TSLA, 10e18);

        uint256 receipts = pool.getUserCollateral(deployer, TSLA);
        uint256 maxBorrow = pool.getMaxBorrow(deployer);
        console.log("TSLA receipt tokens:", receipts);
        console.log("Max borrow (WETH):", maxBorrow);

        // ── Step 4: Borrow 0.25 WETH (conservative) ──
        console.log("\n=== Step 4: Borrow 0.25 WETH ===");
        pool.borrow(0.25e18);

        uint256 debt = pool.getUserDebt(deployer);
        uint256 healthFactor = pool.getHealthFactor(deployer);
        console.log("Debt after borrow:", debt);
        console.log("Health factor:", healthFactor);

        // ── Step 5: State snapshot ──
        console.log("\n=== Step 5: State snapshot ===");
        console.log("  TSLA collateral (receipts):", pool.getUserCollateral(deployer, TSLA));
        console.log("  User debt:", pool.getUserDebt(deployer));
        console.log("  Health factor:", pool.getHealthFactor(deployer));
        console.log("  Pool WETH balance:", IERC20(WETH).balanceOf(address(pool)));
        console.log("  Deployer WETH balance:", IERC20(WETH).balanceOf(deployer));

        // ── Step 6: Repay full debt ──
        console.log("\n=== Step 6: Repay full debt ===");
        uint256 fullDebt = pool.getUserDebt(deployer);
        console.log("Repaying debt:", fullDebt);
        IERC20(WETH).approve(address(pool), fullDebt);
        pool.repay(fullDebt);
        console.log("Debt after repay:", pool.getUserDebt(deployer));

        // ── Step 7: Withdraw all TSLA receipts ──
        console.log("\n=== Step 7: Withdraw all TSLA ===");
        uint256 allReceipts = pool.getUserCollateral(deployer, TSLA);
        console.log("Withdrawing receipts:", allReceipts);
        pool.withdraw(TSLA, allReceipts);

        console.log("Final TSLA balance:", IERC20(TSLA).balanceOf(deployer));
        console.log("Final WETH balance:", IERC20(WETH).balanceOf(deployer));
        console.log("Final debt:", pool.getUserDebt(deployer));

        vm.stopBroadcast();

        console.log("\n=== Lending lifecycle complete ===");
    }

    // ═══════════════════════════════════════════════════════════════════
    //  runLiquidation() — Liquidation flow
    // ═══════════════════════════════════════════════════════════════════

    function runLiquidation() external {
        _loadEnv();

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        // ── Pre-flight checks ──
        uint256 tslaBalance = IERC20(TSLA).balanceOf(deployer);
        uint256 wethBalance = IERC20(WETH).balanceOf(deployer);
        console.log("Deployer:", deployer);
        console.log("TSLA balance:", tslaBalance);
        console.log("WETH balance:", wethBalance);

        require(tslaBalance >= 10e18, "NEED TSLA: deployer must hold >= 10 TSLA tokens");
        require(wethBalance >= 5e18,  "NEED WETH: deployer must hold >= 5 WETH for pool seeding + repayment");

        // Determine liquidator: use LIQUIDATOR_KEY if set, otherwise self-liquidate
        uint256 liquidatorKey;
        address liquidatorAddr;
        bool useSeparateLiquidator = false;

        try vm.envUint("LIQUIDATOR_KEY") returns (uint256 lk) {
            if (lk != 0) {
                liquidatorKey = lk;
                liquidatorAddr = vm.addr(lk);
                useSeparateLiquidator = true;
                console.log("Using separate liquidator:", liquidatorAddr);
            }
        } catch {
            // No LIQUIDATOR_KEY set, will self-liquidate
        }

        if (!useSeparateLiquidator) {
            liquidatorKey = deployerKey;
            liquidatorAddr = deployer;
            console.log("Self-liquidation mode (no LIQUIDATOR_KEY)");
        }

        vm.startBroadcast(deployerKey);

        // ── Step 1: Refresh oracle prices ──
        console.log("\n=== Step 1: Refresh oracle prices ===");
        _refreshPrices();

        // ── Step 2: Seed pool with WETH if needed ──
        console.log("\n=== Step 2: Seed pool with WETH ===");
        _seedPoolIfNeeded();

        // ── Step 3: Deposit 10 TSLA + borrow 0.5 WETH (tight position ~91% of max) ──
        console.log("\n=== Step 3: Deposit 10 TSLA + borrow 0.5 WETH ===");
        IERC20(TSLA).approve(address(pool), 10e18);
        pool.deposit(TSLA, 10e18);

        uint256 maxBorrow = pool.getMaxBorrow(deployer);
        console.log("Max borrow:", maxBorrow);

        pool.borrow(0.5e18);
        console.log("Borrowed 0.5 WETH");
        console.log("Health factor:", pool.getHealthFactor(deployer));

        // ── Step 4: Crash TSLA price $250 → $100 ──
        console.log("\n=== Step 4: Crash TSLA price $250 -> $100 ===");
        oracle.setPrice(TSLA, 100_00000000);

        uint256 healthAfterCrash = pool.getHealthFactor(deployer);
        console.log("Health factor after crash:", healthAfterCrash);
        require(healthAfterCrash < 1e18, "Position should be underwater after price crash");
        console.log("Position is underwater - ready for liquidation");

        vm.stopBroadcast();

        // ── Step 5: Liquidate 25% of debt ──
        console.log("\n=== Step 5: Liquidate 25% of debt ===");
        uint256 debtBefore = pool.getUserDebt(deployer);
        uint256 debtToRepay = debtBefore / 4; // 25% of debt
        console.log("Debt before liquidation:", debtBefore);
        console.log("Liquidating debt amount:", debtToRepay);

        vm.startBroadcast(liquidatorKey);

        IERC20(WETH).approve(address(pool), debtToRepay);
        pool.liquidate(deployer, TSLA, debtToRepay);

        uint256 debtAfter = pool.getUserDebt(deployer);
        console.log("Debt after liquidation:", debtAfter);
        console.log("Liquidator TSLA collateral:", pool.getUserCollateral(liquidatorAddr, TSLA));

        vm.stopBroadcast();

        // ── Step 6: Cleanup — restore price, repay remaining debt, withdraw ──
        console.log("\n=== Step 6: Cleanup ===");
        vm.startBroadcast(deployerKey);

        // Restore TSLA price
        oracle.setPrice(TSLA, PRICE_TSLA);
        console.log("TSLA price restored to $250");

        // Repay remaining debt
        uint256 remainingDebt = pool.getUserDebt(deployer);
        if (remainingDebt > 0) {
            console.log("Repaying remaining debt:", remainingDebt);
            IERC20(WETH).approve(address(pool), remainingDebt);
            pool.repay(remainingDebt);
        }

        // Withdraw remaining collateral
        uint256 remainingCollateral = pool.getUserCollateral(deployer, TSLA);
        if (remainingCollateral > 0) {
            console.log("Withdrawing remaining collateral:", remainingCollateral);
            pool.withdraw(TSLA, remainingCollateral);
        }

        console.log("Final TSLA balance:", IERC20(TSLA).balanceOf(deployer));
        console.log("Final WETH balance:", IERC20(WETH).balanceOf(deployer));

        vm.stopBroadcast();

        console.log("\n=== Liquidation flow complete ===");
    }
}
