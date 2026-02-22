/* SPDX-License-Identifier: MIT */
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";

import {MockPriceOracle} from "../src/periphery/MockPriceOracle.sol";
import {InterestRateModel} from "../src/periphery/InterestRateModel.sol";
import {RiskRegistry} from "../src/periphery/RiskRegistry.sol";
import {LiquidationEngine} from "../src/periphery/LiquidationEngine.sol";
import {LendingPool} from "../src/core/LendingPool.sol";
import {AssetVault} from "../src/core/AssetVault.sol";

/**
 * @title Deploy
 * @notice Full deployment + configuration for Equities Money Market
 *         on Robinhood Chain Testnet (chain ID 46630).
 *
 *   forge script script/Deploy.s.sol:Deploy \
 *     --rpc-url https://rpc.testnet.chain.robinhood.com \
 *     --private-key $PRIVATE_KEY \
 *     --broadcast \
 *     --verify --verifier blockscout \
 *     --verifier-url https://explorer.testnet.chain.robinhood.com/api/
 */
contract Deploy is Script {
    // Robinhood Chain Testnet token addresses
    address constant WETH = 0x7943e237c7F95DA44E0301572D358911207852Fa;
    address constant TSLA = 0xC9f9c86933092BbbfFF3CCb4b105A4A94bf3Bd4E;
    address constant AMZN = 0x5884aD2f920c162CFBbACc88C9C51AA75eC09E02;
    address constant PLTR = 0x1FBE1a0e43594b3455993B5dE5Fd0A7A266298d0;
    address constant NFLX = 0x3b8262A63d25f0477c4DDE23F83cfe22Cb768C93;
    address constant AMD  = 0x71178BAc73cBeb415514eB542a8995b82669778d;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        /**
         * Step 1: Deploy periphery contracts (no dependencies)
         */
        MockPriceOracle oracle = new MockPriceOracle();
        console.log("MockPriceOracle:", address(oracle));

        InterestRateModel irm = new InterestRateModel(
            0.02e18,   /* 2% base rate */
            0.10e18,   /* 10% slope1 */
            3.00e18,   /* 300% slope2 */
            0.80e18    /* 80% kink */
        );
        console.log("InterestRateModel:", address(irm));

        RiskRegistry registry = new RiskRegistry();
        console.log("RiskRegistry:", address(registry));

        /**
         * Step 2: Deploy LendingPool (needs WETH, oracle, IRM, registry)
         */
        LendingPool pool = new LendingPool(
            WETH,
            address(oracle),
            address(irm),
            address(registry)
        );
        console.log("LendingPool:", address(pool));

        /**
         * Step 3: Deploy 6x AssetVaults (one per token)
         */
        AssetVault vaultTSLA = new AssetVault(TSLA, "Robinhood TSLA", "rhTSLA", 18);
        AssetVault vaultAMZN = new AssetVault(AMZN, "Robinhood AMZN", "rhAMZN", 18);
        AssetVault vaultPLTR = new AssetVault(PLTR, "Robinhood PLTR", "rhPLTR", 18);
        AssetVault vaultNFLX = new AssetVault(NFLX, "Robinhood NFLX", "rhNFLX", 18);
        AssetVault vaultAMD  = new AssetVault(AMD,  "Robinhood AMD",  "rhAMD",  18);
        AssetVault vaultWETH = new AssetVault(WETH, "Robinhood WETH", "rhWETH", 18);

        console.log("Vault TSLA:", address(vaultTSLA));
        console.log("Vault AMZN:", address(vaultAMZN));
        console.log("Vault PLTR:", address(vaultPLTR));
        console.log("Vault NFLX:", address(vaultNFLX));
        console.log("Vault AMD:",  address(vaultAMD));
        console.log("Vault WETH:", address(vaultWETH));

        /**
         * Step 4: Link vaults to pool
         */
        vaultTSLA.setLendingPool(address(pool));
        vaultAMZN.setLendingPool(address(pool));
        vaultPLTR.setLendingPool(address(pool));
        vaultNFLX.setLendingPool(address(pool));
        vaultAMD.setLendingPool(address(pool));
        vaultWETH.setLendingPool(address(pool));

        /**
         * Step 5: Register assets with pool
         */
        pool.addAsset(TSLA, address(vaultTSLA));
        pool.addAsset(AMZN, address(vaultAMZN));
        pool.addAsset(PLTR, address(vaultPLTR));
        pool.addAsset(NFLX, address(vaultNFLX));
        pool.addAsset(AMD,  address(vaultAMD));
        pool.addAsset(WETH, address(vaultWETH));

        /**
         * Step 6: Deploy LiquidationEngine
         */
        LiquidationEngine engine = new LiquidationEngine(
            address(pool),
            address(oracle),
            address(registry),
            WETH
        );
        console.log("LiquidationEngine:", address(engine));

        /**
         * Step 7: Link liquidation engine to pool
         */
        pool.setLiquidationEngine(address(engine));

        /**
         * Step 8: Configure risk parameters per asset
         *
         *   Asset | LTV   | Liq Threshold | Liq Bonus
         *   AMZN  | 65%   | 80%           | 5%
         *   NFLX  | 60%   | 75%           | 6%
         *   TSLA  | 55%   | 70%           | 7.5%
         *   AMD   | 50%   | 70%           | 8%
         *   PLTR  | 45%   | 65%           | 10%
         *   WETH  | 80%   | 85%           | 5%
         */
        registry.setRiskParams(AMZN, 6500, 8000,  500, 18);
        registry.setRiskParams(NFLX, 6000, 7500,  600, 18);
        registry.setRiskParams(TSLA, 5500, 7000,  750, 18);
        registry.setRiskParams(AMD,  5000, 7000,  800, 18);
        registry.setRiskParams(PLTR, 4500, 6500, 1000, 18);
        registry.setRiskParams(WETH, 8000, 8500,  500, 18);

        /**
         * Step 9: Set initial stock prices (8 decimals, Chainlink convention)
         */
        address[] memory assets = new address[](6);
        uint256[] memory priceValues = new uint256[](6);

        assets[0] = TSLA;  priceValues[0] = 250_00000000;   /* $250 */
        assets[1] = AMZN;  priceValues[1] = 185_00000000;   /* $185 */
        assets[2] = PLTR;  priceValues[2] =  80_00000000;   /* $80 */
        assets[3] = NFLX;  priceValues[3] = 950_00000000;   /* $950 */
        assets[4] = AMD;   priceValues[4] = 120_00000000;   /* $120 */
        assets[5] = WETH;  priceValues[5] = 2500_00000000;  /* $2500 */

        oracle.setPrices(assets, priceValues);

        /**
         * Step 10: All markets open
         */
        for (uint256 i = 0; i < assets.length; i++) {
            oracle.setMarketStatus(assets[i], true);
        }

        vm.stopBroadcast();

        console.log("--- Deployment complete ---");
    }
}
