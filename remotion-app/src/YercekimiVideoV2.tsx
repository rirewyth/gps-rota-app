import React, { useMemo } from 'react';
import {
  AbsoluteFill,
  Audio,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import metadata from './yercekimi_v2_metadata.json';

// --- THEME & STYLES ---
const THEME = {
  bgDeep: '#0B081A',
  bgCosmic: '#1A1033',
  paperBg: '#FBF9F2',
  paperBorder: '#E3DDD0',
  tapeColor: '#F59E0B',
  accentOrange: '#FF4D26',
  accentRed: '#EF4444',
  accentCyan: '#00E5FF',
  accentGold: '#FBBF24',
  textDark: '#1E293B',
  textMuted: '#64748B',
  fontBold: 'Impact, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
  fontSans: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
};

// Masking Tape on card corners (Cutreal signature element)
const MaskingTape: React.FC<{ style?: React.CSSProperties }> = ({ style }) => (
  <div
    style={{
      position: 'absolute',
      width: 76,
      height: 26,
      backgroundColor: THEME.tapeColor,
      opacity: 0.9,
      boxShadow: '0 2px 6px rgba(0,0,0,0.22)',
      borderRadius: 2,
      zIndex: 25,
      ...style,
    }}
  />
);

// Paper grain texture overlay for tactile card feel
const PaperGrain: React.FC = () => (
  <svg
    style={{
      position: 'absolute',
      inset: 0,
      width: '100%',
      height: '100%',
      opacity: 0.05,
      pointerEvents: 'none',
      mixBlendMode: 'multiply',
    }}
  >
    <filter id="noiseFilter">
      <feTurbulence type="fractalNoise" baseFrequency="0.8" numOctaves="3" stitchTiles="stitch" />
    </filter>
    <rect width="100%" height="100%" filter="url(#noiseFilter)" />
  </svg>
);

// ============================================================================
// MAIN COMPOSITION
// ============================================================================
export const YercekimiVideoV2: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Find active scene
  const activeSceneIndex = useMemo(() => {
    const idx = metadata.scenes.findIndex(
      (sc) => frame >= sc.startFrame && frame < sc.endFrame
    );
    return idx === -1 ? metadata.scenes.length - 1 : idx;
  }, [frame]);

  const activeScene = metadata.scenes[activeSceneIndex];
  const sceneProgress = activeScene
    ? (frame - activeScene.startFrame) / activeScene.durationFrames
    : 0;

  const sceneSpring = spring({
    frame: frame - (activeScene?.startFrame || 0),
    fps,
    config: { damping: 12, stiffness: 100 },
  });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: THEME.bgDeep,
        fontFamily: THEME.fontSans,
        color: '#FFFFFF',
        overflow: 'hidden',
      }}
    >
      {/* Master Soundtrack with Broadcast Voiceover & EQ */}
      <Audio src={staticFile('yercekimi_v2/yercekimi_v2_master_soundtrack.mp3')} />

      {/* 1. Cosmic Gradient Background */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: `radial-gradient(circle at 50% 35%, ${THEME.bgCosmic} 0%, ${THEME.bgDeep} 85%)`,
        }}
      />

      {/* Subtle Star Dust */}
      <svg
        style={{
          position: 'absolute',
          inset: 0,
          width: '100%',
          height: '100%',
          opacity: 0.45,
          pointerEvents: 'none',
        }}
      >
        {Array.from({ length: 60 }).map((_, i) => {
          const sx = (i * 97) % 1080;
          const sy = (i * 137) % 1920;
          const r = (i % 3) + 1.2;
          const blink = Math.sin((frame + i * 15) * 0.1) * 0.4 + 0.6;
          return <circle key={i} cx={sx} cy={sy} r={r} fill="#FFFFFF" opacity={blink} />;
        })}
      </svg>

      {/* 2. TOP PINNED WARNING CARD (Taped Paper Note) */}
      <div
        style={{
          position: 'absolute',
          top: 60,
          left: 50,
          right: 50,
          backgroundColor: THEME.paperBg,
          borderRadius: 18,
          border: `2px solid ${THEME.paperBorder}`,
          boxShadow: '0 16px 36px rgba(0,0,0,0.5)',
          padding: '22px 32px',
          display: 'flex',
          alignItems: 'center',
          gap: 20,
          zIndex: 40,
        }}
      >
        <PaperGrain />
        <MaskingTape style={{ top: -10, left: 30, transform: 'rotate(-4deg)' }} />
        <MaskingTape style={{ top: -10, right: 30, transform: 'rotate(5deg)' }} />

        {/* 3D Warning Icon */}
        <div
          style={{
            width: 76,
            height: 76,
            backgroundColor: '#FEF08A',
            border: '3px solid #EAB308',
            borderRadius: 18,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: 44,
            flexShrink: 0,
            boxShadow: '0 6px 14px rgba(234, 179, 8, 0.35)',
          }}
        >
          ⚠️
        </div>

        {/* Header Title */}
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          <span
            style={{
              fontFamily: THEME.fontBold,
              fontSize: 32,
              letterSpacing: 2,
              color: THEME.textDark,
              lineHeight: 1.15,
            }}
          >
            YA YERÇEKİMİ
          </span>
          <span
            style={{
              fontFamily: THEME.fontBold,
              fontSize: 34,
              letterSpacing: 2,
              color: THEME.accentOrange,
              lineHeight: 1.15,
            }}
          >
            10 SANİYELİĞİNE YOK OLSAYDI?
          </span>
        </div>
      </div>

      {/* 3. CENTRAL STAGE WINDOW (Cutreal Rounded Canvas Card) */}
      <div
        style={{
          position: 'absolute',
          top: 220,
          left: 50,
          right: 50,
          height: 1200,
          backgroundColor: '#000000',
          borderRadius: 36,
          border: '7px solid #FFFFFF',
          boxShadow: '0 25px 60px rgba(0,0,0,0.65), inset 0 0 30px rgba(0,0,0,0.5)',
          overflow: 'hidden',
          zIndex: 20,
        }}
      >
        {/* Floating Context HUD / Pill Badge */}
        {activeScene.badge && (
          <div
            style={{
              position: 'absolute',
              top: 24,
              left: '50%',
              transform: 'translateX(-50%)',
              backgroundColor: '#FFFFFF',
              borderRadius: 50,
              padding: '10px 26px',
              display: 'flex',
              alignItems: 'center',
              gap: 12,
              boxShadow: '0 6px 18px rgba(0,0,0,0.22)',
              zIndex: 50,
              border: '2px solid rgba(0,0,0,0.08)',
            }}
          >
            <span style={{ fontSize: 24, fontWeight: 800, color: THEME.textDark, letterSpacing: 1 }}>
              {activeScene.badge}
            </span>
            <div
              style={{
                backgroundColor: THEME.accentRed,
                color: '#FFFFFF',
                borderRadius: 20,
                padding: '4px 12px',
                fontSize: 16,
                fontWeight: 800,
              }}
            >
              {activeScene.timer}
            </div>
          </div>
        )}

        {/* Scene Switcher */}
        {activeScene.id === 'scene_00_intro' && (
          <Scene00Intro frame={frame} progress={sceneProgress} />
        )}
        {activeScene.id === 'scene_01_hook' && (
          <Scene01Hook frame={frame} progress={sceneProgress} springVal={sceneSpring} />
        )}
        {activeScene.id === 'scene_02_room' && (
          <Scene02Room frame={frame} progress={sceneProgress} springVal={sceneSpring} />
        )}
        {activeScene.id === 'scene_03_street' && (
          <Scene03Street frame={frame} progress={sceneProgress} springVal={sceneSpring} />
        )}
        {activeScene.id === 'scene_04_oceans' && (
          <Scene04Oceans frame={frame} progress={sceneProgress} springVal={sceneSpring} />
        )}
        {activeScene.id === 'scene_05_crash' && (
          <Scene05Crash frame={frame} progress={sceneProgress} springVal={sceneSpring} />
        )}
      </div>

      {/* 4. BOTTOM SUBTITLE CARD (Taped Paper Note with Spoken Word Highlighting) */}
      <div
        style={{
          position: 'absolute',
          bottom: 65,
          left: 50,
          right: 50,
          minHeight: 280,
          backgroundColor: THEME.paperBg,
          borderRadius: 18,
          border: `2px solid ${THEME.paperBorder}`,
          boxShadow: '0 20px 45px rgba(0,0,0,0.5)',
          padding: '36px 44px',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'center',
          alignItems: 'center',
          textAlign: 'center',
          zIndex: 40,
        }}
      >
        <PaperGrain />
        <MaskingTape style={{ top: -10, left: 35, transform: 'rotate(-3deg)' }} />
        <MaskingTape style={{ top: -10, right: 35, transform: 'rotate(4deg)' }} />

        <p
          style={{
            margin: 0,
            fontSize: 40,
            fontWeight: 800,
            lineHeight: 1.45,
            color: THEME.textDark,
            fontFamily: THEME.fontSans,
            letterSpacing: -0.5,
          }}
        >
          {activeScene.words.map((w, i) => {
            const isActive = frame >= w.startFrame && frame <= w.endFrame;
            return (
              <span
                key={i}
                style={{
                  color: isActive ? THEME.accentOrange : THEME.textDark,
                  display: 'inline-block',
                  margin: '0 6px',
                  transform: isActive ? 'scale(1.12)' : 'scale(1.0)',
                  transition: 'transform 0.1s ease',
                  textShadow: isActive ? '0 2px 10px rgba(255, 77, 38, 0.4)' : 'none',
                }}
              >
                {w.text}
              </span>
            );
          })}
        </p>
      </div>
    </AbsoluteFill>
  );
};

// ============================================================================
// SCENE 00: ROTA MEDYA BRANDED INTRO
// ============================================================================
const Scene00Intro: React.FC<{ frame: number; progress: number }> = ({ frame, progress }) => {
  const pulse = Math.sin(frame * 0.18) * 0.06 + 1;

  return (
    <AbsoluteFill
      style={{
        backgroundColor: '#0A0618',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        overflow: 'hidden',
      }}
    >
      {/* Sci-fi Target Ring Grid */}
      <svg
        style={{
          position: 'absolute',
          width: 720,
          height: 720,
          transform: `scale(${pulse})`,
          opacity: 0.35,
        }}
        viewBox="0 0 500 500"
      >
        <circle cx="250" cy="250" r="230" stroke="#00E5FF" strokeWidth="2" strokeDasharray="10 14" fill="none" />
        <circle cx="250" cy="250" r="170" stroke="#FF4D26" strokeWidth="2" fill="none" />
        <circle cx="250" cy="250" r="110" stroke="#00E5FF" strokeWidth="1.5" strokeDasharray="6 8" fill="none" />
      </svg>

      {/* ROTA MEDYA Central Emblem */}
      <div
        style={{
          position: 'relative',
          zIndex: 10,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: 14,
        }}
      >
        <div
          style={{
            fontFamily: THEME.fontSans,
            fontSize: 22,
            letterSpacing: 8,
            color: THEME.accentCyan,
            textTransform: 'uppercase',
            fontWeight: 800,
          }}
        >
          ÖZEL DOSYA · NO. 10
        </div>

        <h1
          style={{
            fontFamily: THEME.fontBold,
            fontSize: 88,
            letterSpacing: 4,
            margin: 0,
            color: '#FFFFFF',
            textShadow: '0 0 35px rgba(255,255,255,0.4)',
          }}
        >
          ROTA MEDYA
        </h1>

        <div
          style={{
            height: 3,
            width: 220,
            background: `linear-gradient(90deg, transparent, ${THEME.accentOrange}, transparent)`,
            margin: '4px 0',
          }}
        />

        <div
          style={{
            fontFamily: THEME.fontSans,
            fontSize: 30,
            fontWeight: 700,
            color: THEME.accentGold,
            letterSpacing: 2,
          }}
        >
          BİLİM & DÜŞÜNCE DENEYİ
        </div>

        {/* Audio Waveform Spectrum */}
        <div style={{ display: 'flex', gap: 6, marginTop: 20 }}>
          {Array.from({ length: 16 }).map((_, i) => {
            const h = Math.abs(Math.sin((frame + i * 8) * 0.25)) * 38 + 8;
            return (
              <div
                key={i}
                style={{
                  width: 6,
                  height: h,
                  backgroundColor: i % 2 === 0 ? THEME.accentCyan : THEME.accentOrange,
                  borderRadius: 3,
                }}
              />
            );
          })}
        </div>
      </div>
    </AbsoluteFill>
  );
};

// ============================================================================
// SCENE 01: CAFE PATIO (HOOK & ZERO GRAVITY COFFEE LIFT)
// ============================================================================
const Scene01Hook: React.FC<{ frame: number; progress: number; springVal: number }> = ({
  frame,
  progress,
}) => {
  const isZeroG = progress > 0.32;
  const coffeeFloat = interpolate(progress, [0.32, 1], [0, -260], { extrapolateLeft: 'clamp' });
  const charFloat = interpolate(progress, [0.38, 1], [0, -90], { extrapolateLeft: 'clamp' });

  return (
    <AbsoluteFill style={{ overflow: 'hidden', backgroundColor: '#87CEEB' }}>
      {/* Sun with Glowing Rays */}
      <div
        style={{
          position: 'absolute',
          top: 80,
          right: 90,
          width: 140,
          height: 140,
          borderRadius: '50%',
          backgroundColor: '#FDE047',
          boxShadow: '0 0 50px rgba(253, 224, 71, 0.8), 0 0 100px rgba(250, 204, 21, 0.4)',
        }}
      />

      {/* Fluffy Paper Clouds */}
      <VectorPaperCloud x={80} y={110} scale={1.2} />
      <VectorPaperCloud x={560} y={180} scale={1.4} />
      <VectorPaperCloud x={40} y={320} scale={0.9} />

      {/* Layered Green Hills */}
      <svg
        style={{ position: 'absolute', bottom: 180, width: '100%', height: 350 }}
        viewBox="0 0 1000 350"
      >
        <path d="M 0 240 Q 250 120 500 220 Q 750 320 1000 180 L 1000 350 L 0 350 Z" fill="#86EFAC" />
        <path d="M 0 280 Q 300 200 650 270 Q 850 310 1000 250 L 1000 350 L 0 350 Z" fill="#4ADE80" />
      </svg>

      {/* Wooden Deck Floor with Planks */}
      <div
        style={{
          position: 'absolute',
          bottom: 0,
          left: 0,
          right: 0,
          height: 190,
          backgroundColor: '#B45309',
          borderTop: '6px solid #78350F',
          boxShadow: 'inset 0 10px 20px rgba(0,0,0,0.18)',
        }}
      >
        <div style={{ display: 'flex', height: '100%' }}>
          {Array.from({ length: 8 }).map((_, i) => (
            <div
              key={i}
              style={{
                flex: 1,
                borderRight: '2px solid #78350F',
                borderLeft: '1px solid rgba(255,255,255,0.12)',
                position: 'relative',
              }}
            >
              <div style={{ position: 'absolute', top: 12, left: '50%', width: 5, height: 5, borderRadius: '50%', backgroundColor: '#451A03' }} />
              <div style={{ position: 'absolute', bottom: 14, left: '50%', width: 5, height: 5, borderRadius: '50%', backgroundColor: '#451A03' }} />
            </div>
          ))}
        </div>
      </div>

      {/* Wooden Café Table */}
      <div style={{ position: 'absolute', bottom: 175, left: 400, width: 300, height: 170 }}>
        {/* Table Top with Bevel */}
        <div
          style={{
            width: 300,
            height: 24,
            backgroundColor: '#D97706',
            borderRadius: 6,
            boxShadow: '0 10px 20px rgba(0,0,0,0.25)',
            border: '2px solid #92400E',
          }}
        />
        {/* Table Legs */}
        <div style={{ width: 16, height: 146, backgroundColor: '#78350F', position: 'absolute', left: 45, top: 24 }} />
        <div style={{ width: 16, height: 146, backgroundColor: '#78350F', position: 'absolute', right: 45, top: 24 }} />

        {/* Ceramic Coffee Cup with Saucer */}
        <div style={{ position: 'absolute', left: 110, top: -45 }}>
          <VectorCoffeeCup />
        </div>

        {/* Floating Coffee Liquid Sphere */}
        {isZeroG && (
          <div
            style={{
              position: 'absolute',
              left: 115,
              top: -65 + coffeeFloat,
              transform: `scale(${1 + Math.sin(frame * 0.3) * 0.08})`,
            }}
          >
            <VectorLiquidSphere />
          </div>
        )}

        {/* Comic Action Sticker */}
        {progress > 0.42 && progress < 0.88 && (
          <div
            style={{
              position: 'absolute',
              left: 170,
              top: -150 + coffeeFloat * 0.5,
              backgroundColor: '#FEF08A',
              border: '4px solid #000000',
              borderRadius: 20,
              padding: '8px 22px',
              fontWeight: 900,
              fontSize: 32,
              color: '#000000',
              fontFamily: THEME.fontBold,
              transform: 'rotate(10deg)',
              boxShadow: '0 8px 0 #000000',
            }}
          >
            GÜP! 🫧
          </div>
        )}
      </div>

      {/* Cutreal Vector Character */}
      <div style={{ position: 'absolute', bottom: 190, left: 180 }}>
        <VectorCutrealCharacter
          pose={isZeroG ? 'shocked' : 'stand'}
          floatingY={charFloat}
          rotation={interpolate(progress, [0.38, 1], [0, -12], { extrapolateLeft: 'clamp' })}
        />
      </div>
    </AbsoluteFill>
  );
};

// ============================================================================
// SCENE 02: ROOM CHAOS (TUMBLING IN 0G & COFFEE SPHERE)
// ============================================================================
const Scene02Room: React.FC<{ frame: number; progress: number; springVal: number }> = ({
  frame,
  progress,
}) => {
  const charFloatY = interpolate(progress, [0, 0.85], [0, -420]);
  const charRot = interpolate(progress, [0, 1], [0, 160]);
  const blobX = interpolate(progress, [0.15, 0.7], [320, 520]);
  const blobY = interpolate(progress, [0.15, 0.7], [700, 420]);
  const isSplash = progress > 0.65;

  return (
    <AbsoluteFill style={{ overflow: 'hidden', backgroundColor: '#FEF3C7' }}>
      {/* Wallpaper Vertical Stripes */}
      <svg style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', opacity: 0.16 }}>
        <pattern id="room_stripes" width="48" height="48" patternUnits="userSpaceOnUse">
          <line x1="0" y1="0" x2="0" y2="48" stroke="#D97706" strokeWidth="3" />
        </pattern>
        <rect width="100%" height="100%" fill="url(#room_stripes)" />
      </svg>

      {/* Picture Frame on Wall */}
      <div
        style={{
          position: 'absolute',
          top: 130,
          right: 130,
          width: 140,
          height: 110,
          backgroundColor: '#FFFFFF',
          border: '8px solid #92400E',
          borderRadius: 6,
          boxShadow: '0 8px 18px rgba(0,0,0,0.15)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: 42,
        }}
      >
        🏔️
      </div>

      {/* Big Window Looking Outside */}
      <div
        style={{
          position: 'absolute',
          top: 120,
          left: 100,
          width: 230,
          height: 330,
          backgroundColor: '#93C5FD',
          border: '10px solid #FFFFFF',
          boxShadow: '0 12px 30px rgba(0,0,0,0.18)',
          borderRadius: 8,
          overflow: 'hidden',
        }}
      >
        <div style={{ position: 'absolute', left: '50%', top: 0, bottom: 0, width: 6, backgroundColor: '#FFFFFF' }} />
        <div style={{ position: 'absolute', top: '50%', left: 0, right: 0, height: 6, backgroundColor: '#FFFFFF' }} />
        <div style={{ position: 'absolute', top: 20, right: 15 }}>
          <VectorPaperCloud x={0} y={0} scale={0.7} />
        </div>
      </div>

      {/* Wooden Floor */}
      <div
        style={{
          position: 'absolute',
          bottom: 0,
          left: 0,
          right: 0,
          height: 150,
          backgroundColor: '#78350F',
          borderTop: '16px solid #B45309',
        }}
      />

      {/* Character Floating & Tumbling in 0G */}
      <div style={{ position: 'absolute', bottom: 170, left: 360 }}>
        <VectorCutrealCharacter pose="flail" floatingY={charFloatY} rotation={charRot} />
      </div>

      {/* Floating Props (Laptop, Slippers, Books) */}
      <div
        style={{
          position: 'absolute',
          bottom: 280 - charFloatY * 0.7,
          left: 150,
          transform: `rotate(${frame * 2.2}deg)`,
        }}
      >
        <div
          style={{
            width: 100,
            height: 65,
            backgroundColor: '#475569',
            borderRadius: 6,
            border: '3px solid #1E293B',
            boxShadow: '0 8px 16px rgba(0,0,0,0.25)',
          }}
        />
      </div>

      <div
        style={{
          position: 'absolute',
          bottom: 230 - charFloatY * 0.9,
          right: 170,
          transform: `rotate(${-frame * 1.8}deg)`,
        }}
      >
        <div style={{ width: 68, height: 32, backgroundColor: '#EF4444', borderRadius: '18px 18px 8px 8px', border: '3px solid #B91C1C' }} />
      </div>

      {/* Shimmering Coffee Sphere or Splash */}
      {!isSplash ? (
        <div style={{ position: 'absolute', left: blobX, top: blobY }}>
          <VectorLiquidSphere size={88} />
        </div>
      ) : (
        /* Comic SPLASH burst */
        <div
          style={{
            position: 'absolute',
            left: 440,
            top: 380,
            backgroundColor: '#FEF08A',
            border: '6px solid #000000',
            borderRadius: 28,
            padding: '16px 36px',
            fontFamily: THEME.fontBold,
            fontSize: 48,
            color: '#78350F',
            transform: 'rotate(-10deg) scale(1.15)',
            boxShadow: '0 12px 0 #000000',
            zIndex: 60,
          }}
        >
          ŞLAAAP! ☕💥
        </div>
      )}
    </AbsoluteFill>
  );
};

// ============================================================================
// SCENE 03: STREET CHAOS (CAR & DOG FLOATING)
// ============================================================================
const Scene03Street: React.FC<{ frame: number; progress: number; springVal: number }> = ({
  frame,
  progress,
}) => {
  const carFloatY = interpolate(progress, [0, 1], [0, -320]);
  const dogFloatY = interpolate(progress, [0, 1], [0, -420]);
  const carRot = Math.sin(frame * 0.12) * 8 - 12;

  return (
    <AbsoluteFill style={{ overflow: 'hidden', backgroundColor: '#93C5FD' }}>
      {/* City Skyline with Window Panes & Shop Awnings */}
      <div
        style={{
          position: 'absolute',
          bottom: 220,
          left: 0,
          right: 0,
          display: 'flex',
          gap: 16,
          alignItems: 'flex-end',
          padding: '0 20px',
        }}
      >
        <Building width={160} height={420} color="#F87171" windows={12} awning />
        <Building width={190} height={520} color="#FDE047" windows={16} />
        <Building width={170} height={380} color="#A78BFA" windows={10} awning />
        <Building width={210} height={490} color="#38BDF8" windows={15} />
        <Building width={160} height={360} color="#FB923C" windows={9} />
      </div>

      {/* Street & Sidewalk with Curb */}
      <div
        style={{
          position: 'absolute',
          bottom: 0,
          left: 0,
          right: 0,
          height: 220,
          backgroundColor: '#334155',
          borderTop: '18px solid #CBD5E1',
          boxShadow: 'inset 0 10px 20px rgba(0,0,0,0.2)',
        }}
      >
        {/* Dashed Road Markings */}
        <div style={{ display: 'flex', gap: 60, marginTop: 70, paddingLeft: 40 }}>
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} style={{ width: 85, height: 14, backgroundColor: '#FFFFFF', borderRadius: 4 }} />
          ))}
        </div>
      </div>

      {/* High-End Vector Sedan Car Floating */}
      <div
        style={{
          position: 'absolute',
          bottom: 180 - carFloatY,
          left: 240,
          transform: `rotate(${carRot}deg)`,
          filter: 'drop-shadow(0 20px 35px rgba(0,0,0,0.35))',
        }}
      >
        <VectorModernCar frame={frame} isFloating={true} />
      </div>

      {/* Floating Vector Dog */}
      <div
        style={{
          position: 'absolute',
          bottom: 240 - dogFloatY,
          right: 120,
          transform: `rotate(${Math.sin(frame * 0.1) * 15 + 25}deg)`,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
        }}
      >
        <VectorCartoonDog />
        <div
          style={{
            backgroundColor: '#FEF08A',
            border: '3px solid #000000',
            borderRadius: 14,
            padding: '4px 12px',
            fontSize: 20,
            fontWeight: 900,
            marginTop: -8,
            color: '#000000',
            boxShadow: '0 4px 0 #000000',
          }}
        >
          HAV? ❓
        </div>
      </div>
    </AbsoluteFill>
  );
};

// ============================================================================
// SCENE 04: OCEANS & ATMOSPHERE RISING INTO SPACE
// ============================================================================
const Scene04Oceans: React.FC<{ frame: number; progress: number; springVal: number }> = ({
  frame,
  progress,
}) => {
  return (
    <AbsoluteFill style={{ overflow: 'hidden', backgroundColor: '#030712' }}>
      {/* Deep Space Background with Blue Nebula */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: 'radial-gradient(circle at 50% 25%, #1E1B4B 0%, #030712 90%)',
        }}
      />

      {/* Atmospheric Air Escape Banners */}
      <div
        style={{
          position: 'absolute',
          top: 130,
          left: 0,
          right: 0,
          display: 'flex',
          justifyContent: 'space-around',
          color: '#38BDF8',
          fontSize: 32,
          fontWeight: 900,
          zIndex: 30,
        }}
      >
        <span>⬆ ATMOSFER KAÇIYOR</span>
        <span>⬆ 0 BAR BASINÇ</span>
      </div>

      {/* Orbiting Space Satellite */}
      <div
        style={{
          position: 'absolute',
          top: 220,
          right: 80,
          transform: `rotate(${frame * 0.8}deg)`,
          filter: 'drop-shadow(0 0 15px rgba(56, 189, 248, 0.5))',
        }}
      >
        <VectorSpaceSatellite />
      </div>

      {/* Detailed Vector Earth Globe with Rising Waves */}
      <div style={{ position: 'absolute', bottom: -120, left: '50%', transform: 'translateX(-50%)' }}>
        <VectorEarthGlobe frame={frame} progress={progress} />
      </div>
    </AbsoluteFill>
  );
};

// ============================================================================
// SCENE 05: CRASH & BONK (10 SECONDS EXPIRE!)
// ============================================================================
const Scene05Crash: React.FC<{ frame: number; progress: number; springVal: number }> = ({
  frame,
  progress,
}) => {
  const isCrashed = progress > 0.16;
  const bonkScale = spring({
    frame: frame - metadata.scenes[5].startFrame - 6,
    fps: 30,
    config: { damping: 9, stiffness: 140 },
  });

  return (
    <AbsoluteFill style={{ overflow: 'hidden', backgroundColor: '#FEF08A' }}>
      {/* Ground Pavement */}
      <div
        style={{
          position: 'absolute',
          bottom: 0,
          left: 0,
          right: 0,
          height: 320,
          backgroundColor: '#334155',
          borderTop: '12px solid #64748B',
        }}
      />

      {/* Downward Comic Speed Lines Before Crash */}
      {!isCrashed && (
        <svg style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
          {Array.from({ length: 28 }).map((_, i) => {
            const lx = (i * 38) % 980 + 20;
            return (
              <line
                key={i}
                x1={lx}
                y1={0}
                x2={lx}
                y2={1200}
                stroke="#EF4444"
                strokeWidth="5"
                strokeDasharray="40 20"
                opacity="0.65"
              />
            );
          })}
        </svg>
      )}

      {/* Knocked-Out Character Lying on Sidewalk */}
      {isCrashed && (
        <>
          {/* Comic Dust Puff Under Character */}
          <div style={{ position: 'absolute', bottom: 300, left: 140 }}>
            <VectorComicDustPuff />
          </div>

          <div style={{ position: 'absolute', bottom: 235, left: 160 }}>
            <VectorCutrealCharacter pose="knocked" floatingY={0} rotation={90} />

            {/* Fallen Coffee Mug */}
            <div
              style={{
                position: 'absolute',
                top: -60,
                left: -40,
                fontSize: 48,
                transform: 'rotate(-45deg)',
              }}
            >
              ☕
            </div>

            {/* Circling Dizzy Stars */}
            <div
              style={{
                position: 'absolute',
                top: -80,
                left: 40,
                display: 'flex',
                gap: 12,
                fontSize: 34,
                transform: `rotate(${frame * 7}deg)`,
              }}
            >
              <span>⭐</span>
              <span>💫</span>
              <span>⭐</span>
            </div>
          </div>
        </>
      )}

      {/* Crushed Accordion Sedan */}
      {isCrashed && (
        <>
          {/* Comic Dust Puff Under Car */}
          <div style={{ position: 'absolute', bottom: 300, right: 90 }}>
            <VectorComicDustPuff />
          </div>

          <div style={{ position: 'absolute', bottom: 305, right: 60 }}>
            <VectorModernCar frame={frame} isCrushed={true} />
          </div>
        </>
      )}

      {/* GIANT COMIC BÖÖÖNK! EXPLOSION */}
      {isCrashed && (
        <div
          style={{
            position: 'absolute',
            top: 250,
            left: '50%',
            transform: `translateX(-50%) scale(${bonkScale}) rotate(-6deg)`,
            backgroundColor: '#EF4444',
            border: '8px solid #000000',
            borderRadius: 36,
            padding: '24px 64px',
            boxShadow: '0 18px 0 #000000',
            zIndex: 60,
          }}
        >
          <span
            style={{
              fontFamily: THEME.fontBold,
              fontSize: 88,
              color: '#FFFFFF',
              textShadow: '0 6px 0 #991B1B',
              letterSpacing: 4,
            }}
          >
            BÖÖÖNK! 💥
          </span>
        </div>
      )}
    </AbsoluteFill>
  );
};

// ============================================================================
// VECTOR ASSETS (AUTHENTIC CUTREAL BENCHMARK DESIGNS)
// ============================================================================

/**
 * Cutreal Vector Character Rig
 * Supports poses: 'stand' | 'shocked' | 'flail' | 'knocked'
 */
const VectorCutrealCharacter: React.FC<{
  pose: 'stand' | 'shocked' | 'flail' | 'knocked';
  floatingY: number;
  rotation: number;
}> = ({ pose, floatingY, rotation }) => {
  const isKnocked = pose === 'knocked';
  const isShocked = pose === 'shocked';
  const isFlail = pose === 'flail';

  return (
    <div
      style={{
        transform: `translateY(${floatingY}px) rotate(${rotation}deg)`,
        transformOrigin: '50% 60%',
        width: 170,
        height: 310,
        position: 'relative',
        filter: 'drop-shadow(0 10px 20px rgba(0,0,0,0.25))',
      }}
    >
      <svg viewBox="0 0 170 310" width="170" height="310" style={{ overflow: 'visible' }}>
        {/* White Sticker Glow Stroke */}
        <filter id="stickerGlow" x="-20%" y="-20%" width="140%" height="140%">
          <feDropShadow dx="0" dy="0" stdDeviation="2" floodColor="#FFFFFF" floodOpacity="0.9" />
        </filter>

        <g filter="url(#stickerGlow)">
          {/* LEGS & PANTS (Dark Slate Jeans) */}
          <g id="legs">
            {/* Left Leg */}
            <path
              d={isFlail ? "M 62 180 L 45 250 L 35 250 L 52 180 Z" : "M 62 180 L 58 260 L 74 260 L 76 180 Z"}
              fill="#1E293B"
              stroke="#0F172A"
              strokeWidth="2.5"
            />
            {/* Right Leg */}
            <path
              d={isFlail ? "M 98 180 L 115 250 L 125 250 L 108 180 Z" : "M 94 180 L 96 260 L 112 260 L 108 180 Z"}
              fill="#1E293B"
              stroke="#0F172A"
              strokeWidth="2.5"
            />

            {/* SNEAKERS (Pure White Capsules with Grey Soles) */}
            {/* Left Sneaker */}
            <g transform={isFlail ? "translate(30, 245) rotate(-15)" : "translate(52, 255)"}>
              <ellipse cx="18" cy="12" rx="18" ry="9" fill="#FFFFFF" stroke="#0F172A" strokeWidth="2.5" />
              <path d="M 2 12 Q 18 16 34 12" stroke="#CBD5E1" strokeWidth="2.5" fill="none" />
            </g>
            {/* Right Sneaker */}
            <g transform={isFlail ? "translate(100, 245) rotate(15)" : "translate(92, 255)"}>
              <ellipse cx="18" cy="12" rx="18" ry="9" fill="#FFFFFF" stroke="#0F172A" strokeWidth="2.5" />
              <path d="M 2 12 Q 18 16 34 12" stroke="#CBD5E1" strokeWidth="2.5" fill="none" />
            </g>
          </g>

          {/* TORSO / HOODIE (Vibrant Orange with White Cutreal Band) */}
          <g id="torso">
            {/* Main Body Hoodie */}
            <path
              d="M 48 95 C 60 88, 110 88, 122 95 L 126 182 C 126 188, 44 188, 44 182 Z"
              fill="#EA580C"
              stroke="#0F172A"
              strokeWidth="3"
            />
            {/* White Chest Stripe */}
            <path
              d="M 45 125 L 125 125 L 125 142 L 45 142 Z"
              fill="#FFFFFF"
              stroke="#0F172A"
              strokeWidth="1.5"
            />
            {/* Crewneck Collar */}
            <ellipse cx="85" cy="94" rx="18" ry="7" fill="#FFFFFF" stroke="#0F172A" strokeWidth="2.5" />
          </g>

          {/* ARMS & HANDS */}
          <g id="arms">
            {isStandArm(pose) && (
              <>
                {/* Left Arm relaxed */}
                <path
                  d="M 46 98 Q 28 135 34 175"
                  stroke="#EA580C"
                  strokeWidth="18"
                  strokeLinecap="round"
                  fill="none"
                />
                <circle cx="34" cy="180" r="11" fill="#FCD5B5" stroke="#0F172A" strokeWidth="2.5" />

                {/* Right Arm relaxed */}
                <path
                  d="M 124 98 Q 142 135 136 175"
                  stroke="#EA580C"
                  strokeWidth="18"
                  strokeLinecap="round"
                  fill="none"
                />
                <circle cx="136" cy="180" r="11" fill="#FCD5B5" stroke="#0F172A" strokeWidth="2.5" />
              </>
            )}

            {(isShocked || isFlail) && (
              <>
                {/* Left Arm Raised */}
                <path
                  d="M 46 100 Q 15 80 18 45"
                  stroke="#EA580C"
                  strokeWidth="18"
                  strokeLinecap="round"
                  fill="none"
                />
                <circle cx="18" cy="40" r="12" fill="#FCD5B5" stroke="#0F172A" strokeWidth="2.5" />

                {/* Right Arm Raised */}
                <path
                  d="M 124 100 Q 155 80 152 45"
                  stroke="#EA580C"
                  strokeWidth="18"
                  strokeLinecap="round"
                  fill="none"
                />
                <circle cx="152" cy="40" r="12" fill="#FCD5B5" stroke="#0F172A" strokeWidth="2.5" />
              </>
            )}

            {isKnocked && (
              <>
                {/* Splayed arms on impact */}
                <path d="M 46 110 L 15 130" stroke="#EA580C" strokeWidth="18" strokeLinecap="round" fill="none" />
                <circle cx="12" cy="132" r="11" fill="#FCD5B5" stroke="#0F172A" strokeWidth="2.5" />
                <path d="M 124 110 L 155 130" stroke="#EA580C" strokeWidth="18" strokeLinecap="round" fill="none" />
                <circle cx="158" cy="132" r="11" fill="#FCD5B5" stroke="#0F172A" strokeWidth="2.5" />
              </>
            )}
          </g>

          {/* HEAD & HAIR & FACE */}
          <g id="head">
            {/* Natural Warm Cartoon Peach Skin */}
            <circle cx="85" cy="52" r="40" fill="#FCD5B5" stroke="#0F172A" strokeWidth="3" />

            {/* Dark Chocolate Hair Cap with Swoop Bangs */}
            <path
              d="M 47 48 C 45 15, 125 15, 123 48 C 115 32, 95 30, 85 36 C 75 42, 60 40, 47 48 Z"
              fill="#261C19"
              stroke="#0F172A"
              strokeWidth="2.5"
            />
            {/* Sideburn */}
            <path d="M 48 45 L 48 62 L 56 50 Z" fill="#261C19" />

            {/* Cheeks Blush */}
            <ellipse cx="68" cy="62" rx="7" ry="4" fill="#F472B6" opacity="0.4" />
            <ellipse cx="106" cy="62" rx="7" ry="4" fill="#F472B6" opacity="0.4" />

            {/* Fleshy Cute Nose Bump */}
            <path
              d="M 88 54 Q 96 58 90 62"
              fill="none"
              stroke="#0F172A"
              strokeWidth="2.5"
              strokeLinecap="round"
            />

            {/* EYES & EXPRESSION */}
            {!isKnocked ? (
              <>
                {/* Left Eye */}
                <ellipse cx="72" cy="48" rx="8" ry={isShocked || isFlail ? 11 : 9} fill="#FFFFFF" stroke="#0F172A" strokeWidth="2" />
                <circle cx="73" cy="48" r="4.5" fill="#0F172A" />
                <circle cx="74.5" cy="46" r="1.8" fill="#FFFFFF" />

                {/* Right Eye */}
                <ellipse cx="102" cy="48" rx="8" ry={isShocked || isFlail ? 11 : 9} fill="#FFFFFF" stroke="#0F172A" strokeWidth="2" />
                <circle cx="103" cy="48" r="4.5" fill="#0F172A" />
                <circle cx="104.5" cy="46" r="1.8" fill="#FFFFFF" />

                {/* Eyebrows */}
                <path
                  d={isShocked || isFlail ? "M 64 34 Q 72 30 78 35" : "M 65 38 L 78 38"}
                  stroke="#0F172A"
                  strokeWidth="3"
                  strokeLinecap="round"
                />
                <path
                  d={isShocked || isFlail ? "M 96 35 Q 102 30 110 34" : "M 96 38 L 109 38"}
                  stroke="#0F172A"
                  strokeWidth="3"
                  strokeLinecap="round"
                />

                {/* MOUTH */}
                {isShocked || isFlail ? (
                  /* Big Open Screaming Mouth with Teeth & Tongue */
                  <g transform="translate(85, 72)">
                    <path
                      d="M -12 -5 Q 0 -12 12 -5 Q 14 14 0 14 Q -14 14 -12 -5 Z"
                      fill="#881337"
                      stroke="#0F172A"
                      strokeWidth="2"
                    />
                    {/* Upper White Teeth */}
                    <path d="M -9 -4 L 9 -4 L 7 0 L -7 0 Z" fill="#FFFFFF" />
                    {/* Pink Tongue */}
                    <ellipse cx="0" cy="9" rx="7" ry="5" fill="#FB7185" />
                  </g>
                ) : (
                  /* Pleasant Smile */
                  <path d="M 78 70 Q 86 78 94 70" stroke="#0F172A" strokeWidth="2.5" strokeLinecap="round" fill="none" />
                )}
              </>
            ) : (
              /* Knocked-Out X X Eyes */
              <>
                <text x="64" y="55" fontSize="20" fontWeight="900" fill="#0F172A">✖</text>
                <text x="96" y="55" fontSize="20" fontWeight="900" fill="#0F172A">✖</text>
                {/* Wavy mouth */}
                <path d="M 76 74 Q 85 68 95 74" stroke="#0F172A" strokeWidth="3" strokeLinecap="round" fill="none" />
              </>
            )}
          </g>
        </g>
      </svg>
    </div>
  );
};

const isStandArm = (p: string) => p === 'stand';

/**
 * Modern Compact Hatchback Vector Car (Matching Cutreal reference)
 */
const VectorModernCar: React.FC<{ frame: number; isFloating?: boolean; isCrushed?: boolean }> = ({
  frame,
  isFloating,
  isCrushed,
}) => {
  const wheelSpin = isFloating ? frame * 18 : 0;

  if (isCrushed) {
    return (
      <svg viewBox="0 0 320 100" width="320" height="100">
        <path
          d="M 20 80 Q 40 40 100 45 Q 160 30 220 50 Q 280 40 300 80 Z"
          fill="#DC2626"
          stroke="#991B1B"
          strokeWidth="4"
        />
        {/* Cracked Window */}
        <path d="M 110 50 L 160 42 L 180 58 Z" fill="#BAE6FD" stroke="#38BDF8" strokeWidth="2" />
        <ellipse cx="65" cy="85" rx="22" ry="12" fill="#0F172A" />
        <ellipse cx="250" cy="85" rx="22" ry="12" fill="#0F172A" />
      </svg>
    );
  }

  return (
    <svg viewBox="0 0 340 160" width="340" height="160">
      {/* Car Body Shadow */}
      <ellipse cx="170" cy="148" rx="150" ry="10" fill="rgba(0,0,0,0.25)" />

      {/* Main Chassis Body (Sleek Modern White/Light Grey) */}
      <path
        d="M 20 120 C 20 90, 45 80, 85 78 L 120 40 C 135 25, 230 25, 255 42 L 310 82 C 330 90, 335 110, 330 125 C 320 132, 20 132, 20 120 Z"
        fill="#F8FAFC"
        stroke="#1E293B"
        strokeWidth="4"
      />

      {/* Sporty Lower Side Skirt */}
      <path d="M 30 122 L 320 122 L 315 130 L 35 130 Z" fill="#EF4444" />

      {/* Front & Rear Windows Tinted Sky Blue */}
      {/* Rear Window */}
      <path
        d="M 125 46 L 175 46 L 175 75 L 95 75 Z"
        fill="#BAE6FD"
        stroke="#38BDF8"
        strokeWidth="2.5"
      />
      {/* Front Window with Panicked Driver Inside */}
      <path
        d="M 185 46 L 245 46 L 285 75 L 185 75 Z"
        fill="#BAE6FD"
        stroke="#38BDF8"
        strokeWidth="2.5"
      />
      {/* Specular Window Reflection Streak */}
      <path d="M 135 48 L 150 48 L 120 73 L 105 73 Z" fill="#FFFFFF" opacity="0.65" />
      <path d="M 195 48 L 210 48 L 180 73 L 165 73 Z" fill="#FFFFFF" opacity="0.65" />

      {/* Driver Head (Shocked Cartoon Inside) */}
      <circle cx="215" cy="62" r="11" fill="#FCD5B5" />
      <circle cx="215" cy="56" r="11" fill="#261C19" />
      <circle cx="218" cy="62" r="2.5" fill="#0F172A" />
      {/* Steering wheel */}
      <ellipse cx="230" cy="68" rx="4" ry="8" fill="none" stroke="#1E293B" strokeWidth="2.5" />

      {/* Headlights & Taillights */}
      <path d="M 320 92 Q 330 96 325 106 Z" fill="#FEF08A" stroke="#EAB308" strokeWidth="2" />
      <path d="M 22 92 L 20 104 L 28 102 Z" fill="#EF4444" stroke="#B91C1C" strokeWidth="1.5" />

      {/* Wheel Wells */}
      <path d="M 52 130 A 28 28 0 0 1 108 130 Z" fill="#1E293B" />
      <path d="M 232 130 A 28 28 0 0 1 288 130 Z" fill="#1E293B" />

      {/* Left Spinning Wheel */}
      <g transform={`translate(80, 130) rotate(${wheelSpin})`}>
        <circle cx="0" cy="0" r="25" fill="#0F172A" stroke="#334155" strokeWidth="3" />
        <circle cx="0" cy="0" r="14" fill="#CBD5E1" />
        <line x1="-12" y1="0" x2="12" y2="0" stroke="#475569" strokeWidth="2.5" />
        <line x1="0" y1="-12" x2="0" y2="12" stroke="#475569" strokeWidth="2.5" />
        <circle cx="0" cy="0" r="4" fill="#0F172A" />
      </g>

      {/* Right Spinning Wheel */}
      <g transform={`translate(260, 130) rotate(${wheelSpin})`}>
        <circle cx="0" cy="0" r="25" fill="#0F172A" stroke="#334155" strokeWidth="3" />
        <circle cx="0" cy="0" r="14" fill="#CBD5E1" />
        <line x1="-12" y1="0" x2="12" y2="0" stroke="#475569" strokeWidth="2.5" />
        <line x1="0" y1="-12" x2="0" y2="12" stroke="#475569" strokeWidth="2.5" />
        <circle cx="0" cy="0" r="4" fill="#0F172A" />
      </g>
    </svg>
  );
};

/**
 * Cartoon Golden Puppy / Dog Floating in 0G
 */
const VectorCartoonDog: React.FC = () => (
  <svg viewBox="0 0 120 100" width="120" height="100">
    {/* Body */}
    <ellipse cx="60" cy="55" rx="36" ry="24" fill="#FBBF24" stroke="#1E293B" strokeWidth="3" />
    {/* Cream Underbelly */}
    <ellipse cx="55" cy="62" rx="22" ry="12" fill="#FEF08A" />

    {/* Head */}
    <circle cx="90" cy="40" r="22" fill="#FBBF24" stroke="#1E293B" strokeWidth="3" />
    {/* Floppy Ear */}
    <path d="M 85 24 Q 72 38 80 50 Z" fill="#D97706" stroke="#1E293B" strokeWidth="2" />

    {/* Eye & Cute Nose */}
    <circle cx="98" cy="38" r="3.5" fill="#0F172A" />
    <circle cx="99.5" cy="36.5" r="1" fill="#FFFFFF" />
    <ellipse cx="108" cy="44" rx="4" ry="3" fill="#0F172A" />

    {/* Wagging Tail */}
    <path d="M 26 50 Q 12 36 20 26" stroke="#FBBF24" strokeWidth="8" strokeLinecap="round" fill="none" />

    {/* Floating Paws */}
    <ellipse cx="45" cy="78" rx="7" ry="10" fill="#FBBF24" stroke="#1E293B" strokeWidth="2.5" />
    <ellipse cx="78" cy="78" rx="7" ry="10" fill="#FBBF24" stroke="#1E293B" strokeWidth="2.5" />
  </svg>
);

/**
 * Ceramic Coffee Cup with Saucer
 */
const VectorCoffeeCup: React.FC = () => (
  <svg viewBox="0 0 100 80" width="100" height="80">
    {/* Saucer */}
    <ellipse cx="50" cy="68" rx="42" ry="8" fill="#E2E8F0" stroke="#94A3B8" strokeWidth="2.5" />
    {/* Cup Body */}
    <path
      d="M 22 25 L 78 25 C 78 55, 68 64, 50 64 C 32 64, 22 55, 22 25 Z"
      fill="#FFFFFF"
      stroke="#1E293B"
      strokeWidth="3"
    />
    {/* Handle */}
    <path
      d="M 76 32 C 92 32, 92 52, 74 54"
      fill="none"
      stroke="#1E293B"
      strokeWidth="3.5"
      strokeLinecap="round"
    />
    {/* Dark Espresso Surface */}
    <ellipse cx="50" cy="27" rx="25" ry="6" fill="#78350F" />
  </svg>
);

/**
 * Shimmering Coffee Liquid Sphere
 */
const VectorLiquidSphere: React.FC<{ size?: number }> = ({ size = 68 }) => (
  <svg viewBox="0 0 100 100" width={size} height={size}>
    {/* Main Amber Liquid Sphere with Surface Glow */}
    <circle cx="50" cy="50" r="42" fill="#78350F" stroke="#B45309" strokeWidth="4" />
    <circle cx="50" cy="50" r="40" fill="radial-gradient(circle at 35% 35%, #D97706 0%, #78350F 70%)" />
    {/* Curved Specular Reflection Highlights */}
    <ellipse cx="36" cy="34" rx="12" ry="7" transform="rotate(-30 36 34)" fill="#FFFFFF" opacity="0.8" />
    <circle cx="30" cy="46" r="3" fill="#FFFFFF" opacity="0.6" />
    {/* Mini Satellite Droplets */}
    <circle cx="88" cy="24" r="7" fill="#78350F" stroke="#B45309" strokeWidth="2" />
    <circle cx="16" cy="74" r="5" fill="#78350F" stroke="#B45309" strokeWidth="1.5" />
  </svg>
);

/**
 * Cinematic Orbit Earth Globe with Rising Tidal Ocean Waves
 */
const VectorEarthGlobe: React.FC<{ frame: number; progress: number }> = ({ frame, progress }) => {
  const waveLift = interpolate(progress, [0, 1], [0, -380]);

  return (
    <svg viewBox="0 0 900 800" width="900" height="800">
      <defs>
        {/* Atmosphere Corona Glow */}
        <radialGradient id="earthAtmosphere" cx="50%" cy="40%" r="60%">
          <stop offset="65%" stopColor="#1E40AF" stopOpacity="0" />
          <stop offset="92%" stopColor="#38BDF8" stopOpacity="0.4" />
          <stop offset="100%" stopColor="#00E5FF" stopOpacity="0.8" />
        </radialGradient>
      </defs>

      {/* Earth Sphere Base (Curved Horizon) */}
      <circle cx="450" cy="900" r="540" fill="#1D4ED8" stroke="#38BDF8" strokeWidth="6" />
      <circle cx="450" cy="900" r="542" fill="url(#earthAtmosphere)" />

      {/* Continents (Europe / Africa / Green Landmasses) */}
      <g opacity="0.85">
        <path
          d="M 320 440 Q 380 410 440 450 Q 480 500 420 540 Q 350 560 310 500 Z"
          fill="#16A34A"
          stroke="#15803D"
          strokeWidth="3"
        />
        <path
          d="M 460 480 Q 560 450 620 510 Q 640 600 550 640 Q 480 610 460 520 Z"
          fill="#CA8A04"
          stroke="#A16207"
          strokeWidth="3"
        />
        <path
          d="M 220 520 Q 280 490 310 560 Q 290 620 230 600 Z"
          fill="#16A34A"
        />
      </g>

      {/* Swirling Cloud Bands */}
      <g opacity="0.6">
        <path d="M 250 480 Q 450 420 650 470" stroke="#FFFFFF" strokeWidth="18" strokeLinecap="round" fill="none" />
        <path d="M 340 550 Q 520 510 720 560" stroke="#FFFFFF" strokeWidth="14" strokeLinecap="round" fill="none" />
      </g>

      {/* Gigantic Sculpted Ocean Water Masses Tearing into Deep Space */}
      {Array.from({ length: 5 }).map((_, i) => {
        const cx = 220 + i * 125;
        const cy = 420 - (i % 2) * 50 + waveLift * (1 + (i % 3) * 0.2);
        const wobble = Math.sin((frame + i * 25) * 0.15) * 14;

        return (
          <g key={i} transform={`translate(${cx + wobble}, ${cy})`}>
            {/* Crystalline Water Mass */}
            <path
              d="M -50 0 C -45 -55, 45 -55, 50 0 C 55 50, -45 50, -50 0 Z"
              fill="#06B6D4"
              stroke="#38BDF8"
              strokeWidth="4"
              opacity="0.9"
            />
            {/* Foam Wave Crest Highlight */}
            <path d="M -35 -20 Q 0 -45 35 -20" stroke="#FFFFFF" strokeWidth="4" strokeLinecap="round" fill="none" />
            <circle cx="-15" cy="5" r="5" fill="#FFFFFF" opacity="0.75" />
          </g>
        );
      })}
    </svg>
  );
};

/**
 * Cutreal Paper Cloud with Drop Shadow
 */
const VectorPaperCloud: React.FC<{ x: number; y: number; scale?: number }> = ({ x, y, scale = 1 }) => (
  <div
    style={{
      position: 'absolute',
      left: x,
      top: y,
      transform: `scale(${scale})`,
      filter: 'drop-shadow(0 6px 14px rgba(0,0,0,0.12))',
    }}
  >
    <svg viewBox="0 0 160 80" width="160" height="80">
      <path
        d="M 30 60 L 130 60 C 146 60, 150 45, 138 34 C 142 16, 120 10, 108 20 C 98 6, 68 8, 62 24 C 52 14, 32 20, 32 35 C 16 38, 16 58, 30 60 Z"
        fill="#FFFFFF"
      />
    </svg>
  </div>
);

/**
 * Building with Windows & Striped Shop Awning
 */
const Building: React.FC<{
  width: number;
  height: number;
  color: string;
  windows: number;
  awning?: boolean;
}> = ({ width, height, color, windows, awning }) => (
  <div
    style={{
      width,
      height,
      backgroundColor: color,
      borderRadius: '8px 8px 0 0',
      border: '4px solid rgba(0,0,0,0.15)',
      boxShadow: '0 8px 20px rgba(0,0,0,0.15)',
      position: 'relative',
      overflow: 'hidden',
    }}
  >
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12, padding: 18 }}>
      {Array.from({ length: windows }).map((_, i) => (
        <div
          key={i}
          style={{
            height: 28,
            backgroundColor: i % 3 === 0 ? '#FEF08A' : '#1E293B',
            borderRadius: 4,
            border: '2px solid rgba(0,0,0,0.2)',
          }}
        />
      ))}
    </div>

    {awning && (
      <div
        style={{
          position: 'absolute',
          bottom: 0,
          left: 0,
          right: 0,
          height: 38,
          background: 'repeating-linear-gradient(90deg, #EF4444, #EF4444 14px, #FFFFFF 14px, #FFFFFF 28px)',
          borderRadius: '6px 6px 0 0',
          boxShadow: '0 6px 12px rgba(0,0,0,0.25)',
        }}
      />
    )}
  </div>
);

/**
 * Orbiting Space Satellite
 */
const VectorSpaceSatellite: React.FC = () => (
  <svg viewBox="0 0 140 100" width="140" height="100">
    {/* Central Module Body */}
    <rect x="50" y="35" width="40" height="30" rx="4" fill="#E2E8F0" stroke="#0F172A" strokeWidth="2.5" />
    <circle cx="70" cy="50" r="7" fill="#00E5FF" />
    {/* Left Solar Panel */}
    <rect x="5" y="32" width="40" height="36" rx="2" fill="#0284C7" stroke="#0F172A" strokeWidth="2" />
    <line x1="18" y1="32" x2="18" y2="68" stroke="#38BDF8" strokeWidth="1.5" />
    <line x1="32" y1="32" x2="32" y2="68" stroke="#38BDF8" strokeWidth="1.5" />
    <line x1="5" y1="50" x2="45" y2="50" stroke="#38BDF8" strokeWidth="1.5" />
    <line x1="45" y1="50" x2="50" y2="50" stroke="#0F172A" strokeWidth="3" />
    {/* Right Solar Panel */}
    <rect x="95" y="32" width="40" height="36" rx="2" fill="#0284C7" stroke="#0F172A" strokeWidth="2" />
    <line x1="108" y1="32" x2="108" y2="68" stroke="#38BDF8" strokeWidth="1.5" />
    <line x1="122" y1="32" x2="122" y2="68" stroke="#38BDF8" strokeWidth="1.5" />
    <line x1="95" y1="50" x2="135" y2="50" stroke="#38BDF8" strokeWidth="1.5" />
    <line x1="90" y1="50" x2="95" y2="50" stroke="#0F172A" strokeWidth="3" />
    {/* Antenna */}
    <line x1="70" y1="35" x2="70" y2="15" stroke="#0F172A" strokeWidth="2" />
    <circle cx="70" cy="14" r="3" fill="#EF4444" />
  </svg>
);

/**
 * Comic Impact Dust Puff (Fluffy white smoke puffs on ground impact)
 */
const VectorComicDustPuff: React.FC = () => (
  <svg viewBox="0 0 160 60" width="160" height="60" style={{ overflow: 'visible' }}>
    <g filter="drop-shadow(0 4px 8px rgba(0,0,0,0.25))">
      {/* Three interconnected puffs */}
      <circle cx="40" cy="38" r="22" fill="#FFFFFF" stroke="#0F172A" strokeWidth="3" />
      <circle cx="80" cy="30" r="28" fill="#FFFFFF" stroke="#0F172A" strokeWidth="3" />
      <circle cx="120" cy="38" r="22" fill="#FFFFFF" stroke="#0F172A" strokeWidth="3" />
      {/* Fill hide seams */}
      <rect x="30" y="28" width="100" height="28" fill="#FFFFFF" />
      {/* Action shock lines */}
      <line x1="10" y1="42" x2="0" y2="44" stroke="#0F172A" strokeWidth="2.5" strokeLinecap="round" />
      <line x1="150" y1="42" x2="160" y2="44" stroke="#0F172A" strokeWidth="2.5" strokeLinecap="round" />
    </g>
  </svg>
);
