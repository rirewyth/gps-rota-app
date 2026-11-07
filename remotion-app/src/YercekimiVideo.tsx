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
import metadata from './yercekimi_metadata.json';

// --- THEME & STYLES (Matching the Cutreal/What-If reference) ---
const THEME = {
  bgDeep: '#0C081A',
  bgCosmic: '#1D1238',
  paperBg: '#F8F5EC',
  paperBorder: '#E5DFD1',
  tapeColor: '#F59E0B',
  accentOrange: '#FF4D26',
  accentRed: '#EF4444',
  accentCyan: '#06B6D4',
  accentBlue: '#3B82F6',
  textDark: '#1E293B',
  textMuted: '#64748B',
  fontBold: 'Impact, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
  fontSans: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
};

// Reusable Masking Tape Piece
const MaskingTape: React.FC<{ style?: React.CSSProperties }> = ({ style }) => (
  <div
    style={{
      position: 'absolute',
      width: 70,
      height: 24,
      backgroundColor: THEME.tapeColor,
      opacity: 0.85,
      boxShadow: '0 2px 4px rgba(0,0,0,0.15)',
      borderRadius: 2,
      zIndex: 20,
      ...style,
    }}
  />
);

export const YercekimiVideo: React.FC = () => {
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

  // Scene entrance spring
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
      {/* Master Audio Track */}
      <Audio src={staticFile('yercekimi/yercekimi_master_soundtrack.mp3')} />

      {/* 1. Cosmic / Starry Gradient Background */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: `radial-gradient(circle at 50% 35%, ${THEME.bgCosmic} 0%, ${THEME.bgDeep} 85%)`,
        }}
      />

      {/* Background Star Particles */}
      <svg
        style={{
          position: 'absolute',
          inset: 0,
          width: '100%',
          height: '100%',
          opacity: 0.35,
          pointerEvents: 'none',
        }}
      >
        {Array.from({ length: 45 }).map((_, i) => {
          const sx = (i * 97) % 1080;
          const sy = (i * 137) % 1920;
          const r = (i % 3) + 1.5;
          const blink = Math.sin((frame + i * 15) * 0.1) * 0.4 + 0.6;
          return <circle key={i} cx={sx} cy={sy} r={r} fill="#FFFFFF" opacity={blink} />;
        })}
      </svg>

      {/* 2. TOP PINNED TITLE CARD (Yellow Taped Paper Note) */}
      <div
        style={{
          position: 'absolute',
          top: 65,
          left: 50,
          right: 50,
          backgroundColor: THEME.paperBg,
          borderRadius: 14,
          border: `2px solid ${THEME.paperBorder}`,
          boxShadow: '0 15px 35px rgba(0,0,0,0.5)',
          padding: '22px 30px',
          display: 'flex',
          alignItems: 'center',
          gap: 20,
          zIndex: 40,
        }}
      >
        {/* Tapes on top corners */}
        <MaskingTape style={{ top: -10, left: 25, transform: 'rotate(-4deg)' }} />
        <MaskingTape style={{ top: -10, right: 25, transform: 'rotate(5deg)' }} />

        {/* Warning Icon with subtle 3D pop */}
        <div
          style={{
            width: 74,
            height: 74,
            backgroundColor: '#FEF08A',
            border: '3px solid #EAB308',
            borderRadius: 16,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: 42,
            flexShrink: 0,
            boxShadow: '0 4px 10px rgba(234, 179, 8, 0.3)',
          }}
        >
          ⚠️
        </div>

        {/* Main Hook Header */}
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
              fontSize: 40,
              color: THEME.accentRed,
              letterSpacing: 1.5,
              lineHeight: 1.15,
            }}
          >
            10 SANİYELİĞİNE YOK OLSAYDI?
          </span>
        </div>
      </div>

      {/* 3. CENTRAL STAGE WINDOW (Main Animated Viewport) */}
      <div
        style={{
          position: 'absolute',
          top: 235,
          left: 50,
          right: 50,
          height: 1200,
          backgroundColor: '#BAE6FD',
          borderRadius: 36,
          border: '6px solid #FFFFFF',
          boxShadow: '0 25px 65px rgba(0,0,0,0.65)',
          overflow: 'hidden',
          zIndex: 30,
        }}
      >
        {/* Stage Status Badge (Floating at top center of window) */}
        <div
          style={{
            position: 'absolute',
            top: 24,
            left: '50%',
            transform: 'translateX(-50%)',
            backgroundColor: '#FFFFFF',
            borderRadius: 50,
            padding: '10px 24px',
            display: 'flex',
            alignItems: 'center',
            gap: 12,
            boxShadow: '0 6px 18px rgba(0,0,0,0.18)',
            zIndex: 50,
            border: '2px solid rgba(0,0,0,0.06)',
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

        {/* Dynamic Scene Content */}
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

      {/* 4. BOTTOM SUBTITLE CARD (Taped Paper Note with Word Highlighting) */}
      <div
        style={{
          position: 'absolute',
          bottom: 70,
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
        {/* Tapes on top corners */}
        <MaskingTape style={{ top: -10, left: 35, transform: 'rotate(-3deg)' }} />
        <MaskingTape style={{ top: -10, right: 35, transform: 'rotate(4deg)' }} />

        {/* Subtitle Words with Active Word Highlight in Orange */}
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
// SCENE 01: THE HOOK (DAYTIME LANDSCAPE & SOUNDWAVE COLLAPSE)
// ============================================================================
const Scene01Hook: React.FC<{ frame: number; progress: number; springVal: number }> = ({
  frame,
  progress,
  springVal,
}) => {
  const coffeeFloat = interpolate(progress, [0.3, 1], [0, -180], { extrapolateLeft: 'clamp' });
  const blobWobble = Math.sin(frame * 0.25) * 12;

  return (
    <AbsoluteFill style={{ overflow: 'hidden' }}>
      {/* Blue Sky with Sun & Layered Paper Clouds */}
      <div style={{ position: 'absolute', inset: 0, backgroundColor: '#7DD3FC' }} />

      {/* Sun */}
      <div
        style={{
          position: 'absolute',
          top: 90,
          right: 90,
          width: 140,
          height: 140,
          borderRadius: '50%',
          backgroundColor: '#FDE047',
          boxShadow: '0 0 45px rgba(253, 224, 71, 0.8), 0 0 100px rgba(250, 204, 21, 0.4)',
        }}
      />

      {/* Clouds */}
      <Cloud x={110} y={150} scale={1.2} />
      <Cloud x={580} y={240} scale={1.5} />
      <Cloud x={80} y={390} scale={1.0} />

      {/* Rolling Hills in Background */}
      <svg
        style={{ position: 'absolute', bottom: 120, width: '100%', height: 350 }}
        viewBox="0 0 1000 350"
      >
        <path d="M 0 240 Q 250 120 500 220 Q 750 320 1000 180 L 1000 350 L 0 350 Z" fill="#86EFAC" />
        <path d="M 0 280 Q 300 200 650 270 Q 850 310 1000 250 L 1000 350 L 0 350 Z" fill="#4ADE80" />
      </svg>

      {/* Green Floor */}
      <div
        style={{
          position: 'absolute',
          bottom: 0,
          left: 0,
          right: 0,
          height: 140,
          backgroundColor: '#22C55E',
          borderTop: '4px solid #16A34A',
        }}
      />

      {/* Outdoor Table & Floating Coffee Cup */}
      <div style={{ position: 'absolute', bottom: 140, left: 340, width: 300, height: 160 }}>
        {/* Table top */}
        <div
          style={{
            width: 300,
            height: 24,
            backgroundColor: '#B45309',
            borderRadius: 6,
            boxShadow: '0 8px 16px rgba(0,0,0,0.2)',
          }}
        />
        {/* Table legs */}
        <div style={{ width: 18, height: 136, backgroundColor: '#78350F', position: 'absolute', left: 40, top: 24 }} />
        <div style={{ width: 18, height: 136, backgroundColor: '#78350F', position: 'absolute', right: 40, top: 24 }} />

        {/* Coffee Cup */}
        <div
          style={{
            position: 'absolute',
            left: 110,
            top: -50,
            width: 80,
            height: 60,
            backgroundColor: '#FFFFFF',
            border: '4px solid #CBD5E1',
            borderRadius: '0 0 20px 20px',
            boxShadow: '0 6px 12px rgba(0,0,0,0.15)',
          }}
        >
          {/* Handle */}
          <div
            style={{
              position: 'absolute',
              right: -20,
              top: 10,
              width: 22,
              height: 34,
              border: '4px solid #CBD5E1',
              borderRadius: '0 12px 12px 0',
            }}
          />
        </div>

        {/* Liquid Sphere Floating Out into Zero-G */}
        {progress > 0.3 && (
          <div
            style={{
              position: 'absolute',
              left: 115 + blobWobble * 0.4,
              top: -60 + coffeeFloat,
              width: 70,
              height: 70,
              borderRadius: '50%',
              backgroundColor: '#78350F',
              border: '4px solid #92400E',
              boxShadow: '0 10px 25px rgba(120, 53, 15, 0.4), inset -6px -6px 14px rgba(0,0,0,0.3)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              transform: `scale(${1 + Math.sin(frame * 0.3) * 0.08})`,
            }}
          >
            {/* Liquid highlight */}
            <div
              style={{
                width: 18,
                height: 18,
                borderRadius: '50%',
                backgroundColor: '#B45309',
                position: 'absolute',
                top: 12,
                left: 14,
              }}
            />
          </div>
        )}

        {/* Comic POP Text Balloon */}
        {progress > 0.45 && progress < 0.85 && (
          <div
            style={{
              position: 'absolute',
              left: 200,
              top: -150 + coffeeFloat * 0.5,
              backgroundColor: '#FEF08A',
              border: '4px solid #000000',
              borderRadius: 20,
              padding: '10px 22px',
              fontWeight: 900,
              fontSize: 32,
              color: '#000000',
              fontFamily: THEME.fontBold,
              transform: 'rotate(12deg)',
              boxShadow: '0 8px 0 #000000',
            }}
          >
            GÜP! 🫧
          </div>
        )}
      </div>

      {/* Surprised Character Standing at Desk */}
      <div style={{ position: 'absolute', bottom: 140, left: 160 }}>
        <CharacterStickman
          pose="surprised"
          floatingY={interpolate(progress, [0.35, 1], [0, -120], { extrapolateLeft: 'clamp' })}
          rotation={interpolate(progress, [0.35, 1], [0, -15], { extrapolateLeft: 'clamp' })}
        />
      </div>
    </AbsoluteFill>
  );
};

// ============================================================================
// SCENE 02: THE ROOM CHAOS (UPSIDE DOWN CHARACTER & SPLASH)
// ============================================================================
const Scene02Room: React.FC<{ frame: number; progress: number; springVal: number }> = ({
  frame,
  progress,
  springVal,
}) => {
  const charFloatY = interpolate(progress, [0, 0.8], [0, -420]);
  const charRot = interpolate(progress, [0, 1], [0, 160]);
  const blobX = interpolate(progress, [0.2, 0.7], [300, 480]);
  const blobY = interpolate(progress, [0.2, 0.7], [650, 420]);
  const isSplash = progress > 0.65;

  return (
    <AbsoluteFill style={{ overflow: 'hidden', backgroundColor: '#FDE68A' }}>
      {/* Cozy Wallpaper with Striped Lines */}
      <svg style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', opacity: 0.15 }}>
        <pattern id="room_stripes" width="40" height="40" patternUnits="userSpaceOnUse">
          <line x1="0" y1="0" x2="0" y2="40" stroke="#B45309" strokeWidth="2" />
        </pattern>
        <rect width="100%" height="100%" fill="url(#room_stripes)" />
      </svg>

      {/* Bedroom Window with Light Beam */}
      <div
        style={{
          position: 'absolute',
          top: 140,
          left: 120,
          width: 220,
          height: 320,
          backgroundColor: '#93C5FD',
          border: '10px solid #FFFFFF',
          boxShadow: '0 10px 25px rgba(0,0,0,0.1)',
          borderRadius: 8,
          overflow: 'hidden',
        }}
      >
        <div style={{ position: 'absolute', top: 30, right: 20 }}>
          <Cloud x={0} y={0} scale={0.8} />
        </div>
      </div>

      {/* Ceiling Lamp swinging */}
      <div style={{ position: 'absolute', top: 0, left: 490 }}>
        <div style={{ width: 4, height: 160, backgroundColor: '#475569' }} />
        <div
          style={{
            position: 'absolute',
            bottom: -25,
            left: -28,
            width: 60,
            height: 30,
            backgroundColor: '#F59E0B',
            borderRadius: '20px 20px 0 0',
          }}
        />
      </div>

      {/* Wooden Floor at Bottom */}
      <div
        style={{
          position: 'absolute',
          bottom: 0,
          left: 0,
          right: 0,
          height: 120,
          backgroundColor: '#78350F',
          borderTop: '6px solid #92400E',
        }}
      />

      {/* Character Floating Upwards and Tumbling */}
      <div style={{ position: 'absolute', bottom: 160, left: 340 }}>
        <CharacterStickman pose="flail" floatingY={charFloatY} rotation={charRot} />
      </div>

      {/* Floating Props (Laptop, Slippers, Pen) */}
      <div
        style={{
          position: 'absolute',
          bottom: 300 - charFloatY * 0.7,
          left: 160,
          transform: `rotate(${frame * 2}deg)`,
        }}
      >
        {/* Laptop */}
        <div style={{ width: 90, height: 60, backgroundColor: '#64748B', borderRadius: 6, border: '3px solid #334155' }} />
      </div>

      <div
        style={{
          position: 'absolute',
          bottom: 220 - charFloatY * 0.9,
          right: 200,
          transform: `rotate(${-frame * 1.5}deg)`,
        }}
      >
        {/* Slippers */}
        <div style={{ width: 55, height: 26, backgroundColor: '#EF4444', borderRadius: '14px 14px 6px 6px' }} />
      </div>

      {/* Floating Coffee Sphere Moving Towards Character */}
      {!isSplash ? (
        <div
          style={{
            position: 'absolute',
            left: blobX,
            top: blobY,
            width: 80,
            height: 80,
            borderRadius: '50%',
            backgroundColor: '#78350F',
            border: '4px solid #92400E',
            boxShadow: '0 10px 30px rgba(120, 53, 15, 0.5)',
          }}
        />
      ) : (
        /* Comic SPLASH on character's face */
        <div
          style={{
            position: 'absolute',
            left: 450,
            top: 380,
            backgroundColor: '#FEF08A',
            border: '5px solid #000000',
            borderRadius: 24,
            padding: '14px 28px',
            fontFamily: THEME.fontBold,
            fontSize: 48,
            color: '#78350F',
            transform: 'rotate(-10deg) scale(1.15)',
            boxShadow: '0 10px 0 #000000',
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
// SCENE 03: OUTDOORS & CARS FLOATING (WHEELS SPINNING)
// ============================================================================
const Scene03Street: React.FC<{ frame: number; progress: number; springVal: number }> = ({
  frame,
  progress,
  springVal,
}) => {
  const carFloatY = interpolate(progress, [0, 1], [0, -280]);
  const dogFloatY = interpolate(progress, [0, 1], [0, -380]);
  const carRot = Math.sin(frame * 0.1) * 8 - 12;

  return (
    <AbsoluteFill style={{ overflow: 'hidden', backgroundColor: '#93C5FD' }}>
      {/* Cityscape Buildings in Background */}
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
        <div style={{ width: 140, height: 420, backgroundColor: '#F87171', borderRadius: '8px 8px 0 0' }} />
        <div style={{ width: 180, height: 520, backgroundColor: '#FCD34D', borderRadius: '8px 8px 0 0' }} />
        <div style={{ width: 160, height: 380, backgroundColor: '#A78BFA', borderRadius: '8px 8px 0 0' }} />
        <div style={{ width: 220, height: 480, backgroundColor: '#38BDF8', borderRadius: '8px 8px 0 0' }} />
        <div style={{ width: 150, height: 350, backgroundColor: '#FB923C', borderRadius: '8px 8px 0 0' }} />
      </div>

      {/* Clouds in Sky */}
      <Cloud x={120} y={90} scale={1.2} />
      <Cloud x={620} y={140} scale={1.4} />

      {/* Street & Sidewalk */}
      <div
        style={{
          position: 'absolute',
          bottom: 0,
          left: 0,
          right: 0,
          height: 220,
          backgroundColor: '#334155',
          borderTop: '16px solid #CBD5E1',
        }}
      >
        {/* Road markings */}
        <div style={{ display: 'flex', gap: 60, marginTop: 70, paddingLeft: 40 }}>
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} style={{ width: 80, height: 12, backgroundColor: '#FFFFFF', borderRadius: 4 }} />
          ))}
        </div>
      </div>

      {/* Floating Red Car */}
      <div
        style={{
          position: 'absolute',
          bottom: 180 - carFloatY,
          left: 280,
          transform: `rotate(${carRot}deg)`,
        }}
      >
        {/* Car Body */}
        <div
          style={{
            width: 320,
            height: 110,
            backgroundColor: '#EF4444',
            borderRadius: '40px 60px 10px 10px',
            position: 'relative',
            boxShadow: '0 15px 35px rgba(0,0,0,0.3)',
          }}
        >
          {/* Windows */}
          <div
            style={{
              position: 'absolute',
              top: 15,
              left: 60,
              width: 90,
              height: 45,
              backgroundColor: '#BAE6FD',
              borderRadius: '16px 0 0 0',
            }}
          />
          <div
            style={{
              position: 'absolute',
              top: 15,
              left: 165,
              width: 80,
              height: 45,
              backgroundColor: '#BAE6FD',
              borderRadius: '0 24px 0 0',
            }}
          />

          {/* Shocked Driver */}
          <div style={{ position: 'absolute', top: 22, left: 185, fontSize: 32 }}>😱</div>

          {/* Wheels Spinning in Mid-Air */}
          <div
            style={{
              position: 'absolute',
              bottom: -30,
              left: 45,
              width: 65,
              height: 65,
              borderRadius: '50%',
              backgroundColor: '#0F172A',
              border: '6px dashed #94A3B8',
              transform: `rotate(${frame * 35}deg)`,
            }}
          />
          <div
            style={{
              position: 'absolute',
              bottom: -30,
              right: 45,
              width: 65,
              height: 65,
              borderRadius: '50%',
              backgroundColor: '#0F172A',
              border: '6px dashed #94A3B8',
              transform: `rotate(${frame * 35}deg)`,
            }}
          />
        </div>

        {/* Wheels spinning SFX balloon */}
        <div
          style={{
            position: 'absolute',
            bottom: -80,
            left: 90,
            backgroundColor: '#FFFFFF',
            border: '3px solid #000000',
            borderRadius: 12,
            padding: '4px 14px',
            fontSize: 22,
            fontWeight: 800,
            color: '#000000',
          }}
        >
          VIIN! 🏎️💨
        </div>
      </div>

      {/* Floating Cute Dog Drifting into Sky */}
      <div
        style={{
          position: 'absolute',
          bottom: 240 - dogFloatY,
          right: 140,
          transform: `rotate(${frame * 1.5}deg)`,
        }}
      >
        <div style={{ fontSize: 72 }}>🐕</div>
        <div
          style={{
            backgroundColor: '#FEF08A',
            border: '2px solid #000000',
            borderRadius: 10,
            padding: '2px 8px',
            fontSize: 16,
            fontWeight: 800,
            marginTop: -10,
          }}
        >
          HAV? ❓
        </div>
      </div>

      {/* Trash Can Floating */}
      <div
        style={{
          position: 'absolute',
          bottom: 240 - dogFloatY * 0.8,
          left: 100,
          transform: `rotate(${-frame * 2}deg)`,
        }}
      >
        <div style={{ width: 60, height: 85, backgroundColor: '#10B981', borderRadius: 8, border: '3px solid #065F46' }} />
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
  springVal,
}) => {
  const waveLift = interpolate(progress, [0, 1], [0, -320]);

  return (
    <AbsoluteFill style={{ overflow: 'hidden', backgroundColor: '#030712' }}>
      {/* Deep Space Background with Stars */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: 'radial-gradient(circle at 50% 20%, #1E1B4B 0%, #030712 90%)',
        }}
      />

      {/* Earth Curve at Bottom */}
      <div
        style={{
          position: 'absolute',
          bottom: -400,
          left: -100,
          right: -100,
          height: 700,
          borderRadius: '50%',
          backgroundColor: '#1E3A8A',
          border: '8px solid #38BDF8',
          boxShadow: '0 0 100px rgba(56, 189, 248, 0.4)',
        }}
      />

      {/* Giant Ocean Water Masses Floating Upwards into Space */}
      {Array.from({ length: 6 }).map((_, i) => {
        const wx = 120 + i * 140;
        const wy = 580 - (i % 3) * 60 + waveLift * (1 + (i % 3) * 0.2);
        const wobble = Math.sin((frame + i * 20) * 0.2) * 16;
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: wx + wobble,
              top: wy,
              width: 130 + (i % 2) * 40,
              height: 110 + (i % 3) * 30,
              borderRadius: '45% 55% 60% 40% / 50% 45% 55% 50%',
              backgroundColor: '#0EA5E9',
              border: '4px solid #38BDF8',
              opacity: 0.88,
              boxShadow: '0 15px 40px rgba(14, 165, 233, 0.5)',
              transform: `rotate(${frame * (i % 2 === 0 ? 1 : -1) * 0.8}deg)`,
            }}
          />
        );
      })}

      {/* Escaping Atmosphere Indicator Arrows */}
      <div
        style={{
          position: 'absolute',
          top: 140,
          left: 0,
          right: 0,
          display: 'flex',
          justifyContent: 'space-around',
          color: '#38BDF8',
          fontSize: 36,
          fontWeight: 900,
        }}
      >
        <span>⬆ ATMOSFER KAÇIYOR</span>
        <span>⬆ 0 BAR BASINÇ</span>
      </div>
    </AbsoluteFill>
  );
};

// ============================================================================
// SCENE 05: THE EPIC CRASH (10 SECONDS ENDS, GRAVITY RESTORES!)
// ============================================================================
const Scene05Crash: React.FC<{ frame: number; progress: number; springVal: number }> = ({
  frame,
  progress,
  springVal,
}) => {
  const isCrashed = progress > 0.2;
  const bonkScale = spring({
    frame: frame - metadata.scenes[4].startFrame - 8,
    fps: 30,
    config: { damping: 10, stiffness: 140 },
  });

  return (
    <AbsoluteFill style={{ overflow: 'hidden', backgroundColor: '#FEF08A' }}>
      {/* Ground Floor */}
      <div
        style={{
          position: 'absolute',
          bottom: 0,
          left: 0,
          right: 0,
          height: 280,
          backgroundColor: '#334155',
          borderTop: '8px solid #64748B',
        }}
      />

      {/* Downward Speed Lines before crash */}
      {!isCrashed && (
        <svg style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
          {Array.from({ length: 25 }).map((_, i) => {
            const lx = (i * 42) % 980 + 20;
            return (
              <line
                key={i}
                x1={lx}
                y1={0}
                x2={lx}
                y2={1200}
                stroke="#EF4444"
                strokeWidth="4"
                strokeDasharray="40 20"
                opacity="0.6"
              />
            );
          })}
        </svg>
      )}

      {/* Character Flattened on Ground */}
      <div style={{ position: 'absolute', bottom: 250, left: 340 }}>
        {/* Flattened character with X eyes */}
        <div style={{ transform: 'rotate(90deg)' }}>
          <CharacterStickman pose="knocked" floatingY={0} rotation={0} />
        </div>

        {/* Coffee Cup Landed on Head with TINK! */}
        <div
          style={{
            position: 'absolute',
            top: -60,
            left: 20,
            fontSize: 48,
            transform: 'rotate(-25deg)',
          }}
        >
          ☕
        </div>

        {/* Dizzy Stars Spinning */}
        <div
          style={{
            position: 'absolute',
            top: -40,
            left: 60,
            display: 'flex',
            gap: 10,
            fontSize: 28,
            transform: `rotate(${frame * 8}deg)`,
          }}
        >
          <span>⭐</span>
          <span>💫</span>
          <span>⭐</span>
        </div>
      </div>

      {/* Crashed Red Car Flat on Floor */}
      <div style={{ position: 'absolute', bottom: 260, right: 60 }}>
        <div
          style={{
            width: 280,
            height: 80,
            backgroundColor: '#DC2626',
            borderRadius: '20px 30px 4px 4px',
            boxShadow: '0 10px 20px rgba(0,0,0,0.4)',
            transform: 'scaleY(0.75)',
          }}
        />
      </div>

      {/* GIANT COMIC BONK! EXPLOSION */}
      {isCrashed && (
        <div
          style={{
            position: 'absolute',
            top: 280,
            left: '50%',
            transform: `translateX(-50%) scale(${bonkScale}) rotate(-6deg)`,
            backgroundColor: '#EF4444',
            border: '8px solid #000000',
            borderRadius: 36,
            padding: '24px 60px',
            boxShadow: '0 16px 0 #000000',
            zIndex: 60,
          }}
        >
          <span
            style={{
              fontFamily: THEME.fontBold,
              fontSize: 84,
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
// MODULAR VECTOR CHARACTER (SVG RIG)
// ============================================================================
const CharacterStickman: React.FC<{
  pose: 'normal' | 'surprised' | 'flail' | 'knocked';
  floatingY: number;
  rotation: number;
}> = ({ pose, floatingY, rotation }) => {
  const isKnocked = pose === 'knocked';
  const isSurprised = pose === 'surprised' || pose === 'flail';

  return (
    <div
      style={{
        transform: `translateY(${floatingY}px) rotate(${rotation}deg)`,
        transformOrigin: '50% 60%',
        width: 140,
        height: 280,
        position: 'relative',
      }}
    >
      {/* Head */}
      <div
        style={{
          position: 'absolute',
          top: 0,
          left: 30,
          width: 80,
          height: 80,
          borderRadius: '50%',
          backgroundColor: '#FED7AA',
          border: '4px solid #EA580C',
        }}
      >
        {/* Hair */}
        <div
          style={{
            position: 'absolute',
            top: -4,
            left: -4,
            width: 88,
            height: 36,
            backgroundColor: '#451A03',
            borderRadius: '40px 40px 0 0',
          }}
        />

        {/* Eyes */}
        {!isKnocked ? (
          <>
            <div
              style={{
                position: 'absolute',
                top: 32,
                left: 45,
                width: 12,
                height: isSurprised ? 16 : 12,
                borderRadius: '50%',
                backgroundColor: '#000000',
              }}
            />
            {/* Mouth */}
            <div
              style={{
                position: 'absolute',
                top: 52,
                left: 48,
                width: isSurprised ? 16 : 12,
                height: isSurprised ? 16 : 4,
                borderRadius: isSurprised ? '50%' : 2,
                backgroundColor: isSurprised ? '#991B1B' : '#000000',
              }}
            />
          </>
        ) : (
          /* X X Knocked Eyes */
          <div style={{ position: 'absolute', top: 32, left: 40, fontSize: 24, fontWeight: 900 }}>
            ✖ ✖
          </div>
        )}
      </div>

      {/* Torso / Orange Shirt */}
      <div
        style={{
          position: 'absolute',
          top: 80,
          left: 35,
          width: 70,
          height: 95,
          backgroundColor: '#EA580C',
          borderRadius: 12,
          border: '4px solid #C2410C',
        }}
      />

      {/* Legs / Dark Blue Pants */}
      <div
        style={{
          position: 'absolute',
          top: 175,
          left: 42,
          width: 24,
          height: 95,
          backgroundColor: '#1E3A8A',
          borderRadius: 8,
        }}
      />
      <div
        style={{
          position: 'absolute',
          top: 175,
          left: 74,
          width: 24,
          height: 95,
          backgroundColor: '#1E3A8A',
          borderRadius: 8,
        }}
      />

      {/* Shoes */}
      <div
        style={{
          position: 'absolute',
          bottom: 0,
          left: 36,
          width: 34,
          height: 18,
          backgroundColor: '#FFFFFF',
          borderRadius: 10,
        }}
      />
      <div
        style={{
          position: 'absolute',
          bottom: 0,
          left: 70,
          width: 34,
          height: 18,
          backgroundColor: '#FFFFFF',
          borderRadius: 10,
        }}
      />
    </div>
  );
};

// Reusable Paper Cloud Shape
const Cloud: React.FC<{ x: number; y: number; scale?: number }> = ({ x, y, scale = 1 }) => (
  <div
    style={{
      position: 'absolute',
      left: x,
      top: y,
      transform: `scale(${scale})`,
      filter: 'drop-shadow(0 6px 12px rgba(0,0,0,0.15))',
    }}
  >
    <div style={{ width: 140, height: 50, backgroundColor: '#FFFFFF', borderRadius: 25, position: 'relative' }}>
      <div style={{ position: 'absolute', top: -25, left: 25, width: 50, height: 50, backgroundColor: '#FFFFFF', borderRadius: '50%' }} />
      <div style={{ position: 'absolute', top: -35, left: 60, width: 60, height: 60, backgroundColor: '#FFFFFF', borderRadius: '50%' }} />
    </div>
  </div>
);
