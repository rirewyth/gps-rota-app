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
  CloudRain,
  Compass,
  Droplet,
  Flame,
  Globe,
  Layers,
  MapPin,
  ShieldAlert,
  Sparkles,
  Waves,
  Wind,
  Zap,
} from "lucide-react";
import masterData from "./master_istanbul_sel_scenes.json";

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

export const IstanbulSelVideo: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Find active scene
  const activeScene =
    (masterData.scenes as SceneData[]).find(
      (s) => frame >= s.startFrame && frame < s.endFrame
    ) || (masterData.scenes[masterData.scenes.length - 1] as SceneData);

  return (
    <AbsoluteFill className="bg-[#030712] text-white font-sans overflow-hidden select-none">
      {/* 1. MASTER AUDIO (Neural Voiceover + Storm Ambiance + Cinematic SFX) */}
      <Audio src={staticFile("istanbul_sel/istanbul_sel_master_soundtrack.mp3")} />

      {/* 2. ATMOSPHERIC STORM RAIN PARTICLES & RADAR GRID */}
      <StormBackground frame={frame} />

      {/* 3. TOP TECHNICAL HUD & HEADER */}
      <HeaderHUD activeScene={activeScene} frame={frame} fps={fps} />

      {/* 4. MAIN INFOGRAPHIC VISUAL STAGE */}
      <div
        className="absolute top-[280px] left-0 w-full h-[1260px] flex items-center justify-center"
        style={{ perspective: 1200 }}
      >
        {activeScene.type === "istanbul_radar" && (
          <SceneIstanbulRadar frame={frame} scene={activeScene} />
        )}
        {activeScene.type === "hydrophobic_soil" && (
          <SceneHydrophobicSoil frame={frame} scene={activeScene} />
        )}
        {activeScene.type === "concrete_urban" && (
          <SceneConcreteUrban frame={frame} scene={activeScene} />
        )}
        {activeScene.type === "supercell_storm" && (
          <SceneSupercellStorm frame={frame} scene={activeScene} />
        )}
        {activeScene.type === "sponge_city" && (
          <SceneSpongeCity frame={frame} scene={activeScene} />
        )}
        {activeScene.type === "scientific_outro" && (
          <SceneScientificOutro frame={frame} scene={activeScene} />
        )}
      </div>

      {/* 5. BOTTOM KARAOKE SUBTITLE BAR */}
      <SubtitleBar activeScene={activeScene} frame={frame} />

      {/* 6. VIGNETTE OVERLAY */}
      <div className="absolute inset-0 pointer-events-none shadow-[inset_0_0_150px_rgba(0,0,0,0.85)] z-50" />
    </AbsoluteFill>
  );
};

// -------------------------------------------------------------
// STORM BACKGROUND: Radar Grid + Vertical Rain Streaks
// -------------------------------------------------------------
const StormBackground: React.FC<{ frame: number }> = ({ frame }) => {
  const rainDrops = React.useMemo(() => {
    return [...Array(50)].map((_, i) => ({
      x: (i * 23) % 1080,
      y: (i * 47) % 1920,
      length: 25 + (i % 4) * 15,
      speed: 18 + (i % 6) * 5,
      opacity: 0.15 + (i % 3) * 0.15,
    }));
  }, []);

  const lightningFlash = Math.sin(frame * 0.05) > 0.96 ? 0.25 : 0;

  return (
    <div className="absolute inset-0 pointer-events-none overflow-hidden">
      {/* Background Storm Clouds Glow */}
      <div
        className="absolute w-[800px] h-[800px] -top-40 -left-40 rounded-full blur-[140px] opacity-25"
        style={{
          background:
            "radial-gradient(circle, rgba(2,132,199,0.5) 0%, rgba(30,58,138,0.2) 60%, transparent 100%)",
        }}
      />
      <div
        className="absolute w-[900px] h-[900px] -bottom-40 -right-40 rounded-full blur-[160px] opacity-20"
        style={{
          background:
            "radial-gradient(circle, rgba(220,38,38,0.4) 0%, rgba(88,28,135,0.2) 60%, transparent 100%)",
        }}
      />

      {/* Lightning ambient flash */}
      {lightningFlash > 0 && (
        <div
          className="absolute inset-0 bg-cyan-200/20 mix-blend-screen transition-opacity duration-75"
          style={{ opacity: lightningFlash }}
        />
      )}

      {/* Perspective Radar Grid */}
      <svg
        className="absolute inset-0 w-full h-full opacity-15"
        xmlns="http://www.w3.org/2000/svg"
      >
        <defs>
          <pattern
            id="radarGrid"
            width="60"
            height="60"
            patternUnits="userSpaceOnUse"
          >
            <path
              d="M 60 0 L 0 0 0 60"
              fill="none"
              stroke="#0284c7"
              strokeWidth="0.8"
              strokeDasharray="2,4"
            />
            <circle cx="0" cy="0" r="1.5" fill="#0284c7" opacity="0.6" />
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill="url(#radarGrid)" />
      </svg>

      {/* Animated Rain Streaks */}
      <svg className="absolute inset-0 w-full h-full">
        {rainDrops.map((d, i) => {
          const curY = (d.y + frame * d.speed) % 1920;
          return (
            <line
              key={`rain-${i}`}
              x1={d.x}
              y1={curY}
              x2={d.x - 3}
              y2={curY + d.length}
              stroke="#38bdf8"
              strokeWidth="1.5"
              strokeLinecap="round"
              opacity={d.opacity}
            />
          );
        })}
      </svg>

      {/* Corner Target Reticles */}
      <div className="absolute top-8 left-8 w-10 h-10 border-t-2 border-l-2 border-cyan-500/50" />
      <div className="absolute top-8 right-8 w-10 h-10 border-t-2 border-r-2 border-cyan-500/50" />
      <div className="absolute bottom-8 left-8 w-10 h-10 border-b-2 border-l-2 border-cyan-500/50" />
      <div className="absolute bottom-8 right-8 w-10 h-10 border-b-2 border-r-2 border-cyan-500/50" />
    </div>
  );
};

// -------------------------------------------------------------
// TOP HUD & HEADER
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
          <span className="w-2.5 h-2.5 rounded-full bg-cyan-400 animate-ping inline-block" />
          <span className="text-zinc-200 font-bold tracking-widest">
            ROTA BİLİM // AFET ANALİZİ
          </span>
          <span className="text-zinc-600">|</span>
          <span className="text-cyan-400 font-semibold">{activeScene.tag}</span>
        </div>
        <div className="flex items-center space-x-3">
          <span className="text-zinc-400 font-mono">T+{seconds}s</span>
          <span className="bg-cyan-500/10 border border-cyan-500/30 text-cyan-300 px-2 py-0.5 rounded text-[10px] font-bold">
            VERİ: MGM & AKOM
          </span>
        </div>
      </div>

      {/* Category Badge */}
      <div className="inline-flex items-center space-x-2 px-3.5 py-1.5 rounded-full bg-cyan-500/15 border border-cyan-500/40 text-cyan-300 text-xs font-bold tracking-widest uppercase mb-2 shadow-[0_0_15px_rgba(6,182,212,0.25)]">
        <CloudRain className="w-4 h-4 text-cyan-400" />
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
        <h1 className="text-5xl font-black tracking-tight text-transparent bg-clip-text bg-gradient-to-r from-cyan-400 via-sky-400 to-blue-500 drop-shadow-[0_4px_30px_rgba(14,165,233,0.5)]">
          {activeScene.glow_title}
        </h1>
      </div>
    </div>
  );
};

// -------------------------------------------------------------
// SCENE 1: ISTANBUL DOPPLER RADAR & RECORD RAINFALL
// -------------------------------------------------------------
const SceneIstanbulRadar: React.FC<{ frame: number; scene: SceneData }> = ({
  frame,
  scene,
}) => {
  const local = frame - scene.startFrame;
  const radarSweep = (local * 4) % 360;
  const progress = Math.min(1, local / 120);
  const currentRain = Math.round(progress * 272);

  return (
    <div className="relative w-full h-full flex flex-col items-center justify-center px-10">
      {/* Doppler Weather Radar Container */}
      <div className="relative w-[880px] h-[720px] bg-zinc-950/90 border border-cyan-500/40 rounded-3xl overflow-hidden shadow-[0_0_80px_rgba(6,182,212,0.2)] flex items-center justify-center">
        {/* Radar Range Rings */}
        <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
          <div className="w-[640px] h-[640px] rounded-full border border-cyan-500/20" />
          <div className="w-[460px] h-[460px] rounded-full border border-cyan-500/25" />
          <div className="w-[280px] h-[280px] rounded-full border border-cyan-500/30" />
          <div className="w-[100px] h-[100px] rounded-full border border-cyan-500/40" />
          <div className="w-full h-px bg-cyan-500/20 absolute" />
          <div className="h-full w-px bg-cyan-500/20 absolute" />
        </div>

        {/* Rotating Doppler Radar Beam */}
        <div
          className="absolute w-[640px] h-[640px] rounded-full pointer-events-none"
          style={{
            transform: `rotate(${radarSweep}deg)`,
            background:
              "conic-gradient(from 0deg, rgba(6,182,212,0.4) 0deg, rgba(6,182,212,0) 60deg, transparent 360deg)",
          }}
        />

        {/* Stylized Istanbul Map & Extreme Storm Cell */}
        <svg className="w-full h-full absolute inset-0">
          {/* Black Sea & Marmara Outline */}
          <path
            d="M 120 220 Q 280 200 440 240 Q 600 210 760 190"
            fill="none"
            stroke="#0369a1"
            strokeWidth="3"
            strokeDasharray="6,6"
            opacity="0.6"
          />
          <path
            d="M 160 520 Q 340 540 500 510 Q 680 530 800 500"
            fill="none"
            stroke="#0369a1"
            strokeWidth="3"
            strokeDasharray="6,6"
            opacity="0.6"
          />
          {/* Bosphorus Strait Channel */}
          <path
            d="M 440 240 Q 470 340 450 420 Q 480 480 500 510"
            fill="none"
            stroke="#38bdf8"
            strokeWidth="6"
            opacity="0.8"
          />

          {/* Supercell Heavy Rain Core (Red/Purple Blobs over Beykoz & Sarıyer) */}
          <circle
            cx="490"
            cy="320"
            r="110"
            fill="url(#stormCoreGrad)"
            opacity="0.85"
            filter="drop-shadow(0 0 35px #ef4444)"
          />
          <circle
            cx="410"
            cy="360"
            r="85"
            fill="url(#stormCoreGrad)"
            opacity="0.8"
            filter="drop-shadow(0 0 25px #dc2626)"
          />

          {/* District Location Pins */}
          <g transform="translate(520, 310)">
            <circle r="6" fill="#f87171" className="animate-ping" />
            <circle r="4" fill="#ffffff" />
            <text x="12" y="5" fill="#fecaca" fontSize="13" fontFamily="monospace" fontWeight="bold">
              BEYKOZ: 272 kg/m²
            </text>
          </g>
          <g transform="translate(380, 330)">
            <circle r="6" fill="#f87171" className="animate-ping" />
            <circle r="4" fill="#ffffff" />
            <text x="-135" y="5" fill="#fecaca" fontSize="13" fontFamily="monospace" fontWeight="bold">
              SARIYER: 208 kg/m²
            </text>
          </g>

          <defs>
            <radialGradient id="stormCoreGrad" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stopColor="#7e22ce" stopOpacity="0.95" />
              <stop offset="45%" stopColor="#ef4444" stopOpacity="0.85" />
              <stop offset="75%" stopColor="#f59e0b" stopOpacity="0.7" />
              <stop offset="100%" stopColor="#10b981" stopOpacity="0" />
            </radialGradient>
          </defs>
        </svg>

        {/* Live Top Hazard Tag */}
        <div className="absolute top-6 left-6 bg-red-950/85 border border-red-500 rounded-xl px-4 py-2 flex items-center space-x-2 text-red-300 font-mono text-xs shadow-xl">
          <AlertOctagon className="w-5 h-5 text-red-400 animate-spin" />
          <span className="font-bold">SON 84 YILIN EN ŞİDDETLİ YAĞIŞI (1942-2026)</span>
        </div>

        {/* Live Rainfall Meter Card */}
        <div className="absolute bottom-6 right-6 bg-zinc-950/90 border border-cyan-500/50 rounded-2xl p-5 text-right font-mono text-xs shadow-2xl">
          <div className="text-zinc-400">METREKAREYE DÜŞEN YAĞIŞ</div>
          <div className="text-4xl font-black text-transparent bg-clip-text bg-gradient-to-r from-cyan-400 to-sky-400 mt-1">
            {currentRain} kg/m²
          </div>
          <div className="text-[11px] text-red-400 font-bold mt-1">
            1 AYLIK TOPLAM YAĞIŞ 2 SAATTE İNDİ
          </div>
        </div>
      </div>

      {/* Bottom Summary Bar */}
      <div className="w-full max-w-[880px] bg-zinc-950/90 border border-zinc-800 rounded-2xl p-4 mt-6 flex items-center justify-between text-xs font-mono text-zinc-300">
        <div className="flex items-center space-x-3">
          <Droplet className="w-5 h-5 text-cyan-400" />
          <span>AFET BÖLGELERİ: AYAZAĞA · BEYKOZ · EYÜPSULTAN · KAĞITHANE</span>
        </div>
        <span className="bg-red-600/90 text-white font-bold px-3 py-1 rounded">
          KIRMIZI KOD
        </span>
      </div>
    </div>
  );
};

// -------------------------------------------------------------
// SCENE 2: HYDROPHOBIC SOIL PARADOX (Kuru Toprak Neden Su Tutmaz?)
// -------------------------------------------------------------
const SceneHydrophobicSoil: React.FC<{ frame: number; scene: SceneData }> = ({
  frame,
  scene,
}) => {
  const local = frame - scene.startFrame;
  const animProgress = Math.min(1, local / 90);

  return (
    <div className="relative w-full h-full flex flex-col items-center justify-center px-10">
      {/* Soil Cross-Section Interactive Diagram */}
      <div className="relative w-[880px] h-[680px] bg-zinc-950/90 border border-amber-500/40 rounded-3xl overflow-hidden shadow-[0_0_80px_rgba(245,158,11,0.2)] p-8 flex flex-col justify-between">
        {/* Top Header & Paradox Tag */}
        <div className="flex items-center justify-between border-b border-zinc-800 pb-4">
          <div>
            <div className="text-xs font-mono text-amber-400 font-bold">
              BİLİMSEL MEKANİZMA
            </div>
            <div className="text-2xl font-black text-white mt-0.5">
              HİDROFOBİK TOPRAK ETKİSİ
            </div>
          </div>
          <div className="bg-amber-500/20 border border-amber-500/40 px-3.5 py-1.5 rounded-full text-xs font-mono text-amber-300 font-bold">
            TAŞLAŞMA & TIKANMA
          </div>
        </div>

        {/* Visual Cross Section: Falling Rain Bouncing off Baked Crust */}
        <div className="relative w-full h-[360px] bg-gradient-to-b from-sky-950/40 via-zinc-900 to-amber-950/60 rounded-2xl border border-zinc-800 overflow-hidden flex flex-col justify-end p-6">
          {/* Incoming Rain Streams */}
          <div className="absolute top-4 inset-x-8 flex justify-around">
            {[...Array(8)].map((_, i) => (
              <div key={i} className="flex flex-col items-center animate-pulse">
                <Droplet className="w-6 h-6 text-cyan-400 mb-1" />
                <div className="w-1 h-16 bg-gradient-to-b from-cyan-400 to-transparent" />
              </div>
            ))}
          </div>

          {/* Baked Crust Layer (Hardened Concrete-like Soil) */}
          <div className="relative w-full h-16 bg-gradient-to-r from-amber-700 via-amber-800 to-stone-800 rounded-xl border-t-4 border-amber-500 flex items-center justify-between px-6 shadow-2xl">
            <span className="text-xs font-mono text-amber-200 font-black tracking-widest">
              FIRINLANMIŞ KURU TOPRAK TABAKASI (GEÇİRİMSİZ KABUK)
            </span>
            <span className="text-xs font-mono text-red-400 font-black">
              SU GEÇİRMEZ!
            </span>
          </div>

          {/* Surface Runoff Arrows (Water bouncing & rushing horizontally) */}
          <div className="relative w-full h-14 mt-2 flex items-center justify-between px-4">
            <div className="flex items-center space-x-2 text-cyan-400 font-mono text-sm font-bold">
              <span>◀◀ DEV YÜZEY AKIŞI (SEL DALGASI)</span>
            </div>
            <div className="flex items-center space-x-2 text-cyan-400 font-mono text-sm font-bold">
              <span>DEV YÜZEY AKIŞI (SEL DALGASI) ▶▶</span>
            </div>
          </div>

          {/* Dry deep soil below */}
          <div className="w-full h-12 bg-stone-950 rounded-lg flex items-center justify-center text-xs font-mono text-zinc-500">
            KUPKURU DERİN KATMAN (EMİLEMEYEN SU: SIFIR BESLENME)
          </div>
        </div>

        {/* Comparative Infographic Gauges */}
        <div className="grid grid-cols-2 gap-6">
          <div className="bg-zinc-900/90 border border-zinc-800 rounded-2xl p-4">
            <div className="text-xs font-mono text-zinc-400">
              NORMAL NEMLİ TOPRAK
            </div>
            <div className="text-2xl font-black text-emerald-400 mt-1">
              %85 EMİLİM
            </div>
            <p className="text-[11px] text-zinc-400 mt-1">
              Gözenekler açıktır, su yeraltı havzalarına süzülür.
            </p>
          </div>

          <div className="bg-zinc-900/90 border border-red-500/50 rounded-2xl p-4 shadow-lg">
            <div className="text-xs font-mono text-red-400 font-bold">
              KURAKLIK SONRASI TAŞLAŞMIŞ TOPRAK
            </div>
            <div className="text-2xl font-black text-red-500 mt-1">
              %92 YÜZEY AKIŞI
            </div>
            <p className="text-[11px] text-zinc-300 mt-1">
              Su yüzeyde birikir ve dakikalar içinde sele dönüşür.
            </p>
          </div>
        </div>
      </div>

      {/* Quote Banner */}
      <div className="w-full max-w-[880px] bg-amber-950/80 border border-amber-500/40 rounded-2xl p-4 mt-6 text-xs font-mono text-amber-200">
        💡 <span className="font-bold">Fiziksel Gerçek:</span> Toprak ne kadar kuruysa, ani sağanağı emmesi o kadar zordur.
      </div>
    </div>
  );
};

// -------------------------------------------------------------
// SCENE 3: CONCRETE JUNGLE & COVERED RIVERBEDS
// -------------------------------------------------------------
const SceneConcreteUrban: React.FC<{ frame: number; scene: SceneData }> = ({
  frame,
  scene,
}) => {
  const local = frame - scene.startFrame;

  return (
    <div className="relative w-full h-full flex flex-col items-center justify-center px-10">
      <div className="w-full max-w-[880px] grid grid-cols-12 gap-8 items-center">
        {/* Urban Concrete Cross-Section Illustration (7 Cols) */}
        <div className="col-span-7 bg-zinc-950/90 border border-zinc-800 rounded-3xl p-6 shadow-2xl">
          <div className="flex items-center space-x-2 text-xs font-mono text-zinc-400 mb-4 font-bold">
            <Layers className="w-4 h-4 text-cyan-400" />
            <span>İSTANBUL ZEMİN PROFİLİ VE DERELER</span>
          </div>

          {/* Concrete vs Water Graphic */}
          <div className="relative w-full h-[400px] bg-zinc-900 rounded-2xl overflow-hidden border border-zinc-700/80 p-5 flex flex-col justify-between">
            {/* Skyline Buildings */}
            <div className="flex items-end justify-between px-4 pt-6 space-x-3">
              <div className="w-16 h-44 bg-zinc-700 rounded-t-lg border-t-2 border-zinc-500" />
              <div className="w-20 h-56 bg-zinc-600 rounded-t-lg border-t-2 border-zinc-400" />
              <div className="w-14 h-36 bg-zinc-700 rounded-t-lg border-t-2 border-zinc-500" />
              <div className="w-24 h-64 bg-zinc-500 rounded-t-lg border-t-2 border-zinc-300" />
              <div className="w-16 h-48 bg-zinc-600 rounded-t-lg border-t-2 border-zinc-400" />
            </div>

            {/* Asphalt Surface Level (Flooding River) */}
            <div className="relative w-full h-16 bg-sky-600/90 rounded-xl border-t-4 border-cyan-300 flex items-center justify-between px-6 shadow-2xl animate-pulse">
              <div className="flex items-center space-x-2 font-mono text-xs font-black text-white">
                <Waves className="w-5 h-5 text-cyan-200" />
                <span>CADDELER VE ALT GEÇİTLER NEHRE DÖNÜŞTÜ</span>
              </div>
              <span className="text-[10px] font-mono bg-black/40 text-cyan-200 px-2 py-1 rounded">
                DEBİ: 450 m³/s
              </span>
            </div>

            {/* Paved Over Historic Stream Culvert */}
            <div className="w-full h-14 bg-zinc-950 border-2 border-dashed border-red-500/60 rounded-xl flex items-center justify-center text-xs font-mono text-red-400 font-bold">
              🚫 ÜZERİ BETONLA KAPATILMIŞ TARİHİ DERE YATAĞI
            </div>
          </div>

          <div className="mt-4 flex items-center justify-between text-xs font-mono text-zinc-400">
            <span>GEÇİRİMSİZ ALAN ORANI:</span>
            <span className="text-xl font-black text-red-500">%80+ BETON & ASFALT</span>
          </div>
        </div>

        {/* Right Info Cards (5 Cols) */}
        <div className="col-span-5 space-y-6">
          <div className="bg-zinc-950/90 border border-red-500/40 rounded-2xl p-6 shadow-xl">
            <div className="text-xs font-mono text-red-400 font-bold mb-2">
              KAYIP DERELER TUZAĞI
            </div>
            <div className="text-xl font-black text-white mb-2">
              SU HAFIZASINI UNUTMAZ
            </div>
            <p className="text-xs text-zinc-300 leading-relaxed">
              Kağıthane, Ayazağa ve Ayamama gibi tarihi derelerin üzerine binalar
              ve yollar yapıldığında, su eski akış rotasını zorla geri alır.
            </p>
          </div>

          <div className="bg-zinc-950/90 border border-amber-500/40 rounded-2xl p-6 shadow-xl">
            <div className="text-xs font-mono text-amber-400 font-bold mb-2">
              KENTSEL ISI ADASI
            </div>
            <div className="text-xl font-black text-white mb-2">
              FIRTINAYI ŞEHRE KİLİTLER
            </div>
            <p className="text-xs text-zinc-300 leading-relaxed">
              Milyonlarca metrekarelik sıcak beton, yükseltici termal hava
              akımıyla yağmur bulutlarını şehrin göbeğine mıknatıs gibi çeker.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

// -------------------------------------------------------------
// SCENE 4: METEOROLOGICAL COLLISION & SUPERCELL
// -------------------------------------------------------------
const SceneSupercellStorm: React.FC<{ frame: number; scene: SceneData }> = ({
  frame,
  scene,
}) => {
  const local = frame - scene.startFrame;
  const pulse = Math.sin(local * 0.3) * 6;

  return (
    <div className="relative w-full h-full flex flex-col items-center justify-center px-10">
      {/* Supercell Atmospheric Collision Graphic */}
      <div className="relative w-[880px] h-[720px] bg-zinc-950/90 border border-purple-500/40 rounded-3xl overflow-hidden shadow-[0_0_80px_rgba(168,85,247,0.25)] p-8 flex flex-col justify-between">
        <div className="flex items-center justify-between border-b border-zinc-800 pb-3">
          <div className="flex items-center space-x-2 text-xs font-mono text-purple-400 font-bold">
            <Zap className="w-4 h-4 animate-bounce text-yellow-400" />
            <span>ATMOSFERİK PATLAMA MEKANİZMASI</span>
          </div>
          <span className="text-xs font-mono text-red-400 font-bold">
            V-ŞEKİLLİ SÜPER HÜCRE
          </span>
        </div>

        {/* 14.000m Giant Storm Cloud Visual */}
        <div className="relative w-full h-[400px] bg-gradient-to-t from-slate-950 via-zinc-900 to-indigo-950 rounded-2xl border border-zinc-800 p-6 flex flex-col justify-between overflow-hidden">
          {/* Upper Polar Cold Trough (-25°C) */}
          <div className="flex items-center justify-between">
            <span className="text-xs font-mono text-cyan-300 font-bold">
              ÜST SEVİYE KUTUPSAL SOĞUK HAVA (-25°C)
            </span>
            <span className="text-[10px] font-mono bg-cyan-950 text-cyan-300 px-2 py-0.5 rounded">
              İRTİFA: 12.000m
            </span>
          </div>

          {/* Cumulonimbus Thundercloud Anvil */}
          <div className="relative w-full flex items-center justify-center my-4">
            <div
              className="w-[620px] h-36 bg-gradient-to-b from-zinc-700 via-slate-800 to-zinc-900 rounded-full blur-[2px] border-t-2 border-cyan-300 flex items-center justify-center shadow-2xl"
              style={{ transform: `scale(${1 + pulse * 0.01})` }}
            >
              <div className="text-center">
                <div className="text-lg font-black text-amber-300 tracking-wider">
                  CUMULONIMBUS BULUTU (SÜPER HÜCRE)
                </div>
                <div className="text-[11px] font-mono text-cyan-200 mt-1">
                  DİKEY GELİŞİM: 14 KİLOMETRE
                </div>
              </div>
            </div>
          </div>

          {/* Sea Surface Heat Bomb (+4°C Anomali) */}
          <div className="flex items-center justify-between border-t border-zinc-800 pt-3">
            <div className="flex items-center space-x-2">
              <Flame className="w-5 h-5 text-red-500 animate-pulse" />
              <span className="text-xs font-mono text-red-400 font-bold">
                REKOR DENİZ SUYU SICAKLIĞI (+4°C ANOMALİ)
              </span>
            </div>
            <span className="text-xs font-mono text-zinc-400">
              AKDENİZ & KARADENİZ NEM BOMBASI
            </span>
          </div>
        </div>

        {/* Training Effect Card */}
        <div className="grid grid-cols-2 gap-6">
          <div className="bg-zinc-900/90 border border-zinc-800 rounded-2xl p-4">
            <div className="text-xs font-mono text-zinc-400">
              TRAINING ETKİSİ (KONVEKTİF TREN)
            </div>
            <div className="text-xl font-black text-white mt-1">
              AYNI HATTA KİLİTLENME
            </div>
            <p className="text-[11px] text-zinc-400 mt-1">
              Bulutlar peş peşe vagonlar gibi saatlerce aynı ilçelerin üzerine
              yağış boşalttı.
            </p>
          </div>

          <div className="bg-zinc-900/90 border border-purple-500/50 rounded-2xl p-4">
            <div className="text-xs font-mono text-purple-400 font-bold">
              BULUT PATLAMASI (DOWNBURST)
            </div>
            <div className="text-xl font-black text-purple-300 mt-1">
              SU DUVARI İNDİ
            </div>
            <p className="text-[11px] text-zinc-300 mt-1">
              Atmosferde asılı kalan binlerce ton su yerçekimiyle aniden yere
              çöktü.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

// -------------------------------------------------------------
// SCENE 5: SPONGE CITY SOLUTION (Sünger Şehir Modeli)
// -------------------------------------------------------------
const SceneSpongeCity: React.FC<{ frame: number; scene: SceneData }> = ({
  frame,
  scene,
}) => {
  return (
    <div className="relative w-full h-full flex flex-col items-center justify-center px-10">
      <div className="w-full max-w-[880px] bg-zinc-950/90 border border-emerald-500/50 rounded-3xl p-8 shadow-[0_0_80px_rgba(16,185,129,0.2)]">
        <div className="flex items-center justify-between border-b border-zinc-800 pb-4 mb-6">
          <div>
            <div className="text-xs font-mono text-emerald-400 font-bold">
              GELECEĞİN DİRENÇLİ KENTLERİ
            </div>
            <div className="text-3xl font-black text-white mt-1">
              SÜNGER ŞEHİR MODELİ (SPONGE CITY)
            </div>
          </div>
          <span className="bg-emerald-500/20 text-emerald-300 border border-emerald-500/40 text-xs font-mono px-3 py-1.5 rounded-full font-bold">
            SÜRDÜRÜLEBİLİR ÇÖZÜM
          </span>
        </div>

        {/* 3 Core Pillars */}
        <div className="grid grid-cols-3 gap-6 mb-6">
          <div className="bg-zinc-900/90 border border-emerald-500/30 rounded-2xl p-5 text-center">
            <div className="w-12 h-12 mx-auto mb-3 rounded-xl bg-emerald-500/20 flex items-center justify-center text-emerald-400">
              <Layers className="w-6 h-6" />
            </div>
            <div className="text-base font-black text-white">GEÇİRGEN ASFALT</div>
            <p className="text-xs text-zinc-400 mt-2 leading-relaxed">
              Yağmur suyunu anında alt katmanlara emerek göllenmeyi önleyen
              gözenekli kaplama.
            </p>
          </div>

          <div className="bg-zinc-900/90 border border-emerald-500/30 rounded-2xl p-5 text-center">
            <div className="w-12 h-12 mx-auto mb-3 rounded-xl bg-emerald-500/20 flex items-center justify-center text-emerald-400">
              <Sparkles className="w-6 h-6" />
            </div>
            <div className="text-base font-black text-white">YAĞMUR BAHÇELERİ</div>
            <p className="text-xs text-zinc-400 mt-2 leading-relaxed">
              Suyu doğal olarak tutan yeşil koridorlar ve çatı bahçeleriyle %40
              yük azaltma.
            </p>
          </div>

          <div className="bg-zinc-900/90 border border-emerald-500/30 rounded-2xl p-5 text-center">
            <div className="w-12 h-12 mx-auto mb-3 rounded-xl bg-emerald-500/20 flex items-center justify-center text-emerald-400">
              <Waves className="w-6 h-6" />
            </div>
            <div className="text-base font-black text-white">DOĞAL DERE ALANLARI</div>
            <p className="text-xs text-zinc-400 mt-2 leading-relaxed">
              Dere yataklarını kapatmak yerine park ve rekreasyon alanı olarak
              serbest bırakmak.
            </p>
          </div>
        </div>

        {/* Comparison Bar */}
        <div className="bg-zinc-900 rounded-2xl p-4 border border-zinc-800 flex items-center justify-between text-xs font-mono">
          <div className="text-zinc-400">
            KLASİK BETON ŞEHİR: <span className="text-red-400 font-bold">%90 SEL RİSKİ</span>
          </div>
          <div className="text-emerald-400 font-bold">
            SÜNGER ŞEHİR: <span className="text-white font-black">%75 SU DEPOLAMA & GERİ DÖNÜŞÜM</span>
          </div>
        </div>
      </div>
    </div>
  );
};

// -------------------------------------------------------------
// SCENE 6: SCIENTIFIC OUTRO (ROTA BİLİM)
// -------------------------------------------------------------
const SceneScientificOutro: React.FC<{ frame: number; scene: SceneData }> = ({
  frame,
  scene,
}) => {
  return (
    <div className="relative w-full h-full flex flex-col items-center justify-center px-12">
      {/* 3 Summary Takeaways */}
      <div className="w-full max-w-[880px] bg-zinc-950/90 border border-cyan-500/40 rounded-3xl p-8 mb-8 shadow-2xl">
        <div className="text-xs font-mono text-cyan-400 font-bold mb-1">
          ÖZET ANALİZ
        </div>
        <div className="text-2xl font-black text-white mb-6">
          İSTANBUL SELİNİN 3 TEMEL SEBEBİ
        </div>

        <div className="space-y-4">
          <div className="flex items-start space-x-4 bg-zinc-900/80 p-4 rounded-2xl border border-zinc-800">
            <div className="p-2 bg-amber-500/20 text-amber-400 rounded-xl font-bold font-mono">
              01
            </div>
            <div>
              <div className="font-bold text-white text-base">
                Hidrofobik Toprak Etkisi
              </div>
              <div className="text-xs text-zinc-400 mt-0.5">
                Aylarca kuruyan toprak taşlaştı; suyu ememeyip doğrudan sele
                dönüştürdü.
              </div>
            </div>
          </div>

          <div className="flex items-start space-x-4 bg-zinc-900/80 p-4 rounded-2xl border border-zinc-800">
            <div className="p-2 bg-red-500/20 text-red-400 rounded-xl font-bold font-mono">
              02
            </div>
            <div>
              <div className="font-bold text-white text-base">
                Geçirimsiz Beton ve Kayıp Dereler
              </div>
              <div className="text-xs text-zinc-400 mt-0.5">
                Megakentin %80 betonlaşması suyun gidecek doğal yolunu yok etti.
              </div>
            </div>
          </div>

          <div className="flex items-start space-x-4 bg-zinc-900/80 p-4 rounded-2xl border border-zinc-800">
            <div className="p-2 bg-cyan-500/20 text-cyan-400 rounded-xl font-bold font-mono">
              03
            </div>
            <div>
              <div className="font-bold text-white text-base">
                Süper Hücre ve Deniz Isı Bombası
              </div>
              <div className="text-xs text-zinc-400 mt-0.5">
                Sıcak Karadeniz nemiyle soğuk hava çarpıştı; Boğaz hattına kilitlendi.
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* ROTA MEDYA Branding & CTA */}
      <div className="w-full max-w-[880px] bg-zinc-950/90 border border-cyan-500/50 rounded-3xl p-8 flex items-center justify-between shadow-[0_16px_50px_rgba(0,0,0,0.9)]">
        <div className="flex items-center space-x-5">
          <div className="w-16 h-16 rounded-2xl bg-gradient-to-tr from-cyan-400 to-blue-600 flex items-center justify-center font-black text-2xl text-black shadow-lg">
            R+
          </div>
          <div>
            <div className="text-2xl font-black tracking-wider text-white">
              ROTA MEDYA // BİLİM
            </div>
            <div className="text-xs font-mono text-cyan-400 tracking-widest mt-1">
              GÜNCEL OLAYLARI BİLİMLE KEŞFET
            </div>
          </div>
        </div>

        <div className="px-7 py-3.5 rounded-2xl bg-gradient-to-r from-cyan-400 to-sky-500 text-black font-black text-sm tracking-wider shadow-[0_0_30px_rgba(6,182,212,0.6)]">
          BEĞEN & TAKİP ET
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
            <span className="w-2 h-2 rounded-full bg-cyan-400" />
            <span>NEURAL TÜRKÇE ANLATIM</span>
          </div>
          <span className="text-cyan-400 font-semibold tracking-wider">
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
                    ? "bg-cyan-400 text-black font-black scale-105 shadow-[0_0_20px_rgba(6,182,212,0.8)]"
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
