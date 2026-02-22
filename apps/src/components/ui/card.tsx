import { type HTMLAttributes, forwardRef } from "react"
import { cn } from "@/lib/utils"

const Card = forwardRef<HTMLDivElement, HTMLAttributes<HTMLDivElement>>(
  ({ className, children, ...props }, ref) => (
    <div
      ref={ref}
      className={cn(
        "relative bg-[#0a0a0a]/80 backdrop-blur-md border border-white/10",
        className
      )}
      {...props}
    >
      <div className="bracket-tl" />
      <div className="bracket-tr" />
      <div className="bracket-bl" />
      <div className="bracket-br" />
      {children}
    </div>
  )
)
Card.displayName = "Card"

export { Card }
