import { Routes, Route, useLocation } from "react-router-dom"
import { Navbar } from "@/components/navbar"
import { StatusBar } from "@/components/status-bar"
import { GlitchBackground } from "@/components/glitch-background"
import { HomeView } from "@/components/home-view"
import { DashboardView } from "@/components/dashboard-view"
import { MarketsView } from "@/components/markets-view"
import { SupplyView } from "@/components/supply-view"
import { BorrowView } from "@/components/borrow-view"
import { LiquidateView } from "@/components/liquidate-view"
import { FaucetView } from "@/components/faucet-view"

export default function App() {
  const location = useLocation()
  const isHome = location.pathname === "/"

  return (
    <div className="min-h-screen bg-[#050505] text-white font-mono overflow-hidden relative selection:bg-white/20">
      <div className="noise-overlay" />
      <div className="absolute inset-0 bg-grid-minor opacity-40 pointer-events-none" />
      <div className="major-grid" />
      {/* Scattered hatching patches like the reference */}
      <div className="hatch-overlay">
        <div className="hatch-patch" style={{ top: '5%', left: '0%', width: '25vw', height: '30vh' }} />
        <div className="hatch-patch-reverse" style={{ top: '0%', right: '0%', width: '20vw', height: '25vh' }} />
        <div className="hatch-patch" style={{ bottom: '10%', left: '2%', width: '30vw', height: '35vh' }} />
        <div className="hatch-patch-reverse" style={{ bottom: '0%', left: '25vw', width: '25vw', height: '20vh' }} />
        <div className="hatch-patch" style={{ top: '40%', right: '5%', width: '15vw', height: '20vh' }} />
        <div className="hatch-patch-reverse" style={{ top: '10%', left: '30%', width: '20vw', height: '15vh' }} />
      </div>

      {isHome && <GlitchBackground />}

      <Navbar />

      <main className={`relative z-10 flex ${isHome ? "h-screen" : "min-h-screen"} pt-24 pb-12 px-8 md:px-16`}>
        <Routes>
          <Route path="/" element={<HomeView />} />
          <Route path="/dashboard" element={<DashboardView />} />
          <Route path="/markets" element={<MarketsView />} />
          <Route path="/supply" element={<SupplyView />} />
          <Route path="/borrow" element={<BorrowView />} />
          <Route path="/liquidate" element={<LiquidateView />} />
          <Route path="/faucet" element={<FaucetView />} />
        </Routes>
      </main>

      <StatusBar />
    </div>
  )
}
