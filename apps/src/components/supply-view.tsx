import { useState } from "react"
import { Card } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { TxStatus } from "@/components/tx-status"
import { OracleBanner } from "@/components/oracle-banner"
import { useAccount } from "wagmi"
import type { Address } from "viem"
import { EQUITY_TOKENS, LENDING_POOL } from "@/config/contracts"
import { useTokenBalances, useUserPosition, useRiskParams, useTokenPrices, useAllowance } from "@/hooks/useProtocol"
import { useApprove, useDeposit, useWithdraw } from "@/hooks/useProtocolActions"
import { formatTokenAmount, formatPrice, formatHealthFactor, formatBps, tokenAmountToNumber, priceToNumber, parseTokenAmount } from "@/lib/format"

type Tab = "deposit" | "withdraw"

export function SupplyView() {
  const [tab, setTab] = useState<Tab>("deposit")
  const [selectedIdx, setSelectedIdx] = useState(0)
  const [amount, setAmount] = useState("")

  const { address, isConnected } = useAccount()
  const balances = useTokenBalances(address)
  const position = useUserPosition(address)
  const riskParams = useRiskParams()
  const prices = useTokenPrices()

  const token = EQUITY_TOKENS[selectedIdx]
  const tokenAddr = token.address as Address

  const allowance = useAllowance(tokenAddr, address, LENDING_POOL)
  const approveTx = useApprove()
  const depositTx = useDeposit()
  const withdrawTx = useWithdraw()

  const walletBal = balances.data?.[selectedIdx]?.result ?? 0n
  const collateral = position.collaterals.data?.[selectedIdx]?.result ?? 0n
  const risk = riskParams.data?.[selectedIdx]?.result as [number, number, number, number, boolean] | undefined
  const price = prices.data?.[selectedIdx]?.result ?? 0n

  const maxAmount = tab === "deposit" ? walletBal : collateral
  const currentAllowance = allowance.data ?? 0n
  const parsedAmount = parseTokenAmount(amount || "0")
  const needsApproval = tab === "deposit" && parsedAmount > 0n && currentAllowance < parsedAmount

  if (!isConnected) {
    return (
      <div className="w-full flex items-center justify-center pt-32">
        <Card className="p-8 text-center">
          <div className="text-[10px] text-[#888888] tracking-widest uppercase mb-4">
            // WALLET NOT CONNECTED
          </div>
          <p className="text-sm text-[#888888]">Connect your wallet to supply collateral.</p>
        </Card>
      </div>
    )
  }

  // Find active tx for status display
  const activeTx = approveTx.hash ? approveTx : depositTx.hash ? depositTx : withdrawTx

  return (
    <div className="w-full h-full flex flex-col pt-8 relative z-20 max-w-3xl mx-auto overflow-y-auto pb-16">
      <div className="mb-8">
        <h2 className="text-3xl font-sans font-medium tracking-tight mb-2">
          Supply
        </h2>
        <div className="text-[10px] text-[#888888] tracking-widest uppercase">
          // DEPOSIT & WITHDRAW COLLATERAL
        </div>
      </div>

      <OracleBanner />

      {/* Tab Toggle */}
      <div className="flex gap-0 mb-8">
        <button
          onClick={() => setTab("deposit")}
          className={`px-6 py-2.5 text-xs uppercase tracking-widest border border-white/20 transition-colors ${
            tab === "deposit"
              ? "bg-white/10 text-white"
              : "text-[#888888] hover:text-white"
          }`}
        >
          Deposit
        </button>
        <button
          onClick={() => setTab("withdraw")}
          className={`px-6 py-2.5 text-xs uppercase tracking-widest border border-white/20 border-l-0 transition-colors ${
            tab === "withdraw"
              ? "bg-white/10 text-white"
              : "text-[#888888] hover:text-white"
          }`}
        >
          Withdraw
        </button>
      </div>

      <div className="grid grid-cols-5 gap-6">
        {/* Form */}
        <Card className="col-span-3 p-6">
          <div className="text-[10px] text-[#888888] tracking-widest uppercase mb-4">
            // {tab === "deposit" ? "DEPOSIT COLLATERAL" : "WITHDRAW COLLATERAL"}
          </div>

          {/* Asset Selector */}
          <div className="mb-5">
            <label className="text-[10px] text-[#888888] tracking-widest uppercase block mb-2">
              Asset
            </label>
            <div className="flex gap-2">
              {EQUITY_TOKENS.map((t, i) => (
                <button
                  key={t.symbol}
                  onClick={() => {
                    setSelectedIdx(i)
                    setAmount("")
                  }}
                  className={`px-3 py-1.5 text-xs font-mono border transition-colors ${
                    selectedIdx === i
                      ? "border-white/40 bg-white/10 text-white"
                      : "border-white/10 text-[#888888] hover:text-white hover:border-white/20"
                  }`}
                >
                  {t.symbol}
                </button>
              ))}
            </div>
          </div>

          {/* Amount Input */}
          <div className="mb-5">
            <label className="text-[10px] text-[#888888] tracking-widest uppercase block mb-2">
              Amount
            </label>
            <div className="flex border border-white/20 bg-black/40">
              <input
                type="number"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="0.00"
                className="flex-1 bg-transparent px-4 py-3 text-sm font-mono text-white outline-none placeholder:text-[#555]"
              />
              <button
                onClick={() => setAmount(tokenAmountToNumber(maxAmount).toString())}
                className="px-4 text-[10px] tracking-widest text-[#00ff66] hover:text-white transition-colors border-l border-white/10"
              >
                MAX
              </button>
            </div>
            <div className="text-[10px] text-[#888888] mt-1.5">
              Available: {formatTokenAmount(maxAmount)} {token.symbol}
            </div>
          </div>

          {/* Price Info */}
          <div className="flex justify-between text-xs text-[#888888] mb-2 py-2 border-t border-white/5">
            <span>Oracle Price</span>
            <span className="text-white font-mono">
              {formatPrice(price)}
            </span>
          </div>
          <div className="flex justify-between text-xs text-[#888888] mb-2">
            <span>Value</span>
            <span className="text-white font-mono">
              ${amount ? (parseFloat(amount) * priceToNumber(price)).toFixed(2) : "0.00"}
            </span>
          </div>
          <div className="flex justify-between text-xs text-[#888888] mb-6">
            <span>Market Status</span>
            <span className={prices.data?.[selectedIdx]?.result ? "text-[#00ff66]" : "text-[#888888]"}>
              {prices.data?.[selectedIdx]?.result ? "OPEN" : "—"}
            </span>
          </div>

          {/* Action Buttons */}
          {tab === "deposit" ? (
            <div className="flex gap-3">
              {needsApproval ? (
                <Button
                  className="flex-1"
                  variant="secondary"
                  onClick={() => approveTx.approve(tokenAddr, LENDING_POOL, parsedAmount)}
                  disabled={approveTx.isPending || approveTx.isConfirming}
                >
                  {approveTx.isPending ? "Approving..." : `Approve ${token.symbol}`}
                </Button>
              ) : (
                <Button
                  className="flex-1"
                  onClick={() => depositTx.deposit(tokenAddr, parsedAmount)}
                  disabled={parsedAmount === 0n || depositTx.isPending || depositTx.isConfirming}
                >
                  {depositTx.isPending ? "Depositing..." : "Deposit"}
                </Button>
              )}
            </div>
          ) : (
            <Button
              className="w-full"
              onClick={() => withdrawTx.withdraw(tokenAddr, parsedAmount)}
              disabled={parsedAmount === 0n || withdrawTx.isPending || withdrawTx.isConfirming}
            >
              {withdrawTx.isPending ? "Withdrawing..." : "Withdraw"}
            </Button>
          )}

          {tab === "withdraw" && collateral > 0n && (
            <div className="mt-3 text-[10px] text-[#ff4e00] tracking-widest">
              WARNING: WITHDRAWING MAY REDUCE HEALTH FACTOR
            </div>
          )}

          <TxStatus
            isPending={activeTx.isPending}
            isConfirming={activeTx.isConfirming}
            isSuccess={activeTx.isSuccess}
            error={activeTx.error}
            hash={activeTx.hash}
          />
        </Card>

        {/* Risk Parameters Sidebar */}
        <Card className="col-span-2 p-5 h-fit">
          <div className="text-[10px] text-[#888888] tracking-widest uppercase mb-4">
            // RISK PARAMETERS
          </div>

          <div className="space-y-3">
            <div className="flex justify-between text-xs">
              <span className="text-[#888888]">LTV</span>
              <span className="font-mono">{risk ? formatBps(risk[0]) : "—"}</span>
            </div>
            <div className="flex justify-between text-xs">
              <span className="text-[#888888]">Liq. Threshold</span>
              <span className="font-mono">{risk ? formatBps(risk[1]) : "—"}</span>
            </div>
            <div className="flex justify-between text-xs">
              <span className="text-[#888888]">Liq. Bonus</span>
              <span className="font-mono">{risk ? formatBps(risk[2]) : "—"}</span>
            </div>

            <div className="h-[1px] bg-white/10 my-3" />

            <div className="flex justify-between text-xs">
              <span className="text-[#888888]">Health Factor</span>
              <span className="font-mono text-[#00ff66]">
                {formatHealthFactor(position.healthFactor.data ?? 0n)}
              </span>
            </div>
            <div className="flex justify-between text-xs">
              <span className="text-[#888888]">Current Debt</span>
              <span className="font-mono">
                {formatTokenAmount(position.debt.data ?? 0n)} WETH
              </span>
            </div>
            <div className="flex justify-between text-xs">
              <span className="text-[#888888]">Deposited</span>
              <span className="font-mono">{formatTokenAmount(collateral)} {token.symbol}</span>
            </div>
          </div>
        </Card>
      </div>
    </div>
  )
}
