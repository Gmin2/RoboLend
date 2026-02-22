import { useState } from "react"
import { Card } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { TxStatus } from "@/components/tx-status"
import { useAccount, useReadContract, useReadContracts } from "wagmi"
import type { Address } from "viem"
import {
  LENDING_POOL,
  LIQUIDATION_ENGINE,
  TOKEN_ADDRESSES,
  TOKENS,
  EQUITY_TOKENS,
  lendingPoolAbi,
  liquidationEngineAbi,
} from "@/config/contracts"
import { useAllowance, useTokenPrices } from "@/hooks/useProtocol"
import { useApprove, useLiquidate } from "@/hooks/useProtocolActions"
import {
  formatTokenAmount,
  formatHealthFactor,
  healthFactorNumber,
  tokenAmountToNumber,
  priceToNumber,
  parseTokenAmount,
} from "@/lib/format"

export function LiquidateView() {
  const [borrowerAddr, setBorrowerAddr] = useState("")
  const [checked, setChecked] = useState(false)
  const [selectedCollateral, setSelectedCollateral] = useState("")
  const [debtAmount, setDebtAmount] = useState("")

  const { address, isConnected } = useAccount()
  const prices = useTokenPrices()
  const wethAddr = TOKEN_ADDRESSES.WETH as Address

  const borrowerAddress = checked && borrowerAddr ? (borrowerAddr as Address) : undefined

  // Read borrower's health factor
  const { data: borrowerHF } = useReadContract({
    address: LENDING_POOL,
    abi: lendingPoolAbi,
    functionName: "getHealthFactor",
    args: borrowerAddress ? [borrowerAddress] : undefined,
    query: { enabled: !!borrowerAddress },
  })

  // Read borrower's debt
  const { data: borrowerDebt } = useReadContract({
    address: LENDING_POOL,
    abi: lendingPoolAbi,
    functionName: "getUserDebt",
    args: borrowerAddress ? [borrowerAddress] : undefined,
    query: { enabled: !!borrowerAddress },
  })

  // Read borrower's collateral for each equity token using useReadContracts
  const borrowerCollaterals = useReadContracts({
    contracts: EQUITY_TOKENS.map((t) => ({
      address: LENDING_POOL,
      abi: lendingPoolAbi,
      functionName: "getUserCollateral" as const,
      args: borrowerAddress ? [borrowerAddress, t.address as Address] as const : undefined,
    })),
    query: { enabled: !!borrowerAddress },
  })

  // Derive collateral info from results
  const collateralResults = EQUITY_TOKENS
    .map((t, i) => {
      const amount = borrowerCollaterals.data?.[i]?.result
      return { symbol: t.symbol, address: t.address as Address, amount: amount ?? 0n }
    })
    .filter((c) => c.amount > 0n)

  const maxDebt = borrowerDebt ? borrowerDebt / 2n : 0n // 50% close factor
  const parsedDebt = parseTokenAmount(debtAmount || "0")
  const selectedCollateralAddr = collateralResults.find((c) => c.symbol === selectedCollateral)?.address

  // Profitability check
  const { data: profitability } = useReadContract({
    address: LIQUIDATION_ENGINE,
    abi: liquidationEngineAbi,
    functionName: "isLiquidationProfitable",
    args:
      borrowerAddress && selectedCollateralAddr && parsedDebt > 0n
        ? [borrowerAddress, selectedCollateralAddr, parsedDebt]
        : undefined,
    query: { enabled: !!borrowerAddress && !!selectedCollateralAddr && parsedDebt > 0n },
  })

  const allowance = useAllowance(wethAddr, address, LENDING_POOL)
  const approveTx = useApprove()
  const liquidateTx = useLiquidate()

  const currentAllowance = allowance.data ?? 0n
  const needsApproval = parsedDebt > 0n && currentAllowance < parsedDebt

  function handleCheck() {
    if (borrowerAddr.length > 5) {
      setChecked(true)
      setSelectedCollateral("")
      setDebtAmount("")
    }
  }

  const activeTx = approveTx.hash ? approveTx : liquidateTx

  return (
    <div className="w-full h-full flex flex-col pt-8 relative z-20 max-w-4xl mx-auto overflow-y-auto pb-16">
      <div className="mb-8">
        <h2 className="text-3xl font-sans font-medium tracking-tight mb-2">
          Liquidate
        </h2>
        <div className="text-[10px] text-[#888888] tracking-widest uppercase">
          // LIQUIDATE UNDERCOLLATERALIZED POSITIONS
        </div>
      </div>

      {/* Borrower Lookup */}
      <Card className="p-6 mb-6">
        <div className="text-[10px] text-[#888888] tracking-widest uppercase mb-4">
          // BORROWER LOOKUP
        </div>
        <div className="flex gap-3">
          <div className="flex flex-1 border border-white/20 bg-black/40">
            <input
              type="text"
              value={borrowerAddr}
              onChange={(e) => {
                setBorrowerAddr(e.target.value)
                setChecked(false)
              }}
              placeholder="0x... borrower address"
              className="flex-1 bg-transparent px-4 py-3 text-sm font-mono text-white outline-none placeholder:text-[#555]"
            />
          </div>
          <Button onClick={handleCheck}>Check</Button>
        </div>
      </Card>

      {checked && borrowerHF !== undefined && (
        <div className="grid grid-cols-5 gap-6">
          {/* Position Info */}
          <Card className="col-span-2 p-5">
            <div className="text-[10px] text-[#888888] tracking-widest uppercase mb-4">
              // BORROWER POSITION
            </div>

            <div className="space-y-3">
              <div className="flex justify-between text-xs">
                <span className="text-[#888888]">Health Factor</span>
                <span className={`font-mono ${healthFactorNumber(borrowerHF) < 1 ? "text-[#ff3333]" : "text-[#00ff66]"}`}>
                  {formatHealthFactor(borrowerHF)}
                </span>
              </div>
              <div className="flex justify-between text-xs items-center">
                <span className="text-[#888888]">Status</span>
                {healthFactorNumber(borrowerHF) < 1 ? (
                  <span className="text-[10px] tracking-widest px-2 py-0.5 border border-[#ff3333]/30 text-[#ff3333]">
                    LIQUIDATABLE
                  </span>
                ) : (
                  <span className="text-[10px] tracking-widest px-2 py-0.5 border border-[#00ff66]/30 text-[#00ff66]">
                    HEALTHY
                  </span>
                )}
              </div>
              <div className="flex justify-between text-xs">
                <span className="text-[#888888]">Total Debt</span>
                <span className="font-mono text-[#ff4e00]">
                  {formatTokenAmount(borrowerDebt ?? 0n)} WETH
                </span>
              </div>

              <div className="h-[1px] bg-white/10 my-3" />

              <div className="text-[10px] text-[#888888] tracking-widest uppercase mb-2">
                COLLATERAL
              </div>
              {collateralResults.map((c) => {
                const idx = TOKENS.findIndex((t) => t.symbol === c.symbol)
                const p = prices.data?.[idx]?.result ?? 0n
                return (
                  <div key={c.symbol} className="flex justify-between text-xs">
                    <span className="text-[#888888]">{c.symbol}</span>
                    <span className="font-mono">
                      {formatTokenAmount(c.amount)}{" "}
                      <span className="text-[#555]">
                        (${(tokenAmountToNumber(c.amount) * priceToNumber(p)).toLocaleString()})
                      </span>
                    </span>
                  </div>
                )
              })}
              {collateralResults.length === 0 && (
                <div className="text-xs text-[#888888]">No collateral found</div>
              )}
            </div>
          </Card>

          {/* Liquidation Form */}
          <Card className="col-span-3 p-6">
            <div className="text-[10px] text-[#888888] tracking-widest uppercase mb-4">
              // EXECUTE LIQUIDATION
            </div>

            {/* Collateral to seize */}
            <div className="mb-5">
              <label className="text-[10px] text-[#888888] tracking-widest uppercase block mb-2">
                Collateral to Seize
              </label>
              <div className="flex gap-2">
                {collateralResults.map((c) => (
                  <button
                    key={c.symbol}
                    onClick={() => setSelectedCollateral(c.symbol)}
                    className={`px-3 py-1.5 text-xs font-mono border transition-colors ${
                      selectedCollateral === c.symbol
                        ? "border-white/40 bg-white/10 text-white"
                        : "border-white/10 text-[#888888] hover:text-white hover:border-white/20"
                    }`}
                  >
                    {c.symbol}
                  </button>
                ))}
              </div>
            </div>

            {/* Debt Amount */}
            <div className="mb-5">
              <label className="text-[10px] text-[#888888] tracking-widest uppercase block mb-2">
                Debt to Repay (WETH)
              </label>
              <div className="flex border border-white/20 bg-black/40">
                <input
                  type="number"
                  value={debtAmount}
                  onChange={(e) => setDebtAmount(e.target.value)}
                  placeholder="0.00"
                  className="flex-1 bg-transparent px-4 py-3 text-sm font-mono text-white outline-none placeholder:text-[#555]"
                />
                <button
                  onClick={() => setDebtAmount(tokenAmountToNumber(maxDebt).toString())}
                  className="px-4 text-[10px] tracking-widest text-[#00ff66] hover:text-white transition-colors border-l border-white/10"
                >
                  MAX 50%
                </button>
              </div>
              <div className="text-[10px] text-[#888888] mt-1.5">
                Close factor: max 50% of debt ({formatTokenAmount(maxDebt)} WETH)
              </div>
            </div>

            {/* Profitability */}
            <div className="border border-white/10 bg-black/30 p-4 mb-6">
              <div className="text-[10px] text-[#00ff66] tracking-widest uppercase mb-3">
                PROFITABILITY CHECK
              </div>
              {profitability ? (
                <div className="space-y-2">
                  <div className="flex justify-between text-xs">
                    <span className="text-[#888888]">Profitable</span>
                    <span className={`font-mono ${profitability[0] ? "text-[#00ff66]" : "text-[#ff3333]"}`}>
                      {profitability[0] ? "YES" : "NO"}
                    </span>
                  </div>
                  <div className="flex justify-between text-xs">
                    <span className="text-[#888888]">Est. Profit</span>
                    <span className="font-mono">
                      {formatTokenAmount(profitability[1])} WETH
                    </span>
                  </div>
                  <div className="flex justify-between text-xs">
                    <span className="text-[#888888]">Bonus Value</span>
                    <span className="font-mono text-[#00ff66]">
                      {formatTokenAmount(profitability[3])}
                    </span>
                  </div>
                </div>
              ) : (
                <div className="text-xs text-[#888888]">
                  Select collateral and enter debt amount to check
                </div>
              )}
            </div>

            {isConnected && (
              <div className="flex gap-3">
                {needsApproval ? (
                  <Button
                    className="flex-1"
                    variant="secondary"
                    onClick={() => approveTx.approve(wethAddr, LENDING_POOL, parsedDebt)}
                    disabled={approveTx.isPending || approveTx.isConfirming}
                  >
                    {approveTx.isPending ? "Approving..." : "Approve WETH"}
                  </Button>
                ) : (
                  <Button
                    className="flex-1"
                    onClick={() => {
                      if (borrowerAddress && selectedCollateralAddr) {
                        liquidateTx.liquidate(borrowerAddress, selectedCollateralAddr, parsedDebt)
                      }
                    }}
                    disabled={
                      parsedDebt === 0n ||
                      !selectedCollateralAddr ||
                      liquidateTx.isPending ||
                      liquidateTx.isConfirming
                    }
                  >
                    {liquidateTx.isPending ? "Liquidating..." : "Liquidate"}
                  </Button>
                )}
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
        </div>
      )}
    </div>
  )
}
