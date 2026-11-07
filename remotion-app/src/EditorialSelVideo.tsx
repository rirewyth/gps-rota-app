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
import metadata from './editorial_sel_metadata.json';
import turkeyPaths from './assets/maps/turkey_map_paths.json';
import istanbulData from './assets/maps/istanbul_map_path.json';

// --- STYLING CONSTANTS (Match reference video theme: banka & yildirim) ---
const THEME = {
  bgDeep: '#050B14',
  bgNavy: '#0A1325',
  accentOrange: '#FF4D26',
  accentGold: '#F5A623',
  accentCyan: '#00E5FF',
  textLight: '#F8FAFC',
  textMuted: '#94A3B8',
  paperBg: '#EDE8DE',
  paperBorder: '#D8D1C3',
  stampRed: '#E11D48',
  fontSerif: 'Georgia, "Playfair Display", "Times New Roman", serif',
  fontSans: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
  fontMono: '"Courier New", Courier, monospace',
};

export const EditorialSelVideo: React.FC = () => {
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
    config: { damping: 14, stiffness: 90 },
  });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: THEME.bgDeep,
        fontFamily: THEME.fontSans,
        color: THEME.textLight,
        overflow: 'hidden',
      }}
    >
      {/* Master Soundtrack */}
      <Audio src={staticFile('editorial_sel/editorial_sel_master_soundtrack.mp3')} />

      {/* 1. Global Tactical Blueprint Background */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: `radial-gradient(circle at 50% 40%, ${THEME.bgNavy} 0%, ${THEME.bgDeep} 85%)`,
        }}
      />

      {/* Blueprint Grid Lines & Crosshairs */}
      <svg
        style={{
          position: 'absolute',
          inset: 0,
          width: '100%',
          height: '100%',
          opacity: 0.22,
          pointerEvents: 'none',
        }}
      >
        <defs>
          <pattern id="grid" width="120" height="120" patternUnits="userSpaceOnUse">
            <path
              d="M 120 0 L 0 0 0 120"
              fill="none"
              stroke="rgba(255,255,255,0.12)"
              strokeWidth="1"
            />
            <path
              d="M 60 55 L 60 65 M 55 60 L 65 60"
              fill="none"
              stroke={THEME.accentCyan}
              strokeWidth="1.2"
              opacity="0.6"
            />
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill="url(#grid)" />
      </svg>

      {/* Vignette Edge Shading */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          boxShadow: 'inset 0 0 160px rgba(0,0,0,0.85)',
          pointerEvents: 'none',
        }}
      />

      {/* 2. Top Tactical HUD (Coordinates, Scale, Fig Badge) */}
      <div
        style={{
          position: 'absolute',
          top: 70,
          left: 60,
          right: 60,
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'flex-start',
          zIndex: 50,
          fontFamily: THEME.fontMono,
          fontSize: 22,
          letterSpacing: 2,
        }}
      >
        {/* Left: FIG & Section Title */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <div
            style={{
              width: 5,
              height: 28,
              backgroundColor: THEME.accentOrange,
              borderRadius: 2,
              boxShadow: `0 0 12px ${THEME.accentOrange}`,
            }}
          />
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            <span style={{ color: THEME.textLight, fontWeight: 700 }}>
              {activeScene.fig}{' '}
              <span style={{ color: THEME.textMuted, fontWeight: 400, marginLeft: 8 }}>
                {activeScene.fig_title}
              </span>
            </span>
          </div>
        </div>

        {/* Right: Technical Coordinates & Map Scale */}
        <div style={{ textAlign: 'right', display: 'flex', flexDirection: 'column', gap: 4 }}>
          <span style={{ color: THEME.textMuted, fontSize: 20 }}>{activeScene.coords}</span>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'flex-end',
              gap: 8,
              color: 'rgba(255,255,255,0.4)',
              fontSize: 16,
            }}
          >
            <span>{activeScene.scale}</span>
            <div
              style={{
                width: 90,
                height: 3,
                backgroundColor: 'rgba(255,255,255,0.3)',
                position: 'relative',
              }}
            >
              <div
                style={{
                  position: 'absolute',
                  left: 0,
                  top: -4,
                  width: 2,
                  height: 11,
                  backgroundColor: 'rgba(255,255,255,0.5)',
                }}
              />
              <div
                style={{
                  position: 'absolute',
                  right: 0,
                  top: -4,
                  width: 2,
                  height: 11,
                  backgroundColor: 'rgba(255,255,255,0.5)',
                }}
              />
            </div>
          </div>
        </div>
      </div>

      {/* 3. SCENE SPECIFIC VISUALS */}
      <AbsoluteFill style={{ zIndex: 10 }}>
        {activeScene.id === 'scene_00_intro' && (
          <IntroScene frame={frame} progress={sceneProgress} />
        )}
        {activeScene.id === 'scene_01_rekor' && (
          <RekorScene frame={frame} progress={sceneProgress} sceneSpring={sceneSpring} />
        )}
        {activeScene.id === 'scene_02_toprak' && (
          <ToprakScene frame={frame} progress={sceneProgress} sceneSpring={sceneSpring} />
        )}
        {activeScene.id === 'scene_03_meteoroloji' && (
          <MeteorolojiScene frame={frame} progress={sceneProgress} sceneSpring={sceneSpring} />
        )}
        {activeScene.id === 'scene_04_beton' && (
          <BetonScene frame={frame} progress={sceneProgress} sceneSpring={sceneSpring} />
        )}
        {activeScene.id === 'scene_05_sunger' && (
          <SungerScene frame={frame} progress={sceneProgress} sceneSpring={sceneSpring} />
        )}
        {activeScene.id === 'scene_06_sonuc' && (
          <SonucScene frame={frame} progress={sceneProgress} sceneSpring={sceneSpring} />
        )}
      </AbsoluteFill>

      {/* 4. SOLID PROFESSIONAL SUBTITLE BAR (NO FLICKERING) */}
      <div
        style={{
          position: 'absolute',
          bottom: 110,
          left: 60,
          right: 60,
          zIndex: 60,
          display: 'flex',
          justifyContent: 'center',
        }}
      >
        <div
          style={{
            backgroundColor: 'rgba(6, 12, 24, 0.88)',
            backdropFilter: 'blur(16px)',
            border: '1px solid rgba(255, 255, 255, 0.14)',
            borderRadius: 16,
            padding: '20px 32px',
            boxShadow: '0 20px 40px rgba(0, 0, 0, 0.7)',
            display: 'flex',
            alignItems: 'center',
            gap: 18,
            maxWidth: 960,
            width: '100%',
          }}
        >
          {/* Accent vertical bar (Cutreal/Banka style) */}
          <div
            style={{
              width: 5,
              height: 40,
              backgroundColor: THEME.accentOrange,
              borderRadius: 3,
              flexShrink: 0,
              boxShadow: `0 0 10px ${THEME.accentOrange}`,
            }}
          />
          <p
            style={{
              margin: 0,
              fontSize: 30,
              fontWeight: 500,
              lineHeight: 1.35,
              color: THEME.textLight,
              fontFamily: THEME.fontSans,
              letterSpacing: -0.3,
            }}
          >
            {activeScene.script}
          </p>
        </div>
      </div>
    </AbsoluteFill>
  );
};

// ============================================================================
// SCENE 00: ROTA MEDYA INTRO
// ============================================================================
const IntroScene: React.FC<{ frame: number; progress: number }> = ({ frame, progress }) => {
  const rotation = frame * 1.5;
  const pulse = Math.sin(frame * 0.15) * 0.08 + 1;

  return (
    <AbsoluteFill
      style={{
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center',
        alignItems: 'center',
        textAlign: 'center',
      }}
    >
      {/* High-tech rotating compass reticle */}
      <div
        style={{
          width: 380,
          height: 380,
          borderRadius: '50%',
          border: '2px dashed rgba(0, 229, 255, 0.35)',
          position: 'absolute',
          transform: `rotate(${rotation}deg) scale(${pulse})`,
          boxShadow: '0 0 50px rgba(0, 229, 255, 0.15)',
        }}
      />
      <div
        style={{
          width: 320,
          height: 320,
          borderRadius: '50%',
          border: '1px solid rgba(255, 77, 38, 0.4)',
          position: 'absolute',
          transform: `rotate(-${rotation * 0.7}deg)`,
        }}
      />

      {/* ROTA MEDYA Central Emblem */}
      <div
        style={{
          position: 'relative',
          zIndex: 10,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: 16,
        }}
      >
        <div
          style={{
            fontFamily: THEME.fontMono,
            fontSize: 20,
            letterSpacing: 8,
            color: THEME.accentCyan,
            textTransform: 'uppercase',
          }}
        >
          ÖZEL DOSYA · NO. 34
        </div>

        <h1
          style={{
            fontFamily: THEME.fontSerif,
            fontSize: 84,
            fontWeight: 900,
            letterSpacing: 4,
            margin: 0,
            color: '#FFFFFF',
            textShadow: '0 0 30px rgba(255,255,255,0.4)',
          }}
        >
          ROTA MEDYA
        </h1>

        <div
          style={{
            height: 3,
            width: 240,
            background: `linear-gradient(90deg, transparent, ${THEME.accentOrange}, transparent)`,
            margin: '8px 0',
          }}
        />

        <div
          style={{
            fontFamily: THEME.fontSans,
            fontSize: 32,
            fontWeight: 600,
            color: THEME.accentGold,
            letterSpacing: 2,
          }}
        >
          İSTANBUL AFET RAPORU
        </div>

        {/* Audio Waveform Viz */}
        <div style={{ display: 'flex', gap: 6, marginTop: 24 }}>
          {Array.from({ length: 16 }).map((_, i) => {
            const h = Math.abs(Math.sin((frame + i * 8) * 0.2)) * 36 + 8;
            return (
              <div
                key={i}
                style={{
                  width: 5,
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
// SCENE 01: 84 YILIN REKORU (REAL TURKEY & ISTANBUL MAP + DOSSIER CARD)
// ============================================================================
const RekorScene: React.FC<{
  frame: number;
  progress: number;
  sceneSpring: number;
}> = ({ frame, progress, sceneSpring }) => {
  // Zoom into Istanbul on the real map
  const mapScale = interpolate(progress, [0, 1], [1.1, 1.45]);
  const mapTransX = interpolate(progress, [0, 1], [0, -140]);
  const mapTransY = interpolate(progress, [0, 1], [0, -40]);

  return (
    <AbsoluteFill
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        paddingTop: 180,
      }}
    >
      {/* Real Turkey Geographic Vector Map */}
      <div
        style={{
          width: 900,
          height: 450,
          position: 'relative',
          transform: `scale(${mapScale}) translate(${mapTransX}px, ${mapTransY}px)`,
          transformOrigin: '55% 45%',
          filter: 'drop-shadow(0 25px 35px rgba(0,0,0,0.8))',
        }}
      >
        <svg viewBox="0 0 900 450" style={{ width: '100%', height: '100%' }}>
          {/* Turkey Provinces Silhouettes */}
          {turkeyPaths.map((prov, i) => {
            const isIstanbul = prov.number === 34;
            return (
              <path
                key={i}
                d={prov.d}
                fill={isIstanbul ? THEME.accentOrange : '#1E293B'}
                stroke="rgba(255, 255, 255, 0.15)"
                strokeWidth={isIstanbul ? '2.5' : '0.8'}
                opacity={isIstanbul ? 1 : 0.75}
              />
            );
          })}

          {/* Sea Labels in elegant serif italics (Banka style) */}
          <text
            x="480"
            y="70"
            fill="rgba(255,255,255,0.25)"
            fontSize="26"
            fontFamily={THEME.fontSerif}
            fontStyle="italic"
            letterSpacing="8"
          >
            KARADENİZ
          </text>
          <text
            x="360"
            y="420"
            fill="rgba(255,255,255,0.25)"
            fontSize="26"
            fontFamily={THEME.fontSerif}
            fontStyle="italic"
            letterSpacing="8"
          >
            AKDENİZ
          </text>

          {/* Epicenter Target Pin & Doppler Radar Waves on Istanbul */}
          <g transform="translate(195, 125)">
            <circle
              r={12 + Math.sin(frame * 0.2) * 6}
              fill="none"
              stroke={THEME.accentOrange}
              strokeWidth="2.5"
              opacity="0.8"
            />
            <circle
              r={28 + Math.sin(frame * 0.15) * 12}
              fill="none"
              stroke={THEME.accentOrange}
              strokeWidth="1.5"
              opacity="0.4"
            />
            <circle r="6" fill={THEME.accentOrange} />
          </g>
        </svg>

        {/* Map Callout Pin Label */}
        <div
          style={{
            position: 'absolute',
            left: 210,
            top: 70,
            backgroundColor: 'rgba(15, 23, 42, 0.9)',
            border: `1px solid ${THEME.accentOrange}`,
            padding: '6px 14px',
            borderRadius: 6,
            fontSize: 16,
            fontFamily: THEME.fontMono,
            color: '#FFFFFF',
            boxShadow: '0 4px 12px rgba(0,0,0,0.5)',
          }}
        >
          İSTANBUL · BEYKOZ (272 kg/m²)
        </div>
      </div>

      {/* Tactile Dossier Archive Card (Cutreal / Banka Dossier Style) */}
      <div
        style={{
          width: 880,
          backgroundColor: THEME.paperBg,
          borderRadius: 8,
          border: `2px solid ${THEME.paperBorder}`,
          boxShadow: '0 30px 60px rgba(0,0,0,0.7), inset 0 0 20px rgba(0,0,0,0.04)',
          color: '#1E293B',
          padding: '36px 44px',
          marginTop: 60,
          transform: `translateY(${(1 - sceneSpring) * 60}px) scale(${sceneSpring})`,
          opacity: sceneSpring,
          position: 'relative',
        }}
      >
        {/* Double border inset */}
        <div
          style={{
            position: 'absolute',
            inset: 8,
            border: '1px solid rgba(0,0,0,0.1)',
            pointerEvents: 'none',
          }}
        />

        {/* Card Header */}
        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            borderBottom: '2px solid rgba(0,0,0,0.1)',
            paddingBottom: 14,
            marginBottom: 24,
            fontFamily: THEME.fontMono,
            fontSize: 18,
            letterSpacing: 2,
            color: THEME.stampRed,
            fontWeight: 700,
          }}
        >
          <span>METEOROLOJİ GENEL MÜDÜRLÜĞÜ · DOSYA NO. 34</span>
          <span style={{ color: '#475569' }}>14-15 EKİM 2026</span>
        </div>

        {/* Hero Serif Numbers */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <div>
            <div
              style={{
                fontFamily: THEME.fontSerif,
                fontSize: 64,
                fontWeight: 900,
                lineHeight: 1.1,
                color: '#0F172A',
              }}
            >
              272 <span style={{ fontSize: 36, fontWeight: 600 }}>kg / m²</span>
            </div>
            <div
              style={{
                fontFamily: THEME.fontSans,
                fontSize: 22,
                color: '#64748B',
                marginTop: 6,
                fontWeight: 600,
              }}
            >
              Beykoz & Sarıyer — 84 Yılın Rekoru (1942'den Beri)
            </div>
          </div>

          {/* Slanted Ink Stamp */}
          <div
            style={{
              border: `3px solid ${THEME.stampRed}`,
              borderRadius: 6,
              padding: '8px 18px',
              color: THEME.stampRed,
              fontFamily: THEME.fontMono,
              fontSize: 24,
              fontWeight: 900,
              letterSpacing: 3,
              transform: 'rotate(-8deg)',
              boxShadow: 'inset 0 0 8px rgba(225, 29, 72, 0.2)',
            }}
          >
            KOD KIRMIZI
          </div>
        </div>

        {/* Data Rows */}
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: '1fr 1fr',
            gap: 20,
            marginTop: 28,
            paddingTop: 20,
            borderTop: '1px dashed rgba(0,0,0,0.15)',
            fontFamily: THEME.fontMono,
            fontSize: 19,
          }}
        >
          <div>
            <span style={{ color: '#64748B' }}>ÖNCEKİ DURUM:</span>{' '}
            <strong style={{ color: '#0F172A' }}>90 Gün Aşırı Kuraklık</strong>
          </div>
          <div>
            <span style={{ color: '#64748B' }}>DÜŞEN YAĞIŞ:</span>{' '}
            <strong style={{ color: THEME.stampRed }}>4 Aylık Yağış / 6 Saat</strong>
          </div>
        </div>
      </div>
    </AbsoluteFill>
  );
};

// ============================================================================
// SCENE 02: TOPRAK PARADOKSU (HYDROPHOBIC SOIL STRATA CROSS-SECTION)
// ============================================================================
const ToprakScene: React.FC<{
  frame: number;
  progress: number;
  sceneSpring: number;
}> = ({ frame, progress, sceneSpring }) => {
  return (
    <AbsoluteFill
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        paddingTop: 180,
      }}
    >
      {/* Large Editorial Serif Question (Banka / Cutreal style) */}
      <div
        style={{
          fontFamily: THEME.fontSerif,
          fontSize: 54,
          fontWeight: 800,
          textAlign: 'center',
          lineHeight: 1.25,
          color: '#FFFFFF',
          marginBottom: 36,
          transform: `translateY(${(1 - sceneSpring) * 30}px)`,
        }}
      >
        Kuru toprak suyu çeker mi?{' '}
        <span style={{ color: THEME.accentOrange, fontStyle: 'italic' }}>Hayır.</span>
      </div>

      {/* Tactile Geological Soil Strata Cutaway Box */}
      <div
        style={{
          width: 900,
          height: 480,
          backgroundColor: '#0F172A',
          borderRadius: 16,
          border: '2px solid rgba(255,255,255,0.15)',
          boxShadow: '0 25px 50px rgba(0,0,0,0.7)',
          overflow: 'hidden',
          position: 'relative',
        }}
      >
        {/* Animated Rain Falling from Clouds */}
        <svg
          style={{
            position: 'absolute',
            top: 0,
            left: 0,
            width: '100%',
            height: 140,
            zIndex: 10,
          }}
        >
          {Array.from({ length: 30 }).map((_, i) => {
            const rx = (i * 31) % 880 + 10;
            const ry = ((frame * 18 + i * 45) % 130) + 10;
            return (
              <line
                key={i}
                x1={rx}
                y1={ry}
                x2={rx - 4}
                y2={ry + 16}
                stroke={THEME.accentCyan}
                strokeWidth="2.5"
                opacity="0.75"
              />
            );
          })}
        </svg>

        {/* Soil Surface: Hardened Hydrophobic Crust */}
        <div
          style={{
            position: 'absolute',
            top: 140,
            left: 0,
            right: 0,
            height: 50,
            background: 'linear-gradient(180deg, #B45309 0%, #78350F 100%)',
            borderTop: '3px solid #F59E0B',
            boxShadow: '0 0 25px rgba(245, 158, 11, 0.4)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '0 24px',
            color: '#FEF3C7',
            fontFamily: THEME.fontMono,
            fontSize: 18,
            fontWeight: 700,
            zIndex: 20,
          }}
        >
          <span>FIRINLANMIŞ HİDROFOBİK KABUK (0-5 CM)</span>
          <span style={{ color: '#FCD34D' }}>GÖZENEKLER TIKALI ✕</span>
        </div>

        {/* Runoff Water Torrent sliding sideways across the crust */}
        <div
          style={{
            position: 'absolute',
            top: 120,
            left: 0,
            right: 0,
            height: 24,
            background: `linear-gradient(90deg, transparent, ${THEME.accentCyan}, ${THEME.accentOrange})`,
            opacity: 0.85,
            zIndex: 25,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'flex-end',
            paddingRight: 20,
            fontSize: 14,
            fontWeight: 800,
            color: '#FFFFFF',
            fontFamily: THEME.fontMono,
          }}
        >
          HIZLI YÜZEY AKIŞI (RUNOFF) ➔➔➔
        </div>

        {/* Soil Sub-layer 2: Dry Compact Clay */}
        <div
          style={{
            position: 'absolute',
            top: 190,
            left: 0,
            right: 0,
            height: 140,
            backgroundColor: '#451A03',
            borderBottom: '1px dashed rgba(255,255,255,0.2)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: '#D97706',
            fontFamily: THEME.fontMono,
            fontSize: 18,
          }}
        >
          KURU KİLLİ ZEMİN (NEM: %0 — SU GEÇİRMEZLİK BARİYERİ)
        </div>

        {/* Soil Sub-layer 3: Solid Bedrock */}
        <div
          style={{
            position: 'absolute',
            top: 330,
            left: 0,
            right: 0,
            bottom: 0,
            backgroundColor: '#1E1B18',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: '#71717A',
            fontFamily: THEME.fontMono,
            fontSize: 18,
          }}
        >
          ANA KAYA TABAKASI
        </div>
      </div>

      {/* Physics Gauge Metrics (Infiltration vs Runoff) */}
      <div
        style={{
          width: 900,
          display: 'grid',
          gridTemplateColumns: '1fr 1fr',
          gap: 24,
          marginTop: 36,
        }}
      >
        <div
          style={{
            backgroundColor: 'rgba(239, 68, 68, 0.12)',
            border: '2px solid rgba(239, 68, 68, 0.4)',
            borderRadius: 12,
            padding: '20px 24px',
          }}
        >
          <div style={{ color: '#FCA5A5', fontFamily: THEME.fontMono, fontSize: 18 }}>
            TOPRAĞA SIZMA (İNFiLTRASYON)
          </div>
          <div style={{ fontSize: 48, fontWeight: 900, color: '#EF4444', marginTop: 4 }}>
            %8 <span style={{ fontSize: 20, fontWeight: 500 }}>(MİNİMUM)</span>
          </div>
        </div>

        <div
          style={{
            backgroundColor: 'rgba(0, 229, 255, 0.12)',
            border: '2px solid rgba(0, 229, 255, 0.4)',
            borderRadius: 12,
            padding: '20px 24px',
          }}
        >
          <div style={{ color: '#67E8F9', fontFamily: THEME.fontMono, fontSize: 18 }}>
            YÜZEYDE AKAN SEL SUYU (RUNOFF)
          </div>
          <div style={{ fontSize: 48, fontWeight: 900, color: THEME.accentCyan, marginTop: 4 }}>
            %92 <span style={{ fontSize: 20, fontWeight: 500 }}>(KATSTROFİK)</span>
          </div>
        </div>
      </div>
    </AbsoluteFill>
  );
};

// ============================================================================
// SCENE 03: SÜPERHÜCRE VE TREN ETKİSİ (ATMOSPHERIC COLLISION)
// ============================================================================
const MeteorolojiScene: React.FC<{
  frame: number;
  progress: number;
  sceneSpring: number;
}> = ({ frame, progress, sceneSpring }) => {
  const lightningFlash = (frame % 45 < 3) ? 1 : 0.15;

  return (
    <AbsoluteFill
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        paddingTop: 170,
      }}
    >
      <div
        style={{
          fontFamily: THEME.fontSerif,
          fontSize: 48,
          fontWeight: 800,
          textAlign: 'center',
          color: '#FFFFFF',
          marginBottom: 28,
        }}
      >
        Atmosferik Patlama: <span style={{ color: THEME.accentCyan }}>Süperhücre & Tren Etkisi</span>
      </div>

      {/* Atmospheric Elevation Chamber (0 to 14 km Troposphere) */}
      <div
        style={{
          width: 900,
          height: 480,
          backgroundColor: '#090D1A',
          borderRadius: 16,
          border: '2px solid rgba(0, 229, 255, 0.3)',
          boxShadow: '0 25px 50px rgba(0,0,0,0.8)',
          position: 'relative',
          overflow: 'hidden',
        }}
      >
        {/* Height Axis on Left */}
        <div
          style={{
            position: 'absolute',
            left: 20,
            top: 20,
            bottom: 20,
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'space-between',
            fontFamily: THEME.fontMono,
            fontSize: 16,
            color: THEME.textMuted,
            zIndex: 30,
          }}
        >
          <span>14 km (Troposfer Tavanı)</span>
          <span>10 km</span>
          <span>5 km (Donma Seviyesi)</span>
          <span>0 km (Karadeniz Yüzeyi)</span>
        </div>

        {/* Cold Polar Trough from Top (-25°C) */}
        <div
          style={{
            position: 'absolute',
            top: 20,
            right: 40,
            backgroundColor: 'rgba(59, 130, 246, 0.25)',
            border: '1px solid #60A5FA',
            borderRadius: 8,
            padding: '8px 16px',
            fontFamily: THEME.fontMono,
            fontSize: 18,
            color: '#93C5FD',
            zIndex: 30,
          }}
        >
          ⬇ KUTUP HAVA CEPHESİ (-25°C)
        </div>

        {/* Warm Sea Moisture from Bottom (+4°C Anomaly) */}
        <div
          style={{
            position: 'absolute',
            bottom: 20,
            right: 40,
            backgroundColor: 'rgba(239, 68, 68, 0.25)',
            border: '1px solid #F87171',
            borderRadius: 8,
            padding: '8px 16px',
            fontFamily: THEME.fontMono,
            fontSize: 18,
            color: '#FCA5A5',
            zIndex: 30,
          }}
        >
          ⬆ KARADENİZ SU ANOMALİSİ (+4°C / 23°C)
        </div>

        {/* Giant Cumulonimbus Storm Cell with Lightning */}
        <svg
          style={{
            position: 'absolute',
            inset: 0,
            width: '100%',
            height: '100%',
          }}
        >
          {/* Cloud Body */}
          <path
            d="M 220 380 Q 240 220 360 200 Q 400 120 540 100 Q 720 90 800 160 Q 820 280 780 380 Z"
            fill="rgba(30, 41, 59, 0.85)"
            stroke={THEME.accentCyan}
            strokeWidth="2"
          />

          {/* Lightning Bolt */}
          <path
            d="M 520 160 L 480 250 L 530 260 L 470 380"
            fill="none"
            stroke="#FEF08A"
            strokeWidth="5"
            opacity={lightningFlash}
            filter="drop-shadow(0 0 12px #FDE047)"
          />

          {/* Updraft Convective Arrows */}
          <path
            d="M 340 380 Q 360 260 420 220"
            fill="none"
            stroke={THEME.accentOrange}
            strokeWidth="3.5"
            strokeDasharray="8 6"
          />
          <path
            d="M 680 380 Q 640 260 580 220"
            fill="none"
            stroke="#60A5FA"
            strokeWidth="3.5"
            strokeDasharray="8 6"
          />
        </svg>

        {/* Training Effect Banner */}
        <div
          style={{
            position: 'absolute',
            top: 210,
            left: 240,
            backgroundColor: 'rgba(0,0,0,0.75)',
            border: `1px solid ${THEME.accentGold}`,
            padding: '8px 18px',
            borderRadius: 6,
            fontFamily: THEME.fontMono,
            fontSize: 17,
            color: THEME.accentGold,
            fontWeight: 700,
          }}
        >
          TRAINING EFFECT: AYNI HATTA KİLİTLİ FIRTINA TRENİ
        </div>
      </div>

      {/* Tactile Dossier Metadata Strip */}
      <div
        style={{
          width: 900,
          backgroundColor: THEME.paperBg,
          borderRadius: 8,
          border: `2px solid ${THEME.paperBorder}`,
          padding: '18px 28px',
          color: '#1E293B',
          marginTop: 28,
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          fontFamily: THEME.fontMono,
          fontSize: 19,
          fontWeight: 700,
        }}
      >
        <span>KÜMÜLONİMBUS YÜKSEKLİĞİ: 14.200 METRE</span>
        <span style={{ color: THEME.stampRed }}>ŞİMŞEK ÇAKIMI: 1 SAATTE 8.400+</span>
      </div>
    </AbsoluteFill>
  );
};

// ============================================================================
// SCENE 04: BETON ZIRH VE DERE YATAKLARI (URBAN CULVERT ERUPTION)
// ============================================================================
const BetonScene: React.FC<{
  frame: number;
  progress: number;
  sceneSpring: number;
}> = ({ frame, progress, sceneSpring }) => {
  const waterErupt = Math.sin(frame * 0.3) * 15 + 65;

  return (
    <AbsoluteFill
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        paddingTop: 170,
      }}
    >
      <div
        style={{
          fontFamily: THEME.fontSerif,
          fontSize: 48,
          fontWeight: 800,
          textAlign: 'center',
          color: '#FFFFFF',
          marginBottom: 28,
        }}
      >
        Kentsel Tuzak: <span style={{ color: THEME.stampRed }}>%80 Beton Zırh & Kapatılan Dereler</span>
      </div>

      {/* Urban Cross-Section Diagram */}
      <div
        style={{
          width: 900,
          height: 480,
          backgroundColor: '#0F172A',
          borderRadius: 16,
          border: '2px solid rgba(255,255,255,0.15)',
          boxShadow: '0 25px 50px rgba(0,0,0,0.8)',
          position: 'relative',
          overflow: 'hidden',
        }}
      >
        {/* City Buildings Silhouette on Surface */}
        <div
          style={{
            position: 'absolute',
            top: 60,
            left: 40,
            right: 40,
            height: 120,
            display: 'flex',
            alignItems: 'flex-end',
            gap: 16,
            opacity: 0.5,
          }}
        >
          <div style={{ width: 80, height: 90, backgroundColor: '#334155', borderRadius: '4px 4px 0 0' }} />
          <div style={{ width: 110, height: 130, backgroundColor: '#475569', borderRadius: '4px 4px 0 0' }} />
          <div style={{ width: 70, height: 75, backgroundColor: '#334155', borderRadius: '4px 4px 0 0' }} />
          <div style={{ width: 130, height: 110, backgroundColor: '#1E293B', borderRadius: '4px 4px 0 0' }} />
          <div style={{ width: 90, height: 140, backgroundColor: '#475569', borderRadius: '4px 4px 0 0' }} />
        </div>

        {/* Asphalt Road Layer */}
        <div
          style={{
            position: 'absolute',
            top: 180,
            left: 0,
            right: 0,
            height: 40,
            backgroundColor: '#1E293B',
            borderTop: '3px solid #64748B',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '0 24px',
            fontFamily: THEME.fontMono,
            fontSize: 16,
            color: '#94A3B8',
          }}
        >
          <span>ASFALT YOL TABAKASI (%100 SU GEÇİRİMSİZ)</span>
          <span style={{ color: THEME.accentOrange }}>SU KAÇACAK YER BULAMADI</span>
        </div>

        {/* Manhole with Erupting Water Geyser */}
        <div
          style={{
            position: 'absolute',
            top: 180 - waterErupt,
            left: 420,
            width: 70,
            height: waterErupt,
            background: 'linear-gradient(180deg, rgba(0,229,255,0.9), rgba(59,130,246,0.6))',
            borderRadius: '12px 12px 0 0',
            boxShadow: '0 0 25px rgba(0,229,255,0.6)',
          }}
        />
        <div
          style={{
            position: 'absolute',
            top: 172,
            left: 410,
            width: 90,
            height: 14,
            backgroundColor: '#0F172A',
            border: '2px solid #00E5FF',
            borderRadius: 4,
          }}
        />

        {/* Underground Buried Concrete River Culvert (Menfez) */}
        <div
          style={{
            position: 'absolute',
            top: 260,
            left: 100,
            right: 100,
            height: 160,
            backgroundColor: '#020617',
            border: '4px dashed #EF4444',
            borderRadius: 12,
            padding: 24,
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center',
            alignItems: 'center',
            textAlign: 'center',
          }}
        >
          <div style={{ color: THEME.stampRed, fontFamily: THEME.fontMono, fontSize: 22, fontWeight: 800 }}>
            HAPSEDİLMİŞ DERELER: KAĞITHANE & AYAZAĞA
          </div>
          <div style={{ color: '#94A3B8', fontFamily: THEME.fontSans, fontSize: 18, marginTop: 8 }}>
            Doğal dere yatakları borulara hapsedildi. Kapasite aşılınca doğa yatağını zorla geri aldı!
          </div>
        </div>
      </div>

      {/* Archive Card Callout */}
      <div
        style={{
          width: 900,
          backgroundColor: THEME.paperBg,
          borderRadius: 8,
          border: `2px solid ${THEME.paperBorder}`,
          padding: '20px 32px',
          color: '#1E293B',
          marginTop: 28,
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          fontFamily: THEME.fontMono,
          fontSize: 19,
          fontWeight: 700,
        }}
      >
        <span>KENTSEL GEÇİRİMSİZLİK: %82.4</span>
        <span style={{ color: THEME.stampRed }}>KAYBOLAN DERELER: 42 KOL</span>
      </div>
    </AbsoluteFill>
  );
};

// ============================================================================
// SCENE 05: SÜNGER ŞEHİR MODELİ (ENGINEERING BLUEPRINT)
// ============================================================================
const SungerScene: React.FC<{
  frame: number;
  progress: number;
  sceneSpring: number;
}> = ({ frame, progress, sceneSpring }) => {
  return (
    <AbsoluteFill
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        paddingTop: 170,
      }}
    >
      <div
        style={{
          fontFamily: THEME.fontSerif,
          fontSize: 48,
          fontWeight: 800,
          textAlign: 'center',
          color: '#FFFFFF',
          marginBottom: 28,
        }}
      >
        Geleceğin Çözümü: <span style={{ color: '#10B981' }}>Sünger Şehir (Sponge City) Mimarisi</span>
      </div>

      {/* High-tech Engineering Blueprint */}
      <div
        style={{
          width: 900,
          height: 480,
          backgroundColor: '#062017',
          borderRadius: 16,
          border: '2px solid rgba(16, 185, 129, 0.4)',
          boxShadow: '0 25px 50px rgba(0,0,0,0.8)',
          position: 'relative',
          padding: 36,
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'space-between',
        }}
      >
        {/* Layer 1: Permeable Pavement */}
        <div
          style={{
            backgroundColor: 'rgba(16, 185, 129, 0.15)',
            border: '1px solid #10B981',
            borderRadius: 8,
            padding: '16px 24px',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            fontFamily: THEME.fontMono,
            fontSize: 20,
            color: '#A7F3D0',
          }}
        >
          <span>1. GEÇİRGEN ASFALT & GÖZENEKLİ TAŞLAR</span>
          <span style={{ fontWeight: 800, color: '#34D399' }}>SUYU DERHAL ALTA SÜZER</span>
        </div>

        {/* Layer 2: Bio-retention Rain Gardens */}
        <div
          style={{
            backgroundColor: 'rgba(16, 185, 129, 0.15)',
            border: '1px solid #10B981',
            borderRadius: 8,
            padding: '16px 24px',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            fontFamily: THEME.fontMono,
            fontSize: 20,
            color: '#A7F3D0',
          }}
        >
          <span>2. YAĞMUR BAHÇELERİ & BİYOLOJİK HENDEKLER</span>
          <span style={{ fontWeight: 800, color: '#34D399' }}>DOĞAL FİLTRASYON</span>
        </div>

        {/* Layer 3: Underground Retention Cisterns */}
        <div
          style={{
            backgroundColor: 'rgba(16, 185, 129, 0.15)',
            border: '1px solid #10B981',
            borderRadius: 8,
            padding: '16px 24px',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            fontFamily: THEME.fontMono,
            fontSize: 20,
            color: '#A7F3D0',
          }}
        >
          <span>3. DEV YERALTI SEL SARNIÇLARI (RETENTION TANKS)</span>
          <span style={{ fontWeight: 800, color: '#34D399' }}>YENİDEN KULLANIM</span>
        </div>
      </div>

      {/* Comparison Efficiency Metrics */}
      <div
        style={{
          width: 900,
          display: 'grid',
          gridTemplateColumns: '1fr 1fr',
          gap: 24,
          marginTop: 28,
        }}
      >
        <div
          style={{
            backgroundColor: 'rgba(16, 185, 129, 0.12)',
            border: '2px solid rgba(16, 185, 129, 0.4)',
            borderRadius: 12,
            padding: '18px 24px',
          }}
        >
          <div style={{ color: '#A7F3D0', fontFamily: THEME.fontMono, fontSize: 18 }}>
            SÜNGER ŞEHİR YERİNDE TUTMA ORANI
          </div>
          <div style={{ fontSize: 44, fontWeight: 900, color: '#10B981', marginTop: 4 }}>
            %85 <span style={{ fontSize: 20, fontWeight: 500 }}>(GÜVENLİ)</span>
          </div>
        </div>

        <div
          style={{
            backgroundColor: 'rgba(239, 68, 68, 0.12)',
            border: '2px solid rgba(239, 68, 68, 0.4)',
            borderRadius: 12,
            padding: '18px 24px',
          }}
        >
          <div style={{ color: '#FCA5A5', fontFamily: THEME.fontMono, fontSize: 18 }}>
            ESKİ BETON DRENAJ BORULARI
          </div>
          <div style={{ fontSize: 44, fontWeight: 900, color: '#EF4444', marginTop: 4 }}>
            %15 <span style={{ fontSize: 20, fontWeight: 500 }}>(TAŞTI)</span>
          </div>
        </div>
      </div>
    </AbsoluteFill>
  );
};

// ============================================================================
// SCENE 06: SONUÇ VE TARTIŞMA (EDITORIAL QUOTE & INTERACTIVE CTA)
// ============================================================================
const SonucScene: React.FC<{
  frame: number;
  progress: number;
  sceneSpring: number;
}> = ({ frame, progress, sceneSpring }) => {
  return (
    <AbsoluteFill
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        paddingTop: 180,
      }}
    >
      {/* Large Editorial Serif Impact Quote (Banka 45s style) */}
      <div
        style={{
          fontFamily: THEME.fontSerif,
          fontSize: 60,
          fontWeight: 900,
          textAlign: 'center',
          lineHeight: 1.25,
          color: '#FFFFFF',
          maxWidth: 900,
          marginBottom: 44,
        }}
      >
        Doğa, kendisine ait olanı eninde sonunda{' '}
        <span style={{ color: THEME.accentGold, fontStyle: 'italic' }}>geri alır.</span>
      </div>

      {/* Tactile Poll Card (Banka 52s style) */}
      <div
        style={{
          width: 880,
          backgroundColor: THEME.paperBg,
          borderRadius: 8,
          border: `2px solid ${THEME.paperBorder}`,
          boxShadow: '0 30px 60px rgba(0,0,0,0.7)',
          color: '#1E293B',
          padding: '36px 44px',
          position: 'relative',
        }}
      >
        <div
          style={{
            fontFamily: THEME.fontMono,
            fontSize: 20,
            letterSpacing: 2,
            color: THEME.accentOrange,
            fontWeight: 800,
            marginBottom: 20,
          }}
        >
          TARTIŞMA SORUSU // SİZCE?
        </div>

        <div style={{ fontFamily: THEME.fontSans, fontSize: 26, fontWeight: 700, color: '#0F172A', marginBottom: 24 }}>
          Şehirlerimiz bu yeni iklim çağına ve afetlere karşı hazır mı?
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <div
            style={{
              border: '2px solid rgba(0,0,0,0.15)',
              borderRadius: 8,
              padding: '14px 20px',
              fontFamily: THEME.fontMono,
              fontSize: 20,
              fontWeight: 700,
              display: 'flex',
              alignItems: 'center',
              gap: 16,
              backgroundColor: '#FFFFFF',
            }}
          >
            <div
              style={{
                width: 32,
                height: 32,
                borderRadius: '50%',
                border: '2px solid #0F172A',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              A
            </div>
            <span>Hayır, altyapımız tamamen savunmasız</span>
          </div>

          <div
            style={{
              border: '2px solid rgba(0,0,0,0.15)',
              borderRadius: 8,
              padding: '14px 20px',
              fontFamily: THEME.fontMono,
              fontSize: 20,
              fontWeight: 700,
              display: 'flex',
              alignItems: 'center',
              gap: 16,
              backgroundColor: '#FFFFFF',
            }}
          >
            <div
              style={{
                width: 32,
                height: 32,
                borderRadius: '50%',
                border: '2px solid #0F172A',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              B
            </div>
            <span>Acil Sünger Şehir dönüşümü şart</span>
          </div>
        </div>

        {/* Footer Signature */}
        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            marginTop: 28,
            paddingTop: 18,
            borderTop: '1px solid rgba(0,0,0,0.1)',
            fontFamily: THEME.fontMono,
            fontSize: 16,
            color: '#64748B',
          }}
        >
          <span>İMZA: ROTA MEDYA BİLİM SERVİSİ</span>
          <span style={{ color: THEME.stampRed, fontWeight: 800 }}>YORUMLARDA BULUŞALIM ✍</span>
        </div>
      </div>
    </AbsoluteFill>
  );
};
