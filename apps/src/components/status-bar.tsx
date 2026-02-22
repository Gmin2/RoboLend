import { useEffect, useState } from "react"

export function StatusBar() {
  const [time, setTime] = useState("")

  useEffect(() => {
    const updateTime = () => {
      const now = new Date()
      setTime(`UTC ${now.toISOString().split("T")[1].split(".")[0]}`)
    }
    updateTime()
    const interval = setInterval(updateTime, 1000)
    return () => clearInterval(interval)
  }, [])

  return (
    <footer className="fixed bottom-0 left-0 right-0 z-40 flex items-center justify-between px-8 py-3 border-t border-white/10 bg-[#050505]/90 text-[10px] text-[#888888] tracking-widest uppercase">
      <div>ALL SYSTEMS NOMINAL</div>
      <div>FEED LATENCY 12ms</div>
      <div className="flex gap-8">
        <span>ROBOLEND v1.0.0</span>
        <span>{time}</span>
      </div>
    </footer>
  )
}
