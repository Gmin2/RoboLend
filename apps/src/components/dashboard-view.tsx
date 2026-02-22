import { useNavigate } from "react-router-dom"
import { TokenIcon } from "@/components/token-icon"
import { Card } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { useAccount } from "wagmi"
import { TOKENS, EQUITY_TOKENS } from "@/config/contracts"
import { useUserPosition, useTokenPrices, useMarketStatus, useTokenBalances, useRiskParams } from "@/hooks/useProtocol"
import { formatTokenAmount, formatPrice, formatHealthFactor, healthFactorNumber, formatBps, shortenAddress, tokenAmountToNumber, priceToNumber } from "@/lib/format"

function StatusDot({ open }: { open: boolean }) {
  return (
    <span
      className={`inline-block w-1.5 h-1.5 rounded-full ${
        open ? "bg-[#00ff66]" : "bg-[#ff3333]"
      }`}
    />
  )
}

function HealthBadge({ value }: { value: number }) {
  const color =
    value > 1.5
      ? "text-[#00ff66] border-[#00ff66]/30"
      : value >= 1.0
        ? "text-[#ff4e00] border-[#ff4e00]/30"
        : "text-[#ff3333] border-[#ff3333]/30"
  const label = value > 1.5 ? "SAFE" : value >= 1.0 ? "WARNING" : "DANGER"
  const display = value === Infinity ? "∞" : value.toFixed(2)

  return (
    <span
      className={`text-[10px] tracking-widest px-2 py-0.5 border ${color}`}
    >
      {label} — {display}
    </span>
  )
}

export function DashboardView() {
  const navigate = useNavigate()
  const { address, isConnected } = useAccount()
  const position = useUserPosition(address)
  const prices = useTokenPrices()
  const markets = useMarketStatus()
  const balances = useTokenBalances(address)
  const riskParams = useRiskParams()

  if (!isConnected) {
    return (
      <div className="w-full flex items-center justify-center pt-32">
        <Card className="p-8 text-center">
          <div className="text-[10px] text-[#888888] tracking-widest uppercase mb-4">
            // WALLET NOT CONNECTED
          </div>
          <p className="text-sm text-[#888888]">Connect your wallet to view your dashboard.</p>
        </Card>
      </div>
    )
  }

  const isLoading = position.isLoading || prices.isLoading || markets.isLoading || balances.isLoading

  if (isLoading) {
    return (
      <div className="w-full flex items-center justify-center pt-32">
        <div className="text-xs text-[#888888] tracking-widest uppercase animate-pulse">
          LOADING PROTOCOL DATA...
        </div>
      </div>
    )
  }

  const hfRaw = position.healthFactor.data ?? 0n
  const hfNum = healthFactorNumber(hfRaw)
  const debtRaw = position.debt.data ?? 0n
  const maxBorrowRaw = position.maxBorrow.data ?? 0n

  // Find WETH index and get its balance + price
  const wethIdx = TOKENS.findIndex((t) => t.symbol === "WETH")
  const wethBalance = balances.data?.[wethIdx]?.result ?? 0n
  const wethPrice = prices.data?.[wethIdx]?.result ?? 0n

  return (
    <div className="w-full h-full flex flex-col pt-8 relative z-20 max-w-6xl mx-auto overflow-y-auto pb-16">
      {/* Header */}
      <div className="flex items-center justify-between mb-8">
        <div>
          <h2 className="text-3xl font-sans font-medium tracking-tight mb-2">
            Dashboard
          </h2>
          <div className="text-[10px] text-[#888888] tracking-widest uppercase">
            // PORTFOLIO OVERVIEW
          </div>
        </div>
        <div className="flex items-center gap-3 text-xs text-[#888888]">
          <span className="font-mono">{shortenAddress(address!)}</span>
        </div>
      </div>

      {/* Position Summary Cards */}
      <div className="grid grid-cols-4 gap-4 mb-8">
        <Card className="p-4">
          <div className="text-[10px] text-[#888888] tracking-widest uppercase mb-2">
            HEALTH FACTOR
          </div>
          <div className="text-2xl font-mono text-[#00ff66] mb-2">
            {formatHealthFactor(hfRaw)}
          </div>
          <HealthBadge value={hfNum} />
        </Card>

        <Card className="p-4">
          <div className="text-[10px] text-[#888888] tracking-widest uppercase mb-2">
            TOTAL DEBT
          </div>
          <div className="text-2xl font-mono text-[#ff4e00]">
            {formatTokenAmount(debtRaw)} WETH
          </div>
          <div className="text-[10px] text-[#888888] mt-2">
            ${(tokenAmountToNumber(debtRaw) * priceToNumber(wethPrice)).toFixed(2)}
          </div>
        </Card>

        <Card className="p-4">
          <div className="text-[10px] text-[#888888] tracking-widest uppercase mb-2">
            MAX BORROW
          </div>
          <div className="text-2xl font-mono">
            {formatTokenAmount(maxBorrowRaw)} WETH
          </div>
          <div className="text-[10px] text-[#888888] mt-2">Available capacity</div>
        </Card>

        <Card className="p-4">
          <div className="text-[10px] text-[#888888] tracking-widest uppercase mb-2">
            WETH BALANCE
          </div>
          <div className="text-2xl font-mono">
            {formatTokenAmount(wethBalance)}
          </div>
          <div className="text-[10px] text-[#888888] mt-2">In wallet</div>
        </Card>
      </div>

      {/* Quick Actions */}
      <div className="flex gap-3 mb-8">
        <Button onClick={() => navigate("/supply")}>Deposit</Button>
        <Button onClick={() => navigate("/borrow")}>Borrow</Button>
        <Button variant="secondary" onClick={() => navigate("/supply")}>
          Withdraw
        </Button>
        <Button variant="secondary" onClick={() => navigate("/borrow")}>
          Repay
        </Button>
      </div>

      {/* Collateral Positions Table */}
      <div className="mb-6">
        <div className="text-[10px] text-[#888888] tracking-widest uppercase mb-4">
          // YOUR COLLATERAL POSITIONS
        </div>
        <Card>
          <div className="grid grid-cols-7 gap-4 p-4 border-b border-white/10 text-[10px] text-[#888888] tracking-widest uppercase">
            <div className="col-span-2">Asset</div>
            <div className="text-right">Price</div>
            <div className="text-right">Market</div>
            <div className="text-right">Wallet</div>
            <div className="text-right">Deposited</div>
            <div className="text-right">LTV</div>
          </div>

          {EQUITY_TOKENS.map((token, i) => {
            const price = prices.data?.[i]?.result ?? 0n
            const marketOpen = markets.data?.[i]?.result ?? false
            const walletBal = balances.data?.[i]?.result ?? 0n
            const collateral = position.collaterals.data?.[i]?.result ?? 0n
            const risk = riskParams.data?.[i]?.result as [number, number, number, number, boolean] | undefined
            const ltv = risk ? risk[0] : 0

            return (
              <div
                key={token.symbol}
                className="grid grid-cols-7 gap-4 p-4 border-b border-white/5 hover:bg-white/5 transition-colors items-center group"
              >
                <div className="col-span-2 flex items-center gap-3">
                  <TokenIcon symbol={token.symbol} />
                  <div>
                    <div className="text-sm text-white">{token.symbol}</div>
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
                  {formatTokenAmount(walletBal)}
                </div>
                <div className="text-right font-mono text-sm">
                  {collateral > 0n ? (
                    <span className="text-[#00ff66]">{formatTokenAmount(collateral)}</span>
                  ) : (
                    <span className="text-[#888888]">—</span>
                  )}
                </div>
                <div className="text-right font-mono text-sm text-[#888888]">
                  {ltv ? formatBps(ltv) : "—"}
                </div>
              </div>
            )
          })}
        </Card>
      </div>
    </div>
  )
}
