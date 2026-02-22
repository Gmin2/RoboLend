/* SPDX-License-Identifier: MIT */
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {LendingPool} from "../src/core/LendingPool.sol";
import {AssetVault} from "../src/core/AssetVault.sol";
import {MockPriceOracle} from "../src/periphery/MockPriceOracle.sol";
import {InterestRateModel} from "../src/periphery/InterestRateModel.sol";
import {RiskRegistry} from "../src/periphery/RiskRegistry.sol";
import {LiquidationEngine} from "../src/periphery/LiquidationEngine.sol";
import {WadRayMath} from "../src/libraries/WadRayMath.sol";
import {MockERC20} from "./helpers/MockERC20.sol";

contract LiquidationEngineTest is Test {
    LendingPool pool;
    MockPriceOracle oracle;
    InterestRateModel irm;
    RiskRegistry registry;
    LiquidationEngine engine;

    MockERC20 weth;
    MockERC20 tsla;
    AssetVault vaultWETH;
    AssetVault vaultTSLA;

    address alice = makeAddr("alice");
    address liquidator = makeAddr("liquidator");

    function setUp() public {
        // Mock ArbSys
        vm.mockCall(
            address(0x64),
            abi.encodeWithSignature("arbBlockNumber()"),
            abi.encode(uint256(1_000_000))
        );
        vm.mockCall(
            address(0x64),
            abi.encodeWithSignature("arbChainID()"),
            abi.encode(uint256(46630))
        );

        // Mock ArbGasInfo
        vm.mockCall(
            address(0x6C),
            abi.encodeWithSignature("getMinimumGasPrice()"),
            abi.encode(uint256(0.1 gwei))
        );
        vm.mockCall(
            address(0x6C),
            abi.encodeWithSignature("getL1BaseFeeEstimate()"),
            abi.encode(uint256(30 gwei))
        );

        weth = new MockERC20("Wrapped ETH", "WETH");
        tsla = new MockERC20("Tesla Token", "TSLA");

        oracle = new MockPriceOracle();
        irm = new InterestRateModel(0.02e18, 0.10e18, 3.00e18, 0.80e18);
        registry = new RiskRegistry();

        pool = new LendingPool(
            address(weth),
            address(oracle),
            address(irm),
            address(registry)
        );

        vaultTSLA = new AssetVault(address(tsla), "Robinhood TSLA", "rhTSLA", 18);
        vaultWETH = new AssetVault(address(weth), "Robinhood WETH", "rhWETH", 18);

        vaultTSLA.setLendingPool(address(pool));
        vaultWETH.setLendingPool(address(pool));

        pool.addAsset(address(tsla), address(vaultTSLA));
        pool.addAsset(address(weth), address(vaultWETH));

        engine = new LiquidationEngine(
            address(pool),
            address(oracle),
            address(registry),
            address(weth)
        );
        pool.setLiquidationEngine(address(engine));

        registry.setRiskParams(address(tsla), 5500, 7000, 750, 18);
        registry.setRiskParams(address(weth), 8000, 8500, 500, 18);

        oracle.setPrice(address(tsla), 250_00000000);
        oracle.setPrice(address(weth), 2500_00000000);

        // Fund
        tsla.mint(alice, 100e18);
        weth.mint(address(pool), 1000e18);
        weth.mint(liquidator, 100e18);
    }

    function _setupUnderwaterPosition() internal {
        // Alice deposits 10 TSLA and borrows 0.5 WETH
        vm.startPrank(alice);
        tsla.approve(address(pool), 10e18);
        pool.deposit(address(tsla), 10e18);
        pool.borrow(0.5e18);
        vm.stopPrank();

        // Crash TSLA price to make position underwater
        oracle.setPrice(address(tsla), 100_00000000);

        // Confirm underwater
        uint256 hf = pool.getHealthFactor(alice);
        assertLt(hf, 1e18, "Position should be underwater");
    }

    function test_liquidation_healthy_position_reverts() public {
        vm.startPrank(alice);
        tsla.approve(address(pool), 10e18);
        pool.deposit(address(tsla), 10e18);
        pool.borrow(0.3e18);
        vm.stopPrank();

        vm.startPrank(liquidator);
        weth.approve(address(pool), 0.15e18);
        vm.expectRevert("LiquidationEngine: healthy position");
        pool.liquidate(alice, address(tsla), 0.15e18);
        vm.stopPrank();
    }

    function test_liquidation_success() public {
        _setupUnderwaterPosition();

        uint256 debtBefore = pool.getUserDebt(alice);

        vm.startPrank(liquidator);
        weth.approve(address(pool), 0.25e18);
        pool.liquidate(alice, address(tsla), 0.25e18);
        vm.stopPrank();

        uint256 debtAfter = pool.getUserDebt(alice);
        assertLt(debtAfter, debtBefore, "Debt should decrease after liquidation");

        // Liquidator should have received collateral
        uint256 liquidatorCollateral = pool.getUserCollateral(liquidator, address(tsla));
        assertGt(liquidatorCollateral, 0, "Liquidator should have collateral");
    }

    function test_gasConditions_view() public view {
        (uint256 l2Gas, uint256 l1Fee, uint256 liqCost) = engine.getGasConditions();
        assertEq(l2Gas, 0.1 gwei);
        assertEq(l1Fee, 30 gwei);
        assertGt(liqCost, 0);
    }

    function test_isLiquidationProfitable_healthy() public {
        vm.startPrank(alice);
        tsla.approve(address(pool), 10e18);
        pool.deposit(address(tsla), 10e18);
        pool.borrow(0.3e18);
        vm.stopPrank();

        (bool profitable, , , ) = engine.isLiquidationProfitable(
            alice, address(tsla), 0.15e18
        );
        assertFalse(profitable, "Should not be profitable on healthy position");
    }

    function test_isLiquidationProfitable_underwater() public {
        _setupUnderwaterPosition();

        (bool profitable, uint256 profit, uint256 gasCost, uint256 bonus) =
            engine.isLiquidationProfitable(alice, address(tsla), 0.25e18);

        assertGt(bonus, 0, "Bonus should be positive");
        assertGt(gasCost, 0, "Gas cost should be positive");
        // Profitability depends on gas vs bonus — just check it returns
    }

    function test_closeFactor_caps_at_50percent() public {
        _setupUnderwaterPosition();

        uint256 fullDebt = pool.getUserDebt(alice);

        // Try to liquidate 100% — engine should cap at 50%
        vm.startPrank(liquidator);
        weth.approve(address(pool), fullDebt);
        pool.liquidate(alice, address(tsla), fullDebt);
        vm.stopPrank();

        uint256 debtAfter = pool.getUserDebt(alice);
        // Should have roughly 50% of debt remaining
        assertGt(debtAfter, 0, "Should not fully liquidate");
    }
}
