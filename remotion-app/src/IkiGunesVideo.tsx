import React from "react";
import {
  AbsoluteFill,
  Audio,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import {
  Activity,
  AlertOctagon,
  AlertTriangle,
  Compass,
  Flame,
  Globe,
  Radio,
  Shield,
  ShieldAlert,
  Sparkles,
  Sun,
  Thermometer,
  Zap,
} from "lucide-react";
import masterData from "./master_iki_gunes_scenes.json";

interface WordTiming {
  text: string;
  startFrame: number;
  endFrame: number;
}

interface SceneData {
  id: string;
  badge: string;
  top_title: string;
  glow_title: string;
  tag: string;
  script: string;
  type: string;
  startFrame: number;
  endFrame: number;
  durationInFrames: number;
  audioDurationSec: number;
  words: WordTiming[];
}

export const IkiGunesVideo: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Find active scene
  const activeScene =
    (masterData.scenes as SceneData[]).find(
      (s) => frame >= s.startFrame && frame < s.endFrame
    ) || (masterData.scenes[masterData.scenes.length - 1] as SceneData);

  // Global camera tilt & breathe
  const camTiltX = Math.sin(frame * 0.02) * 2;
  const camTiltY = Math.cos(frame * 0.015) * 3;

  return (
    <AbsoluteFill className="bg-[#02040a] text-white font-sans overflow-hidden select-none">
      {/* 1. MASTER CINEMATIC SOUNDTRACK & SFX */}
      <Audio src={staticFile("iki_gunes/iki_gunes_master_soundtrack.mp3")} />

      {/* 2. DYNAMIC DEEP SPACE & EINSTEINIAN SPACETIME FABRIC */}
      <SpacetimeFabricBackground frame={frame} />

      {/* 3. FLOATING 3D SPACE DUST & STARS */}
      <FloatingStarDust frame={frame} />

      {/* 4. TOP HUD TELEMETRY & KINETIC HEADER */}
      <HeaderHUD activeScene={activeScene} frame={frame} fps={fps} />

      {/* 5. 3D MAIN CINEMATIC STAGE */}
      <div
        className="absolute top-[280px] left-0 w-full h-[1260px] flex items-center justify-center"
        style={{
          perspective: 1400,
          transform: `rotateX(${camTiltX}deg) rotateY(${camTiltY}deg)`,
          transformStyle: "preserve-3d",
        }}
      >
        {activeScene.type === "binary_stars" && (
          <SceneBinaryStars frame={frame} scene={activeScene} />
        )}
        {activeScene.type === "orbital_chaos" && (
          <SceneOrbitalChaos frame={frame} scene={activeScene} />
        )}
        {activeScene.type === "daynight_loss" && (
          <SceneDayNightLoss frame={frame} scene={activeScene} />
        )}
        {activeScene.type === "thermal_collapse" && (
          <SceneThermalCollapse frame={frame} scene={activeScene} />
        )}
        {activeScene.type === "radiation_storm" && (
          <SceneRadiationStorm frame={frame} scene={activeScene} />
        )}
        {activeScene.type === "scientific_outro" && (
          <SceneScientificOutro frame={frame} scene={activeScene} />
        )}
      </div>

      {/* 6. BOTTOM KARAOKE SUBTITLE BAR */}
      <SubtitleBar activeScene={activeScene} frame={frame} />

      {/* 7. CINEMATIC FILM GRAIN & VIGNETTE OVERLAY */}
      <div className="absolute inset-0 pointer-events-none shadow-[inset_0_0_140px_rgba(0,0,0,0.85)] z-50" />
    </AbsoluteFill>
  );
};

// -------------------------------------------------------------
// BACKGROUND: 3D Isometric Spacetime Fabric (Einsteinian Gravitational Grid)
// -------------------------------------------------------------
const SpacetimeFabricBackground: React.FC<{ frame: number }> = ({ frame }) => {
  const gridShift = (frame * 1.8) % 80;
  return (
    <div className="absolute inset-0 pointer-events-none overflow-hidden">
      {/* Deep cosmic nebulae */}
      <div
        className="absolute w-[900px] h-[900px] -top-60 -left-60 rounded-full blur-[150px] opacity-30"
        style={{
          background:
            "radial-gradient(circle, rgba(245,158,11,0.6) 0%, rgba(220,38,38,0.25) 50%, transparent 100%)",
        }}
      />
      <div
        className="absolute w-[1000px] h-[1000px] -bottom-60 -right-60 rounded-full blur-[180px] opacity-25"
        style={{
          background:
            "radial-gradient(circle, rgba(56,189,248,0.5) 0%, rgba(147,51,234,0.3) 60%, transparent 100%)",
        }}
      />

      {/* 3D Perspective Curved Spacetime Mesh */}
      <div
        className="absolute inset-0 opacity-20"
        style={{
          transform: "perspective(1000px) rotateX(64deg) translateY(120px)",
          transformOrigin: "center bottom",
        }}
      >
        <svg
          className="w-[1400px] h-[1400px] -ml-[160px]"
          xmlns="http://www.w3.org/2000/svg"
        >
          <defs>
            <pattern
              id="gravityGrid"
              width="60"
              height="60"
              patternUnits="userSpaceOnUse"
              patternTransform={`translate(0, ${gridShift})`}
            >
              <path
                d="M 60 0 L 0 0 0 60"
                fill="none"
                stroke="#f59e0b"
                strokeWidth="0.75"
                strokeDasharray="2,4"
              />
              <circle cx="0" cy="0" r="1.5" fill="#f59e0b" opacity="0.7" />
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="url(#gravityGrid)" />
        </svg>
      </div>

      {/* Cinematic HUD Corner Brackets */}
      <div className="absolute top-8 left-8 w-10 h-10 border-t-2 border-l-2 border-amber-500/50" />
      <div className="absolute top-8 right-8 w-10 h-10 border-t-2 border-r-2 border-amber-500/50" />
      <div className="absolute bottom-8 left-8 w-10 h-10 border-b-2 border-l-2 border-amber-500/50" />
      <div className="absolute bottom-8 right-8 w-10 h-10 border-b-2 border-r-2 border-amber-500/50" />
    </div>
  );
};

// -------------------------------------------------------------
// FLOATING 3D STAR DUST PARTICLES
// -------------------------------------------------------------
const FloatingStarDust: React.FC<{ frame: number }> = ({ frame }) => {
  const particles = React.useMemo(() => {
    return [...Array(40)].map((_, i) => ({
      x: (i * 37) % 1080,
      y: (i * 59) % 1920,
      size: 1.5 + (i % 3) * 1.5,
      speed: 0.4 + (i % 5) * 0.3,
      opacity: 0.3 + (i % 4) * 0.2,
      color: i % 2 === 0 ? "#fef08a" : "#93c5fd",
    }));
  }, []);

  return (
    <div className="absolute inset-0 pointer-events-none z-10">
      {particles.map((p, i) => {
        const curY = (p.y + frame * p.speed) % 1920;
        return (
          <div
            key={`dust-${i}`}
            className="absolute rounded-full"
            style={{
              left: p.x,
              top: curY,
              width: p.size,
              height: p.size,
              backgroundColor: p.color,
              opacity: p.opacity,
              boxShadow: `0 0 6px ${p.color}`,
            }}
          />
        );
      })}
    </div>
  );
};

// -------------------------------------------------------------
// TOP HUD & KINETIC HEADER
// -------------------------------------------------------------
const HeaderHUD: React.FC<{
  activeScene: SceneData;
  frame: number;
  fps: number;
}> = ({ activeScene, frame, fps }) => {
  const localFrame = frame - activeScene.startFrame;
  const titlePop = spring({
    frame: localFrame,
    fps,
    config: { damping: 14, mass: 0.6, stiffness: 120 },
  });

  const seconds = (frame / fps).toFixed(1);

  return (
    <div className="absolute top-12 left-0 w-full px-12 z-40">
      {/* Top micro telemetry bar */}
      <div className="flex items-center justify-between text-xs tracking-[0.25em] font-mono text-zinc-400 mb-3 border-b border-zinc-800/80 pb-3">
        <div className="flex items-center space-x-3">
          <span className="w-2.5 h-2.5 rounded-full bg-amber-500 animate-ping inline-block" />
          <span className="text-zinc-200 font-bold tracking-widest">
            ROTA MEDYA // KOZMO-LAB
          </span>
          <span className="text-zinc-600">|</span>
          <span className="text-amber-400 font-semibold">{activeScene.tag}</span>
        </div>
        <div className="flex items-center space-x-3">
          <span className="text-zinc-400 font-mono">T+{seconds}s</span>
          <span className="bg-amber-500/10 border border-amber-500/30 text-amber-300 px-2 py-0.5 rounded text-[10px] font-bold">
            SİMÜLASYON #3-BODY
          </span>
        </div>
      </div>

      {/* Category Badge */}
      <div className="inline-flex items-center space-x-2 px-3 py-1 rounded-full bg-amber-500/15 border border-amber-500/40 text-amber-400 text-xs font-bold tracking-widest uppercase mb-2 shadow-[0_0_15px_rgba(245,158,11,0.2)]">
        <Sparkles className="w-3.5 h-3.5 text-amber-400" />
        <span>{activeScene.badge}</span>
      </div>

      {/* Main Kinetic Typography */}
      <div
        style={{
          transform: `scale(${interpolate(titlePop, [0, 1], [0.93, 1])})`,
          opacity: titlePop,
        }}
      >
        <h2 className="text-2xl font-black tracking-wider text-zinc-300 uppercase">
          {activeScene.top_title}
        </h2>
        <h1 className="text-5xl font-black tracking-tight text-transparent bg-clip-text bg-gradient-to-r from-amber-300 via-orange-400 to-red-500 drop-shadow-[0_4px_30px_rgba(245,158,11,0.5)]">
          {activeScene.glow_title}
        </h1>
      </div>
    </div>
  );
};

// -------------------------------------------------------------
// REALISTIC 3D PROCEDURAL SUN COMPONENT
// -------------------------------------------------------------
const VolumetricSun: React.FC<{
  cx: number;
  cy: number;
  radius: number;
  type: "yellow" | "red";
  frame: number;
}> = ({ cx, cy, radius, type, frame }) => {
  const pulse = Math.sin(frame * 0.12) * 5;
  const flareRot = (frame * 1.5) % 360;

  const isYellow = type === "yellow";
  const coreColor = isYellow ? "#ffffff" : "#fee2e2";
  const midColor = isYellow ? "#fbbf24" : "#f97316";
  const edgeColor = isYellow ? "#d97706" : "#dc2626";
  const glowColor = isYellow ? "rgba(245,158,11," : "rgba(239,68,68,";

  return (
    <g transform={`translate(${cx}, ${cy})`}>
      {/* 1. Deep Volumetric Corona Glow */}
      <circle
        r={radius * 2.2 + pulse}
        fill={`url(#coronaGlow_${type})`}
        opacity="0.65"
      />

      {/* 2. Anamorphic Lens Flare Horizontal Rays */}
      <ellipse
        rx={radius * 3.4 + pulse * 2}
        ry={radius * 0.25}
        fill={`url(#lensStreak_${type})`}
        opacity="0.7"
        transform={`rotate(${flareRot * 0.1})`}
      />
      <ellipse
        rx={radius * 3.4 + pulse * 2}
        ry={radius * 0.25}
        fill={`url(#lensStreak_${type})`}
        opacity="0.7"
        transform={`rotate(${flareRot * 0.1 + 90})`}
      />

      {/* 3. Rotating Solar Prominences / Plasma Flares */}
      <g transform={`rotate(${flareRot})`}>
        {[0, 60, 120, 180, 240, 300].map((deg) => (
          <path
            key={deg}
            d={`M 0 -${radius} Q ${radius * 0.4} -${radius * 1.45 + pulse} 0 -${
              radius * 1.6 + pulse
            }`}
            fill="none"
            stroke={midColor}
            strokeWidth="3.5"
            strokeLinecap="round"
            opacity="0.8"
            transform={`rotate(${deg})`}
          />
        ))}
      </g>

      {/* 4. Core Sun Sphere with 3D Spherical Radial Lighting */}
      <circle
        r={radius}
        fill={`url(#sunCoreGrad_${type})`}
        filter={`drop-shadow(0 0 ${radius * 0.8}px ${edgeColor})`}
      />

      {/* 5. Surface Solar Convection Granules (Turbulent Rings) */}
      <circle
        r={radius * 0.95}
        fill="none"
        stroke={coreColor}
        strokeWidth="2"
        strokeDasharray="10,14"
        opacity="0.4"
        transform={`rotate(${-flareRot * 0.8})`}
      />

      {/* Gradient Definitions */}
      <defs>
        <radialGradient id={`coronaGlow_${type}`} cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor={`${glowColor}0.9)`} />
          <stop offset="50%" stopColor={`${glowColor}0.4)`} />
          <stop offset="100%" stopColor={`${glowColor}0)`} />
        </radialGradient>
        <radialGradient id={`sunCoreGrad_${type}`} cx="35%" cy="35%" r="65%">
          <stop offset="0%" stopColor={coreColor} />
          <stop offset="25%" stopColor={midColor} />
          <stop offset="75%" stopColor={edgeColor} />
          <stop offset="100%" stopColor="#450a0a" />
        </radialGradient>
        <linearGradient
          id={`lensStreak_${type}`}
          x1="0%"
          y1="0%"
          x2="100%"
          y2="0%"
        >
          <stop offset="0%" stopColor={`${glowColor}0)`} />
          <stop offset="50%" stopColor={midColor} stopOpacity="0.8" />
          <stop offset="100%" stopColor={`${glowColor}0)`} />
        </linearGradient>
      </defs>
    </g>
  );
};

// -------------------------------------------------------------
// REALISTIC 3D EARTH GLOBE COMPONENT
// -------------------------------------------------------------
const Realistic3DEarth: React.FC<{
  x: number;
  y: number;
  radius: number;
  frame: number;
  state?: "normal" | "dual_lit" | "scorched" | "shielded";
}> = ({ x, y, radius, frame, state = "normal" }) => {
  const rot = (frame * 0.8) % 360;
  const isScorched = state === "scorched";
  const isDualLit = state === "dual_lit";
  const isShielded = state === "shielded";

  return (
    <g transform={`translate(${x}, ${y})`}>
      {/* 1. Atmospheric Rayleigh Scattering Blue Halo */}
      <circle
        r={radius * 1.25}
        fill="none"
        stroke={isScorched ? "#f97316" : "#38bdf8"}
        strokeWidth={radius * 0.22}
        opacity="0.45"
        filter={`drop-shadow(0 0 ${radius * 0.5}px ${
          isScorched ? "#ef4444" : "#0284c7"
        })`}
      />

      {/* 2. Magnetic Shield Ring (Scene 5) */}
      {isShielded && (
        <circle
          r={radius * 1.55}
          fill="none"
          stroke="#a855f7"
          strokeWidth="4"
          strokeDasharray="8,6"
          opacity="0.85"
          filter="drop-shadow(0 0 15px #a855f7)"
          className="animate-pulse"
        />
      )}

      {/* 3. Base Ocean / Magma Sphere */}
      <circle
        r={radius}
        fill={`url(#earthOcean_${state})`}
        filter="drop-shadow(0 15px 35px rgba(0,0,0,0.8))"
      />

      {/* 4. Continents Texture Overlay (Clipped to Sphere) */}
      <g clipPath="url(#earthSphereClip)">
        {/* Continental shapes sliding horizontally to simulate 3D spin */}
        <g transform={`translate(${((rot * 2) % (radius * 3)) - radius * 1.5}, 0)`}>
          {[-1, 0, 1].map((copyIdx) => (
            <g key={copyIdx} transform={`translate(${copyIdx * radius * 3}, 0)`}>
              {/* Simplified stylized continents */}
              <path
                d={`M -${radius * 0.8} -${radius * 0.3} Q -${radius * 0.4} -${
                  radius * 0.6
                } 0 -${radius * 0.2} Q ${radius * 0.5} -${radius * 0.5} ${
                  radius * 0.7
                } 0 Q ${radius * 0.4} ${radius * 0.6} -${radius * 0.2} ${
                  radius * 0.4
                } Z`}
                fill={isScorched ? "#78350f" : "#10b981"}
                opacity="0.85"
              />
              <path
                d={`M -${radius * 0.3} ${radius * 0.2} Q 0 ${radius * 0.7} ${
                  radius * 0.4
                } ${radius * 0.5} Q ${radius * 0.2} ${radius * 0.8} -${
                  radius * 0.4
                } ${radius * 0.6} Z`}
                fill={isScorched ? "#991b1b" : "#059669"}
                opacity="0.8"
              />
            </g>
          ))}
        </g>

        {/* 5. Terminator Shading: If Dual Lit, light from BOTH sides; otherwise standard 3D shadow */}
        {isDualLit ? (
          <>
            {/* Left rim light from Sun A */}
            <circle
              r={radius}
              fill="none"
              stroke="#fbbf24"
              strokeWidth={radius * 0.3}
              opacity="0.6"
            />
            {/* Right rim light from Sun B */}
            <circle
              r={radius}
              fill="none"
              stroke="#f97316"
              strokeWidth={radius * 0.3}
              opacity="0.6"
            />
          </>
        ) : (
          <path
            d={`M 0 -${radius} A ${radius} ${radius} 0 0 1 0 ${radius} A ${
              radius * 0.4
            } ${radius} 0 0 0 0 -${radius} Z`}
            fill="#020617"
            opacity="0.55"
          />
        )}
      </g>

      {/* Sphere Clip & Gradients */}
      <defs>
        <clipPath id="earthSphereClip">
          <circle r={radius} />
        </clipPath>
        <radialGradient id="earthOcean_normal" cx="35%" cy="35%" r="65%">
          <stop offset="0%" stopColor="#38bdf8" />
          <stop offset="40%" stopColor="#0284c7" />
          <stop offset="100%" stopColor="#082f49" />
        </radialGradient>
        <radialGradient id="earthOcean_dual_lit" cx="50%" cy="50%" r="60%">
          <stop offset="0%" stopColor="#7dd3fc" />
          <stop offset="70%" stopColor="#0284c7" />
          <stop offset="100%" stopColor="#0369a1" />
        </radialGradient>
        <radialGradient id="earthOcean_scorched" cx="35%" cy="35%" r="65%">
          <stop offset="0%" stopColor="#fbbf24" />
          <stop offset="40%" stopColor="#dc2626" />
          <stop offset="100%" stopColor="#450a0a" />
        </radialGradient>
        <radialGradient id="earthOcean_shielded" cx="35%" cy="35%" r="65%">
          <stop offset="0%" stopColor="#a5f3fc" />
          <stop offset="50%" stopColor="#0284c7" />
          <stop offset="100%" stopColor="#0f172a" />
        </radialGradient>
      </defs>
    </g>
  );
};

// -------------------------------------------------------------
// SCENE 1: BINARY STARS (Güneş A & Güneş B Yörüngesi)
// -------------------------------------------------------------
const SceneBinaryStars: React.FC<{ frame: number; scene: SceneData }> = ({
  frame,
  scene,
}) => {
  const local = frame - scene.startFrame;
  const rot = local * 1.1;

  const cx = 540;
  const cy = 600;
  const orbitR = 210;

  const sunAx = cx + Math.cos((rot * Math.PI) / 180) * orbitR;
  const sunAy = cy + Math.sin((rot * Math.PI) / 180) * orbitR;

  const sunBx = cx + Math.cos(((rot + 180) * Math.PI) / 180) * orbitR;
  const sunBy = cy + Math.sin(((rot + 180) * Math.PI) / 180) * orbitR;

  // Earth outer circumbinary orbit
  const earthOrbitR = 470;
  const earthX =
    cx + Math.cos(((rot * 0.35 + 80) * Math.PI) / 180) * earthOrbitR;
  const earthY =
    cy + Math.sin(((rot * 0.35 + 80) * Math.PI) / 180) * earthOrbitR;

  return (
    <div className="relative w-full h-full flex items-center justify-center">
      <svg className="w-full h-full absolute inset-0">
        {/* Orbital Ellipses */}
        <circle
          cx={cx}
          cy={cy}
          r={orbitR}
          fill="none"
          stroke="#f59e0b"
          strokeWidth="1.5"
          strokeDasharray="6,8"
          opacity="0.35"
        />
        <circle
          cx={cx}
          cy={cy}
          r={earthOrbitR}
          fill="none"
          stroke="#38bdf8"
          strokeWidth="2"
          strokeDasharray="8,10"
          opacity="0.4"
        />

        {/* Gravitational Binding Tension Ribbon */}
        <line
          x1={sunAx}
          y1={sunAy}
          x2={sunBx}
          y2={sunBy}
          stroke="#fbbf24"
          strokeWidth="2.5"
          strokeDasharray="6,4"
          opacity="0.6"
        />

        {/* Center Barycenter Indicator */}
        <circle
          cx={cx}
          cy={cy}
          r="12"
          fill="none"
          stroke="#ef4444"
          strokeWidth="2"
        />
        <line
          x1={cx - 24}
          y1={cy}
          x2={cx + 24}
          y2={cy}
          stroke="#ef4444"
          strokeWidth="2"
        />
        <line
          x1={cx}
          y1={cy - 24}
          x2={cx}
          y2={cy + 24}
          stroke="#ef4444"
          strokeWidth="2"
        />

        {/* Volumetric Glowing Sun-A (Sarı Dev) */}
        <VolumetricSun
          cx={sunAx}
          cy={sunAy}
          radius={58}
          type="yellow"
          frame={frame}
        />

        {/* Volumetric Glowing Sun-B (Kızıl Dev) */}
        <VolumetricSun
          cx={sunBx}
          cy={sunBy}
          radius={48}
          type="red"
          frame={frame}
        />

        {/* 3D Textured Earth Globe */}
        <Realistic3DEarth
          x={earthX}
          y={earthY}
          radius={26}
          frame={frame}
          state="normal"
        />
      </svg>

      {/* Floating Holographic Telemetry Cards */}
      <div className="absolute bottom-12 left-12 bg-zinc-950/85 backdrop-blur-xl border border-amber-500/40 rounded-2xl p-4 flex items-center space-x-4 shadow-[0_12px_40px_rgba(0,0,0,0.8)]">
        <div className="p-3 bg-amber-500/20 rounded-xl text-amber-400">
          <Sun className="w-8 h-8 animate-spin" />
        </div>
        <div>
          <div className="text-[11px] font-mono text-zinc-400 tracking-wider">
            YILDIZ-A (1.0 GÜNEŞ KÜTLESİ)
          </div>
          <div className="text-xl font-black text-white">5.778 KELVİN</div>
          <div className="text-xs text-amber-400 font-medium">Sarı Cüce</div>
        </div>
      </div>

      <div className="absolute bottom-12 right-12 bg-zinc-950/85 backdrop-blur-xl border border-red-500/40 rounded-2xl p-4 flex items-center space-x-4 shadow-[0_12px_40px_rgba(0,0,0,0.8)]">
        <div className="p-3 bg-red-500/20 rounded-xl text-red-400">
          <Flame className="w-8 h-8 animate-bounce" />
        </div>
        <div>
          <div className="text-[11px] font-mono text-zinc-400 tracking-wider">
            YILDIZ-B (0.8 GÜNEŞ KÜTLESİ)
          </div>
          <div className="text-xl font-black text-white">3.900 KELVİN</div>
          <div className="text-xs text-red-400 font-medium">Kızıl Yıldız</div>
        </div>
      </div>

      <div className="absolute top-[490px] bg-black/80 border border-zinc-700/80 px-5 py-2 rounded-full text-xs font-mono text-zinc-300 shadow-xl">
        ✦ ORTAK KÜTLEÇEKİM MERKEZİ (BARYCENTER)
      </div>
    </div>
  );
};

// -------------------------------------------------------------
// SCENE 2: ORBITAL CHAOS (3-Body Problem Simulation)
// -------------------------------------------------------------
const SceneOrbitalChaos: React.FC<{ frame: number; scene: SceneData }> = ({
  frame,
  scene,
}) => {
  const local = frame - scene.startFrame;
  const chaos = Math.min(1, local / 90);
  const shake = Math.sin(local * 0.9) * 5 * chaos;

  return (
    <div className="relative w-full h-full flex flex-col items-center justify-center px-10">
      <div className="relative w-[880px] h-[730px] bg-zinc-950/90 border border-red-500/40 rounded-3xl overflow-hidden shadow-[0_0_80px_rgba(239,68,68,0.2)] flex items-center justify-center">
        {/* Radar scan grid */}
        <div className="absolute inset-0 bg-[radial-gradient(#ef4444_1px,transparent_1px)] [background-size:28px_28px] opacity-20" />

        <svg className="w-full h-full absolute inset-0">
          {/* Chaotic Trajectory Ribbon */}
          <path
            d={`M 140 365 Q 260 ${180 + shake * 4} 440 160 T 740 ${
              340 - shake * 5
            } T 560 560 T 240 500 Z`}
            fill="none"
            stroke="#ef4444"
            strokeWidth="4"
            strokeDasharray="6,3"
            filter="drop-shadow(0 0 16px #ef4444)"
          />

          {/* Twin Pulling Stars */}
          <VolumetricSun cx={280} cy={300} radius={46} type="yellow" frame={frame} />
          <VolumetricSun cx={600} cy={420} radius={42} type="red" frame={frame} />

          {/* Gravitational Tension Vectors */}
          <line
            x1="440"
            y1="365"
            x2="280"
            y2="300"
            stroke="#f59e0b"
            strokeWidth="3"
            strokeDasharray="6,4"
          />
          <line
            x1="440"
            y1="365"
            x2="600"
            y2="420"
            stroke="#ef4444"
            strokeWidth="3"
            strokeDasharray="6,4"
          />

          {/* Earth in Crisis */}
          <Realistic3DEarth
            x={440 + shake}
            y={365 - shake}
            radius={28}
            frame={frame}
            state="normal"
          />
        </svg>

        {/* Warning Badges */}
        <div className="absolute top-6 left-6 bg-red-950/90 border border-red-500 rounded-xl px-4 py-2 flex items-center space-x-2 text-red-300 font-mono text-xs">
          <AlertOctagon className="w-5 h-5 text-red-400 animate-spin" />
          <span className="font-bold">FİZİKSEL KAOS: 3-CİSİM KARARSIZLIĞI</span>
        </div>

        <div className="absolute bottom-6 right-6 bg-zinc-900/90 border border-zinc-700 rounded-2xl p-4 font-mono text-xs text-right shadow-xl">
          <div className="text-zinc-400">YÖRÜNGEDEN SAVRULMA RİSKİ</div>
          <div className="text-3xl font-black text-red-500 mt-1">
            %{(60 + chaos * 39).toFixed(1)}
          </div>
        </div>
      </div>

      {/* Dual Outcome Cards */}
      <div className="grid grid-cols-2 gap-6 w-full max-w-[880px] mt-6">
        <div className="bg-zinc-950/90 border border-amber-500/40 rounded-2xl p-5 shadow-xl">
          <div className="text-xs font-mono text-amber-400 font-bold mb-1">
            SENARYO A
          </div>
          <div className="text-xl font-black text-white mb-2">
            UZAYA SAVRULMA
          </div>
          <p className="text-xs text-zinc-300 leading-relaxed">
            Kütleçekim sapanıyla Dünya Güneş Sistemi'nden atılır; eksi 270
            derecede buz tutmuş bir serseri gezegene dönüşür.
          </p>
        </div>

        <div className="bg-zinc-950/90 border border-red-500/40 rounded-2xl p-5 shadow-xl">
          <div className="text-xs font-mono text-red-400 font-bold mb-1">
            SENARYO B
          </div>
          <div className="text-xl font-black text-white mb-2">
            GÜNEŞE ÇARPMA
          </div>
          <p className="text-xs text-zinc-300 leading-relaxed">
            Çekim kuyusuna düşen gezegen, saatte milyonlarca kilometre hızla
            doğrudan yıldızın koronasında buharlaşır.
          </p>
        </div>
      </div>
    </div>
  );
};

// -------------------------------------------------------------
// SCENE 3: DAY/NIGHT LOSS (24h Non-Stop Daylight)
// -------------------------------------------------------------
const SceneDayNightLoss: React.FC<{ frame: number; scene: SceneData }> = ({
  frame,
  scene,
}) => {
  const local = frame - scene.startFrame;
  const rot = local * 1.4;

  return (
    <div className="relative w-full h-full flex flex-col items-center justify-center px-10">
      {/* 24-Hour Circular Dial Infographic */}
      <div className="relative w-[780px] h-[780px] rounded-full border-4 border-amber-500/50 flex items-center justify-center shadow-[0_0_90px_rgba(245,158,11,0.25)] bg-zinc-950/90">
        {/* Outer hour markings */}
        <div className="absolute inset-3 rounded-full border border-dashed border-zinc-700" />

        <div className="absolute top-5 text-xs font-mono text-amber-400 font-bold">
          12:00 (GÜNEŞ A TEPE)
        </div>
        <div className="absolute bottom-5 text-xs font-mono text-orange-400 font-bold">
          00:00 (GÜNEŞ B TEPE)
        </div>
        <div className="absolute left-6 text-xs font-mono text-zinc-400 font-bold">
          06:00 (ÇİFTE DOĞUŞ)
        </div>
        <div className="absolute right-6 text-xs font-mono text-zinc-400 font-bold">
          18:00 (GÜN BATMAZ)
        </div>

        {/* Dual Suns Lighting Earth from Both Sides */}
        <div
          className="absolute inset-0 flex items-center justify-between px-8 pointer-events-none"
          style={{ transform: `rotate(${rot * 0.25}deg)` }}
        >
          <div className="flex flex-col items-center">
            <VolumetricSun cx={0} cy={0} radius={44} type="yellow" frame={frame} />
            <span className="text-xs font-mono text-yellow-400 font-bold mt-2">
              GÜNEŞ-1
            </span>
          </div>

          <div className="flex flex-col items-center">
            <VolumetricSun cx={0} cy={0} radius={40} type="red" frame={frame} />
            <span className="text-xs font-mono text-orange-400 font-bold mt-2">
              GÜNEŞ-2
            </span>
          </div>
        </div>

        {/* 3D Earth: No Shadow, Dual-Lit */}
        <Realistic3DEarth
          x={0}
          y={0}
          radius={70}
          frame={frame}
          state="dual_lit"
        />

        {/* Center Alert Tag */}
        <div className="absolute bg-red-600 text-white font-black text-xs px-5 py-2 rounded-full tracking-wider shadow-xl">
          %0 KARANLIK · 24 SAAT ARALIKSIZ GÜNDÜZ
        </div>
      </div>

      {/* Circadian Collapse Scorecard */}
      <div className="w-full max-w-[780px] bg-zinc-950/90 border border-amber-500/40 rounded-2xl p-6 mt-6 shadow-2xl">
        <div className="flex items-center justify-between border-b border-zinc-800 pb-3 mb-4">
          <span className="text-xs font-mono text-zinc-400 uppercase tracking-widest">
            BİYOLOJİK RİTİM VE EKOSİSTEM İFLASI
          </span>
          <span className="text-xs font-mono text-red-400 font-bold">
            SİRKADİYEN ÇÖKÜŞ
          </span>
        </div>
        <div className="grid grid-cols-3 gap-4 text-center">
          <div className="bg-zinc-900 p-3 rounded-xl border border-zinc-800">
            <div className="text-2xl font-black text-amber-400">0 LUX</div>
            <div className="text-[11px] text-zinc-400 mt-1">Gece Karanlığı</div>
          </div>
          <div className="bg-zinc-900 p-3 rounded-xl border border-zinc-800">
            <div className="text-2xl font-black text-red-500">-%100</div>
            <div className="text-[11px] text-zinc-400 mt-1">Melatonin Salgısı</div>
          </div>
          <div className="bg-zinc-900 p-3 rounded-xl border border-zinc-800">
            <div className="text-2xl font-black text-orange-400">ÖLÜMCÜL</div>
            <div className="text-[11px] text-zinc-400 mt-1">Fotosentez Şoku</div>
          </div>
        </div>
      </div>
    </div>
  );
};

// -------------------------------------------------------------
// SCENE 4: THERMAL COLLAPSE (+85°C & Boiling Oceans)
// -------------------------------------------------------------
const SceneThermalCollapse: React.FC<{ frame: number; scene: SceneData }> = ({
  frame,
  scene,
}) => {
  const local = frame - scene.startFrame;
  const progress = Math.min(1, local / 95);
  const currentTemp = Math.round(15 + progress * 70);

  return (
    <div className="relative w-full h-full flex items-center justify-center px-12">
      <div className="w-full max-w-[900px] grid grid-cols-12 gap-8 items-center">
        {/* Giant Vertical Thermometer */}
        <div className="col-span-5 bg-zinc-950/90 border border-orange-500/40 rounded-3xl p-6 flex flex-col items-center shadow-[0_0_60px_rgba(249,115,22,0.25)]">
          <div className="flex items-center space-x-2 text-xs font-mono text-orange-400 mb-6 font-bold">
            <Thermometer className="w-5 h-5 animate-pulse" />
            <span>KÜRESEL ISI İNDEKSİ</span>
          </div>

          <div className="relative w-16 h-[500px] bg-zinc-900 rounded-full border-2 border-zinc-700 overflow-hidden flex flex-col justify-end p-1.5">
            <div
              className="w-full rounded-full transition-all duration-300"
              style={{
                height: `${(currentTemp / 100) * 100}%`,
                background:
                  "linear-gradient(to top, #f59e0b, #f97316, #ef4444)",
                boxShadow: "0 0 28px rgba(239,68,68,0.9)",
              }}
            />
            <div className="absolute inset-0 flex flex-col justify-between py-6 px-1 text-[10px] font-mono text-zinc-500 pointer-events-none">
              <span>100°C</span>
              <span>80°C</span>
              <span>50°C</span>
              <span>20°C</span>
              <span>0°C</span>
            </div>
          </div>

          <div className="mt-6 text-center">
            <div className="text-5xl font-black text-transparent bg-clip-text bg-gradient-to-r from-orange-400 to-red-500">
              +{currentTemp}°C
            </div>
            <div className="text-xs font-mono text-red-400 font-bold mt-1">
              {currentTemp > 65 ? "ÖLÜMCÜL TERMAL ALARM" : "HIZLA YÜKSELİYOR"}
            </div>
          </div>
        </div>

        {/* Scorched Earth Graphic & Impact Cards */}
        <div className="col-span-7 space-y-6">
          {/* Scorched 3D Earth Preview */}
          <div className="bg-zinc-950/90 border border-red-500/40 rounded-2xl p-6 flex items-center space-x-6 shadow-xl">
            <svg width="120" height="120" viewBox="0 0 120 120">
              <Realistic3DEarth
                x={60}
                y={60}
                radius={48}
                frame={frame}
                state="scorched"
              />
            </svg>
            <div>
              <div className="text-xs font-mono text-red-400 font-bold">
                KAVRULAN GEZEGEN
              </div>
              <div className="text-xl font-black text-white mt-1">
                MAGMA VE BUHAR ÇAĞI
              </div>
              <div className="text-xs text-zinc-400 mt-1">
                Karasal bitki örtüsü kendiliğinden alev alır.
              </div>
            </div>
          </div>

          <div className="bg-zinc-950/90 border border-red-500/40 rounded-2xl p-6 shadow-xl">
            <div className="flex items-center justify-between mb-3">
              <span className="text-xs font-mono text-zinc-400">
                OKYANUS SULARININ BUHARLAŞMASI
              </span>
              <span className="text-xs font-mono text-red-500 font-bold">
                KAYNAMA NOKTASI
              </span>
            </div>
            <div className="text-3xl font-black text-white mb-2">
              %72 SU KAYBI
            </div>
            <div className="w-full bg-zinc-900 h-3 rounded-full overflow-hidden border border-zinc-800">
              <div
                className="h-full bg-red-600 rounded-full"
                style={{ width: `${progress * 72}%` }}
              />
            </div>
            <p className="text-xs text-zinc-400 mt-3 leading-relaxed">
              Milyarlarca ton su gökyüzüne buharlaşır; kontrolsüz sera etkisiyle
              Dünya devasa bir düdüklü tencereye döner.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

// -------------------------------------------------------------
// SCENE 5: RADIATION STORM (Solar Wind & Breached Magnetosphere)
// -------------------------------------------------------------
const SceneRadiationStorm: React.FC<{ frame: number; scene: SceneData }> = ({
  frame,
  scene,
}) => {
  const local = frame - scene.startFrame;
  const pulse = Math.sin(local * 0.4) * 8;

  return (
    <div className="relative w-full h-full flex flex-col items-center justify-center px-10">
      <div className="relative w-[880px] h-[700px] bg-zinc-950/90 border border-purple-500/50 rounded-3xl overflow-hidden shadow-[0_0_70px_rgba(168,85,247,0.25)] flex items-center justify-center">
        <svg className="w-full h-full absolute inset-0">
          {/* Earth Center Shielded */}
          <Realistic3DEarth
            x={440}
            y={350}
            radius={70}
            frame={frame}
            state="shielded"
          />

          {/* Magnetic Bow Shock Waves */}
          <path
            d={`M 310 ${190 + pulse} Q ${240 - pulse} 350 310 ${510 - pulse}`}
            fill="none"
            stroke="#a855f7"
            strokeWidth="5"
            filter="drop-shadow(0 0 16px #a855f7)"
          />
          <path
            d={`M 570 ${190 - pulse} Q ${640 + pulse} 350 570 ${510 + pulse}`}
            fill="none"
            stroke="#ec4899"
            strokeWidth="5"
            filter="drop-shadow(0 0 16px #ec4899)"
          />

          {/* Plasma Streams Left */}
          {[...Array(6)].map((_, i) => (
            <line
              key={`left-${i}`}
              x1="0"
              y1={170 + i * 70 + pulse}
              x2="280"
              y2={200 + i * 60}
              stroke="#fbbf24"
              strokeWidth="3.5"
              strokeDasharray="14,14"
              opacity="0.8"
            />
          ))}

          {/* Plasma Streams Right */}
          {[...Array(6)].map((_, i) => (
            <line
              key={`right-${i}`}
              x1="880"
              y1={170 + i * 70 - pulse}
              x2="600"
              y2={200 + i * 60}
              stroke="#ef4444"
              strokeWidth="3.5"
              strokeDasharray="14,14"
              opacity="0.8"
            />
          ))}
        </svg>

        {/* Live Gauges */}
        <div className="absolute top-6 left-6 bg-purple-950/80 border border-purple-500 rounded-xl px-4 py-2 flex items-center space-x-3">
          <ShieldAlert className="w-5 h-5 text-purple-400" />
          <span className="text-xs font-mono text-purple-200 font-bold">
            MANYETİK KALKAN DELİNİYOR
          </span>
        </div>

        <div className="absolute bottom-6 left-6 bg-zinc-900/90 border border-zinc-700 rounded-2xl p-4 font-mono text-xs">
          <div className="text-zinc-400">UV RADYASYON İNDEKSİ</div>
          <div className="text-3xl font-black text-red-500 mt-1">35+ UV</div>
          <div className="text-[10px] text-zinc-400">NORMAL MAX: 11 UV</div>
        </div>

        <div className="absolute bottom-6 right-6 bg-zinc-900/90 border border-zinc-700 rounded-2xl p-4 font-mono text-xs text-right">
          <div className="text-zinc-400">OZON TABAKASI TAHRİBATI</div>
          <div className="text-3xl font-black text-amber-400 mt-1">%100</div>
          <div className="text-[10px] text-zinc-400">TAM KALKAN KAYBI</div>
        </div>
      </div>

      <div className="w-full max-w-[880px] bg-red-950/90 border border-red-500 rounded-2xl p-4 mt-6 flex items-center justify-between text-xs text-red-200 font-mono">
        <div className="flex items-center space-x-3">
          <Zap className="w-5 h-5 text-red-400 animate-bounce" />
          <span>CANLI HÜCRELER DAKİKALAR İÇİNDE DNA TAHRİBATIYLA YOK OLUR</span>
        </div>
        <span className="bg-red-600 text-white font-bold px-3 py-1 rounded">
          ÖLÜMCÜL DOZ
        </span>
      </div>
    </div>
  );
};

// -------------------------------------------------------------
// SCENE 6: SCIENTIFIC OUTRO (The Miracle of One Sun)
// -------------------------------------------------------------
const SceneScientificOutro: React.FC<{ frame: number; scene: SceneData }> = ({
  frame,
  scene,
}) => {
  return (
    <div className="relative w-full h-full flex flex-col items-center justify-center px-12">
      <div className="w-full max-w-[900px] grid grid-cols-2 gap-8 mb-8">
        {/* Single Sun (Life) */}
        <div className="bg-gradient-to-b from-emerald-950/70 to-zinc-950 border-2 border-emerald-500/50 rounded-3xl p-6 shadow-[0_0_50px_rgba(16,185,129,0.25)]">
          <div className="flex items-center space-x-3 mb-4">
            <div className="p-3 bg-emerald-500/20 rounded-xl text-emerald-400">
              <Sun className="w-8 h-8" />
            </div>
            <div>
              <div className="text-xs font-mono text-emerald-400 font-bold">
                BİZİM SİSTEMİMİZ
              </div>
              <div className="text-2xl font-black text-white">TEK GÜNEŞ</div>
            </div>
          </div>
          <ul className="space-y-2.5 text-xs text-zinc-300">
            <li className="flex items-center space-x-2">
              <span className="text-emerald-400 font-bold">✔</span>
              <span>Kararlı, eliptik yörünge dengesi</span>
            </li>
            <li className="flex items-center space-x-2">
              <span className="text-emerald-400 font-bold">✔</span>
              <span>12 saat gündüz / 12 saat gece döngüsü</span>
            </li>
            <li className="flex items-center space-x-2">
              <span className="text-emerald-400 font-bold">✔</span>
              <span>Sıvı okyanuslar & 15°C optimum iklim</span>
            </li>
            <li className="flex items-center space-x-2">
              <span className="text-emerald-400 font-bold">✔</span>
              <span>Koruyucu manyetosfer kalkanı</span>
            </li>
          </ul>
        </div>

        {/* Double Sun (Chaos) */}
        <div className="bg-gradient-to-b from-red-950/70 to-zinc-950 border-2 border-red-500/50 rounded-3xl p-6 shadow-[0_0_50px_rgba(239,68,68,0.25)]">
          <div className="flex items-center space-x-3 mb-4">
            <div className="p-3 bg-red-500/20 rounded-xl text-red-400">
              <Flame className="w-8 h-8" />
            </div>
            <div>
              <div className="text-xs font-mono text-red-400 font-bold">
                İKİLİ YILDIZ SİSTEMİ
              </div>
              <div className="text-2xl font-black text-white">ÇİFT GÜNEŞ</div>
            </div>
          </div>
          <ul className="space-y-2.5 text-xs text-zinc-300">
            <li className="flex items-center space-x-2">
              <span className="text-red-400 font-bold">✖</span>
              <span>Kaotik 3 cisim yörünge çöküşü</span>
            </li>
            <li className="flex items-center space-x-2">
              <span className="text-red-400 font-bold">✖</span>
              <span>Gece yok, 24 saat aralıksız kavurucu ışık</span>
            </li>
            <li className="flex items-center space-x-2">
              <span className="text-red-400 font-bold">✖</span>
              <span>85°C sıcaklık ve kaynayan okyanuslar</span>
            </li>
            <li className="flex items-center space-x-2">
              <span className="text-red-400 font-bold">✖</span>
              <span>Ölümcül solar fırtına bombardımanı</span>
            </li>
          </ul>
        </div>
      </div>

      {/* ROTA MEDYA CTA */}
      <div className="w-full max-w-[900px] bg-zinc-950/90 border border-amber-500/50 rounded-3xl p-8 flex items-center justify-between shadow-[0_16px_50px_rgba(0,0,0,0.9)]">
        <div className="flex items-center space-x-5">
          <div className="w-16 h-16 rounded-2xl bg-gradient-to-tr from-amber-400 to-orange-600 flex items-center justify-center font-black text-2xl text-black shadow-lg">
            R+
          </div>
          <div>
            <div className="text-2xl font-black tracking-wider text-white">
              ROTA MEDYA // BİLİM
            </div>
            <div className="text-xs font-mono text-amber-400 tracking-widest mt-1">
              HER GÜN YENİ BİR BİLİMSEL SİMÜLASYON
            </div>
          </div>
        </div>

        <div className="px-7 py-3.5 rounded-2xl bg-gradient-to-r from-amber-400 to-orange-500 text-black font-black text-sm tracking-wider shadow-[0_0_30px_rgba(245,158,11,0.6)]">
          BEĞEN & ABONE OL
        </div>
      </div>
    </div>
  );
};

// -------------------------------------------------------------
// BOTTOM SUBTITLE BAR WITH ACTIVE WORD KARAOKE HIGHLIGHT
// -------------------------------------------------------------
const SubtitleBar: React.FC<{ activeScene: SceneData; frame: number }> = ({
  activeScene,
  frame,
}) => {
  return (
    <div className="absolute bottom-16 left-0 w-full px-12 z-50">
      <div className="bg-zinc-950/90 backdrop-blur-2xl border border-zinc-800/90 rounded-3xl p-7 shadow-[0_25px_70px_rgba(0,0,0,0.9)]">
        <div className="flex items-center justify-between text-[11px] font-mono text-zinc-500 mb-3 border-b border-zinc-900 pb-2">
          <div className="flex items-center space-x-2">
            <span className="w-2 h-2 rounded-full bg-emerald-500" />
            <span>NEURAL TÜRKÇE ANLATIM</span>
          </div>
          <span className="text-amber-400 font-semibold tracking-wider">
            CANLI KELİME TAKİBİ
          </span>
        </div>

        <p className="text-2xl font-medium leading-relaxed text-zinc-300">
          {activeScene.words.map((w, i) => {
            const isActive = frame >= w.startFrame && frame <= w.endFrame;
            return (
              <span
                key={`${w.text}-${i}`}
                className={`inline-block mr-2 px-1 rounded transition-all duration-150 ${
                  isActive
                    ? "bg-amber-400 text-black font-black scale-105 shadow-[0_0_20px_rgba(251,191,36,0.7)]"
                    : "text-zinc-200"
                }`}
              >
                {w.text}
              </span>
            );
          })}
        </p>
      </div>
    </div>
  );
};
