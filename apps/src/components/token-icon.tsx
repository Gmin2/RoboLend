const SUPPORTED = new Set(["TSLA", "AMZN", "PLTR", "NFLX", "AMD", "WETH"])

interface TokenIconProps {
  symbol: string
  className?: string
}

export function TokenIcon({ symbol, className = "w-8 h-8" }: TokenIconProps) {
  if (SUPPORTED.has(symbol)) {
    return (
      <img
        src={`/tokens/${symbol.toLowerCase()}.svg`}
        alt={symbol}
        className={`rounded-full ${className}`}
      />
    )
  }

  return (
    <div className={`rounded-full bg-white/10 flex items-center justify-center text-xs font-bold ${className}`}>
      {symbol[0]}
    </div>
  )
}
