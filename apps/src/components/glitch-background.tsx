const IMAGE_URL = "/socrates.png"

export function GlitchBackground() {
  return (
    <div className="absolute right-0 top-0 w-full h-screen pointer-events-none overflow-hidden z-0">
      {/* Base Image — contain so full bust is visible, blue tint preserved */}
      <div
        className="absolute inset-0 bg-contain bg-no-repeat opacity-85 mix-blend-screen"
        style={{
          backgroundImage: `url(${IMAGE_URL})`,
          backgroundPosition: "55% center",
          backgroundSize: "auto 95vh",
          filter: "contrast(1.4) brightness(0.7)",
        }}
      />

      {/* Halftone dot-matrix overlay */}
      <div className="absolute inset-0 bg-[radial-gradient(circle,transparent_20%,#050505_20%,#050505_80%,transparent_80%,transparent)] bg-[length:3px_3px] opacity-60 mix-blend-overlay" />

      {/* Scanlines */}
      <div className="absolute inset-0 scanlines opacity-50 mix-blend-overlay" />

      {/* Scratch texture */}
      <div className="absolute inset-0 scratch-overlay" />

      {/* Grain layer */}
      <div className="absolute inset-0 grain-heavy mix-blend-overlay" />

      {/* Gradients to blend into dark background */}
      <div className="absolute inset-0 bg-gradient-to-r from-[#050505] via-[#050505]/60 to-transparent w-full lg:w-1/2" />
      <div className="absolute inset-0 bg-gradient-to-t from-[#050505] via-transparent to-[#050505] h-full opacity-80" />
      <div className="absolute inset-0 bg-gradient-to-b from-[#050505] via-transparent to-transparent h-40 opacity-80" />
    </div>
  )
}
