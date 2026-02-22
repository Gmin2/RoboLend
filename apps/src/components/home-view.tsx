import { ArrowUpRight, ChevronRight } from "lucide-react"
import { useNavigate } from "react-router-dom"
import { Button } from "@/components/ui/button"
import { Card } from "@/components/ui/card"
import { Sparkline } from "@/components/sparkline"
import { VolumeBars } from "@/components/volume-bars"

export function HomeView() {
  const navigate = useNavigate()
  return (
    <>
      {/* Left Column: Hero Content */}
      <div className="w-full lg:w-1/2 flex flex-col justify-center pr-8 relative z-20">
        <div className="absolute -left-16 top-1/4 w-32 h-64 bg-stripes opacity-20 -z-10" />

        <div className="text-[10px] text-[#888888] tracking-widest uppercase mb-6 flex items-center gap-2">
          <span>// ROBOLEND_FEED ACTIVE</span>
          <span>&mdash;</span>
          <span>TSLA: $248.32</span>
          <span>&mdash;</span>
          <span>
            MARKET: <span className="text-[#00ff66]">OPEN</span>
          </span>
        </div>

        <h1 className="text-6xl md:text-7xl lg:text-[84px] leading-[0.9] font-sans font-medium tracking-tight mb-8">
          Tokenized
          <br />
          <span className="font-mono font-light text-white/90">
            {" "}
            [Equities]
          </span>
        </h1>

        <p className="text-[#888888] text-sm md:text-base max-w-md leading-relaxed mb-12">
          Lend and borrow against tokenized stocks on Robinhood Chain.
          Deposit TSLA, AMZN, PLTR, NFLX, AMD as collateral and borrow WETH.
        </p>

        <div className="flex items-center gap-4">
          <Button onClick={() => navigate("/markets")}>View Markets</Button>
          <Button
            variant="secondary"
            className="flex items-center gap-2 group"
            onClick={() => navigate("/dashboard")}
          >
            Launch App
            <ChevronRight className="w-4 h-4 opacity-50 group-hover:opacity-100 group-hover:translate-x-1 transition-all" />
            <ChevronRight className="w-4 h-4 -ml-3 opacity-50 group-hover:opacity-100 group-hover:translate-x-1 transition-all" />
          </Button>
        </div>
      </div>

      {/* Right Column: Widgets overlapping the statue */}
      <div className="hidden lg:block w-1/2 relative">
        {/* TSLA Chart — mid-right */}
        <Card className="absolute top-[35%] right-[2%] w-[300px] p-4">
          <div className="flex justify-between items-start mb-3">
            <div className="text-[10px] text-[#888888] tracking-widest">
              //TSLA_USD
            </div>
            <ArrowUpRight className="w-3 h-3 text-[#888888]" />
          </div>

          <div className="h-[90px] relative mb-3">
            <div className="absolute left-0 top-0 bottom-0 flex flex-col justify-between text-[8px] text-[#555]">
              <span>260</span>
              <span>250</span>
              <span>240</span>
              <span>230</span>
            </div>
            <div className="ml-6 h-full">
              <Sparkline
                data={[232, 238, 235, 242, 240, 248, 245, 252, 249, 248]}
                color="#ff4e00"
              />
            </div>
          </div>

          <div className="text-[10px] text-[#888888]">
            Asset: Tesla Inc - TSLA
            <br />
            Network: Robinhood Chain
          </div>
        </Card>

        {/* AMZN Chart — bottom-left empty area */}
        <Card className="absolute bottom-[12%] left-[-35%] w-[280px] p-4">
          <div className="flex justify-between items-start mb-3">
            <div className="text-[10px] text-[#888888] tracking-widest">
              //AMZN_USD
            </div>
            <ArrowUpRight className="w-3 h-3 text-[#888888]" />
          </div>

          <div className="h-[80px] relative mb-3">
            <div className="absolute left-0 top-0 bottom-0 flex flex-col justify-between text-[8px] text-[#555]">
              <span>195</span>
              <span>190</span>
              <span>185</span>
              <span>180</span>
            </div>
            <div className="ml-6 h-full">
              <Sparkline
                data={[180, 182, 179, 184, 186, 183, 188, 185, 187, 186]}
                color="#00ff66"
              />
            </div>
          </div>

          <div className="text-[10px] text-[#888888]">
            Asset: Amazon - AMZN
            <br />
            Layer: Robinhood Chain
          </div>
        </Card>

        {/* Ticker Card — bottom-right */}
        <Card className="absolute bottom-[2%] right-[0%] w-[400px] p-5 bg-[#0a0a0a]/90">
          <div className="flex flex-col gap-2.5 text-xs">
            <div className="flex items-center justify-between group cursor-pointer">
              <div className="w-10 text-[#888888] group-hover:text-white transition-colors">
                TSLA
              </div>
              <div className="flex-1 px-3">
                <VolumeBars value={88} />
              </div>
              <div className="w-20 text-right font-mono">$248.32</div>
              <div className="w-20 text-right text-[#00ff66] font-mono">
                &#9650; 2.14%
              </div>
            </div>

            <div className="flex items-center justify-between group cursor-pointer">
              <div className="w-10 text-[#888888] group-hover:text-white transition-colors">
                AMZN
              </div>
              <div className="flex-1 px-3">
                <VolumeBars value={72} />
              </div>
              <div className="w-20 text-right font-mono">$186.14</div>
              <div className="w-20 text-right text-[#00ff66] font-mono">
                &#9650; 1.73%
              </div>
            </div>

            <div className="flex items-center justify-between group cursor-pointer">
              <div className="w-10 text-[#888888] group-hover:text-white transition-colors">
                NFLX
              </div>
              <div className="flex-1 px-3">
                <VolumeBars value={95} />
              </div>
              <div className="w-20 text-right font-mono">$875.40</div>
              <div className="w-20 text-right text-[#00ff66] font-mono">
                &#9650; 4.21%
              </div>
            </div>

            <div className="h-[1px] bg-white/10 my-1 w-full" />

            <div className="flex items-center justify-between group cursor-pointer">
              <div className="w-10 text-[#888888] group-hover:text-white transition-colors">
                PLTR
              </div>
              <div className="flex-1 px-3">
                <VolumeBars value={60} />
              </div>
              <div className="w-20 text-right font-mono">$78.45</div>
              <div className="w-20 text-right text-[#ff3333] font-mono">
                &#9660; 0.88%
              </div>
            </div>

            <div className="flex items-center justify-between group cursor-pointer">
              <div className="w-10 text-[#888888] group-hover:text-white transition-colors">
                AMD
              </div>
              <div className="flex-1 px-3">
                <VolumeBars value={68} />
              </div>
              <div className="w-20 text-right font-mono">$162.80</div>
              <div className="w-20 text-right text-[#00ff66] font-mono">
                &#9650; 3.14%
              </div>
            </div>

            <div className="h-[1px] bg-white/10 my-1 w-full" />

            {/* Summary stats */}
            <div className="flex items-center justify-between text-[#888888]">
              <div>TVL</div>
              <div className="text-white font-mono">$12.4M</div>
              <div className="w-20 text-right text-[#00ff66] font-mono">
                &#9650; 1.90%
              </div>
            </div>
            <div className="flex items-center justify-between text-[#888888]">
              <div>BORROWED</div>
              <div className="text-white font-mono">842.5 WETH</div>
              <div className="w-20 text-right text-[#ff3333] font-mono">
                &#9660; 0.30%
              </div>
            </div>
          </div>
        </Card>
      </div>
    </>
  )
}
