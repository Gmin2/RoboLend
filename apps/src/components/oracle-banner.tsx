import { Button } from "@/components/ui/button"
import { TxStatus } from "@/components/tx-status"
import { useTokenPrices } from "@/hooks/useProtocol"
import { useRefreshPrices } from "@/hooks/useProtocolActions"

export function OracleBanner() {
  const prices = useTokenPrices()
  const refreshPrices = useRefreshPrices()

  // Check if any price is 0 or errored (= stale/unset)
  const allPricesLoaded = prices.data && prices.data.length > 0
  const hasStalePrice =
    allPricesLoaded &&
    prices.data!.some((p) => p.status === "failure" || p.result === 0n)

  if (!hasStalePrice) return null

  return (
    <div className="mb-6 border border-[#ff4e00]/40 bg-[#ff4e00]/5 p-4">
      <div className="flex items-center justify-between gap-4">
        <div>
          <div className="text-xs font-mono text-[#ff4e00] mb-1">
            ORACLE PRICES STALE
          </div>
          <div className="text-[10px] text-[#888888]">
            Prices expire after 1 hour. Refresh to enable borrowing, withdrawals, and accurate valuations.
          </div>
        </div>
        <Button
          onClick={() => refreshPrices.refreshPrices()}
          disabled={refreshPrices.isPending || refreshPrices.isConfirming}
          className="shrink-0"
        >
          {refreshPrices.isPending
            ? "Confirm in wallet..."
            : refreshPrices.isConfirming
              ? "Refreshing..."
              : "Refresh Prices"}
        </Button>
      </div>
      <TxStatus
        isPending={refreshPrices.isPending}
        isConfirming={refreshPrices.isConfirming}
        isSuccess={refreshPrices.isSuccess}
        error={refreshPrices.error}
        hash={refreshPrices.hash}
      />
    </div>
  )
}
