const EXPLORER = "https://explorer.testnet.chain.robinhood.com"

interface TxStatusProps {
  isPending: boolean
  isConfirming: boolean
  isSuccess: boolean
  error: Error | null
  hash?: `0x${string}`
}

export function TxStatus({ isPending, isConfirming, isSuccess, error, hash }: TxStatusProps) {
  if (!isPending && !isConfirming && !isSuccess && !error) return null

  return (
    <div className="mt-4 border border-white/10 bg-black/40 p-3 text-xs font-mono space-y-1">
      {isPending && (
        <div className="text-[#ff4e00] animate-pulse">SUBMITTING TX...</div>
      )}
      {isConfirming && hash && (
        <div className="text-[#ff4e00]">
          CONFIRMING...{" "}
          <a
            href={`${EXPLORER}/tx/${hash}`}
            target="_blank"
            rel="noopener noreferrer"
            className="underline hover:text-white"
          >
            {hash.slice(0, 10)}...{hash.slice(-6)}
          </a>
        </div>
      )}
      {isSuccess && (
        <div className="text-[#00ff66]">CONFIRMED</div>
      )}
      {error && (
        <div className="text-[#ff3333]">
          ERROR: {(error as { shortMessage?: string }).shortMessage ?? error.message}
        </div>
      )}
    </div>
  )
}
