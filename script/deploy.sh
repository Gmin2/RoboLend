#!/usr/bin/env bash
# deploy.sh — Deploy Equities Money Market to Robinhood Chain Testnet
#
# Usage:
#   source .env && bash script/deploy.sh
#
# Requires: PRIVATE_KEY set in environment
# Uses forge create (forge script --broadcast doesn't support chain 46630)

set -euo pipefail

PRIVATE_KEY=0xc741c8081d62b0db4544550a6e266f6abb66b57146a848d09b649199c0d5103d

RPC="https://rpc.testnet.chain.robinhood.com"

# Robinhood Chain Testnet token addresses
WETH=0x7943e237c7F95DA44E0301572D358911207852Fa
TSLA=0xC9f9c86933092BbbfFF3CCb4b105A4A94bf3Bd4E
AMZN=0x5884aD2f920c162CFBbACc88C9C51AA75eC09E02
PLTR=0x1FBE1a0e43594b3455993B5dE5Fd0A7A266298d0
NFLX=0x3b8262A63d25f0477c4DDE23F83cfe22Cb768C93
AMD=0x71178BAc73cBeb415514eB542a8995b82669778d

echo "========================================="
echo "  Equities Money Market — Deployment"
echo "========================================="

# Helper: extract deployed address from forge create output
extract_addr() {
    grep "Deployed to:" | awk '{print $3}'
}

# ── Step 1: Deploy periphery contracts ──
echo ""
echo "Step 1: Deploying MockPriceOracle..."
ORACLE=$(forge create src/periphery/MockPriceOracle.sol:MockPriceOracle \
    --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --broadcast | extract_addr)
echo "  MockPriceOracle: $ORACLE"

echo "Step 1: Deploying InterestRateModel..."
IRM=$(forge create src/periphery/InterestRateModel.sol:InterestRateModel \
    --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --broadcast \
    --constructor-args 20000000000000000 100000000000000000 3000000000000000000 800000000000000000 | extract_addr)
echo "  InterestRateModel: $IRM"

echo "Step 1: Deploying RiskRegistry..."
REGISTRY=$(forge create src/periphery/RiskRegistry.sol:RiskRegistry \
    --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --broadcast | extract_addr)
echo "  RiskRegistry: $REGISTRY"

# ── Step 2: Deploy LendingPool ──
echo ""
echo "Step 2: Deploying LendingPool..."
POOL=$(forge create src/core/LendingPool.sol:LendingPool \
    --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --broadcast \
    --constructor-args "$WETH" "$ORACLE" "$IRM" "$REGISTRY" | extract_addr)
echo "  LendingPool: $POOL"

# ── Step 3: Deploy 6 AssetVaults ──
echo ""
echo "Step 3: Deploying AssetVaults..."

VAULT_TSLA=$(forge create src/core/AssetVault.sol:AssetVault \
    --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --broadcast \
    --constructor-args "$TSLA" "Robinhood TSLA" "rhTSLA" 18 | extract_addr)
echo "  Vault TSLA: $VAULT_TSLA"

VAULT_AMZN=$(forge create src/core/AssetVault.sol:AssetVault \
    --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --broadcast \
    --constructor-args "$AMZN" "Robinhood AMZN" "rhAMZN" 18 | extract_addr)
echo "  Vault AMZN: $VAULT_AMZN"

VAULT_PLTR=$(forge create src/core/AssetVault.sol:AssetVault \
    --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --broadcast \
    --constructor-args "$PLTR" "Robinhood PLTR" "rhPLTR" 18 | extract_addr)
echo "  Vault PLTR: $VAULT_PLTR"

VAULT_NFLX=$(forge create src/core/AssetVault.sol:AssetVault \
    --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --broadcast \
    --constructor-args "$NFLX" "Robinhood NFLX" "rhNFLX" 18 | extract_addr)
echo "  Vault NFLX: $VAULT_NFLX"

VAULT_AMD=$(forge create src/core/AssetVault.sol:AssetVault \
    --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --broadcast \
    --constructor-args "$AMD" "Robinhood AMD" "rhAMD" 18 | extract_addr)
echo "  Vault AMD: $VAULT_AMD"

VAULT_WETH=$(forge create src/core/AssetVault.sol:AssetVault \
    --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --broadcast \
    --constructor-args "$WETH" "Robinhood WETH" "rhWETH" 18 | extract_addr)
echo "  Vault WETH: $VAULT_WETH"

# ── Step 4: Link vaults to pool ──
echo ""
echo "Step 4: Linking vaults to pool..."
cast send "$VAULT_TSLA" "setLendingPool(address)" "$POOL" --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$VAULT_AMZN" "setLendingPool(address)" "$POOL" --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$VAULT_PLTR" "setLendingPool(address)" "$POOL" --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$VAULT_NFLX" "setLendingPool(address)" "$POOL" --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$VAULT_AMD"  "setLendingPool(address)" "$POOL" --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$VAULT_WETH" "setLendingPool(address)" "$POOL" --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
echo "  Done"

# ── Step 5: Register assets with pool ──
echo ""
echo "Step 5: Registering assets with pool..."
cast send "$POOL" "addAsset(address,address)" "$TSLA" "$VAULT_TSLA" --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$POOL" "addAsset(address,address)" "$AMZN" "$VAULT_AMZN" --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$POOL" "addAsset(address,address)" "$PLTR" "$VAULT_PLTR" --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$POOL" "addAsset(address,address)" "$NFLX" "$VAULT_NFLX" --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$POOL" "addAsset(address,address)" "$AMD"  "$VAULT_AMD"  --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$POOL" "addAsset(address,address)" "$WETH" "$VAULT_WETH" --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
echo "  Done"

# ── Step 6: Deploy LiquidationEngine ──
echo ""
echo "Step 6: Deploying LiquidationEngine..."
ENGINE=$(forge create src/periphery/LiquidationEngine.sol:LiquidationEngine \
    --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --broadcast \
    --constructor-args "$POOL" "$ORACLE" "$REGISTRY" "$WETH" | extract_addr)
echo "  LiquidationEngine: $ENGINE"

# ── Step 7: Link liquidation engine to pool ──
echo ""
echo "Step 7: Linking liquidation engine to pool..."
cast send "$POOL" "setLiquidationEngine(address)" "$ENGINE" --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
echo "  Done"

# ── Step 8: Configure risk parameters ──
echo ""
echo "Step 8: Setting risk parameters..."
cast send "$REGISTRY" "setRiskParams(address,uint16,uint16,uint16,uint8)" "$AMZN" 6500 8000  500 18 --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$REGISTRY" "setRiskParams(address,uint16,uint16,uint16,uint8)" "$NFLX" 6000 7500  600 18 --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$REGISTRY" "setRiskParams(address,uint16,uint16,uint16,uint8)" "$TSLA" 5500 7000  750 18 --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$REGISTRY" "setRiskParams(address,uint16,uint16,uint16,uint8)" "$AMD"  5000 7000  800 18 --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$REGISTRY" "setRiskParams(address,uint16,uint16,uint16,uint8)" "$PLTR" 4500 6500 1000 18 --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$REGISTRY" "setRiskParams(address,uint16,uint16,uint16,uint8)" "$WETH" 8000 8500  500 18 --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
echo "  Done"

# ── Step 9: Set initial oracle prices (8 decimals) ──
echo ""
echo "Step 9: Setting oracle prices..."
# setPrices(address[],uint256[]) — easier to call setPrice individually
cast send "$ORACLE" "setPrice(address,uint256)" "$TSLA" 25000000000 --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$ORACLE" "setPrice(address,uint256)" "$AMZN" 18500000000 --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$ORACLE" "setPrice(address,uint256)" "$PLTR"  8000000000 --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$ORACLE" "setPrice(address,uint256)" "$NFLX" 95000000000 --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$ORACLE" "setPrice(address,uint256)" "$AMD"  12000000000 --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$ORACLE" "setPrice(address,uint256)" "$WETH" 250000000000 --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
echo "  Done"

# ── Step 10: Open all markets ──
echo ""
echo "Step 10: Opening all markets..."
cast send "$ORACLE" "setMarketStatus(address,bool)" "$TSLA" true --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$ORACLE" "setMarketStatus(address,bool)" "$AMZN" true --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$ORACLE" "setMarketStatus(address,bool)" "$PLTR" true --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$ORACLE" "setMarketStatus(address,bool)" "$NFLX" true --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$ORACLE" "setMarketStatus(address,bool)" "$AMD"  true --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$ORACLE" "setMarketStatus(address,bool)" "$WETH" true --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
echo "  Done"

# ── Summary ──
echo ""
echo "========================================="
echo "  Deployment Complete!"
echo "========================================="
echo ""
echo "Add these to your .env file:"
echo ""
echo "ORACLE=$ORACLE"
echo "LENDING_POOL=$POOL"
echo "LIQUIDATION_ENGINE=$ENGINE"
echo ""
echo "Other deployed contracts:"
echo "  InterestRateModel: $IRM"
echo "  RiskRegistry:      $REGISTRY"
echo "  Vault TSLA:        $VAULT_TSLA"
echo "  Vault AMZN:        $VAULT_AMZN"
echo "  Vault PLTR:        $VAULT_PLTR"
echo "  Vault NFLX:        $VAULT_NFLX"
echo "  Vault AMD:         $VAULT_AMD"
echo "  Vault WETH:        $VAULT_WETH"
