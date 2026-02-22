export const LENDING_POOL = "0x8E5F63D90B459f71a94FD86901A17a81a8F1e4AE" as const
export const MOCK_PRICE_ORACLE = "0x6954b1F86A2c1615F8dc41969Cef57D558969e2c" as const
export const LIQUIDATION_ENGINE = "0x79129F69544ca67920eAc0a269817C1E79cfE7C1" as const

export const TOKEN_ADDRESSES = {
  WETH: "0x7943e237c7F95DA44E0301572D358911207852Fa",
  TSLA: "0xC9f9c86933092BbbfFF3CCb4b105A4A94bf3Bd4E",
  AMZN: "0x5884aD2f920c162CFBbACc88C9C51AA75eC09E02",
  PLTR: "0x1FBE1a0e43594b3455993B5dE5Fd0A7A266298d0",
  NFLX: "0x3b8262A63d25f0477c4DDE23F83cfe22Cb768C93",
  AMD: "0x71178BAc73cBeb415514eB542a8995b82669778d",
} as const

export type TokenSymbol = keyof typeof TOKEN_ADDRESSES

export const TOKENS = [
  { symbol: "TSLA" as const, name: "Tesla Inc.", address: TOKEN_ADDRESSES.TSLA },
  { symbol: "AMZN" as const, name: "Amazon.com", address: TOKEN_ADDRESSES.AMZN },
  { symbol: "PLTR" as const, name: "Palantir Tech", address: TOKEN_ADDRESSES.PLTR },
  { symbol: "NFLX" as const, name: "Netflix Inc.", address: TOKEN_ADDRESSES.NFLX },
  { symbol: "AMD" as const, name: "AMD Inc.", address: TOKEN_ADDRESSES.AMD },
  { symbol: "WETH" as const, name: "Wrapped ETH", address: TOKEN_ADDRESSES.WETH },
] as const

export const EQUITY_TOKENS = TOKENS.filter((t) => t.symbol !== "WETH")

// --- Minimal ABIs ---

export const lendingPoolAbi = [
  { type: "function", name: "deposit", inputs: [{ name: "asset", type: "address" }, { name: "amount", type: "uint256" }], outputs: [], stateMutability: "nonpayable" },
  { type: "function", name: "withdraw", inputs: [{ name: "asset", type: "address" }, { name: "receiptAmount", type: "uint256" }], outputs: [], stateMutability: "nonpayable" },
  { type: "function", name: "borrow", inputs: [{ name: "amount", type: "uint256" }], outputs: [], stateMutability: "nonpayable" },
  { type: "function", name: "repay", inputs: [{ name: "amount", type: "uint256" }], outputs: [], stateMutability: "nonpayable" },
  { type: "function", name: "liquidate", inputs: [{ name: "borrower", type: "address" }, { name: "collateralAsset", type: "address" }, { name: "debtToRepay", type: "uint256" }], outputs: [], stateMutability: "nonpayable" },
  { type: "function", name: "getHealthFactor", inputs: [{ name: "user", type: "address" }], outputs: [{ name: "", type: "uint256" }], stateMutability: "view" },
  { type: "function", name: "getUserDebt", inputs: [{ name: "user", type: "address" }], outputs: [{ name: "", type: "uint256" }], stateMutability: "view" },
  { type: "function", name: "getUserCollateral", inputs: [{ name: "user", type: "address" }, { name: "asset", type: "address" }], outputs: [{ name: "", type: "uint256" }], stateMutability: "view" },
  { type: "function", name: "getMaxBorrow", inputs: [{ name: "user", type: "address" }], outputs: [{ name: "", type: "uint256" }], stateMutability: "view" },
  { type: "function", name: "getSupportedAssets", inputs: [], outputs: [{ name: "", type: "address[]" }], stateMutability: "view" },
  { type: "function", name: "borrowIndex", inputs: [], outputs: [{ name: "", type: "uint256" }], stateMutability: "view" },
  { type: "function", name: "totalBorrowAmount", inputs: [], outputs: [{ name: "", type: "uint256" }], stateMutability: "view" },
  { type: "function", name: "totalBorrowShares", inputs: [], outputs: [{ name: "", type: "uint256" }], stateMutability: "view" },
  { type: "function", name: "reserves", inputs: [], outputs: [{ name: "", type: "uint256" }], stateMutability: "view" },
  { type: "function", name: "reserveFactor", inputs: [], outputs: [{ name: "", type: "uint256" }], stateMutability: "view" },
  { type: "function", name: "riskRegistry", inputs: [], outputs: [{ name: "", type: "address" }], stateMutability: "view" },
] as const

export const oracleAbi = [
  { type: "function", name: "getPrice", inputs: [{ name: "asset", type: "address" }], outputs: [{ name: "priceUsd", type: "uint256" }], stateMutability: "view" },
  { type: "function", name: "isMarketOpen", inputs: [{ name: "asset", type: "address" }], outputs: [{ name: "", type: "bool" }], stateMutability: "view" },
] as const

export const liquidationEngineAbi = [
  {
    type: "function", name: "isLiquidationProfitable",
    inputs: [
      { name: "borrower", type: "address" },
      { name: "collateralAsset", type: "address" },
      { name: "debtAmount", type: "uint256" },
    ],
    outputs: [
      { name: "isProfitable", type: "bool" },
      { name: "estimatedProfit", type: "uint256" },
      { name: "gasCost", type: "uint256" },
      { name: "bonusValue", type: "uint256" },
    ],
    stateMutability: "view",
  },
] as const

export const riskRegistryAbi = [
  {
    type: "function", name: "getRiskParams",
    inputs: [{ name: "asset", type: "address" }],
    outputs: [
      { name: "ltvBps", type: "uint16" },
      { name: "liquidationThresholdBps", type: "uint16" },
      { name: "liquidationBonusBps", type: "uint16" },
      { name: "decimals", type: "uint8" },
      { name: "isActive", type: "bool" },
    ],
    stateMutability: "view",
  },
] as const

export const erc20Abi = [
  { type: "function", name: "balanceOf", inputs: [{ name: "account", type: "address" }], outputs: [{ name: "", type: "uint256" }], stateMutability: "view" },
  { type: "function", name: "allowance", inputs: [{ name: "owner", type: "address" }, { name: "spender", type: "address" }], outputs: [{ name: "", type: "uint256" }], stateMutability: "view" },
  { type: "function", name: "approve", inputs: [{ name: "spender", type: "address" }, { name: "value", type: "uint256" }], outputs: [{ name: "", type: "bool" }], stateMutability: "nonpayable" },
  { type: "function", name: "symbol", inputs: [], outputs: [{ name: "", type: "string" }], stateMutability: "view" },
  { type: "function", name: "decimals", inputs: [], outputs: [{ name: "", type: "uint8" }], stateMutability: "view" },
] as const
