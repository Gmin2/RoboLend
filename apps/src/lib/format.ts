const MAX_UINT256 = 2n ** 256n - 1n
const WAD = 10n ** 18n
const RAY = 10n ** 27n

/** Divide bigint by 10^decimals and return a JS number */
function toNumber(value: bigint, decimals: number): number {
  const divisor = 10n ** BigInt(decimals)
  const integer = value / divisor
  const remainder = value % divisor
  const fractionStr = remainder.toString().padStart(decimals, "0")
  return parseFloat(`${integer}.${fractionStr}`)
}

/** Format token amount (18 decimals) → "1,234.5678" */
export function formatTokenAmount(value: bigint, decimals = 4): string {
  const num = toNumber(value, 18)
  return num.toLocaleString("en-US", {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  })
}

/** Format oracle price (8 decimals) → "$1,234.56" */
export function formatPrice(value: bigint): string {
  const num = toNumber(value, 8)
  return `$${num.toLocaleString("en-US", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`
}

/** Format health factor (18 decimals) → "2.14" or "∞" */
export function formatHealthFactor(value: bigint): string {
  if (value === MAX_UINT256 || value === 0n) return "∞"
  return toNumber(value, 18).toFixed(2)
}

/** Get health factor as number for comparisons */
export function healthFactorNumber(value: bigint): number {
  if (value === MAX_UINT256 || value === 0n) return Infinity
  return toNumber(value, 18)
}

/** Format basis points → "65%" */
export function formatBps(bps: number): string {
  return `${(bps / 100).toFixed(0)}%`
}

/** Format WAD (18 decimals) as percent → "10%" */
export function formatWad(value: bigint): string {
  const pct = toNumber(value, 18) * 100
  return `${pct.toFixed(0)}%`
}

/** Format RAY (27 decimals) → "1.0051" */
export function formatRay(value: bigint): string {
  const integer = value / RAY
  const remainder = value % RAY
  const fractionStr = remainder.toString().padStart(27, "0").slice(0, 4)
  return `${integer}.${fractionStr}`
}

/** Shorten address → "0x1234...5678" */
export function shortenAddress(addr: string): string {
  if (addr.length < 10) return addr
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`
}

/** Parse token amount string to bigint (18 decimals) */
export function parseTokenAmount(value: string): bigint {
  if (!value || value === "0") return 0n
  const [integer = "0", fraction = ""] = value.split(".")
  const paddedFraction = fraction.padEnd(18, "0").slice(0, 18)
  return BigInt(integer) * WAD + BigInt(paddedFraction)
}

/** Get raw token amount as number for display math */
export function tokenAmountToNumber(value: bigint): number {
  return toNumber(value, 18)
}

/** Get raw price as number */
export function priceToNumber(value: bigint): number {
  return toNumber(value, 8)
}
