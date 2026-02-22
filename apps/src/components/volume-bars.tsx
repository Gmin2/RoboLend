interface VolumeBarsProps {
  value: number
}

export function VolumeBars({ value }: VolumeBarsProps) {
  const maxBars = 40
  const activeBars = Math.floor((value / 100) * maxBars)

  return (
    <div className="flex gap-[2px] h-3 items-end opacity-60">
      {Array.from({ length: maxBars }).map((_, i) => (
        <div
          key={i}
          className={`w-[2px] bg-white ${
            i < activeBars ? "h-full" : "h-[30%] opacity-30"
          }`}
        />
      ))}
    </div>
  )
}
