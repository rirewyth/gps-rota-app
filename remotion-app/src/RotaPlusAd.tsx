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
import metadata from './ad_metadata.json';

const THEME = {
  bgDeep: '#07090E',
  bgCard: 'rgba(15, 22, 35, 0.94)',
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

export const RotaPlusAd: React.FC = () => {
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

  // 3D Perspective & Subtle Breathing Motion
  const rotY = Math.sin(sceneElapsed * 0.04) * 3 - 1.5;
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
      {/* High-Impact Master Soundtrack (ElevenLabs Charlie + Sub-bass + 124 BPM) */}
      <Audio src={staticFile('rotaplus/ad_audio_master.wav')} volume={1.0} />

      {/* Atmospheric Background: Dark Vignette & Ambient Radial Glow */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: 'radial-gradient(circle at 50% 30%, #151A28 0%, #06080D 85%)',
        }}
      />

      {/* Subtle Topographic Contour Grid */}
      <img
        src={staticFile('rotaplus/topo_bg.png')}
        style={{
          position: 'absolute',
          inset: 0,
          width: '100%',
          height: '100%',
          objectFit: 'cover',
          opacity: 0.12,
          filter: 'invert(1)',
          pointerEvents: 'none',
        }}
      />

      {/* Volumetric Orange Flare from Top */}
      <div
        style={{
          position: 'absolute',
          top: -120,
          left: '50%',
          transform: 'translateX(-50%)',
          width: 900,
          height: 600,
          background: 'radial-gradient(circle, rgba(255,85,0,0.18) 0%, transparent 65%)',
          pointerEvents: 'none',
        }}
      />

      {/* ==================================================================== */}
      {/* 1. HOOK SCENE: The Problem / Threat (0 - ~8.5s)                     */}
      {/* ==================================================================== */}
      {activeScene.id === 'ad_hook' && (
        <AbsoluteFill
          style={{
            justifyContent: 'center',
            alignItems: 'center',
            padding: '0 60px',
            textAlign: 'center',
          }}
        >
          {frame < 130 ? (
            <div>
              {/* Emergency Alert Tag */}
              <div
                style={{
                  fontSize: 22,
                  fontFamily: THEME.fontMono,
                  color: THEME.accentRed,
                  letterSpacing: 6,
                  marginBottom: 36,
                  fontWeight: 800,
                }}
              >
                ● GERÇEK HAYAT SENARYOSU
              </div>

              {frame < 60 && (
                <div
                  style={{
                    fontSize: 86,
                    fontFamily: THEME.fontDisplay,
                    fontWeight: 800,
                    color: '#FFF',
                    lineHeight: 1.1,
                    textShadow: '0 0 50px rgba(255,255,255,0.4)',
                  }}
                >
                  BÜYÜK BİR DEPREMDE...
                </div>
              )}

              {frame >= 60 && frame < 105 && (
                <div
                  style={{
                    fontSize: 88,
                    fontFamily: THEME.fontDisplay,
                    fontWeight: 800,
                    color: THEME.accentRed,
                    lineHeight: 1.1,
                    textShadow: '0 0 50px rgba(239,68,68,0.5)',
                  }}
                >
                  ŞEBEKE TAMAMEN ÇÖKTÜĞÜNDE!
                </div>
              )}

              {frame >= 105 && (
                <div
                  style={{
                    fontSize: 100,
                    fontFamily: THEME.fontDisplay,
                    fontWeight: 800,
                    color: THEME.accentOrange,
                    lineHeight: 1.1,
                    textShadow: '0 0 50px rgba(255,85,0,0.7)',
                  }}
                >
                  PEKİ ŞİMDİ NE YAPACAKSIN?
                </div>
              )}
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
              {/* Expanding Shockwave Ring */}
              <div
                style={{
                  position: 'relative',
                  width: 330,
                  height: 330,
                  display: 'flex',
                  justifyContent: 'center',
                  alignItems: 'center',
                  marginBottom: 44,
                }}
              >
                <div
                  style={{
                    position: 'absolute',
                    width: 320,
                    height: 320,
                    borderRadius: '50%',
                    border: '2px solid rgba(255,85,0,0.5)',
                    transform: `scale(${1 + ((frame - 130) % 25) * 0.05})`,
                    opacity: 1 - ((frame - 130) % 25) / 25,
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
                    transform: `scale(${spring({ frame: frame - 130, fps, config: { damping: 11 } })})`,
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
      {/* 2. AD FEATURE SCENES (Deprem, GPS, Auto-SOS, İlk Yardım)            */}
      {/* ==================================================================== */}
      {activeScene.id !== 'ad_hook' && activeScene.id !== 'ad_outro' && (
        <AbsoluteFill style={{ padding: '70px 60px' }}>
          {/* Top Header: Tag + Big Commercial Headline */}
          <div
            style={{
              height: 210,
              display: 'flex',
              flexDirection: 'column',
              justifyContent: 'center',
              transform: `translateY(${interpolate(enterSpring, [0, 1], [-20, 0])}px)`,
              opacity: enterSpring,
            }}
          >
            {/* Tag Badge */}
            <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 8 }}>
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
                ● MIL-SPEC SAHRA SİSTEMİ
              </span>
            </div>

            {/* Bold Title */}
            <div
              style={{
                fontSize: 60,
                fontFamily: THEME.fontDisplay,
                fontWeight: 800,
                color: '#FFF',
                lineHeight: 1.1,
                letterSpacing: 1,
              }}
            >
              {activeScene.title}
            </div>

            {/* Subtitle */}
            <div
              style={{
                fontSize: 25,
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

          {/* Center Stage: Phone Mockup (Height: 890px, perfectly balanced) */}
          <div
            style={{
              position: 'relative',
              width: '100%',
              height: 940,
              display: 'flex',
              justifyContent: 'center',
              alignItems: 'center',
              perspective: 1200,
            }}
          >
            <div
              style={{
                width: 500,
                height: 890,
                borderRadius: 44,
                overflow: 'hidden',
                backgroundColor: '#0F1218',
                border: '9px solid #282C37',
                boxShadow:
                  '0 35px 85px rgba(0,0,0,0.65), 0 0 50px rgba(255,85,0,0.12), inset 0 0 10px rgba(255,255,255,0.06)',
                transform: `rotateY(${rotY}deg) rotateX(${rotX}deg) translateY(${floatY}px) scale(${enterSpring})`,
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
                  top: 12,
                  left: '50%',
                  transform: 'translateX(-50%)',
                  width: 100,
                  height: 26,
                  backgroundColor: '#000',
                  borderRadius: 13,
                  zIndex: 40,
                }}
              />

              {/* In-Screen Tactical Enhancements (NO wireframe stroke boxes!) */}

              {/* Scene 2: Deprem - Breathing Aura on Güvendeyim */}
              {activeScene.id === 'ad_deprem' && (
                <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
                  <div
                    style={{
                      position: 'absolute',
                      top: 115,
                      left: 20,
                      right: 20,
                      height: 140,
                      borderRadius: 22,
                      boxShadow: `0 0 ${25 + Math.sin(frame * 0.25) * 15}px rgba(16, 185, 129, 0.55)`,
                      border: '2px solid rgba(16, 185, 129, 0.6)',
                    }}
                  />
                </div>
              )}

              {/* Scene 3: GPS - Live Satellite Lock Tag */}
              {activeScene.id === 'ad_gps' && (
                <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
                  <div
                    style={{
                      position: 'absolute',
                      top: 430,
                      left: 20,
                      backgroundColor: 'rgba(15, 20, 30, 0.92)',
                      backdropFilter: 'blur(8px)',
                      padding: '6px 14px',
                      borderRadius: 10,
                      border: '1px solid rgba(255, 85, 0, 0.5)',
                      fontSize: 12,
                      fontFamily: THEME.fontMono,
                      color: '#FF8C00',
                      fontWeight: 800,
                    }}
                  >
                    🛰️ SIFIR ŞEBEKE · UYDU KİLİTLİ
                  </div>
                </div>
              )}

              {/* Scene 4: Auto-SOS - Emergency Red Vignette & Warning Header */}
              {activeScene.id === 'ad_autosos' && (
                <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
                  <div
                    style={{
                      position: 'absolute',
                      inset: 0,
                      border: '4px solid #EF4444',
                      boxShadow: 'inset 0 0 50px rgba(239, 68, 68, 0.5)',
                      opacity: 0.6 + Math.sin(frame * 0.4) * 0.4,
                    }}
                  />
                  <div
                    style={{
                      position: 'absolute',
                      top: 80,
                      left: 20,
                      right: 20,
                      backgroundColor: 'rgba(239, 68, 68, 0.95)',
                      borderRadius: 14,
                      padding: '14px 18px',
                      color: '#FFF',
                      textAlign: 'center',
                      boxShadow: '0 10px 30px rgba(239,68,68,0.7)',
                    }}
                  >
                    <div style={{ fontSize: 15, fontFamily: THEME.fontMono, fontWeight: 800 }}>
                      ⚠️ HAREKETSİZLİK TESPİT EDİLDİ
                    </div>
                    <div style={{ fontSize: 12, marginTop: 4, opacity: 0.9 }}>
                      Siren tetikleniyor · Acil koordinat SMS hazırlanıyor.
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Bottom Conversion Callout Card (Zero overlap, generous breathing room!) */}
          <div
            style={{
              position: 'absolute',
              bottom: 60,
              left: 60,
              right: 60,
              height: 180,
              backgroundColor: THEME.bgCard,
              backdropFilter: 'blur(20px)',
              borderRadius: 24,
              padding: '24px 32px',
              border: '1.5px solid rgba(255, 85, 0, 0.45)',
              boxShadow: '0 25px 60px rgba(0,0,0,0.65)',
              display: 'flex',
              flexDirection: 'column',
              justifyContent: 'center',
              transform: `translateY(${interpolate(enterSpring, [0, 1], [30, 0])}px)`,
              opacity: enterSpring,
              zIndex: 30,
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 10 }}>
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
                  fontSize: 15,
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
                fontSize: 20,
                fontFamily: THEME.fontSans,
                color: '#E2E8F0',
                lineHeight: 1.4,
                fontWeight: 600,
              }}
            >
              {activeScene.id === 'ad_deprem' &&
                'Şebekeler çöktüğünde bile BLE radarı ve akustik arama, enkaz altında yerinizi kurtarma ekiplerine gösterir.'}
              {activeScene.id === 'ad_gps' &&
                'İnternet veya baz istasyonu olmadan, doğrudan GPS uydularıyla sahrada adım adım rotanızı çizer.'}
              {activeScene.id === 'ad_autosos' &&
                'Kaza veya bayılma durumunda hareketsiz kaldığınız an otomatik olarak yüksek sesli siren çalar ve ekibinize SMS gönderir.'}
              {activeScene.id === 'ad_ilkyardim' &&
                'Panik anında ne yapacağınızı şaşırdığınızda turnike, kanama ve dağcılık düğümlerini çevrimdışı adım adım gösterir.'}
            </div>
          </div>
        </AbsoluteFill>
      )}

      {/* ==================================================================== */}
      {/* 3. CALL TO ACTION / OUTRO (High Conversion Finish)                   */}
      {/* ==================================================================== */}
      {activeScene.id === 'ad_outro' && (
        <AbsoluteFill
          style={{
            backgroundColor: '#07090E',
            justifyContent: 'center',
            alignItems: 'center',
            flexDirection: 'column',
            padding: '0 60px',
            textAlign: 'center',
          }}
        >
          {/* Ambient Rim Light */}
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

          {/* App Store and Google Play Download Badges */}
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
