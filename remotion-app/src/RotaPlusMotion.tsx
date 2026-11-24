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
import metadata from './rotaplus_metadata.json';

const THEME = {
  bgParchment: '#F6F2E9',
  bgDark: '#08090C',
  accentOrange: '#FF5500',
  accentRed: '#E11D48',
  accentCyan: '#00FFCC',
  accentGreen: '#10B981',
  textDark: '#0F172A',
  textMutedDark: '#475569',
  fontMono: '"IBMPlexMono", monospace, monospace',
  fontDisplay: '"BarlowCondensed", Impact, sans-serif',
  fontSans: '"Barlow", sans-serif',
};

export const RotaPlusMotion: React.FC = () => {
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
  const sceneElapsed = frame - activeScene.startFrame;
  const isParchment = activeScene.id !== 'hook' && activeScene.id !== 'outro';

  // Smooth entrance spring for each scene
  const enterSpring = spring({
    frame: sceneElapsed,
    fps,
    config: { damping: 14, stiffness: 90 },
  });

  // 3D Isometric Floating Physics for the Phone
  const phoneRotY = Math.sin(sceneElapsed * 0.04) * 3 - 2;
  const phoneRotX = Math.cos(sceneElapsed * 0.04) * 2 + 1;
  const phoneFloatY = Math.sin(sceneElapsed * 0.06) * 6;

  return (
    <AbsoluteFill
      style={{
        backgroundColor: isParchment ? THEME.bgParchment : THEME.bgDark,
        fontFamily: THEME.fontSans,
        overflow: 'hidden',
      }}
    >
      {/* Master Soundtrack with ElevenLabs Charlie Voice + 124 BPM Sub-Drops */}
      <Audio src={staticFile('rotaplus/audio_master.wav')} volume={1.0} />

      {/* Topographic Map Background Texture on Parchment */}
      {isParchment && (
        <img
          src={staticFile('rotaplus/topo_bg.png')}
          style={{
            position: 'absolute',
            inset: 0,
            width: '100%',
            height: '100%',
            objectFit: 'cover',
            opacity: 0.88,
            pointerEvents: 'none',
          }}
        />
      )}

      {/* ==================================================================== */}
      {/* 1. HOOK SCENE (0 to ~250 frames) */}
      {/* ==================================================================== */}
      {activeScene.id === 'hook' && (
        <AbsoluteFill
          style={{
            justifyContent: 'center',
            alignItems: 'center',
            backgroundColor: '#07090E',
            position: 'relative',
          }}
        >
          {/* Animated Tactical Grid Lines */}
          <svg
            style={{
              position: 'absolute',
              inset: 0,
              width: '100%',
              height: '100%',
              opacity: 0.18,
            }}
          >
            <defs>
              <pattern id="tacticalGrid" width="60" height="60" patternUnits="userSpaceOnUse">
                <path d="M 60 0 L 0 0 0 60" fill="none" stroke="#00FFCC" strokeWidth="1" />
              </pattern>
            </defs>
            <rect width="100%" height="100%" fill="url(#tacticalGrid)" />
          </svg>

          {/* Dramatic Hook Typography or Logo Reveal */}
          {frame < 125 ? (
            <div style={{ textAlign: 'center', zIndex: 10 }}>
              <div
                style={{
                  fontSize: 22,
                  fontFamily: THEME.fontMono,
                  color: 'rgba(255,255,255,0.45)',
                  letterSpacing: 6,
                  marginBottom: 36,
                }}
              >
                ✖ ŞEBEKE YOK · ✖ İNTERNET YOK
              </div>

              {frame < 50 && (
                <div
                  style={{
                    fontSize: 100,
                    fontFamily: THEME.fontDisplay,
                    fontWeight: 800,
                    color: '#FFF',
                    letterSpacing: 2,
                    textShadow: '0 0 40px rgba(255,255,255,0.4)',
                  }}
                >
                  ŞEBEKE YOK.
                </div>
              )}
              {frame >= 50 && frame < 95 && (
                <div
                  style={{
                    fontSize: 100,
                    fontFamily: THEME.fontDisplay,
                    fontWeight: 800,
                    color: '#FFF',
                    letterSpacing: 2,
                    textShadow: '0 0 40px rgba(255,255,255,0.4)',
                  }}
                >
                  İNTERNET YOK.
                </div>
              )}
              {frame >= 95 && (
                <div
                  style={{
                    fontSize: 108,
                    fontFamily: THEME.fontDisplay,
                    fontWeight: 800,
                    color: THEME.accentOrange,
                    letterSpacing: 2,
                    textShadow: '0 0 50px rgba(255,85,0,0.6)',
                  }}
                >
                  PEKİ ŞİMDİ?
                </div>
              )}
            </div>
          ) : (
            <div
              style={{
                textAlign: 'center',
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                zIndex: 10,
              }}
            >
              {/* Expanding Shockwave Ring */}
              <div
                style={{
                  position: 'relative',
                  width: 320,
                  height: 320,
                  display: 'flex',
                  justifyContent: 'center',
                  alignItems: 'center',
                  marginBottom: 44,
                }}
              >
                <div
                  style={{
                    position: 'absolute',
                    width: 300,
                    height: 300,
                    borderRadius: '50%',
                    border: '2px solid rgba(255,85,0,0.5)',
                    transform: `scale(${1 + ((frame - 125) % 30) * 0.05})`,
                    opacity: 1 - ((frame - 125) % 30) / 30,
                  }}
                />

                {/* Circular Metallic Compass Logo */}
                <div
                  style={{
                    width: 280,
                    height: 280,
                    borderRadius: '50%',
                    overflow: 'hidden',
                    boxShadow: '0 0 80px rgba(255,85,0,0.7), 0 0 120px rgba(0,255,204,0.3)',
                    border: '4px solid rgba(255,140,20,0.9)',
                    transform: `scale(${spring({ frame: frame - 125, fps, config: { damping: 11 } })})`,
                  }}
                >
                  <img
                    src={staticFile('rotaplus/logo.png')}
                    style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                  />
                </div>
              </div>

              <div
                style={{
                  fontSize: 78,
                  fontFamily: THEME.fontDisplay,
                  fontWeight: 800,
                  color: '#FFF',
                  letterSpacing: 2,
                }}
              >
                ROTA+ KESİNTİSİZ ÇALIŞIR
              </div>
              <div
                style={{
                  fontSize: 24,
                  fontFamily: THEME.fontMono,
                  color: THEME.accentCyan,
                  marginTop: 18,
                  fontWeight: 700,
                  letterSpacing: 3,
                }}
              >
                TAMAMEN ÇEVRİMDIŞI · %100 YERLİ SAHRA SİSTEMİ
              </div>
            </div>
          )}
        </AbsoluteFill>
      )}

      {/* ==================================================================== */}
      {/* 2. SLIDES 01 TO 09 (TOP-TIER MOTION GRAPHICS) */}
      {/* ==================================================================== */}
      {isParchment && (
        <AbsoluteFill style={{ padding: '75px 65px' }}>
          {/* Header Row: Category Badge & Scene Counter */}
          <div
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              marginBottom: 12,
              transform: `translateY(${interpolate(enterSpring, [0, 1], [-20, 0])}px)`,
              opacity: enterSpring,
            }}
          >
            <span
              style={{
                fontSize: 18,
                fontFamily: THEME.fontMono,
                color: '#8B2626',
                backgroundColor: '#E6DFD2',
                padding: '6px 20px',
                borderRadius: 20,
                fontWeight: 700,
                letterSpacing: 1.5,
                border: '1px solid rgba(139,38,38,0.2)',
              }}
            >
              [{activeScene.tag}]
            </span>
            <span
              style={{
                fontSize: 26,
                fontFamily: THEME.fontMono,
                color: '#A61C1C',
                fontWeight: 800,
                letterSpacing: 2,
              }}
            >
              {activeScene.num} — 09
            </span>
          </div>

          {/* Big Sharp Title */}
          <div
            style={{
              fontSize: 62,
              fontFamily: THEME.fontDisplay,
              fontWeight: 800,
              color: THEME.textDark,
              lineHeight: 1.1,
              marginBottom: 10,
              transform: `translateY(${interpolate(enterSpring, [0, 1], [20, 0])}px)`,
              opacity: enterSpring,
            }}
          >
            {activeScene.title}
          </div>

          {/* Subtitle with generous margin so it NEVER overlaps the phone */}
          <div
            style={{
              fontSize: 25,
              fontFamily: THEME.fontSans,
              color: THEME.textMutedDark,
              fontWeight: 600,
              marginBottom: 36,
              maxWidth: 920,
              lineHeight: 1.35,
              transform: `translateY(${interpolate(enterSpring, [0, 1], [15, 0])}px)`,
              opacity: enterSpring,
            }}
          >
            {activeScene.sub}
          </div>

          {/* Center Stage: 3D Floating Phone Frame + Layered Motion Graphic Overlays */}
          <div
            style={{
              position: 'relative',
              width: '100%',
              height: 1040,
              display: 'flex',
              justifyContent: 'center',
              alignItems: 'center',
              perspective: 1200,
            }}
          >
            {/* The Phone Itself */}
            <div
              style={{
                width: 550,
                height: 980,
                borderRadius: 44,
                overflow: 'hidden', // STRICT BOUNDARY: NO ROUTE OR DRAWING EVER SPILLS OUT
                backgroundColor: '#0F1218',
                border: '10px solid #252830',
                boxShadow:
                  '0 35px 80px rgba(28,22,16,0.32), 0 10px 25px rgba(0,0,0,0.2), inset 0 0 10px rgba(255,255,255,0.06)',
                transform: `rotateY(${phoneRotY}deg) rotateX(${phoneRotX}deg) translateY(${phoneFloatY}px) scale(${enterSpring})`,
                position: 'relative',
                transformStyle: 'preserve-3d',
              }}
            >
              {/* The Actual Screen Image */}
              <img
                src={staticFile(`rotaplus/${activeScene.screen}`)}
                style={{ width: '100%', height: '100%', objectFit: 'cover' }}
              />

              {/* Dynamic Island Notch */}
              <div
                style={{
                  position: 'absolute',
                  top: 14,
                  left: '50%',
                  transform: 'translateX(-50%)',
                  width: 110,
                  height: 28,
                  backgroundColor: '#000',
                  borderRadius: 14,
                  zIndex: 40,
                }}
              />

              {/* ============================================================ */}
              {/* SPECIFIC IN-SCREEN MOTION GRAPHIC OVERLAYS                   */}
              {/* ============================================================ */}

              {/* SLIDE 01: Kokpit & Meteoroloji HUD */}
              {activeScene.id === 's01' && (
                <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
                  {/* Laser Scanline sweeping down */}
                  <div
                    style={{
                      position: 'absolute',
                      left: 0,
                      right: 0,
                      top: 80 + ((sceneElapsed * 4) % 650),
                      height: 2,
                      background: 'linear-gradient(90deg, transparent, #00FFCC, transparent)',
                      boxShadow: '0 0 12px #00FFCC',
                      opacity: 0.7,
                    }}
                  />

                  {/* Pulsing Target Lock on Barometer */}
                  <div
                    style={{
                      position: 'absolute',
                      top: 295,
                      left: 45,
                      width: 130,
                      height: 85,
                      border: '2px solid rgba(0, 255, 204, 0.7)',
                      borderRadius: 14,
                      boxShadow: '0 0 18px rgba(0, 255, 204, 0.4)',
                    }}
                  >
                    <span
                      style={{
                        position: 'absolute',
                        top: -10,
                        right: 8,
                        backgroundColor: '#00FFCC',
                        color: '#000',
                        fontSize: 10,
                        fontFamily: THEME.fontMono,
                        fontWeight: 800,
                        padding: '1px 6px',
                        borderRadius: 4,
                      }}
                    >
                      LIVE 1012 hPa
                    </span>
                  </div>

                  {/* Pulsing Target Lock on Compass */}
                  <div
                    style={{
                      position: 'absolute',
                      top: 420,
                      right: 45,
                      width: 220,
                      height: 140,
                      border: '2px solid rgba(255, 85, 0, 0.7)',
                      borderRadius: 16,
                      boxShadow: '0 0 20px rgba(255, 85, 0, 0.4)',
                    }}
                  >
                    <span
                      style={{
                        position: 'absolute',
                        top: -10,
                        right: 8,
                        backgroundColor: '#FF5500',
                        color: '#FFF',
                        fontSize: 10,
                        fontFamily: THEME.fontMono,
                        fontWeight: 800,
                        padding: '1px 6px',
                        borderRadius: 4,
                      }}
                    >
                      125° GD
                    </span>
                  </div>
                </div>
              )}

              {/* SLIDE 02: Canlı GPS Takibi & Dynamic Numbers */}
              {/* STRICT RULE: ROUTE IS 100% CONTAINED IN THE TOP MAP VIEWPORT */}
              {activeScene.id === 's02' && (
                <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
                  {/* Top Map Region (y: 65 to 490px) */}
                  <div
                    style={{
                      position: 'absolute',
                      top: 65,
                      left: 0,
                      width: '100%',
                      height: 425,
                      overflow: 'hidden', // ABSOLUTELY CANNOT LEAK OUTSIDE
                    }}
                  >
                    <svg width="100%" height="100%" viewBox="0 0 550 425">
                      <defs>
                        <filter id="routeGlow" x="-20%" y="-20%" width="140%" height="140%">
                          <feGaussianBlur stdDeviation="4" result="blur" />
                          <feMerge>
                            <feMergeNode in="blur" />
                            <feMergeNode in="SourceGraphic" />
                          </feMerge>
                        </filter>
                      </defs>

                      {/* Tactical Route Line Tracing on Street Grid */}
                      {(() => {
                        const p = Math.min(1.0, sceneElapsed / 90);
                        const pathLen = 480;
                        return (
                          <>
                            <path
                              d="M 150 330 L 230 320 L 290 250 L 350 240 L 380 160 L 440 150"
                              fill="none"
                              stroke="#FF5500"
                              strokeWidth="8"
                              strokeLinecap="round"
                              strokeLinejoin="round"
                              strokeDasharray={pathLen}
                              strokeDashoffset={pathLen * (1 - p)}
                              filter="url(#routeGlow)"
                            />

                            {/* Start Waypoint Marker */}
                            <circle cx="150" cy="330" r="8" fill="#10B981" stroke="#FFF" strokeWidth="3" />

                            {/* Moving GPS Target Reticle */}
                            {p > 0.05 && (
                              <g
                                transform={`translate(${interpolate(
                                  p,
                                  [0.05, 1],
                                  [150, 440]
                                )}, ${interpolate(p, [0.05, 1], [330, 150])})`}
                              >
                                <circle
                                  r={14 + (frame % 20)}
                                  fill="none"
                                  stroke="#FF5500"
                                  strokeWidth="2.5"
                                  opacity={1 - (frame % 20) / 20}
                                />
                                <circle r="8" fill="#FF5500" stroke="#FFF" strokeWidth="2.5" />
                              </g>
                            )}
                          </>
                        );
                      })()}
                    </svg>

                    {/* Floating Map Coordinates Tag */}
                    <div
                      style={{
                        position: 'absolute',
                        top: 20,
                        left: 20,
                        backgroundColor: 'rgba(15,18,24,0.85)',
                        backdropFilter: 'blur(8px)',
                        padding: '4px 12px',
                        borderRadius: 8,
                        border: '1px solid rgba(255,85,0,0.4)',
                        fontSize: 12,
                        fontFamily: THEME.fontMono,
                        color: '#FF8C00',
                        fontWeight: 700,
                      }}
                    >
                      ● GPS KİLİTLİ: 38.4356° N, 27.1856° E
                    </div>
                  </div>

                  {/* Active Recording Pill over BAŞLAT button */}
                  <div
                    style={{
                      position: 'absolute',
                      bottom: 85,
                      left: 25,
                      right: 25,
                      height: 64,
                      borderRadius: 16,
                      border: '2px solid #FF5500',
                      backgroundColor: 'rgba(255, 85, 0, 0.25)',
                      backdropFilter: 'blur(4px)',
                      display: 'flex',
                      justifyContent: 'center',
                      alignItems: 'center',
                      gap: 12,
                      boxShadow: `0 0 ${16 + Math.sin(frame * 0.25) * 10}px rgba(255,85,0,0.6)`,
                    }}
                  >
                    <div
                      style={{
                        width: 12,
                        height: 12,
                        borderRadius: '50%',
                        backgroundColor: '#FF5500',
                        boxShadow: '0 0 10px #FF5500',
                      }}
                    />
                    <span
                      style={{
                        color: '#FFF',
                        fontFamily: THEME.fontDisplay,
                        fontSize: 24,
                        fontWeight: 800,
                        letterSpacing: 2,
                      }}
                    >
                      CANLI TAKİP AKTİF
                    </span>
                  </div>
                </div>
              )}

              {/* SLIDE 03: AUTO-SOS & Hareketsizlik Sensörü */}
              {activeScene.id === 's03' && (
                <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
                  {/* Emergency Red Flashing Border inside the phone */}
                  <div
                    style={{
                      position: 'absolute',
                      inset: 0,
                      border: '4px solid #E11D48',
                      boxShadow: 'inset 0 0 40px rgba(225, 29, 72, 0.5)',
                      opacity: 0.6 + Math.sin(frame * 0.3) * 0.4,
                    }}
                  />

                  {/* Pulsing Countdown Alert Banner */}
                  <div
                    style={{
                      position: 'absolute',
                      top: 100,
                      left: 25,
                      right: 25,
                      backgroundColor: 'rgba(225, 29, 72, 0.95)',
                      borderRadius: 16,
                      padding: '16px 20px',
                      color: '#FFF',
                      textAlign: 'center',
                      boxShadow: '0 10px 30px rgba(225, 29, 72, 0.6)',
                    }}
                  >
                    <div style={{ fontSize: 16, fontFamily: THEME.fontMono, fontWeight: 800, letterSpacing: 2 }}>
                      ⚠️ HAREKETSİZLİK ALGILANDI!
                    </div>
                    <div style={{ fontSize: 12, opacity: 0.9, marginTop: 4 }}>
                      Düşme / bayılma sensörü devrede. Otomatik siren tetikleniyor.
                    </div>
                  </div>
                </div>
              )}

              {/* SLIDE 04: Topografik Rota Planlama */}
              {activeScene.id === 's04' && (
                <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
                  {/* Waypoint A and Waypoint B connecting line */}
                  <svg width="100%" height="100%" style={{ position: 'absolute', inset: 0 }}>
                    <line
                      x1="220"
                      y1="520"
                      x2="380"
                      y2="660"
                      stroke="#FF5500"
                      strokeWidth="5"
                      strokeDasharray="8 6"
                    />
                    <circle cx="220" cy="520" r="10" fill="#10B981" stroke="#FFF" strokeWidth="3" />
                    <circle cx="380" cy="660" r="10" fill="#E11D48" stroke="#FFF" strokeWidth="3" />
                  </svg>
                  <div
                    style={{
                      position: 'absolute',
                      top: 480,
                      left: 170,
                      backgroundColor: '#10B981',
                      color: '#FFF',
                      fontSize: 11,
                      fontFamily: THEME.fontMono,
                      fontWeight: 800,
                      padding: '2px 8px',
                      borderRadius: 6,
                    }}
                  >
                    BAŞLANGIÇ
                  </div>
                  <div
                    style={{
                      position: 'absolute',
                      top: 675,
                      left: 350,
                      backgroundColor: '#E11D48',
                      color: '#FFF',
                      fontSize: 11,
                      fontFamily: THEME.fontMono,
                      fontWeight: 800,
                      padding: '2px 8px',
                      borderRadius: 6,
                    }}
                  >
                    HEDEF: 5.8 KM
                  </div>
                </div>
              )}

              {/* SLIDE 05: Ekip Güvenlik Ağı */}
              {activeScene.id === 's05' && (
                <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
                  {/* Live SOS Callout highlighting Bekir's alert */}
                  <div
                    style={{
                      position: 'absolute',
                      top: 440,
                      left: 20,
                      right: 20,
                      height: 120,
                      border: '2px solid #E11D48',
                      borderRadius: 18,
                      boxShadow: '0 0 25px rgba(225, 29, 72, 0.45)',
                    }}
                  >
                    <span
                      style={{
                        position: 'absolute',
                        top: -10,
                        right: 12,
                        backgroundColor: '#E11D48',
                        color: '#FFF',
                        fontSize: 11,
                        fontFamily: THEME.fontMono,
                        fontWeight: 800,
                        padding: '2px 8px',
                        borderRadius: 6,
                      }}
                    >
                      🚨 ACİL ÇAĞRI
                    </span>
                  </div>
                </div>
              )}

              {/* SLIDE 06: Deprem & Enkaz Modu */}
              {activeScene.id === 's06' && (
                <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
                  {/* Güvendeyim Button Pulse */}
                  <div
                    style={{
                      position: 'absolute',
                      top: 130,
                      left: 25,
                      right: 25,
                      height: 155,
                      borderRadius: 24,
                      border: '2px solid #10B981',
                      boxShadow: `0 0 ${20 + Math.sin(frame * 0.2) * 12}px rgba(16, 185, 129, 0.5)`,
                    }}
                  />

                  {/* Hayatta Kalma Sayacı Live Tick */}
                  {(() => {
                    const sec = Math.floor(sceneElapsed / 3);
                    const sStr = sec < 10 ? `0${sec}` : sec;
                    return (
                      <div
                        style={{
                          position: 'absolute',
                          top: 405,
                          left: '50%',
                          transform: 'translateX(-50%)',
                          fontSize: 38,
                          fontFamily: THEME.fontMono,
                          fontWeight: 800,
                          color: '#FFF',
                          backgroundColor: '#0F1218',
                          padding: '0 12px',
                        }}
                      >
                        00:00:{sStr}
                      </div>
                    );
                  })()}
                </div>
              )}

              {/* SLIDE 07: Acil İlk Yardım Rehberi */}
              {activeScene.id === 's07' && (
                <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
                  {/* Selection Border on Kanamalar & Turnike */}
                  <div
                    style={{
                      position: 'absolute',
                      top: 500,
                      left: 30,
                      right: 30,
                      height: 70,
                      borderRadius: 16,
                      border: '2px solid #FF5500',
                      boxShadow: '0 0 20px rgba(255, 85, 0, 0.45)',
                    }}
                  >
                    <span
                      style={{
                        position: 'absolute',
                        top: -10,
                        right: 12,
                        backgroundColor: '#FF5500',
                        color: '#FFF',
                        fontSize: 10,
                        fontFamily: THEME.fontMono,
                        fontWeight: 800,
                        padding: '1px 6px',
                        borderRadius: 4,
                      }}
                    >
                      MÜDAHALE ADIMI
                    </span>
                  </div>
                </div>
              )}

              {/* SLIDE 08: Dağcılık Düğümleri */}
              {activeScene.id === 's08' && (
                <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
                  {/* High-tech Magnifier Reticle over Alpine Butterfly */}
                  <div
                    style={{
                      position: 'absolute',
                      top: 350,
                      left: 35,
                      width: 480,
                      height: 90,
                      border: '2px solid #00FFCC',
                      borderRadius: 12,
                      boxShadow: '0 0 20px rgba(0, 255, 204, 0.4)',
                    }}
                  >
                    <span
                      style={{
                        position: 'absolute',
                        top: -10,
                        right: 8,
                        backgroundColor: '#00FFCC',
                        color: '#000',
                        fontSize: 10,
                        fontFamily: THEME.fontMono,
                        fontWeight: 800,
                        padding: '1px 6px',
                        borderRadius: 4,
                      }}
                    >
                      ALPIN KELEBEK DÜĞÜMÜ
                    </span>
                  </div>
                </div>
              )}

              {/* SLIDE 09: Askeri Standartta Güvenlik */}
              {activeScene.id === 's09' && (
                <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
                  {/* L-Band Satellite Lock Badge */}
                  <div
                    style={{
                      position: 'absolute',
                      top: 140,
                      left: '50%',
                      transform: 'translateX(-50%)',
                      backgroundColor: 'rgba(0, 255, 204, 0.15)',
                      border: '1.5px solid #00FFCC',
                      borderRadius: 20,
                      padding: '6px 18px',
                      color: '#00FFCC',
                      fontFamily: THEME.fontMono,
                      fontSize: 13,
                      fontWeight: 800,
                      boxShadow: '0 0 16px rgba(0, 255, 204, 0.4)',
                    }}
                  >
                    🛰️ L-BAND UYDU KİLİTLİ: %99.8
                  </div>
                </div>
              )}
            </div>

            {/* ============================================================ */}
            {/* FLOATING 2.5D TACTICAL HUD CARD (ALONGSIDE THE PHONE)         */}
            {/* ============================================================ */}
            <div
              style={{
                position: 'absolute',
                bottom: 25,
                right: 30,
                width: 320,
                backgroundColor: 'rgba(15, 23, 42, 0.92)',
                backdropFilter: 'blur(16px)',
                borderRadius: 20,
                padding: '16px 20px',
                border: '1.5px solid rgba(255, 85, 0, 0.5)',
                boxShadow: '0 20px 40px rgba(0,0,0,0.45)',
                transform: `translateY(${interpolate(enterSpring, [0, 1], [30, 0])}px) translateZ(50px)`,
                opacity: enterSpring,
                zIndex: 30,
              }}
            >
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 10,
                  marginBottom: 8,
                }}
              >
                <div
                  style={{
                    width: 10,
                    height: 10,
                    borderRadius: '50%',
                    backgroundColor: THEME.accentGreen,
                    boxShadow: '0 0 8px #10B981',
                  }}
                />
                <span
                  style={{
                    fontSize: 13,
                    fontFamily: THEME.fontMono,
                    color: '#FFF',
                    fontWeight: 800,
                    letterSpacing: 1.5,
                  }}
                >
                  MIL-SPEC PROTOKOL
                </span>
              </div>
              <div
                style={{
                  fontSize: 13,
                  fontFamily: THEME.fontSans,
                  color: '#CBD5E1',
                  lineHeight: 1.35,
                  fontWeight: 500,
                }}
              >
                {activeScene.id === 's01' && 'Pusula ve barometre donanım sensörleri çevrimdışı senkronize edilir.'}
                {activeScene.id === 's02' && 'İnternet olmasa da GPS çipi doğrudan uydulardan konum hesaplar.'}
                {activeScene.id === 's03' && 'Hareketsizlik algılandığında 20 saniye içinde siren ve SMS aktifleşir.'}
                {activeScene.id === 's04' && 'Vektörel sahra haritası cihaz hafızasında sıfır internetle çalışır.'}
                {activeScene.id === 's05' && 'Ekip acil durum çağrıları anlık konum ve koordinatla iletilir.'}
                {activeScene.id === 's06' && 'Enkaz altında akustik ses arama ve düşük enerjili BLE sinyali yayar.'}
                {activeScene.id === 's07' && 'Hayati yaralanmalarda sesli triyaj adımlarıyla panik önlenir.'}
                {activeScene.id === 's08' && 'Görsel ve resimli teknik dağcılık düğümleri internetsiz açılır.'}
                {activeScene.id === 's09' && 'Düşük enerji mimarisi ile 72 saat kesintisiz operasyon sağlar.'}
              </div>
            </div>
          </div>
        </AbsoluteFill>
      )}

      {/* ==================================================================== */}
      {/* 3. OUTRO SCENE (EXACT USER SPECIFICATION)                           */}
      {/* ==================================================================== */}
      {activeScene.id === 'outro' && (
        <AbsoluteFill
          style={{
            backgroundColor: '#090B10',
            justifyContent: 'center',
            alignItems: 'center',
            flexDirection: 'column',
          }}
        >
          {/* Subtle Ambient Glow */}
          <div
            style={{
              position: 'absolute',
              width: 600,
              height: 600,
              borderRadius: '50%',
              background: 'radial-gradient(circle, rgba(255,85,0,0.2) 0%, transparent 70%)',
            }}
          />

          {/* New Circular Metallic Compass Emblem */}
          <div
            style={{
              width: 320,
              height: 320,
              borderRadius: '50%',
              overflow: 'hidden',
              boxShadow: '0 0 80px rgba(255,85,0,0.7), 0 0 120px rgba(0,255,204,0.3)',
              border: '4px solid rgba(255,140,20,0.9)',
              marginBottom: 40,
              transform: `scale(${spring({ frame: sceneElapsed, fps, config: { damping: 12 } })})`,
              zIndex: 10,
            }}
          >
            <img
              src={staticFile('rotaplus/logo.png')}
              style={{ width: '100%', height: '100%', objectFit: 'cover' }}
            />
          </div>

          {/* Clean Sharp Brand Title */}
          <div
            style={{
              fontSize: 88,
              fontFamily: THEME.fontDisplay,
              fontWeight: 800,
              color: '#FFF',
              letterSpacing: 3,
              marginBottom: 10,
              zIndex: 10,
            }}
          >
            ROTA+
          </div>

          <div
            style={{
              fontSize: 28,
              fontFamily: THEME.fontSans,
              color: '#94A3B8',
              fontWeight: 600,
              letterSpacing: 2,
              marginBottom: 45,
              zIndex: 10,
            }}
          >
            ZORLU KOŞULLARDA YANINDA.
          </div>

          {/* Google Play and App Store Badges Side by Side */}
          <div
            style={{
              display: 'flex',
              gap: 24,
              marginBottom: 40,
              zIndex: 10,
              transform: `translateY(${interpolate(
                spring({ frame: sceneElapsed - 15, fps, config: { damping: 12 } }),
                [0, 1],
                [30, 0]
              )}px)`,
            }}
          >
            <img
              src={staticFile('rotaplus/badge_appstore.png')}
              style={{
                height: 64,
                borderRadius: 12,
                boxShadow: '0 8px 24px rgba(0,0,0,0.5)',
              }}
            />
            <img
              src={staticFile('rotaplus/badge_googleplay.png')}
              style={{
                height: 64,
                borderRadius: 12,
                boxShadow: '0 8px 24px rgba(0,0,0,0.5)',
              }}
            />
          </div>

          {/* Web Address */}
          <div
            style={{
              fontSize: 22,
              fontFamily: THEME.fontMono,
              color: THEME.accentCyan,
              letterSpacing: 4,
              fontWeight: 700,
              zIndex: 10,
            }}
          >
            acildurumapp.com
          </div>
        </AbsoluteFill>
      )}
    </AbsoluteFill>
  );
};
