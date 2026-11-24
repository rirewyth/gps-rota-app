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
import metadata from './ultimate_metadata.json';

const THEME = {
  bgDeep: '#06080D',
  bgCard: 'rgba(12, 17, 28, 0.94)',
  accentOrange: '#FF5500',
  accentRed: '#EF4444',
  accentCyan: '#00FFCC',
  accentGreen: '#10B981',
  textLight: '#F8FAFC',
  textMuted: '#94A3B8',
  fontMono: '"IBMPlexMono", monospace, monospace',
  fontDisplay: '"BarlowCondensed", Impact, sans-serif',
  fontSans: '"Barlow", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
};

export const RotaPlusUltimate: React.FC = () => {
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

  // Entrance spring per scene
  const enterSpring = spring({
    frame: sceneElapsed,
    fps,
    config: { damping: 14, stiffness: 85 },
  });

  // 3D Perspective & Floating Motion
  const rotY = Math.sin(sceneElapsed * 0.04) * 3 - 2;
  const rotX = Math.cos(sceneElapsed * 0.04) * 2 + 1;
  const floatY = Math.sin(sceneElapsed * 0.05) * 5;

  return (
    <AbsoluteFill
      style={{
        backgroundColor: THEME.bgDeep,
        fontFamily: THEME.fontSans,
        color: THEME.textLight,
        overflow: 'hidden',
      }}
    >
      {/* High-Impact Master Soundtrack (ElevenLabs + Music + Braam + Alarm + Whooshes) */}
      <Audio src={staticFile('rotaplus/ultimate_audio_master.wav')} volume={1.0} />

      {/* ==================================================================== */}
      {/* 1. DYNAMIC & RICH BACKGROUND (Zero Empty Space)                     */}
      {/* ==================================================================== */}

      {/* Atmospheric Dark Radial Gradient */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: 'radial-gradient(circle at 50% 35%, #131926 0%, #05070A 85%)',
        }}
      />

      {/* Animated Perspective Cyber Grid on Floor */}
      <div
        style={{
          position: 'absolute',
          bottom: -150,
          left: -200,
          right: -200,
          height: 700,
          perspective: 600,
          pointerEvents: 'none',
          opacity: 0.28,
        }}
      >
        <div
          style={{
            width: '100%',
            height: '100%',
            transform: 'rotateX(72deg)',
            backgroundImage:
              'linear-gradient(rgba(0,255,204,0.3) 1px, transparent 1px), linear-gradient(90deg, rgba(0,255,204,0.3) 1px, transparent 1px)',
            backgroundSize: '70px 70px',
            backgroundPosition: `0px ${(frame * 2.5) % 70}px`,
          }}
        />
      </div>

      {/* Drifting Floating Embers / Sparks */}
      <svg
        style={{
          position: 'absolute',
          inset: 0,
          width: '100%',
          height: '100%',
          pointerEvents: 'none',
          opacity: 0.6,
        }}
      >
        {Array.from({ length: 30 }).map((_, i) => {
          const sx = ((i * 127) + Math.sin(frame * 0.02 + i) * 30) % 1080;
          const sy = (1920 - ((frame * 2.5 + i * 90) % 1920));
          const r = (i % 3) + 1.2;
          const op = Math.sin((frame + i * 15) * 0.1) * 0.35 + 0.5;
          const col = i % 2 === 0 ? '#FF5500' : '#00FFCC';
          return <circle key={i} cx={sx} cy={sy} r={r} fill={col} opacity={op} />;
        })}
      </svg>

      {/* Topographic Contour Texture Overlay */}
      <img
        src={staticFile('rotaplus/topo_bg.png')}
        style={{
          position: 'absolute',
          inset: 0,
          width: '100%',
          height: '100%',
          objectFit: 'cover',
          opacity: 0.09,
          filter: 'invert(1)',
          pointerEvents: 'none',
        }}
      />

      {/* Large Tactical Watermark Text Scrolling in Background */}
      <div
        style={{
          position: 'absolute',
          top: 340,
          left: 0,
          whiteSpace: 'nowrap',
          fontSize: 84,
          fontFamily: THEME.fontDisplay,
          fontWeight: 900,
          color: 'rgba(255,255,255,0.03)',
          letterSpacing: 10,
          transform: `translateX(-${(frame * 1.5) % 1200}px)`,
          pointerEvents: 'none',
        }}
      >
        MIL-SPEC 810G SURVIVAL PROTOCOL · OFFLINE P2P MESH ARCHITECTURE · DIRECT SATELLITE TELEMETRY ·
      </div>

      {/* Volumetric Dual Beams (Cyan Left, Amber Right) */}
      <div
        style={{
          position: 'absolute',
          top: -150,
          left: -100,
          width: 600,
          height: 600,
          background: 'radial-gradient(circle, rgba(0,255,204,0.14) 0%, transparent 65%)',
          pointerEvents: 'none',
        }}
      />
      <div
        style={{
          position: 'absolute',
          top: -150,
          right: -100,
          width: 700,
          height: 700,
          background: 'radial-gradient(circle, rgba(255,85,0,0.18) 0%, transparent 65%)',
          pointerEvents: 'none',
        }}
      />

      {/* Corner HUD Reticles & Coordinates */}
      <div
        style={{
          position: 'absolute',
          top: 30,
          left: 40,
          fontSize: 12,
          fontFamily: THEME.fontMono,
          color: 'rgba(255,255,255,0.3)',
          letterSpacing: 2,
        }}
      >
        SYS: MIL-SPEC 810G · ENCRYPTED
      </div>
      <div
        style={{
          position: 'absolute',
          top: 30,
          right: 40,
          fontSize: 12,
          fontFamily: THEME.fontMono,
          color: THEME.accentCyan,
          letterSpacing: 2,
        }}
      >
        ● 38.4356° N, 27.1856° E
      </div>

      {/* ==================================================================== */}
      {/* 2. HOOK SCENE (0 - ~8s)                                             */}
      {/* ==================================================================== */}
      {activeScene.id === 'u_hook' && (
        <AbsoluteFill
          style={{
            justifyContent: 'center',
            alignItems: 'center',
            padding: '0 60px',
            textAlign: 'center',
          }}
        >
          {frame < 125 ? (
            <div>
              <div
                style={{
                  fontSize: 24,
                  fontFamily: THEME.fontMono,
                  color: THEME.accentRed,
                  letterSpacing: 6,
                  marginBottom: 36,
                  fontWeight: 800,
                }}
              >
                ● KRİTİK AFET VE ACİL DURUM SENARYOSU
              </div>

              {frame < 55 && (
                <div
                  style={{
                    fontSize: 88,
                    fontFamily: THEME.fontDisplay,
                    fontWeight: 800,
                    color: '#FFF',
                    lineHeight: 1.1,
                    textShadow: '0 0 50px rgba(255,255,255,0.5)',
                  }}
                >
                  ŞEBEKE SIFIR!
                </div>
              )}

              {frame >= 55 && frame < 95 && (
                <div
                  style={{
                    fontSize: 88,
                    fontFamily: THEME.fontDisplay,
                    fontWeight: 800,
                    color: THEME.accentRed,
                    lineHeight: 1.1,
                    textShadow: '0 0 50px rgba(239,68,68,0.6)',
                  }}
                >
                  TELEFONUN ÇEKMİYOR!
                </div>
              )}

              {frame >= 95 && (
                <div
                  style={{
                    fontSize: 98,
                    fontFamily: THEME.fontDisplay,
                    fontWeight: 800,
                    color: THEME.accentOrange,
                    lineHeight: 1.1,
                    textShadow: '0 0 50px rgba(255,85,0,0.8)',
                  }}
                >
                  PEKİ ŞİMDİ NE YAPACAKSIN?
                </div>
              )}
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
              <div
                style={{
                  position: 'relative',
                  width: 340,
                  height: 340,
                  display: 'flex',
                  justifyContent: 'center',
                  alignItems: 'center',
                  marginBottom: 44,
                }}
              >
                <div
                  style={{
                    position: 'absolute',
                    width: 330,
                    height: 330,
                    borderRadius: '50%',
                    border: '2px solid rgba(255,85,0,0.5)',
                    transform: `scale(${1 + ((frame - 125) % 25) * 0.05})`,
                    opacity: 1 - ((frame - 125) % 25) / 25,
                  }}
                />

                <div
                  style={{
                    width: 290,
                    height: 290,
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
                ROTA+ DEVREYE GİRER
              </div>
              <div
                style={{
                  fontSize: 26,
                  fontFamily: THEME.fontMono,
                  color: THEME.accentCyan,
                  marginTop: 18,
                  fontWeight: 700,
                  letterSpacing: 3,
                }}
              >
                SIFIR İNTERNET · TAM GÜVENLİK
              </div>
            </div>
          )}
        </AbsoluteFill>
      )}

      {/* ==================================================================== */}
      {/* 3. FEATURE SCENES WITH DUAL-STAGE (Phone + Side Motion Graphic Widget)*/}
      {/* ==================================================================== */}
      {activeScene.id !== 'u_hook' && activeScene.id !== 'u_outro' && (
        <AbsoluteFill style={{ padding: '75px 55px' }}>
          {/* Top Header */}
          <div
            style={{
              height: 180,
              display: 'flex',
              flexDirection: 'column',
              justifyContent: 'center',
              transform: `translateY(${interpolate(enterSpring, [0, 1], [-20, 0])}px)`,
              opacity: enterSpring,
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 6 }}>
              <span
                style={{
                  backgroundColor: 'rgba(255, 85, 0, 0.18)',
                  color: THEME.accentOrange,
                  border: '1.5px solid rgba(255, 85, 0, 0.45)',
                  padding: '4px 16px',
                  borderRadius: 16,
                  fontSize: 14,
                  fontFamily: THEME.fontMono,
                  fontWeight: 800,
                  letterSpacing: 1.5,
                }}
              >
                [{activeScene.tag}]
              </span>
              <span
                style={{
                  fontSize: 14,
                  fontFamily: THEME.fontMono,
                  color: THEME.accentCyan,
                  letterSpacing: 2,
                }}
              >
                ● ÇEVRİMDIŞI SAHRA SİSTEMİ
              </span>
            </div>

            <div
              style={{
                fontSize: 58,
                fontFamily: THEME.fontDisplay,
                fontWeight: 800,
                color: '#FFF',
                lineHeight: 1.1,
                letterSpacing: 1,
              }}
            >
              {activeScene.title}
            </div>

            <div
              style={{
                fontSize: 24,
                fontFamily: THEME.fontSans,
                color: THEME.textMuted,
                fontWeight: 600,
                marginTop: 6,
                lineHeight: 1.35,
              }}
            >
              {activeScene.sub}
            </div>
          </div>

          {/* Central Split Stage: Left is Phone, Right is Animated Infographic Widget */}
          <div
            style={{
              position: 'relative',
              width: '100%',
              height: 980,
              display: 'flex',
              alignItems: 'center',
              perspective: 1200,
            }}
          >
            {/* The 3D Phone (Left Side) */}
            <div
              style={{
                width: 470,
                height: 860,
                borderRadius: 42,
                overflow: 'hidden',
                backgroundColor: '#0F1218',
                border: '8px solid #282C37',
                boxShadow:
                  '0 35px 85px rgba(0,0,0,0.65), 0 0 50px rgba(255,85,0,0.12), inset 0 0 10px rgba(255,255,255,0.06)',
                transform: `rotateY(${rotY}deg) rotateX(${rotX}deg) translateY(${floatY}px) scale(${enterSpring})`,
                position: 'relative',
                transformStyle: 'preserve-3d',
                flexShrink: 0,
              }}
            >
              {/* App Screenshot */}
              <img
                src={staticFile(`rotaplus/${activeScene.screen}`)}
                style={{ width: '100%', height: '100%', objectFit: 'cover' }}
              />

              {/* Dynamic Island */}
              <div
                style={{
                  position: 'absolute',
                  top: 12,
                  left: '50%',
                  transform: 'translateX(-50%)',
                  width: 96,
                  height: 24,
                  backgroundColor: '#000',
                  borderRadius: 12,
                  zIndex: 40,
                }}
              />

              {/* Exact HUD Target Reticle Brackets (Pixel-Perfect Framing) */}

              {/* Mesh Scene: Framing the Aktif Düğüm card */}
              {activeScene.id === 'u_mesh' && (
                <div
                  style={{
                    position: 'absolute',
                    top: '17.5%',
                    left: '4.5%',
                    width: '91%',
                    height: '14.5%',
                    borderRadius: 16,
                    border: '1.5px solid rgba(0,255,204,0.7)',
                    boxShadow: '0 0 20px rgba(0,255,204,0.4)',
                    pointerEvents: 'none',
                  }}
                >
                  <span
                    style={{
                      position: 'absolute',
                      top: -10,
                      right: 12,
                      backgroundColor: '#00FFCC',
                      color: '#000',
                      fontSize: 10,
                      fontFamily: THEME.fontMono,
                      fontWeight: 800,
                      padding: '1px 6px',
                      borderRadius: 4,
                    }}
                  >
                    P2P BAĞLANTI AKTİF
                  </span>
                </div>
              )}

              {/* Deprem Scene: Framing the Güvendeyim button */}
              {activeScene.id === 'u_deprem' && (
                <div
                  style={{
                    position: 'absolute',
                    top: '12.7%',
                    left: '4.3%',
                    width: '91.3%',
                    height: '15.6%',
                    borderRadius: 22,
                    boxShadow: `0 0 ${25 + Math.sin(frame * 0.25) * 15}px rgba(16, 185, 129, 0.6)`,
                    border: '2px solid rgba(16, 185, 129, 0.7)',
                    pointerEvents: 'none',
                  }}
                />
              )}

              {/* GPS Scene: Framing Waypoint on Map */}
              {activeScene.id === 'u_gps' && (
                <div
                  style={{
                    position: 'absolute',
                    top: '42.5%',
                    left: '4.3%',
                    backgroundColor: 'rgba(15, 20, 30, 0.92)',
                    backdropFilter: 'blur(8px)',
                    padding: '6px 14px',
                    borderRadius: 10,
                    border: '1px solid rgba(255, 85, 0, 0.5)',
                    fontSize: 11,
                    fontFamily: THEME.fontMono,
                    color: '#FF8C00',
                    fontWeight: 800,
                    pointerEvents: 'none',
                  }}
                >
                  🛰️ UYDU KİLİTLİ: 38.4356° N, 27.1856° E
                </div>
              )}

              {/* Auto-SOS Scene: Framing Hareketsizlik Sensörü */}
              {activeScene.id === 'u_autosos' && (
                <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
                  <div
                    style={{
                      position: 'absolute',
                      inset: 0,
                      border: '4px solid #EF4444',
                      boxShadow: 'inset 0 0 45px rgba(239, 68, 68, 0.5)',
                      opacity: 0.6 + Math.sin(frame * 0.4) * 0.4,
                    }}
                  />
                  <div
                    style={{
                      position: 'absolute',
                      top: 75,
                      left: 18,
                      right: 18,
                      backgroundColor: 'rgba(239, 68, 68, 0.95)',
                      borderRadius: 14,
                      padding: '12px 16px',
                      color: '#FFF',
                      textAlign: 'center',
                      boxShadow: '0 10px 30px rgba(239,68,68,0.7)',
                    }}
                  >
                    <div style={{ fontSize: 14, fontFamily: THEME.fontMono, fontWeight: 800 }}>
                      ⚠️ HAREKETSİZLİK DETEKTÖRÜ
                    </div>
                  </div>
                </div>
              )}
            </div>

            {/* ============================================================ */}
            {/* RIGHT SIDE: ANIMATED MOTION GRAPHIC INFOGRAPHIC WIDGET        */}
            {/* (The user's direct request: "mesh ağı diyo ya orda yanda animasyon") */}
            {/* ============================================================ */}
            <div
              style={{
                flex: 1,
                marginLeft: 40,
                height: 860,
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'center',
                transform: `translateX(${interpolate(enterSpring, [0, 1], [40, 0])}px)`,
                opacity: enterSpring,
              }}
            >
              {/* SCENE 1: DOĞA MESH AĞI WIDGET */}
              {activeScene.id === 'u_mesh' && (
                <div
                  style={{
                    backgroundColor: 'rgba(15, 23, 42, 0.92)',
                    backdropFilter: 'blur(16px)',
                    borderRadius: 24,
                    border: '1.5px solid rgba(0, 255, 204, 0.45)',
                    padding: '28px 24px',
                    boxShadow: '0 20px 50px rgba(0,0,0,0.55)',
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                  }}
                >
                  <div
                    style={{
                      fontSize: 14,
                      fontFamily: THEME.fontMono,
                      color: THEME.accentCyan,
                      fontWeight: 800,
                      letterSpacing: 2,
                      marginBottom: 20,
                    }}
                  >
                    ● ÇEVRİMDIŞI MESH AĞI TOPOLOJİSİ
                  </div>

                  {/* Animated Mesh Node SVG Diagram */}
                  <svg width="380" height="340" viewBox="0 0 380 340">
                    <defs>
                      <filter id="meshGlow" x="-20%" y="-20%" width="140%" height="140%">
                        <feGaussianBlur stdDeviation="3" result="blur" />
                        <feMerge>
                          <feMergeNode in="blur" />
                          <feMergeNode in="SourceGraphic" />
                        </feMerge>
                      </filter>
                    </defs>

                    {/* Connecting Mesh Circuit Lines */}
                    <line x1="190" y1="60" x2="80" y2="180" stroke="#00FFCC" strokeWidth="2.5" opacity="0.7" strokeDasharray="6 4" />
                    <line x1="190" y1="60" x2="300" y2="180" stroke="#00FFCC" strokeWidth="2.5" opacity="0.7" strokeDasharray="6 4" />
                    <line x1="80" y1="180" x2="190" y2="280" stroke="#FF5500" strokeWidth="2.5" opacity="0.7" strokeDasharray="6 4" />
                    <line x1="300" y1="180" x2="190" y2="280" stroke="#FF5500" strokeWidth="2.5" opacity="0.7" strokeDasharray="6 4" />
                    <line x1="80" y1="180" x2="300" y2="180" stroke="#10B981" strokeWidth="2" opacity="0.5" />

                    {/* Animated Traveling Data Packet Pulses */}
                    {(() => {
                      const t = (frame % 30) / 30;
                      return (
                        <>
                          <circle cx={interpolate(t, [0, 1], [190, 80])} cy={interpolate(t, [0, 1], [60, 180])} r="4.5" fill="#00FFCC" filter="url(#meshGlow)" />
                          <circle cx={interpolate(t, [0, 1], [190, 300])} cy={interpolate(t, [0, 1], [60, 180])} r="4.5" fill="#00FFCC" filter="url(#meshGlow)" />
                          <circle cx={interpolate(t, [0, 1], [80, 190])} cy={interpolate(t, [0, 1], [180, 280])} r="4.5" fill="#FF5500" filter="url(#meshGlow)" />
                          <circle cx={interpolate(t, [0, 1], [300, 190])} cy={interpolate(t, [0, 1], [180, 280])} r="4.5" fill="#FF5500" filter="url(#meshGlow)" />
                        </>
                      );
                    })()}

                    {/* Center Leader Node */}
                    <g transform="translate(190, 60)">
                      <circle r="24" fill="#0F172A" stroke="#00FFCC" strokeWidth="3" filter="url(#meshGlow)" />
                      <text textAnchor="middle" dy="5" fill="#FFF" fontSize="12" fontFamily={THEME.fontMono} fontWeight="bold">SEN</text>
                    </g>

                    {/* Left Node */}
                    <g transform="translate(80, 180)">
                      <circle r="22" fill="#0F172A" stroke="#FF5500" strokeWidth="2.5" />
                      <text textAnchor="middle" dy="4" fill="#FFF" fontSize="10" fontFamily={THEME.fontMono}>EKİP 1</text>
                    </g>

                    {/* Right Node */}
                    <g transform="translate(300, 180)">
                      <circle r="22" fill="#0F172A" stroke="#FF5500" strokeWidth="2.5" />
                      <text textAnchor="middle" dy="4" fill="#FFF" fontSize="10" fontFamily={THEME.fontMono}>EKİP 2</text>
                    </g>

                    {/* Bottom Rescue Node */}
                    <g transform="translate(190, 280)">
                      <circle r="24" fill="#0F172A" stroke="#10B981" strokeWidth="3" filter="url(#meshGlow)" />
                      <text textAnchor="middle" dy="5" fill="#10B981" fontSize="11" fontFamily={THEME.fontMono} fontWeight="bold">KURTARMA</text>
                    </g>
                  </svg>

                  {/* Mesh Telemetry Stats */}
                  <div
                    style={{
                      width: '100%',
                      backgroundColor: 'rgba(0,0,0,0.4)',
                      borderRadius: 14,
                      padding: '12px 18px',
                      display: 'flex',
                      justifyContent: 'space-between',
                      marginTop: 10,
                      border: '1px solid rgba(0,255,204,0.25)',
                    }}
                  >
                    <div>
                      <div style={{ fontSize: 11, color: '#94A3B8', fontFamily: THEME.fontMono }}>DÜĞÜM TİPİ</div>
                      <div style={{ fontSize: 16, color: '#00FFCC', fontFamily: THEME.fontMono, fontWeight: 800 }}>P2P BLUETOOTH & WIFI</div>
                    </div>
                    <div style={{ textAlign: 'right' }}>
                      <div style={{ fontSize: 11, color: '#94A3B8', fontFamily: THEME.fontMono }}>ŞEBEKE</div>
                      <div style={{ fontSize: 16, color: '#10B981', fontFamily: THEME.fontMono, fontWeight: 800 }}>SIFIR İNTERNET</div>
                    </div>
                  </div>
                </div>
              )}

              {/* SCENE 2: DEPREM & ENKAZ AKUSTİK RADAR WIDGET */}
              {activeScene.id === 'u_deprem' && (
                <div
                  style={{
                    backgroundColor: 'rgba(15, 23, 42, 0.92)',
                    backdropFilter: 'blur(16px)',
                    borderRadius: 24,
                    border: '1.5px solid rgba(16, 185, 129, 0.5)',
                    padding: '28px 24px',
                    boxShadow: '0 20px 50px rgba(0,0,0,0.55)',
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                  }}
                >
                  <div
                    style={{
                      fontSize: 14,
                      fontFamily: THEME.fontMono,
                      color: THEME.accentGreen,
                      fontWeight: 800,
                      letterSpacing: 2,
                      marginBottom: 16,
                    }}
                  >
                    ● ENKAZ ALTI BLE KURTARMA RADARI
                  </div>

                  {/* 360 Degree Radar Sweep SVG */}
                  <svg width="340" height="300" viewBox="0 0 340 300">
                    <circle cx="170" cy="150" r="130" fill="none" stroke="rgba(16, 185, 129, 0.3)" strokeWidth="1.5" />
                    <circle cx="170" cy="150" r="90" fill="none" stroke="rgba(16, 185, 129, 0.4)" strokeWidth="1.5" />
                    <circle cx="170" cy="150" r="45" fill="none" stroke="rgba(16, 185, 129, 0.5)" strokeWidth="1.5" />
                    <line x1="40" y1="150" x2="300" y2="150" stroke="rgba(16, 185, 129, 0.25)" strokeWidth="1" />
                    <line x1="170" y1="20" x2="170" y2="280" stroke="rgba(16, 185, 129, 0.25)" strokeWidth="1" />

                    {/* Rotating Radar Sweep Line */}
                    {(() => {
                      const angle = (frame * 4) % 360;
                      const rad = (angle * Math.PI) / 180;
                      const x2 = 170 + Math.cos(rad) * 130;
                      const y2 = 150 + Math.sin(rad) * 130;
                      return (
                        <>
                          <line x1="170" y1="150" x2={x2} y2={y2} stroke="#10B981" strokeWidth="2.5" />
                          <circle cx={x2} cy={y2} r="5" fill="#10B981" />
                        </>
                      );
                    })()}

                    {/* Center Survivor Beacon */}
                    <circle cx="170" cy="150" r="10" fill="#10B981" />
                    <circle cx="170" cy="150" r={16 + (frame % 20)} fill="none" stroke="#10B981" strokeWidth="2" opacity={1 - (frame % 20) / 20} />
                  </svg>

                  {/* Audio Spectrum Bars (Listening for Whistle / Help) */}
                  <div style={{ display: 'flex', alignItems: 'flex-end', gap: 6, height: 60, marginTop: 12 }}>
                    {Array.from({ length: 18 }).map((_, i) => {
                      const h = 10 + Math.abs(Math.sin((frame + i * 8) * 0.2)) * 45;
                      return (
                        <div
                          key={i}
                          style={{
                            width: 12,
                            height: h,
                            backgroundColor: i % 3 === 0 ? '#10B981' : '#00FFCC',
                            borderRadius: 4,
                          }}
                        />
                      );
                    })}
                  </div>
                  <div style={{ fontSize: 12, fontFamily: THEME.fontMono, color: '#94A3B8', marginTop: 10 }}>
                    AKUSTİK SES DEDEKTÖRÜ: DİNLİYOR
                  </div>
                </div>
              )}

              {/* SCENE 3: GPS & TOPOĞRAFYA WIDGET */}
              {activeScene.id === 'u_gps' && (
                <div
                  style={{
                    backgroundColor: 'rgba(15, 23, 42, 0.92)',
                    backdropFilter: 'blur(16px)',
                    borderRadius: 24,
                    border: '1.5px solid rgba(255, 85, 0, 0.45)',
                    padding: '28px 24px',
                    boxShadow: '0 20px 50px rgba(0,0,0,0.55)',
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                  }}
                >
                  <div
                    style={{
                      fontSize: 14,
                      fontFamily: THEME.fontMono,
                      color: THEME.accentOrange,
                      fontWeight: 800,
                      letterSpacing: 2,
                      marginBottom: 16,
                    }}
                  >
                    ● DOĞRUDAN UYDU VE ALTIMETRE
                  </div>

                  {/* Orbiting Satellite SVG */}
                  <svg width="340" height="240" viewBox="0 0 340 240">
                    <ellipse cx="170" cy="120" rx="140" ry="60" fill="none" stroke="rgba(255,85,0,0.3)" strokeWidth="1.5" strokeDasharray="6 4" />
                    {(() => {
                      const t = (frame * 0.05) % (2 * Math.PI);
                      const sx = 170 + Math.cos(t) * 140;
                      const sy = 120 + Math.sin(t) * 60;
                      return (
                        <>
                          <line x1={sx} y1={sy} x2="170" y2="180" stroke="#FF5500" strokeWidth="2" strokeDasharray="4 4" opacity="0.8" />
                          <g transform={`translate(${sx}, ${sy})`}>
                            <rect x="-10" y="-8" width="20" height="16" fill="#FF5500" rx="3" />
                            <line x1="-18" y1="0" x2="-10" y2="0" stroke="#00FFCC" strokeWidth="3" />
                            <line x1="10" y1="0" x2="18" y2="0" stroke="#00FFCC" strokeWidth="3" />
                          </g>
                        </>
                      );
                    })()}
                    <circle cx="170" cy="180" r="14" fill="#0F172A" stroke="#00FFCC" strokeWidth="3" />
                    <text x="170" y="215" textAnchor="middle" fill="#00FFCC" fontSize="11" fontFamily={THEME.fontMono}>HEDEF KOORDİNAT</text>
                  </svg>

                  {/* Elevation Curve Box */}
                  <div
                    style={{
                      width: '100%',
                      backgroundColor: 'rgba(0,0,0,0.4)',
                      borderRadius: 14,
                      padding: '14px 20px',
                      border: '1px solid rgba(255,85,0,0.3)',
                    }}
                  >
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
                      <span style={{ fontSize: 12, color: '#94A3B8', fontFamily: THEME.fontMono }}>ANLIK RAKIM</span>
                      <span style={{ fontSize: 18, color: '#FF5500', fontFamily: THEME.fontMono, fontWeight: 800 }}>312 M</span>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span style={{ fontSize: 12, color: '#94A3B8', fontFamily: THEME.fontMono }}>UYDU KİLİDİ</span>
                      <span style={{ fontSize: 16, color: '#10B981', fontFamily: THEME.fontMono, fontWeight: 800 }}>14 UYDU (TAM HASSASİYET)</span>
                    </div>
                  </div>
                </div>
              )}

              {/* SCENE 4: AUTO-SOS & DEADMAN SWITCH WIDGET */}
              {activeScene.id === 'u_autosos' && (
                <div
                  style={{
                    backgroundColor: 'rgba(15, 23, 42, 0.92)',
                    backdropFilter: 'blur(16px)',
                    borderRadius: 24,
                    border: '1.5px solid rgba(239, 68, 68, 0.55)',
                    padding: '28px 24px',
                    boxShadow: '0 20px 50px rgba(0,0,0,0.55)',
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                  }}
                >
                  <div
                    style={{
                      fontSize: 14,
                      fontFamily: THEME.fontMono,
                      color: THEME.accentRed,
                      fontWeight: 800,
                      letterSpacing: 2,
                      marginBottom: 16,
                    }}
                  >
                    ● DEADMAN SWITCH & SİREN PROTOKOLÜ
                  </div>

                  {/* Radial Countdown Progress Ring */}
                  <div style={{ position: 'relative', width: 200, height: 200, display: 'flex', justifyContent: 'center', alignItems: 'center' }}>
                    <svg width="200" height="200">
                      <circle cx="100" cy="100" r="85" fill="none" stroke="rgba(239,68,68,0.2)" strokeWidth="12" />
                      <circle
                        cx="100"
                        cy="100"
                        r="85"
                        fill="none"
                        stroke="#EF4444"
                        strokeWidth="12"
                        strokeDasharray={534}
                        strokeDashoffset={interpolate((frame % 60), [0, 60], [0, 534])}
                        strokeLinecap="round"
                        transform="rotate(-90 100 100)"
                      />
                    </svg>
                    <div style={{ position: 'absolute', textAlign: 'center' }}>
                      <div style={{ fontSize: 48, fontFamily: THEME.fontDisplay, fontWeight: 900, color: '#FFF' }}>
                        {20 - Math.floor((sceneElapsed / 15) % 20)}
                      </div>
                      <div style={{ fontSize: 11, fontFamily: THEME.fontMono, color: THEME.accentRed }}>SANİYE</div>
                    </div>
                  </div>

                  {/* Heartbeat ECG Line */}
                  <svg width="340" height="70" viewBox="0 0 340 70" style={{ marginTop: 16 }}>
                    <path
                      d="M 10 35 L 80 35 L 100 10 L 120 60 L 140 25 L 150 45 L 160 35 L 330 35"
                      fill="none"
                      stroke="#EF4444"
                      strokeWidth="3"
                      strokeLinecap="round"
                      strokeDasharray="400"
                      strokeDashoffset={(frame * 8) % 400}
                    />
                  </svg>
                  <div style={{ fontSize: 13, fontFamily: THEME.fontMono, color: '#FFF', marginTop: 12, fontWeight: 700 }}>
                    KAZA / BAYILMA ANINDA OTOMATİK SİREN
                  </div>
                </div>
              )}

              {/* SCENE 5: İLK YARDIM VE DAĞCILIK WIDGET */}
              {activeScene.id === 'u_ilkyardim' && (
                <div
                  style={{
                    backgroundColor: 'rgba(15, 23, 42, 0.92)',
                    backdropFilter: 'blur(16px)',
                    borderRadius: 24,
                    border: '1.5px solid rgba(255, 85, 0, 0.45)',
                    padding: '28px 24px',
                    boxShadow: '0 20px 50px rgba(0,0,0,0.55)',
                    display: 'flex',
                    flexDirection: 'column',
                  }}
                >
                  <div
                    style={{
                      fontSize: 14,
                      fontFamily: THEME.fontMono,
                      color: THEME.accentOrange,
                      fontWeight: 800,
                      letterSpacing: 2,
                      marginBottom: 16,
                      textAlign: 'center',
                    }}
                  >
                    ● ÇEVRİMDIŞI TRİYAJ & PROTOKOLLER
                  </div>

                  {['TURNİKE & ATELLEME PROTOKOLÜ', 'HİPOTERMİ & ŞOK ÖNLEME', 'ALPIN KELEBEK DÜĞÜMÜ', 'RESMİ DAĞCILIK VE SAHRA REHBERİ'].map((item, idx) => (
                    <div
                      key={idx}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: 12,
                        backgroundColor: 'rgba(0,0,0,0.35)',
                        padding: '14px 18px',
                        borderRadius: 14,
                        marginBottom: 10,
                        border: '1px solid rgba(255,85,0,0.25)',
                      }}
                    >
                      <div
                        style={{
                          width: 24,
                          height: 24,
                          borderRadius: '50%',
                          backgroundColor: THEME.accentGreen,
                          display: 'flex',
                          justifyContent: 'center',
                          alignItems: 'center',
                          fontSize: 14,
                          color: '#FFF',
                          fontWeight: 'bold',
                        }}
                      >
                        ✓
                      </div>
                      <span style={{ fontSize: 14, fontFamily: THEME.fontMono, color: '#FFF', fontWeight: 700 }}>
                        {item}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>

          {/* Bottom Conversion Bar (Clear, High-Impact Value Proposition) */}
          <div
            style={{
              position: 'absolute',
              bottom: 50,
              left: 55,
              right: 55,
              height: 155,
              backgroundColor: THEME.bgCard,
              backdropFilter: 'blur(20px)',
              borderRadius: 22,
              padding: '20px 30px',
              border: '1.5px solid rgba(255, 85, 0, 0.45)',
              boxShadow: '0 20px 50px rgba(0,0,0,0.7)',
              display: 'flex',
              flexDirection: 'column',
              justifyContent: 'center',
              transform: `translateY(${interpolate(enterSpring, [0, 1], [30, 0])}px)`,
              opacity: enterSpring,
              zIndex: 30,
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 8 }}>
              <div
                style={{
                  width: 12,
                  height: 12,
                  borderRadius: '50%',
                  backgroundColor: THEME.accentGreen,
                  boxShadow: '0 0 10px #10B981',
                }}
              />
              <span
                style={{
                  fontSize: 14,
                  fontFamily: THEME.fontMono,
                  color: '#FFF',
                  fontWeight: 800,
                  letterSpacing: 2,
                }}
              >
                NEDEN HAYAT KURTARIR?
              </span>
            </div>
            <div
              style={{
                fontSize: 19,
                fontFamily: THEME.fontSans,
                color: '#E2E8F0',
                lineHeight: 1.4,
                fontWeight: 600,
              }}
            >
              {activeScene.id === 'u_mesh' &&
                'Baz istasyonu olmadan doğrudan telefonlar arası P2P bağlantı kurar, ekibinizle sıfır internetle haberleşirsiniz.'}
              {activeScene.id === 'u_deprem' &&
                'Enkaz altında sesiniz kısılsa bile BLE radarı ve akustik ses dedektörü yerinizi kurtarma ekiplerine bildirir.'}
              {activeScene.id === 'u_gps' &&
                'İnternetsiz izohipsli sahra haritasında doğrudan GPS uydularıyla adım adım rotanızı çizer ve kaybolmayı önler.'}
              {activeScene.id === 'u_autosos' &&
                'Kaza veya bayılma anında hareketsiz kaldığınızda otomatik siren çalar ve ekibinize acil durum SMS çağrısı iletir.'}
              {activeScene.id === 'u_ilkyardim' &&
                'Panik anında ne yapacağınızı şaşırdığınızda turnike, kanama ve dağcılık düğümlerini çevrimdışı rehberle sunar.'}
            </div>
          </div>
        </AbsoluteFill>
      )}

      {/* ==================================================================== */}
      {/* 4. OUTRO (High Conversion Finish)                                   */}
      {/* ==================================================================== */}
      {activeScene.id === 'u_outro' && (
        <AbsoluteFill
          style={{
            backgroundColor: '#06080D',
            justifyContent: 'center',
            alignItems: 'center',
            flexDirection: 'column',
            padding: '0 60px',
            textAlign: 'center',
          }}
        >
          {/* Ambient Flare */}
          <div
            style={{
              position: 'absolute',
              width: 700,
              height: 700,
              borderRadius: '50%',
              background: 'radial-gradient(circle, rgba(255,85,0,0.22) 0%, transparent 70%)',
            }}
          />

          {/* Big Metallic Compass Logo */}
          <div
            style={{
              width: 320,
              height: 320,
              borderRadius: '50%',
              overflow: 'hidden',
              boxShadow: '0 0 90px rgba(255,85,0,0.75), 0 0 140px rgba(0,255,204,0.3)',
              border: '4px solid rgba(255,140,20,0.9)',
              marginBottom: 36,
              transform: `scale(${spring({ frame: sceneElapsed, fps, config: { damping: 12 } })})`,
              zIndex: 10,
            }}
          >
            <img
              src={staticFile('rotaplus/logo.png')}
              style={{ width: '100%', height: '100%', objectFit: 'cover' }}
            />
          </div>

          <div
            style={{
              fontSize: 88,
              fontFamily: THEME.fontDisplay,
              fontWeight: 800,
              color: '#FFF',
              letterSpacing: 3,
              marginBottom: 12,
              zIndex: 10,
            }}
          >
            ROTA+
          </div>

          <div
            style={{
              fontSize: 28,
              fontFamily: THEME.fontSans,
              color: THEME.accentOrange,
              fontWeight: 700,
              letterSpacing: 2,
              marginBottom: 40,
              maxWidth: 880,
              lineHeight: 1.3,
              zIndex: 10,
            }}
          >
            ACİL DURUM KAPINI ÇALMADAN ÖNCE İNDİR.
          </div>

          {/* App Store & Google Play Badges */}
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
                height: 66,
                borderRadius: 14,
                boxShadow: '0 10px 30px rgba(0,0,0,0.6)',
              }}
            />
            <img
              src={staticFile('rotaplus/badge_googleplay.png')}
              style={{
                height: 66,
                borderRadius: 14,
                boxShadow: '0 10px 30px rgba(0,0,0,0.6)',
              }}
            />
          </div>

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
