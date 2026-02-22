#!/usr/bin/env bash
# interact.sh — Full lending lifecycle smoke test (deposit → borrow → repay → withdraw)
#
# Usage:
#   bash script/interact.sh

set -euo pipefail

PRIVATE_KEY=0xc741c8081d62b0db4544550a6e266f6abb66b57146a848d09b649199c0d5103d
RPC="https://rpc.testnet.chain.robinhood.com"
DEPLOYER=0x2eAB963E2dF2fcfdff673820a2e79F029f49C003

# Deployed contracts
ORACLE=0x6954b1F86A2c1615F8dc41969Cef57D558969e2c
POOL=0x8E5F63D90B459f71a94FD86901A17a81a8F1e4AE
ENGINE=0x79129F69544ca67920eAc0a269817C1E79cfE7C1

# Token addresses
WETH=0x7943e237c7F95DA44E0301572D358911207852Fa
TSLA=0xC9f9c86933092BbbfFF3CCb4b105A4A94bf3Bd4E
AMZN=0x5884aD2f920c162CFBbACc88C9C51AA75eC09E02
PLTR=0x1FBE1a0e43594b3455993B5dE5Fd0A7A266298d0
NFLX=0x3b8262A63d25f0477c4DDE23F83cfe22Cb768C93
AMD=0x71178BAc73cBeb415514eB542a8995b82669778d

# WETH vault — _accrueInterest() reads WETH from here for utilization rate
WETH_VAULT=0xa13762D14313838Dca3c29b4a72F2e7Ec07f05a7

# Borrow/repay amounts
BORROW_AMT=500000000000000       # 0.0005 WETH
REPAY_APPROVE=600000000000000    # 0.0006 WETH (20% buffer for accrued interest)

C="--rpc-url $RPC --private-key $PRIVATE_KEY"

echo "========================================="
echo "  Lending Lifecycle Smoke Test"
echo "========================================="

# ── Pre-flight checks ──
echo ""
echo "Pre-flight checks..."
TSLA_BAL=$(cast call "$TSLA" "balanceOf(address)(uint256)" "$DEPLOYER" --rpc-url "$RPC")
WETH_BAL=$(cast call "$WETH" "balanceOf(address)(uint256)" "$DEPLOYER" --rpc-url "$RPC")
echo "  TSLA balance: $TSLA_BAL"
echo "  WETH balance: $WETH_BAL"

# ── Step 1: Refresh oracle prices (reset staleness timer) ──
echo ""
echo "=== Step 1: Refresh oracle prices ==="
cast send "$ORACLE" "setPrice(address,uint256)" "$TSLA" 25000000000  $C > /dev/null
cast send "$ORACLE" "setPrice(address,uint256)" "$AMZN" 18500000000  $C > /dev/null
cast send "$ORACLE" "setPrice(address,uint256)" "$PLTR"  8000000000  $C > /dev/null
cast send "$ORACLE" "setPrice(address,uint256)" "$NFLX" 95000000000  $C > /dev/null
cast send "$ORACLE" "setPrice(address,uint256)" "$AMD"  12000000000  $C > /dev/null
cast send "$ORACLE" "setPrice(address,uint256)" "$WETH" 250000000000 $C > /dev/null
echo "  All 6 prices refreshed"

# ── Step 2: Seed pool + WETH vault ──
# borrow() transfers WETH from the pool contract's own balance.
# _accrueInterest() reads the WETH vault balance for utilization rate.
# Both need WETH or the protocol breaks.
echo ""
echo "=== Step 2: Seed pool + WETH vault ==="
POOL_WETH=$(cast call "$WETH" "balanceOf(address)(uint256)" "$POOL" --rpc-url "$RPC" | awk '{print $1}')
echo "  Pool WETH: $POOL_WETH"
if [ "$POOL_WETH" = "0" ]; then
    echo "  Seeding pool with 0.001 WETH..."
    cast send "$WETH" "transfer(address,uint256)" "$POOL" 1000000000000000 $C > /dev/null
fi

VAULT_WETH=$(cast call "$WETH" "balanceOf(address)(uint256)" "$WETH_VAULT" --rpc-url "$RPC" | awk '{print $1}')
echo "  WETH vault balance: $VAULT_WETH"
if [ "$VAULT_WETH" = "0" ]; then
    echo "  Seeding WETH vault with 0.001 WETH..."
    cast send "$WETH" "transfer(address,uint256)" "$WETH_VAULT" 1000000000000000 $C > /dev/null
fi
echo "  Done"

# ── Step 3: Deposit 5 TSLA as collateral ──
echo ""
echo "=== Step 3: Deposit 5 TSLA as collateral ==="
cast send "$TSLA" "approve(address,uint256)" "$POOL" 5000000000000000000 $C > /dev/null
echo "  Approved 5 TSLA"
cast send "$POOL" "deposit(address,uint256)" "$TSLA" 5000000000000000000 $C > /dev/null
echo "  Deposited 5 TSLA"

RECEIPTS=$(cast call "$POOL" "getUserCollateral(address,address)(uint256)" "$DEPLOYER" "$TSLA" --rpc-url "$RPC")
MAX_BORROW=$(cast call "$POOL" "getMaxBorrow(address)(uint256)" "$DEPLOYER" --rpc-url "$RPC")
echo "  Receipt tokens: $RECEIPTS"
echo "  Max borrow (WETH): $MAX_BORROW"

# ── Step 4: Borrow WETH ──
echo ""
echo "=== Step 4: Borrow 0.0005 WETH ==="
cast send "$POOL" "borrow(uint256)" "$BORROW_AMT" $C > /dev/null
echo "  Borrowed 0.0005 WETH"

DEBT=$(cast call "$POOL" "getUserDebt(address)(uint256)" "$DEPLOYER" --rpc-url "$RPC")
HF=$(cast call "$POOL" "getHealthFactor(address)(uint256)" "$DEPLOYER" --rpc-url "$RPC")
echo "  Debt: $DEBT"
echo "  Health factor: $HF"

# ── Step 5: State snapshot ──
echo ""
echo "=== Step 5: State snapshot ==="
echo "  TSLA collateral: $(cast call "$POOL" "getUserCollateral(address,address)(uint256)" "$DEPLOYER" "$TSLA" --rpc-url "$RPC")"
echo "  User debt:       $(cast call "$POOL" "getUserDebt(address)(uint256)" "$DEPLOYER" --rpc-url "$RPC")"
echo "  Health factor:   $(cast call "$POOL" "getHealthFactor(address)(uint256)" "$DEPLOYER" --rpc-url "$RPC")"
echo "  Pool WETH:       $(cast call "$WETH" "balanceOf(address)(uint256)" "$POOL" --rpc-url "$RPC")"
echo "  Deployer WETH:   $(cast call "$WETH" "balanceOf(address)(uint256)" "$DEPLOYER" --rpc-url "$RPC")"

# ── Step 6: Repay full debt ──
# Approve with large buffer — repay() caps at actual debt so extra is never taken.
# This prevents the dust-debt problem where interest accrues between read and tx.
echo ""
echo "=== Step 6: Repay full debt ==="
FULL_DEBT=$(cast call "$POOL" "getUserDebt(address)(uint256)" "$DEPLOYER" --rpc-url "$RPC" | awk '{print $1}')
echo "  Current debt: $FULL_DEBT"
echo "  Approving with buffer: $REPAY_APPROVE"
cast send "$WETH" "approve(address,uint256)" "$POOL" "$REPAY_APPROVE" $C > /dev/null
cast send "$POOL" "repay(uint256)" "$REPAY_APPROVE" $C > /dev/null
echo "  Debt after repay: $(cast call "$POOL" "getUserDebt(address)(uint256)" "$DEPLOYER" --rpc-url "$RPC")"

# ── Step 7: Withdraw all TSLA ──
echo ""
echo "=== Step 7: Withdraw all TSLA ==="
ALL_RECEIPTS=$(cast call "$POOL" "getUserCollateral(address,address)(uint256)" "$DEPLOYER" "$TSLA" --rpc-url "$RPC" | awk '{print $1}')
echo "  Withdrawing receipts: $ALL_RECEIPTS"
cast send "$POOL" "withdraw(address,uint256)" "$TSLA" "$ALL_RECEIPTS" $C > /dev/null

echo ""
echo "  Final TSLA balance: $(cast call "$TSLA" "balanceOf(address)(uint256)" "$DEPLOYER" --rpc-url "$RPC")"
echo "  Final WETH balance: $(cast call "$WETH" "balanceOf(address)(uint256)" "$DEPLOYER" --rpc-url "$RPC")"
echo "  Final debt:         $(cast call "$POOL" "getUserDebt(address)(uint256)" "$DEPLOYER" --rpc-url "$RPC")"

echo ""
echo "========================================="
echo "  Lending Lifecycle Complete!"
echo "========================================="
