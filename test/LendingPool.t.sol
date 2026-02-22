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

contract LendingPoolTest is Test {
    using WadRayMath for uint256;

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
    address bob   = makeAddr("bob");

    uint256 constant CHAIN_ID = 46630;

    function setUp() public {
        // Mock ArbSys precompile
        vm.mockCall(
            address(0x64),
            abi.encodeWithSignature("arbBlockNumber()"),
            abi.encode(uint256(1_000_000))
        );
        vm.mockCall(
            address(0x64),
            abi.encodeWithSignature("arbChainID()"),
            abi.encode(CHAIN_ID)
        );

        // Mock ArbGasInfo precompile
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

        // Deploy mock tokens
        weth = new MockERC20("Wrapped ETH", "WETH");
        tsla = new MockERC20("Tesla Token", "TSLA");

        // Deploy periphery
        oracle = new MockPriceOracle();
        irm = new InterestRateModel(0.02e18, 0.10e18, 3.00e18, 0.80e18);
        registry = new RiskRegistry();

        // Deploy pool
        pool = new LendingPool(
            address(weth),
            address(oracle),
            address(irm),
            address(registry)
        );

        // Deploy vaults
        vaultTSLA = new AssetVault(address(tsla), "Robinhood TSLA", "rhTSLA", 18);
        vaultWETH = new AssetVault(address(weth), "Robinhood WETH", "rhWETH", 18);

        // Link vaults to pool
        vaultTSLA.setLendingPool(address(pool));
        vaultWETH.setLendingPool(address(pool));

        // Register assets
        pool.addAsset(address(tsla), address(vaultTSLA));
        pool.addAsset(address(weth), address(vaultWETH));

        // Deploy liquidation engine
        engine = new LiquidationEngine(
            address(pool),
            address(oracle),
            address(registry),
            address(weth)
        );
        pool.setLiquidationEngine(address(engine));

        // Configure risk params: TSLA 55% LTV, 70% liq threshold, 7.5% bonus
        registry.setRiskParams(address(tsla), 5500, 7000, 750, 18);
        registry.setRiskParams(address(weth), 8000, 8500, 500, 18);

        // Set prices
        oracle.setPrice(address(tsla), 250_00000000);  /* $250 */
        oracle.setPrice(address(weth), 2500_00000000); /* $2500 */

        // Fund accounts
        tsla.mint(alice, 100e18);
        weth.mint(address(pool), 1000e18); /* Pool liquidity for borrowing */
        weth.mint(bob, 100e18);
    }

    function test_deposit() public {
        vm.startPrank(alice);
        tsla.approve(address(pool), 10e18);
        pool.deposit(address(tsla), 10e18);
        vm.stopPrank();

        // Alice should have collateral tracked
        uint256 collateral = pool.getUserCollateral(alice, address(tsla));
        assertGt(collateral, 0);
    }

    function test_deposit_and_borrow() public {
        // Alice deposits 10 TSLA ($2500 worth)
        vm.startPrank(alice);
        tsla.approve(address(pool), 10e18);
        pool.deposit(address(tsla), 10e18);

        /**
         * Max borrow at 55% LTV:
         * 10 TSLA * $250 = $2500
         * $2500 * 55% = $1375 worth of WETH
         * $1375 / $2500 per WETH = 0.55 WETH
         */
        pool.borrow(0.5e18);
        vm.stopPrank();

        uint256 debt = pool.getUserDebt(alice);
        assertEq(debt, 0.5e18);
    }

    function test_borrow_reverts_undercollateralized() public {
        vm.startPrank(alice);
        tsla.approve(address(pool), 10e18);
        pool.deposit(address(tsla), 10e18);

        // Try to borrow more than LTV allows (should revert)
        vm.expectRevert("LendingPool: undercollateralized");
        pool.borrow(1e18);
        vm.stopPrank();
    }

    function test_repay() public {
        // Alice deposits and borrows
        vm.startPrank(alice);
        tsla.approve(address(pool), 10e18);
        pool.deposit(address(tsla), 10e18);
        pool.borrow(0.3e18);

        // Repay
        weth.mint(alice, 0.3e18);
        weth.approve(address(pool), 0.3e18);
        pool.repay(0.3e18);
        vm.stopPrank();

        assertEq(pool.getUserDebt(alice), 0);
    }

    function test_withdraw() public {
        vm.startPrank(alice);
        tsla.approve(address(pool), 10e18);
        pool.deposit(address(tsla), 10e18);

        uint256 collateral = pool.getUserCollateral(alice, address(tsla));
        pool.withdraw(address(tsla), collateral);
        vm.stopPrank();

        assertEq(pool.getUserCollateral(alice, address(tsla)), 0);
        assertEq(tsla.balanceOf(alice), 100e18);
    }

    function test_withdraw_reverts_if_undercollateralized() public {
        vm.startPrank(alice);
        tsla.approve(address(pool), 10e18);
        pool.deposit(address(tsla), 10e18);
        pool.borrow(0.3e18);

        uint256 collateral = pool.getUserCollateral(alice, address(tsla));

        // Withdrawing all collateral while having debt should revert
        vm.expectRevert("LendingPool: would be undercollateralized");
        pool.withdraw(address(tsla), collateral);
        vm.stopPrank();
    }

    function test_healthFactor_healthy() public {
        vm.startPrank(alice);
        tsla.approve(address(pool), 10e18);
        pool.deposit(address(tsla), 10e18);
        pool.borrow(0.3e18);
        vm.stopPrank();

        uint256 hf = pool.getHealthFactor(alice);
        // Should be well above 1.0
        assertGt(hf, 1e18);
    }

    function test_healthFactor_drops_on_price_crash() public {
        vm.startPrank(alice);
        tsla.approve(address(pool), 10e18);
        pool.deposit(address(tsla), 10e18);
        pool.borrow(0.5e18);
        vm.stopPrank();

        uint256 hfBefore = pool.getHealthFactor(alice);

        // Crash TSLA price by 50%
        oracle.setPrice(address(tsla), 125_00000000);

        uint256 hfAfter = pool.getHealthFactor(alice);
        assertLt(hfAfter, hfBefore);
    }

    function test_getSupportedAssets() public view {
        address[] memory assets = pool.getSupportedAssets();
        assertEq(assets.length, 2);
    }

    function test_getMaxBorrow() public {
        vm.startPrank(alice);
        tsla.approve(address(pool), 10e18);
        pool.deposit(address(tsla), 10e18);
        vm.stopPrank();

        uint256 maxBorrow = pool.getMaxBorrow(alice);
        // 10 TSLA * $250 * 55% LTV / $2500 WETH = 0.55 WETH
        assertApproxEqAbs(maxBorrow, 0.55e18, 0.01e18);
    }
}
