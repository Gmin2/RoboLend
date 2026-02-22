import { Card } from "@/components/ui/card"
import { TokenIcon } from "@/components/token-icon"
import { TOKENS, EQUITY_TOKENS } from "@/config/contracts"
import { useTokenPrices, useMarketStatus, useRiskParams, useProtocolStats, usePoolWethBalance } from "@/hooks/useProtocol"
import { formatPrice, formatBps, formatRay, formatWad, formatTokenAmount } from "@/lib/format"

function StatusDot({ open }: { open: boolean }) {
  return (
    <span
      className={`inline-block w-1.5 h-1.5 rounded-full ${
        open ? "bg-[#00ff66]" : "bg-[#ff3333]"
      }`}
    />
  )
}

export function MarketsView() {
  const prices = useTokenPrices()
  const markets = useMarketStatus()
  const riskParams = useRiskParams()
  const stats = useProtocolStats()
  const poolWeth = usePoolWethBalance()

  const isLoading = prices.isLoading || markets.isLoading || riskParams.isLoading || stats.isLoading

  if (isLoading) {
    return (
      <div className="w-full flex items-center justify-center pt-32">
        <div className="text-xs text-[#888888] tracking-widest uppercase animate-pulse">
          LOADING MARKET DATA...
        </div>
      </div>
    )
  }

  const totalBorrowAmount = stats.data?.[0]?.result ?? 0n
  const totalBorrowShares = stats.data?.[1]?.result ?? 0n
  const borrowIndex = stats.data?.[2]?.result ?? 0n
  const reserves = stats.data?.[3]?.result ?? 0n
  const reserveFactor = stats.data?.[4]?.result ?? 0n
  const poolBalance = poolWeth.data ?? 0n

  const statCards = [
    { label: "TOTAL BORROW AMOUNT", value: `${formatTokenAmount(totalBorrowAmount)} WETH` },
    { label: "TOTAL BORROW SHARES", value: formatTokenAmount(totalBorrowShares) },
    { label: "BORROW INDEX", value: formatRay(borrowIndex) },
    { label: "RESERVES", value: `${formatTokenAmount(reserves)} WETH` },
    { label: "RESERVE FACTOR", value: formatWad(reserveFactor) },
    { label: "POOL WETH BALANCE", value: `${formatTokenAmount(poolBalance)} WETH` },
  ]

  // WETH is at index 5 in TOKENS array
  const wethIdx = TOKENS.findIndex((t) => t.symbol === "WETH")

  return (
    <div className="w-full h-full flex flex-col pt-8 relative z-20 max-w-6xl mx-auto overflow-y-auto pb-16">
      <div className="flex items-center justify-between mb-8">
        <div>
          <h2 className="text-3xl font-sans font-medium tracking-tight mb-2">
            Markets
          </h2>
          <div className="text-[10px] text-[#888888] tracking-widest uppercase">
            // PROTOCOL-WIDE ASSET DATA
          </div>
        </div>
      </div>

      {/* Protocol Stats */}
      <div className="grid grid-cols-6 gap-3 mb-8">
        {statCards.map((s) => (
          <Card key={s.label} className="p-3">
            <div className="text-[10px] text-[#888888] tracking-widest uppercase mb-1">
              {s.label}
            </div>
            <div className="text-sm font-mono text-white">{s.value}</div>
          </Card>
        ))}
      </div>

      {/* Asset Table */}
      <Card className="mb-8">
        <div className="grid grid-cols-8 gap-3 p-4 border-b border-white/10 text-[10px] text-[#888888] tracking-widest uppercase">
          <div className="col-span-2">Asset</div>
          <div className="text-right">Price</div>
          <div className="text-right">Status</div>
          <div className="text-right">LTV</div>
          <div className="text-right">Liq. Threshold</div>
          <div className="text-right">Liq. Bonus</div>
          <div className="text-right">Active</div>
        </div>

        {EQUITY_TOKENS.map((token, i) => {
          const price = prices.data?.[i]?.result ?? 0n
          const marketOpen = markets.data?.[i]?.result ?? false
          const risk = riskParams.data?.[i]?.result as [number, number, number, number, boolean] | undefined

          return (
            <div
              key={token.symbol}
              className="grid grid-cols-8 gap-3 p-4 border-b border-white/5 hover:bg-white/5 transition-colors items-center group"
            >
              <div className="col-span-2 flex items-center gap-3">
                <TokenIcon symbol={token.symbol} />
                <div>
                  <div className="text-sm text-white group-hover:text-[#00ff66] transition-colors">
                    {token.symbol}
                  </div>
                  <div className="text-[10px] text-[#888888]">
                    {token.name}
                  </div>
                </div>
              </div>
              <div className="text-right font-mono text-sm">
                {formatPrice(price)}
              </div>
              <div className="text-right flex items-center justify-end gap-1.5">
                <StatusDot open={marketOpen} />
                <span
                  className={`text-xs ${
                    marketOpen ? "text-[#00ff66]" : "text-[#ff3333]"
                  }`}
                >
                  {marketOpen ? "OPEN" : "CLOSED"}
                </span>
              </div>
              <div className="text-right font-mono text-sm">
                {risk ? formatBps(risk[0]) : "—"}
              </div>
              <div className="text-right font-mono text-sm">
                {risk ? formatBps(risk[1]) : "—"}
              </div>
              <div className="text-right font-mono text-sm text-[#ff4e00]">
                {risk ? formatBps(risk[2]) : "—"}
              </div>
              <div className="text-right">
                {risk?.[4] !== false ? (
                  <span className="text-[10px] tracking-widest px-2 py-0.5 border border-[#00ff66]/30 text-[#00ff66]">
                    ACTIVE
                  </span>
                ) : (
                  <span className="text-[10px] tracking-widest px-2 py-0.5 border border-[#ff3333]/30 text-[#ff3333]">
                    INACTIVE
                  </span>
                )}
              </div>
            </div>
          )
        })}

        {/* WETH row */}
        {(() => {
          const wethPrice = prices.data?.[wethIdx]?.result ?? 0n
          const wethMarket = markets.data?.[wethIdx]?.result ?? false
          const wethRisk = riskParams.data?.[wethIdx]?.result as [number, number, number, number, boolean] | undefined

          return (
            <div className="grid grid-cols-8 gap-3 p-4 border-b border-white/5 hover:bg-white/5 transition-colors items-center group">
              <div className="col-span-2 flex items-center gap-3">
                <div className="w-8 h-8 rounded-full bg-white/10 flex items-center justify-center text-xs font-bold group-hover:bg-white group-hover:text-black transition-colors">
                  W
                </div>
                <div>
                  <div className="text-sm text-white group-hover:text-[#00ff66] transition-colors">
                    WETH
                  </div>
                  <div className="text-[10px] text-[#888888]">
                    Borrow Asset
                  </div>
                </div>
              </div>
              <div className="text-right font-mono text-sm">
                {formatPrice(wethPrice)}
              </div>
              <div className="text-right flex items-center justify-end gap-1.5">
                <StatusDot open={wethMarket} />
                <span className={`text-xs ${wethMarket ? "text-[#00ff66]" : "text-[#ff3333]"}`}>
                  {wethMarket ? "OPEN" : "CLOSED"}
                </span>
              </div>
              <div className="text-right font-mono text-sm">
                {wethRisk ? formatBps(wethRisk[0]) : "—"}
              </div>
              <div className="text-right font-mono text-sm">
                {wethRisk ? formatBps(wethRisk[1]) : "—"}
              </div>
              <div className="text-right font-mono text-sm text-[#ff4e00]">
                {wethRisk ? formatBps(wethRisk[2]) : "—"}
              </div>
              <div className="text-right">
                <span className="text-[10px] tracking-widest px-2 py-0.5 border border-[#00ff66]/30 text-[#00ff66]">
                  ACTIVE
                </span>
              </div>
            </div>
          )
        })()}
      </Card>
    </div>
  )
}
