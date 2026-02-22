import { Link, useLocation, useNavigate } from "react-router-dom"
import { Button } from "@/components/ui/button"
import { useAccount, useConnect, useDisconnect, useBalance, useSwitchChain } from "wagmi"
import { formatUnits } from "viem"
import { injected } from "wagmi/connectors"
import { robinhoodChainTestnet } from "@/config/wagmi"
import { shortenAddress } from "@/lib/format"

const NAV_ITEMS = [
  { key: "dashboard", label: "Dashboard" },
  { key: "markets", label: "Markets" },
  { key: "supply", label: "Supply" },
  { key: "borrow", label: "Borrow" },
  { key: "liquidate", label: "Liquidate" },
  { key: "faucet", label: "Faucet" },
]

export function Navbar() {
  const location = useLocation()
  const navigate = useNavigate()
  const { address, isConnected, chain } = useAccount()
  const { connect } = useConnect()
  const { disconnect } = useDisconnect()
  const { switchChain } = useSwitchChain()
  const { data: balance } = useBalance({ address })

  const wrongChain = isConnected && chain?.id !== robinhoodChainTestnet.id

  return (
    <header className="fixed top-0 left-0 right-0 z-40 flex items-center justify-between px-8 py-6 border-b border-white/10 bg-[#050505]/80 backdrop-blur-sm">
      <div className="flex items-center gap-16">
        <div
          className="flex items-center gap-2 cursor-pointer"
          onClick={() => navigate("/")}
        >
          <img src="/logo.png" alt="RoboLend" className="w-8 h-8 rounded-full" />
          <span className="text-2xl font-sans font-bold tracking-tighter">RoboLend</span>
        </div>
        <nav className="hidden md:flex items-center gap-8 text-xs text-[#888888] tracking-widest uppercase">
          {NAV_ITEMS.map((item) => (
            <Link
              key={item.key}
              to={`/${item.key}`}
              className={`transition-colors hover:text-white ${
                location.pathname === `/${item.key}` ? "text-white" : ""
              }`}
            >
              {item.label}
            </Link>
          ))}
        </nav>
      </div>

      {!isConnected ? (
        <Button
          size="sm"
          className="px-6"
          onClick={() => connect({ connector: injected() })}
        >
          Connect wallet
        </Button>
      ) : wrongChain ? (
        <Button
          size="sm"
          className="px-6 border-[#ff4e00] text-[#ff4e00]"
          onClick={() => switchChain({ chainId: robinhoodChainTestnet.id })}
        >
          Switch Network
        </Button>
      ) : (
        <button
          onClick={() => disconnect()}
          className="flex items-center gap-3 px-4 py-2 border border-white/20 text-xs font-mono hover:bg-white/5 transition-colors"
        >
          <span className="text-[#888888]">{shortenAddress(address!)}</span>
          <span className="text-white">
            {balance ? `${parseFloat(formatUnits(balance.value, balance.decimals)).toFixed(4)} ETH` : "..."}
          </span>
        </button>
      )}
    </header>
  )
}
