import { useState } from "react"
import { Card } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { TxStatus } from "@/components/tx-status"
import { useAccount } from "wagmi"
import type { Address } from "viem"
import { TOKENS, LENDING_POOL, TOKEN_ADDRESSES } from "@/config/contracts"
import { useUserPosition, useTokenPrices, useTokenBalances, useAllowance } from "@/hooks/useProtocol"
import { useApprove, useBorrow, useRepay } from "@/hooks/useProtocolActions"
import { formatTokenAmount, formatPrice, formatHealthFactor, tokenAmountToNumber, priceToNumber, parseTokenAmount } from "@/lib/format"

type Tab = "borrow" | "repay"

export function BorrowView() {
  const [tab, setTab] = useState<Tab>("borrow")
  const [amount, setAmount] = useState("")

  const { address, isConnected } = useAccount()
  const position = useUserPosition(address)
  const prices = useTokenPrices()
  const balances = useTokenBalances(address)

  const wethAddr = TOKEN_ADDRESSES.WETH as Address
  const allowance = useAllowance(wethAddr, address, LENDING_POOL)
  const approveTx = useApprove()
  const borrowTx = useBorrow()
  const repayTx = useRepay()

  const wethIdx = TOKENS.findIndex((t) => t.symbol === "WETH")
  const wethPrice = prices.data?.[wethIdx]?.result ?? 0n
  const wethBalance = balances.data?.[wethIdx]?.result ?? 0n

  const debtRaw = position.debt.data ?? 0n
  const maxBorrowRaw = position.maxBorrow.data ?? 0n

  const maxAmount = tab === "borrow" ? maxBorrowRaw : debtRaw
  const parsedAmount = parseTokenAmount(amount || "0")

  const currentAllowance = allowance.data ?? 0n
  const needsApproval = tab === "repay" && parsedAmount > 0n && currentAllowance < parsedAmount

  const debtNum = tokenAmountToNumber(debtRaw)
  const projectedDebt = amount
    ? tab === "borrow"
      ? debtNum + parseFloat(amount)
      : Math.max(0, debtNum - parseFloat(amount))
    : debtNum

  if (!isConnected) {
    return (
      <div className="w-full flex items-center justify-center pt-32">
        <Card className="p-8 text-center">
          <div className="text-[10px] text-[#888888] tracking-widest uppercase mb-4">
            // WALLET NOT CONNECTED
          </div>
          <p className="text-sm text-[#888888]">Connect your wallet to borrow.</p>
        </Card>
      </div>
    )
  }

  const activeTx = approveTx.hash ? approveTx : borrowTx.hash ? borrowTx : repayTx

  return (
    <div className="w-full h-full flex flex-col pt-8 relative z-20 max-w-3xl mx-auto overflow-y-auto pb-16">
      <div className="mb-8">
        <h2 className="text-3xl font-sans font-medium tracking-tight mb-2">
          Borrow
        </h2>
        <div className="text-[10px] text-[#888888] tracking-widest uppercase">
          // BORROW & REPAY WETH
        </div>
      </div>

      {/* Tab Toggle */}
      <div className="flex gap-0 mb-8">
        <button
          onClick={() => {
            setTab("borrow")
            setAmount("")
          }}
          className={`px-6 py-2.5 text-xs uppercase tracking-widest border border-white/20 transition-colors ${
            tab === "borrow"
              ? "bg-white/10 text-white"
              : "text-[#888888] hover:text-white"
          }`}
        >
          Borrow
        </button>
        <button
          onClick={() => {
            setTab("repay")
            setAmount("")
          }}
          className={`px-6 py-2.5 text-xs uppercase tracking-widest border border-white/20 border-l-0 transition-colors ${
            tab === "repay"
              ? "bg-white/10 text-white"
              : "text-[#888888] hover:text-white"
          }`}
        >
          Repay
        </button>
      </div>

      <div className="grid grid-cols-5 gap-6">
        {/* Form */}
        <Card className="col-span-3 p-6">
          <div className="text-[10px] text-[#888888] tracking-widest uppercase mb-4">
            // {tab === "borrow" ? "BORROW WETH" : "REPAY WETH"}
          </div>

          {/* Amount Input */}
          <div className="mb-5">
            <label className="text-[10px] text-[#888888] tracking-widest uppercase block mb-2">
              Amount (WETH)
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
                {tab === "repay" ? "REPAY ALL" : "MAX"}
              </button>
            </div>
            <div className="text-[10px] text-[#888888] mt-1.5">
              {tab === "borrow"
                ? `Max borrowable: ${formatTokenAmount(maxBorrowRaw)} WETH`
                : `Outstanding debt: ${formatTokenAmount(debtRaw)} WETH`}
            </div>
          </div>

          {/* Info rows */}
          <div className="flex justify-between text-xs text-[#888888] mb-2 py-2 border-t border-white/5">
            <span>WETH Price</span>
            <span className="text-white font-mono">
              {formatPrice(wethPrice)}
            </span>
          </div>
          <div className="flex justify-between text-xs text-[#888888] mb-2">
            <span>Value</span>
            <span className="text-white font-mono">
              ${amount ? (parseFloat(amount) * priceToNumber(wethPrice)).toFixed(2) : "0.00"}
            </span>
          </div>
          {tab === "repay" && (
            <div className="flex justify-between text-xs text-[#888888] mb-2">
              <span>Wallet WETH</span>
              <span className="text-white font-mono">
                {formatTokenAmount(wethBalance)}
              </span>
            </div>
          )}
          <div className="flex justify-between text-xs text-[#888888] mb-6">
            <span>Projected Debt</span>
            <span className="font-mono text-[#ff4e00]">
              {projectedDebt.toFixed(4)} WETH
            </span>
          </div>

          {/* Action Buttons */}
          {tab === "repay" ? (
            <div className="flex gap-3">
              {needsApproval ? (
                <Button
                  className="flex-1"
                  variant="secondary"
                  onClick={() => approveTx.approve(wethAddr, LENDING_POOL, parsedAmount)}
                  disabled={approveTx.isPending || approveTx.isConfirming}
                >
                  {approveTx.isPending ? "Approving..." : "Approve WETH"}
                </Button>
              ) : (
                <Button
                  className="flex-1"
                  onClick={() => repayTx.repay(parsedAmount)}
                  disabled={parsedAmount === 0n || repayTx.isPending || repayTx.isConfirming}
                >
                  {repayTx.isPending ? "Repaying..." : "Repay"}
                </Button>
              )}
            </div>
          ) : (
            <Button
              className="w-full"
              onClick={() => borrowTx.borrow(parsedAmount)}
              disabled={parsedAmount === 0n || borrowTx.isPending || borrowTx.isConfirming}
            >
              {borrowTx.isPending ? "Borrowing..." : "Borrow WETH"}
            </Button>
          )}

          {tab === "borrow" && (
            <div className="mt-3 text-[10px] text-[#888888] tracking-widest">
              ALL DEPOSITED ASSET MARKETS MUST BE OPEN TO BORROW
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

        {/* Position Sidebar */}
        <Card className="col-span-2 p-5 h-fit">
          <div className="text-[10px] text-[#888888] tracking-widest uppercase mb-4">
            // POSITION OVERVIEW
          </div>

          <div className="space-y-3">
            <div className="flex justify-between text-xs">
              <span className="text-[#888888]">Health Factor</span>
              <span className="font-mono text-[#00ff66]">
                {formatHealthFactor(position.healthFactor.data ?? 0n)}
              </span>
            </div>
            <div className="flex justify-between text-xs">
              <span className="text-[#888888]">Current Debt</span>
              <span className="font-mono text-[#ff4e00]">
                {formatTokenAmount(debtRaw)} WETH
              </span>
            </div>
            <div className="flex justify-between text-xs">
              <span className="text-[#888888]">Max Borrow</span>
              <span className="font-mono">{formatTokenAmount(maxBorrowRaw)} WETH</span>
            </div>

            <div className="h-[1px] bg-white/10 my-3" />

            <div className="text-[10px] text-[#888888] tracking-widest uppercase mb-2">
              COLLATERAL ASSETS
            </div>
            {TOKENS.filter((_, i) => {
              const col = position.collaterals.data?.[i]?.result
              return col && col > 0n
            }).map((t, _origIdx) => {
              const idx = TOKENS.findIndex((tok) => tok.symbol === t.symbol)
              const col = position.collaterals.data?.[idx]?.result ?? 0n
              const p = prices.data?.[idx]?.result ?? 0n
              return (
                <div key={t.symbol} className="flex justify-between text-xs">
                  <span className="text-[#888888]">{t.symbol}</span>
                  <span className="font-mono">
                    {formatTokenAmount(col)}{" "}
                    <span className="text-[#555]">
                      (${(tokenAmountToNumber(col) * priceToNumber(p)).toFixed(0)})
                    </span>
                  </span>
                </div>
              )
            })}
          </div>
        </Card>
      </div>
    </div>
  )
}
