import { Card } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { TokenIcon } from "@/components/token-icon"
import { useAccount } from "wagmi"
import { TOKENS } from "@/config/contracts"
import { useTokenBalances, useTokenPrices } from "@/hooks/useProtocol"
import { formatTokenAmount, tokenAmountToNumber, priceToNumber } from "@/lib/format"

export function FaucetView() {
  const { address, isConnected } = useAccount()
  const balances = useTokenBalances(address)
  const prices = useTokenPrices()

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
