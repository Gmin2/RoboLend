# Frontend Requirements — Equities Money Market

## Network

- **Chain:** Robinhood Chain Testnet (chain ID `46630`)
- **RPC:** `https://rpc.testnet.chain.robinhood.com`
- **Explorer:** `https://explorer.testnet.chain.robinhood.com`

## Contracts

| Contract           | Address                                      |
|--------------------|----------------------------------------------|
| LendingPool        | `0x8E5F63D90B459f71a94FD86901A17a81a8F1e4AE` |
| MockPriceOracle    | `0x6954b1F86A2c1615F8dc41969Cef57D558969e2c` |
| LiquidationEngine  | `0x79129F69544ca67920eAc0a269817C1E79cfE7C1` |

## Token Addresses

| Token | Address                                      |
|-------|----------------------------------------------|
| WETH  | `0x7943e237c7F95DA44E0301572D358911207852Fa` |
| TSLA  | `0xC9f9c86933092BbbfFF3CCb4b105A4A94bf3Bd4E` |
| AMZN  | `0x5884aD2f920c162CFBbACc88C9C51AA75eC09E02` |
| PLTR  | `0x1FBE1a0e43594b3455993B5dE5Fd0A7A266298d0` |
| NFLX  | `0x3b8262A63d25f0477c4DDE23F83cfe22Cb768C93` |
| AMD   | `0x71178BAc73cBeb415514eB542a8995b82669778d` |

All tokens are ERC-20 with 18 decimals. Oracle prices use 8 decimals (Chainlink convention).

---

## Pages

### 1. Dashboard (Home)

**Purpose:** Overview of the user's positions and protocol health.

**Data to display:**

- Connected wallet address and ETH balance
- For each supported asset (TSLA, AMZN, PLTR, NFLX, AMD, WETH):
  - Current oracle price (call `oracle.getPrice(asset)` — returns USD with 8 decimals, divide by `1e8` for display)
  - Market open/closed status (call `oracle.isMarketOpen(asset)`)
  - User's wallet balance (call `token.balanceOf(user)`)
  - User's deposited collateral in the pool (call `pool.getUserCollateral(user, asset)` — returns receipt tokens)
- User's total WETH debt (call `pool.getUserDebt(user)`)
- User's health factor (call `pool.getHealthFactor(user)` — returns WAD, divide by `1e18`; display "Safe" if > 1.5, "Warning" if 1.0–1.5, "Danger" if < 1.0; display "N/A" or infinity if no debt)
- User's max borrowable WETH (call `pool.getMaxBorrow(user)`)
- Quick-action buttons: "Deposit", "Borrow", "Repay", "Withdraw" (navigate to respective sections or open modals)

**Contracts called:**

- `MockPriceOracle.getPrice(address asset)` → `uint256` (8 decimals)
- `MockPriceOracle.isMarketOpen(address asset)` → `bool`
- `LendingPool.getUserCollateral(address user, address asset)` → `uint256`
- `LendingPool.getUserDebt(address user)` → `uint256`
- `LendingPool.getHealthFactor(address user)` → `uint256`
- `LendingPool.getMaxBorrow(address user)` → `uint256`
- `LendingPool.getSupportedAssets()` → `address[]`
- `ERC20.balanceOf(address user)` → `uint256` (for each token)

---

### 2. Deposit

**Purpose:** Deposit equity tokens as collateral.

**Input form:**

- Asset selector dropdown (TSLA, AMZN, PLTR, NFLX, AMD) — populated from `pool.getSupportedAssets()`, exclude WETH since WETH is the borrow asset
- Amount input (number field, 18 decimals)
- "Max" button that fills the user's full wallet balance for the selected asset
- Display the user's wallet balance for the selected asset
- Display the asset's current oracle price
- Display the asset's risk parameters:
  - LTV (call `riskRegistry.getRiskParams(asset).ltvBps` — divide by 100 for percentage)
  - Liquidation threshold (`.liquidationThresholdBps` — divide by 100)
  - Liquidation bonus (`.liquidationBonusBps` — divide by 100)

**Actions (two transactions):**

1. **Approve:** `token.approve(poolAddress, amount)` — only if current allowance < amount (check with `token.allowance(user, poolAddress)`)
2. **Deposit:** `pool.deposit(asset, amount)`

**Post-action feedback:**

- Updated collateral balance
- Updated health factor
- Updated max borrow

**Contracts called:**

- `ERC20.balanceOf(user)` → wallet balance
- `ERC20.allowance(user, poolAddress)` → current allowance
- `ERC20.approve(poolAddress, amount)` → approve tx
- `LendingPool.deposit(asset, amount)` → deposit tx
- `RiskRegistry.getRiskParams(asset)` → `(uint16 ltvBps, uint16 liquidationThresholdBps, uint16 liquidationBonusBps, uint8 decimals, bool isActive)`

**Events to listen for:**

- `LendingPool.Deposited(indexed user, indexed asset, amount)`

---

### 3. Withdraw

**Purpose:** Withdraw collateral from the pool.

**Input form:**

- Asset selector dropdown (only assets where user has collateral > 0)
- Amount input (receipt tokens, 18 decimals)
- "Max" button that fills user's full collateral balance for that asset
- Display current collateral balance (call `pool.getUserCollateral(user, asset)`)
- Display current debt and health factor
- **Warning** if withdrawing would push health factor below 1.0 (simulate: re-query `getHealthFactor` after the tx, or compute client-side)

**Action:**

- `pool.withdraw(asset, receiptAmount)`

**Validation:**

- Cannot withdraw if it would make health factor < 1.0 (the contract reverts, but show a client-side warning)
- Cannot withdraw more than deposited balance

**Contracts called:**

- `LendingPool.getUserCollateral(user, asset)` → current collateral
- `LendingPool.getHealthFactor(user)` → current health factor
- `LendingPool.withdraw(asset, receiptAmount)` → withdraw tx

**Events to listen for:**

- `LendingPool.Withdrawn(indexed user, indexed asset, amount)`

---

### 4. Borrow

**Purpose:** Borrow WETH against deposited collateral.

**Input form:**

- Amount input (WETH, 18 decimals)
- "Max" button that fills the max borrowable amount (call `pool.getMaxBorrow(user)`)
- Display max borrow capacity
- Display current debt
- Display projected health factor after borrow (compute client-side or show warning thresholds)
- Display current WETH price from oracle

**Action:**

- `pool.borrow(amount)`

**Validation:**

- Cannot borrow more than `getMaxBorrow(user)` (contract reverts, but show client-side check)
- Must have collateral deposited first
- All deposited asset markets must be open (`oracle.isMarketOpen(asset)`)

**Contracts called:**

- `LendingPool.getMaxBorrow(user)` → max WETH borrowable
- `LendingPool.getUserDebt(user)` → current debt
- `LendingPool.getHealthFactor(user)` → current health factor
- `LendingPool.borrow(amount)` → borrow tx

**Events to listen for:**

- `LendingPool.Borrowed(indexed user, amount)`

---

### 5. Repay

**Purpose:** Repay borrowed WETH.

**Input form:**

- Amount input (WETH, 18 decimals)
- "Max" / "Repay All" button — fills `getUserDebt(user)` plus a small buffer (suggest 0.1% extra to cover interest accrual between read and tx; `repay()` caps at actual debt so overpaying is safe)
- Display current debt (call `pool.getUserDebt(user)`)
- Display user's WETH wallet balance
- Display health factor improvement preview

**Actions (two transactions):**

1. **Approve:** `weth.approve(poolAddress, amount)` — only if allowance < amount
2. **Repay:** `pool.repay(amount)`

**Note:** The `repay()` function caps repayment at the user's actual debt, so approving/sending more than owed is safe — excess is not taken.

**Contracts called:**

- `LendingPool.getUserDebt(user)` → current debt
- `ERC20.balanceOf(user)` → WETH balance
- `ERC20.allowance(user, poolAddress)` → current allowance
- `ERC20.approve(poolAddress, amount)` → approve tx
- `LendingPool.repay(amount)` → repay tx

**Events to listen for:**

- `LendingPool.Repaid(indexed user, amount)`

---

### 6. Liquidate

**Purpose:** Liquidate undercollateralized positions for a bonus.

**Input form:**

- Borrower address input (text field, 0x... address)
- "Check" button to load the borrower's position
- After checking, display:
  - Borrower's health factor (must be < 1.0 to liquidate)
  - Borrower's total debt
  - Borrower's collateral per asset
- Collateral asset selector (only assets where borrower has collateral)
- Debt amount to repay input (WETH, 18 decimals) — capped at 50% of total debt (CLOSE_FACTOR)
- "Max" button that fills 50% of debt
- Liquidation profitability check (call `liquidationEngine.isLiquidationProfitable(borrower, collateralAsset, debtAmount)` — returns `(bool isProfitable, uint256 estimatedProfit, uint256 gasCost, uint256 bonusValue)`)
- Display estimated collateral received and bonus

**Actions (two transactions):**

1. **Approve:** `weth.approve(poolAddress, debtToRepay)`
2. **Liquidate:** `pool.liquidate(borrower, collateralAsset, debtToRepay)`

**Contracts called:**

- `LendingPool.getHealthFactor(borrower)` → health factor
- `LendingPool.getUserDebt(borrower)` → debt
- `LendingPool.getUserCollateral(borrower, asset)` → collateral per asset
- `LendingPool.getSupportedAssets()` → asset list
- `LiquidationEngine.isLiquidationProfitable(borrower, collateralAsset, debtAmount)` → `(bool, uint256, uint256, uint256)`
- `ERC20.approve(poolAddress, debtToRepay)` → approve tx
- `LendingPool.liquidate(borrower, collateralAsset, debtToRepay)` → liquidate tx

---

### 7. Markets

**Purpose:** Display protocol-wide stats for all supported assets.

**Data to display per asset:**

| Column                 | Source                                                    |
|------------------------|-----------------------------------------------------------|
| Asset name/symbol      | Hardcoded or `ERC20.symbol()`                             |
| Price (USD)            | `oracle.getPrice(asset)` ÷ `1e8`                         |
| Market status          | `oracle.isMarketOpen(asset)`                              |
| LTV                    | `riskRegistry.getRiskParams(asset).ltvBps` ÷ 100 → `%`   |
| Liquidation threshold  | `.liquidationThresholdBps` ÷ 100 → `%`                   |
| Liquidation bonus      | `.liquidationBonusBps` ÷ 100 → `%`                       |

**Protocol-wide stats:**

- Total WETH borrowed (`pool.totalBorrowAmount()`)
- Total borrow shares (`pool.totalBorrowShares()`)
- Current borrow index (`pool.borrowIndex()` — RAY, divide by `1e27`)
- Protocol reserves (`pool.reserves()`)
- Reserve factor (`pool.reserveFactor()` — WAD, divide by `1e18`, show as %)
- Pool WETH balance (`weth.balanceOf(poolAddress)`)

**Current configured risk parameters:**

| Asset | LTV   | Liq. Threshold | Liq. Bonus |
|-------|-------|----------------|------------|
| AMZN  | 65%   | 80%            | 5%         |
| NFLX  | 60%   | 75%            | 6%         |
| TSLA  | 55%   | 70%            | 7.5%       |
| AMD   | 50%   | 70%            | 8%         |
| PLTR  | 45%   | 65%            | 10%        |
| WETH  | 80%   | 85%            | 5%         |

**Contracts called:**

- `MockPriceOracle.getPrice(asset)` per asset
- `MockPriceOracle.isMarketOpen(asset)` per asset
- `RiskRegistry.getRiskParams(asset)` per asset
- `LendingPool.totalBorrowAmount()`
- `LendingPool.totalBorrowShares()`
- `LendingPool.borrowIndex()`
- `LendingPool.reserves()`
- `LendingPool.reserveFactor()`
- `ERC20.balanceOf(poolAddress)` (WETH)

---

### 8. Faucet (Optional)

**Purpose:** Link to the Robinhood Chain testnet faucet for getting test tokens.

**Content:**

- Link to `https://faucet.testnet.chain.robinhood.com/`
- Note: Faucet gives 5 of each equity token + 0.01 ETH per 24 hours
- Display user's current balances for all tokens

---

## Wallet Connection

- Support MetaMask / WalletConnect / injected provider
- Auto-add Robinhood Chain Testnet if not configured:
  - Chain ID: `46630`
  - RPC: `https://rpc.testnet.chain.robinhood.com`
  - Currency: ETH
  - Explorer: `https://explorer.testnet.chain.robinhood.com`
- Show connected address and ETH balance in header/navbar

---

## Transaction Flow (All Write Operations)

Every write operation follows this pattern:

1. User fills form and clicks action button
2. If ERC-20 approval needed, prompt approval tx first, wait for confirmation
3. Send the main transaction
4. Show pending state while tx is mining
5. On success: refresh relevant data (balances, health factor, debt, collateral)
6. On failure: show error message from revert reason

---

## Key Formatting Rules

| Value             | Raw                    | Display                            |
|-------------------|------------------------|------------------------------------|
| Token amounts     | `uint256` (18 dec)     | Divide by `1e18`, show 4-6 decimals |
| Prices            | `uint256` (8 dec)      | Divide by `1e8`, show as `$XXX.XX`  |
| Health factor     | `uint256` (18 dec)     | Divide by `1e18`, show 2 decimals   |
| Health factor max | `type(uint256).max`    | Display as "∞" or "No debt"        |
| Basis points      | `uint16`               | Divide by 100, show as `XX%`       |
| Reserve factor    | `uint256` WAD          | Divide by `1e18`, show as `XX%`    |
| Borrow index      | `uint256` RAY          | Divide by `1e27`, show 4 decimals  |

---

## ABI Requirements

The frontend needs ABIs for:

1. **LendingPool** — `deposit`, `withdraw`, `borrow`, `repay`, `liquidate`, `getHealthFactor`, `getUserDebt`, `getUserCollateral`, `getMaxBorrow`, `getSupportedAssets`, `totalBorrowAmount`, `totalBorrowShares`, `borrowIndex`, `reserves`, `reserveFactor`
2. **MockPriceOracle** — `getPrice`, `isMarketOpen`
3. **LiquidationEngine** — `isLiquidationProfitable`
4. **RiskRegistry** — `getRiskParams`
5. **ERC20** — `balanceOf`, `allowance`, `approve`, `symbol`, `decimals`

ABIs can be extracted from the `out/` folder after running `forge build`.
