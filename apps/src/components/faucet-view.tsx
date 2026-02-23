import { Card } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { TokenIcon } from "@/components/token-icon"
import { TxStatus } from "@/components/tx-status"
import { useAccount } from "wagmi"
import { TOKENS, DEFAULT_PRICES } from "@/config/contracts"
import { useTokenBalances, useTokenPrices } from "@/hooks/useProtocol"
import { useRefreshPrices, useSetMarketStatus } from "@/hooks/useProtocolActions"
import { formatTokenAmount, tokenAmountToNumber, priceToNumber } from "@/lib/format"
import type { Address } from "viem"

export function FaucetView() {
  const { address, isConnected } = useAccount()
  const balances = useTokenBalances(address)
  const prices = useTokenPrices()
  const refreshPrices = useRefreshPrices()
  const setMarketStatus = useSetMarketStatus()

  const handleOpenAllMarkets = () => {
    // Open markets one at a time — start with first token
    openMarketSequentially(0)
  }

  const openMarketSequentially = (index: number) => {
    if (index >= TOKENS.length) return
    setMarketStatus.setMarketStatus(TOKENS[index].address as Address, true)
  }

  return (
    <div className="w-full h-full flex flex-col pt-8 relative z-20 max-w-3xl mx-auto overflow-y-auto pb-16">
      <div className="mb-8">
        <h2 className="text-3xl font-sans font-medium tracking-tight mb-2">
          Faucet
        </h2>
        <div className="text-[10px] text-[#888888] tracking-widest uppercase">
          // TESTNET TOKEN FAUCET
        </div>
      </div>

      {/* Oracle Admin Panel */}
      <Card className="p-6 mb-6">
        <div className="text-[10px] text-[#888888] tracking-widest uppercase mb-4">
          // ORACLE ADMIN
        </div>
        <p className="text-sm text-[#888888] mb-4 leading-relaxed">
          Oracle prices expire after 1 hour. Refresh them to keep the protocol
          operational. This sets prices for all supported assets.
        </p>

        <div className="grid grid-cols-2 gap-3 mb-4">
          {TOKENS.map((t) => (
            <div
              key={t.symbol}
              className="flex items-center justify-between border border-white/10 bg-black/30 px-3 py-2"
            >
              <div className="flex items-center gap-2">
                <TokenIcon symbol={t.symbol} className="w-5 h-5" />
                <span className="text-xs font-mono">{t.symbol}</span>
              </div>
              <span className="text-xs font-mono text-[#00ff66]">
                ${(Number(DEFAULT_PRICES[t.symbol]) / 1e8).toLocaleString("en-US", { minimumFractionDigits: 2 })}
              </span>
            </div>
          ))}
        </div>

        <div className="flex gap-4">
          <Button
            onClick={() => refreshPrices.refreshPrices()}
            disabled={refreshPrices.isPending || refreshPrices.isConfirming}
          >
            {refreshPrices.isPending || refreshPrices.isConfirming
              ? "Refreshing..."
              : "Refresh All Prices"}
          </Button>
          <Button
            variant="secondary"
            onClick={handleOpenAllMarkets}
            disabled={setMarketStatus.isPending || setMarketStatus.isConfirming}
          >
            {setMarketStatus.isPending || setMarketStatus.isConfirming
              ? "Opening..."
              : "Open All Markets"}
          </Button>
        </div>
        <TxStatus
          isPending={refreshPrices.isPending}
          isConfirming={refreshPrices.isConfirming}
          isSuccess={refreshPrices.isSuccess}
          error={refreshPrices.error}
          hash={refreshPrices.hash}
        />
        {setMarketStatus.hash && (
          <TxStatus
            isPending={setMarketStatus.isPending}
            isConfirming={setMarketStatus.isConfirming}
            isSuccess={setMarketStatus.isSuccess}
            error={setMarketStatus.error}
            hash={setMarketStatus.hash}
          />
        )}
      </Card>

      <Card className="p-6 mb-6">
        <div className="text-[10px] text-[#888888] tracking-widest uppercase mb-4">
          // ROBINHOOD CHAIN TESTNET FAUCET
        </div>
        <p className="text-sm text-[#888888] mb-4 leading-relaxed">
          Get test tokens for the Robinhood Chain Testnet. The faucet provides 5
          of each equity token and 0.01 ETH per 24 hours.
        </p>

        <div className="flex gap-4 mb-6">
          <a
            href="https://faucet.testnet.chain.robinhood.com/"
            target="_blank"
            rel="noopener noreferrer"
          >
            <Button>Open Faucet</Button>
          </a>
          <a
            href="https://explorer.testnet.chain.robinhood.com"
            target="_blank"
            rel="noopener noreferrer"
          >
            <Button variant="secondary">Explorer</Button>
          </a>
        </div>

        <div className="border border-white/10 bg-black/30 p-4 text-xs font-mono text-[#888888] space-y-1">
          <div>Chain ID: 46630</div>
          <div>RPC: https://rpc.testnet.chain.robinhood.com</div>
          <div>Currency: ETH</div>
        </div>
      </Card>

      {/* Current Balances */}
      <Card className="p-6">
        <div className="text-[10px] text-[#888888] tracking-widest uppercase mb-4">
          // YOUR TOKEN BALANCES
        </div>

        {!isConnected ? (
          <div className="text-xs text-[#888888]">Connect wallet to view balances</div>
        ) : (
          <div className="space-y-0">
            {TOKENS.map((token, i) => {
              const bal = balances.data?.[i]?.result ?? 0n
              const price = prices.data?.[i]?.result ?? 0n
              const valueUsd = tokenAmountToNumber(bal) * priceToNumber(price)

              return (
                <div
                  key={token.symbol}
                  className="flex items-center justify-between py-3 border-b border-white/5 last:border-0"
                >
                  <div className="flex items-center gap-3">
                    <TokenIcon symbol={token.symbol} className="w-7 h-7" />
                    <div>
                      <div className="text-sm">{token.symbol}</div>
                      <div className="text-[10px] text-[#888888]">{token.name}</div>
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="font-mono text-sm">{formatTokenAmount(bal)}</div>
                    <div className="text-[10px] text-[#888888] font-mono">
                      ${valueUsd.toFixed(2)}
                    </div>
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </Card>
    </div>
  )
}
