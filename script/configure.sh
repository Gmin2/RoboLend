#!/usr/bin/env bash
# configure.sh — Complete steps 8-10 for already-deployed contracts
#
# Usage:
#   bash script/configure.sh
#
# Run this after deploy.sh if it failed at step 8 (risk params).

set -euo pipefail

PRIVATE_KEY=0xc741c8081d62b0db4544550a6e266f6abb66b57146a848d09b649199c0d5103d
RPC="https://rpc.testnet.chain.robinhood.com"

# Deployed contract addresses from deploy.sh output
ORACLE=0x6954b1F86A2c1615F8dc41969Cef57D558969e2c
REGISTRY=0x8E6a1F587D3711332Aa7Ac2D54F7633bC882c530

# Token addresses
WETH=0x7943e237c7F95DA44E0301572D358911207852Fa
TSLA=0xC9f9c86933092BbbfFF3CCb4b105A4A94bf3Bd4E
AMZN=0x5884aD2f920c162CFBbACc88C9C51AA75eC09E02
PLTR=0x1FBE1a0e43594b3455993B5dE5Fd0A7A266298d0
NFLX=0x3b8262A63d25f0477c4DDE23F83cfe22Cb768C93
AMD=0x71178BAc73cBeb415514eB542a8995b82669778d

echo "========================================="
echo "  Configure — Steps 8, 9, 10"
echo "========================================="

# ── Step 8: Configure risk parameters (uint16, uint16, uint16, uint8) ──
echo ""
echo "Step 8: Setting risk parameters..."
cast send "$REGISTRY" "setRiskParams(address,uint16,uint16,uint16,uint8)" "$AMZN" 6500 8000  500 18 --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
echo "  AMZN done"
cast send "$REGISTRY" "setRiskParams(address,uint16,uint16,uint16,uint8)" "$NFLX" 6000 7500  600 18 --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
echo "  NFLX done"
cast send "$REGISTRY" "setRiskParams(address,uint16,uint16,uint16,uint8)" "$TSLA" 5500 7000  750 18 --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
echo "  TSLA done"
cast send "$REGISTRY" "setRiskParams(address,uint16,uint16,uint16,uint8)" "$AMD"  5000 7000  800 18 --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
echo "  AMD done"
cast send "$REGISTRY" "setRiskParams(address,uint16,uint16,uint16,uint8)" "$PLTR" 4500 6500 1000 18 --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
echo "  PLTR done"
cast send "$REGISTRY" "setRiskParams(address,uint16,uint16,uint16,uint8)" "$WETH" 8000 8500  500 18 --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
echo "  WETH done"

# ── Step 9: Set initial oracle prices (8 decimals, Chainlink convention) ──
echo ""
echo "Step 9: Setting oracle prices..."
cast send "$ORACLE" "setPrice(address,uint256)" "$TSLA" 25000000000  --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
echo "  TSLA = \$250"
cast send "$ORACLE" "setPrice(address,uint256)" "$AMZN" 18500000000  --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
echo "  AMZN = \$185"
cast send "$ORACLE" "setPrice(address,uint256)" "$PLTR"  8000000000  --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
echo "  PLTR = \$80"
cast send "$ORACLE" "setPrice(address,uint256)" "$NFLX" 95000000000  --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
echo "  NFLX = \$950"
cast send "$ORACLE" "setPrice(address,uint256)" "$AMD"  12000000000  --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
echo "  AMD = \$120"
cast send "$ORACLE" "setPrice(address,uint256)" "$WETH" 250000000000 --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
echo "  WETH = \$2500"

# ── Step 10: Open all markets ──
echo ""
echo "Step 10: Opening all markets..."
cast send "$ORACLE" "setMarketStatus(address,bool)" "$TSLA" true --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$ORACLE" "setMarketStatus(address,bool)" "$AMZN" true --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$ORACLE" "setMarketStatus(address,bool)" "$PLTR" true --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$ORACLE" "setMarketStatus(address,bool)" "$NFLX" true --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$ORACLE" "setMarketStatus(address,bool)" "$AMD"  true --rpc-url "$RPC" --private-key "$PRIVATE_KEY"
cast send "$ORACLE" "setMarketStatus(address,bool)" "$WETH" true --rpc-url "$RPC" --private-key "$PRIVATE_KEY"

echo ""
echo "========================================="
echo "  Configuration Complete!"
echo "========================================="
echo ""
echo "Add these to your .env file:"
echo ""
echo "ORACLE=$ORACLE"
echo "LENDING_POOL=0x8E5F63D90B459f71a94FD86901A17a81a8F1e4AE"
echo "LIQUIDATION_ENGINE=0x79129F69544ca67920eAc0a269817C1E79cfE7C1"
