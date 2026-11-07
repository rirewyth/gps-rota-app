import React, { useState, useEffect } from 'react';
import { 
  Crosshair, 
  X, 
  Maximize2, 
  Minimize2, 
  Radio, 
  Camera, 
  Zap, 
  Compass, 
  Eye, 
  Flame, 
  Sparkles,
  Layers,
  ZoomIn,
  ZoomOut,
  Target,
  RotateCw,
  Expand,
  Shrink
} from 'lucide-react';
import { MapContainer, TileLayer, useMap } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { soundFx } from '../audio';

// Helper to ensure Leaflet recalculates dimensions immediately inside modal/overlay
function MapResizer({ zoomLevel, center }) {
  const map = useMap();
  useEffect(() => {
    map.invalidateSize();
    if (center && center[0] && center[1]) {
      map.setView(center, zoomLevel, { animate: false });
    }
    const t1 = setTimeout(() => {
      map.invalidateSize();
      if (center && center[0] && center[1]) {
        map.setView(center, zoomLevel, { animate: false });
      }
    }, 60);
    const t2 = setTimeout(() => {
      map.invalidateSize();
    }, 300);
    return () => {
      clearTimeout(t1);
      clearTimeout(t2);
    };
  }, [map, center, zoomLevel]);
  return null;
}

export default function UavThermalOverlay({
  targetUser = null,
  orbitAngle = 0,
  onClose = () => {},
  altitude = 450,
  speed = 110
}) {
  // Default to crystal-clear high-definition optical satellite imagery
  const [thermalMode, setThermalMode] = useState('NATURAL_EO'); // NATURAL_EO, WHITE_HOT, GREEN_NVG, FLIR_AMBER
  const [satelliteSource, setSatelliteSource] = useState('google'); // 'google' | 'esri'
  const [zoomLevel, setZoomLevel] = useState(15); // 15 = 0.5X (Geniş Açı), 16 = 1X, 17 = 2X, 18 = 4X
  const [enableRotation, setEnableRotation] = useState(true); // User requested camera rotation with drone
  const [isWidescreen, setIsWidescreen] = useState(false); // Theater / Expanded mode
  const [isMinimized, setIsMinimized] = useState(false);
  const [laserDistance, setLaserDistance] = useState(1280);

  // Micro jitter for military telemetry
  useEffect(() => {
    const interval = setInterval(() => {
      setLaserDistance((prev) => 1250 + Math.round(Math.sin(Date.now() / 800) * 20));
    }, 200);
    return () => clearInterval(interval);
  }, []);

  if (!targetUser) return null;

  const targetName = targetUser.name || 'KAZAZEDE';
  const targetLat = targetUser.lat ? targetUser.lat.toFixed(5) : '38.43000';
  const targetLng = targetUser.lng ? targetUser.lng.toFixed(5) : '27.18000';
  const targetCoords = (targetUser.coords && targetUser.coords.length === 2 && !isNaN(targetUser.coords[0]))
    ? targetUser.coords
    : (targetUser.lat && targetUser.lng ? [targetUser.lat, targetUser.lng] : [38.384, 27.032]);

  // High-clarity filter definitions that preserve satellite sharpness
  const modeStyles = {
    NATURAL_EO: {
      mapFilter: 'contrast(115%) saturate(120%) brightness(105%)',
      tint: 'border-cyan-400 text-cyan-200',
      crosshair: '#00E5FF',
      hudColor: '#00E5FF',
      tag: 'OPTİK: NET HD UYDU (GÜNDÜZ)',
      heatBlip: 'bg-cyan-400 shadow-[0_0_15px_#00E5FF]'
    },
    WHITE_HOT: {
      mapFilter: 'grayscale(100%) invert(100%) contrast(180%) brightness(115%)',
      tint: 'border-slate-300 text-slate-100',
      crosshair: '#FFFFFF',
      hudColor: '#F8FAFC',
      tag: 'FLIR: WHITE-HOT (KIZILÖTESİ)',
      heatBlip: 'bg-white shadow-[0_0_15px_#FFFFFF]'
    },
    GREEN_NVG: {
      mapFilter: 'grayscale(100%) sepia(100%) hue-rotate(80deg) saturate(350%) contrast(150%) brightness(105%)',
      tint: 'border-emerald-500 text-emerald-300',
      crosshair: '#10B981',
      hudColor: '#34D399',
      tag: 'NVG: ASKERİ GECE GÖRÜŞÜ',
      heatBlip: 'bg-emerald-400 shadow-[0_0_15px_#10B981]'
    },
    FLIR_AMBER: {
      mapFilter: 'contrast(190%) saturate(300%) hue-rotate(320deg) brightness(110%)',
      tint: 'border-[#FF4D26] text-[#FF6E40]',
      crosshair: '#FF4D26',
      hudColor: '#FF6E40',
      tag: 'TERMAL ANOMALİ (IRONBOW)',
      heatBlip: 'bg-red-500 shadow-[0_0_15px_#EF4444]'
    }
  };

  const currentMode = modeStyles[thermalMode] || modeStyles.NATURAL_EO;
  const currentHeading = Math.round(orbitAngle % 360);

  if (isMinimized) {
    return (
      <div className="absolute bottom-16 right-[380px] z-[500] select-none font-tactical">
        <div 
          onClick={() => setIsMinimized(false)}
          className="bg-[#02050D] border border-cyan-500 text-cyan-400 px-3 py-1.5 flex items-center gap-2 cursor-pointer shadow-[0_0_15px_rgba(0,229,255,0.4)] hover:bg-cyan-950/60"
        >
          <Radio className="w-3.5 h-3.5 text-cyan-400 animate-pulse" />
          <span className="text-[10px] font-bold">🛰️ İHA-1 GENİŞ AÇI: AKTİF ({targetName})</span>
          <Maximize2 className="w-3 h-3 text-slate-400 hover:text-white" />
        </div>
      </div>
    );
  }

  // Widescreen container sizing
  const containerWidthClass = isWidescreen 
    ? 'fixed inset-x-12 bottom-12 top-20 z-[9999] w-auto max-w-5xl mx-auto' 
    : 'absolute bottom-14 right-[380px] z-[500] w-[560px]';

  const viewportHeightClass = isWidescreen ? 'h-[calc(100%-80px)]' : 'h-[320px]';

  const tileUrl = satelliteSource === 'google'
    ? 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}'
    : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  return (
    <div className={`${containerWidthClass} select-none font-tactical shadow-[0_0_50px_rgba(0,0,0,0.98)] transition-all duration-300`}>
      
      {/* 1. FLIR Top Control Bar */}
      <div className="h-9 bg-[#030712] border-t-2 border-x-2 border-cyan-500/70 px-3 flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <span className="w-2.5 h-2.5 rounded-full bg-red-500 animate-ping" />
          <span className="text-xs font-black text-white tracking-widest uppercase">
            🛰️ İHA GENİŞ AÇI VİZÖRÜ: <span className="text-cyan-400">BAYRAKTAR SAR-1</span>
          </span>
          <span className="text-[10px] text-amber-400 font-mono bg-black/50 px-1.5 border border-amber-500/40">
            HEDEF: {targetName.toUpperCase()}
          </span>
        </div>

        <div className="flex items-center gap-2">
          {/* Toggle Camera Rotation with Drone */}
          <button
            onClick={() => {
              setEnableRotation(!enableRotation);
              soundFx.playSelect();
            }}
            className={`px-2 py-0.5 border text-[9px] font-mono flex items-center gap-1 cursor-pointer transition-colors ${
              enableRotation 
                ? 'border-[#00E5FF] bg-cyan-950/80 text-[#00E5FF] font-bold' 
                : 'border-slate-700 text-slate-400 hover:text-white'
            }`}
            title="Kameranın drone ile birlikte dönmesini aç / kapat"
          >
            <RotateCw className={`w-3 h-3 ${enableRotation ? 'animate-spin' : ''}`} />
            <span>DRONE İLE DÖNÜŞ: {enableRotation ? 'AÇIK' : 'KUZEY'}</span>
          </button>

          {/* Toggle Satellite Tile Engine */}
          <button
            onClick={() => {
              setSatelliteSource(satelliteSource === 'google' ? 'esri' : 'google');
              soundFx.playSelect();
            }}
            className="px-2 py-0.5 border border-cyan-500/50 bg-black text-[9px] font-mono text-cyan-300 hover:bg-cyan-950 cursor-pointer"
            title="Uydu sağlayıcısını değiştir (Google / Esri)"
          >
            {satelliteSource === 'google' ? '🌐 GOOGLE UYDU' : '🌐 ESRI UYDU'}
          </button>

          {/* Toggle Widescreen Theater Mode */}
          <button
            onClick={() => {
              setIsWidescreen(!isWidescreen);
              soundFx.playSelect();
            }}
            className="text-slate-400 hover:text-cyan-400 p-1 cursor-pointer"
            title={isWidescreen ? 'Normal Boyut' : 'Geniş Ekran Modu'}
          >
            {isWidescreen ? <Shrink className="w-4 h-4" /> : <Expand className="w-4 h-4" />}
          </button>

          <button
            onClick={() => setIsMinimized(true)}
            className="text-slate-400 hover:text-white p-1 cursor-pointer"
            title="Simge Durumuna Küçült"
          >
            <Minimize2 className="w-3.5 h-3.5" />
          </button>
          
          <button
            onClick={onClose}
            className="text-slate-400 hover:text-red-400 p-1 cursor-pointer"
            title="İHA Görevini Kapat"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* 2. Main Camera Viewport (ROTATING HIGH-RES SATELLITE CANVAS) */}
      <div className={`relative ${viewportHeightClass} w-full bg-[#02050D] border-x-2 border-cyan-500/40 overflow-hidden flex items-center justify-center`}>
        
        {/* ROTATING SATELLITE WRAPPER - Centered & oversized (240%) so 360° orbit rotation never exposes edges */}
        <div 
          className="pointer-events-none transition-transform duration-300 ease-out"
          style={{ 
            position: 'absolute',
            top: '50%',
            left: '50%',
            width: '240%',
            height: '240%',
            transform: `translate(-50%, -50%) rotate(${enableRotation ? -orbitAngle : 0}deg)`,
            transformOrigin: 'center center',
            filter: currentMode.mapFilter 
          }}
        >
          <MapContainer
            center={targetCoords}
            zoom={zoomLevel}
            zoomControl={false}
            attributionControl={false}
            dragging={false}
            scrollWheelZoom={false}
            doubleClickZoom={false}
            touchZoom={false}
            style={{ width: '100%', height: '100%' }}
          >
            <TileLayer
              key={tileUrl}
              url={tileUrl}
              maxZoom={20}
            />
            <MapResizer zoomLevel={zoomLevel} center={targetCoords} />
          </MapContainer>
        </div>

        {/* Tactical Dark Vignette & Edge Shadow */}
        <div className="absolute inset-0 z-10 pointer-events-none shadow-[inset_0_0_60px_rgba(0,0,0,0.85)]" />

        {/* CRT Scanline & Grain Texture Overlay */}
        <div className="absolute inset-0 z-10 pointer-events-none opacity-20 bg-[linear-gradient(rgba(18,16,16,0)_50%,rgba(0,0,0,0.35)_50%)] bg-[length:100%_4px]" />

        {/* 4 Corner Reticle Brackets */}
        <div className="absolute top-2.5 left-2.5 w-5 h-5 border-t-2 border-l-2 z-20 pointer-events-none" style={{ borderColor: currentMode.crosshair }} />
        <div className="absolute top-2.5 right-2.5 w-5 h-5 border-t-2 border-r-2 z-20 pointer-events-none" style={{ borderColor: currentMode.crosshair }} />
        <div className="absolute bottom-2.5 left-2.5 w-5 h-5 border-b-2 border-l-2 z-20 pointer-events-none" style={{ borderColor: currentMode.crosshair }} />
        <div className="absolute bottom-2.5 right-2.5 w-5 h-5 border-b-2 border-r-2 z-20 pointer-events-none" style={{ borderColor: currentMode.crosshair }} />

        {/* Compass Heading Tape along the Top (Synced with Drone's Orbit Angle) */}
        <div className="absolute top-1.5 left-1/2 transform -translate-x-1/2 z-20 bg-black/75 px-3 py-0.5 border text-[9.5px] font-mono font-bold flex items-center gap-3 pointer-events-none" style={{ borderColor: currentMode.crosshair, color: currentMode.hudColor }}>
          <span className="opacity-40">{Math.round((currentHeading - 30 + 360) % 360)}</span>
          <span className="opacity-70">{Math.round((currentHeading - 15 + 360) % 360)}</span>
          <span className="text-red-400 font-bold border-b-2 border-red-500 px-1.5">▲ {currentHeading}°</span>
          <span className="opacity-70">{Math.round((currentHeading + 15) % 360)}</span>
          <span className="opacity-40">{Math.round((currentHeading + 30) % 360)}</span>
        </div>

        {/* Center Target Lock-on Box & Thermal Heat Signature */}
        <div className="relative z-20 w-32 h-32 border border-dashed flex items-center justify-center animate-pulse pointer-events-none" style={{ borderColor: currentMode.crosshair }}>
          
          {/* Tactical Crosshair */}
          <Crosshair className="w-12 h-12 opacity-85" style={{ color: currentMode.crosshair }} />
          
          {/* Hot Thermal Blip on Target */}
          <div className={`absolute w-4 h-4 rounded-full ${currentMode.heatBlip} animate-ping opacity-75`} />
          <div className={`absolute w-2 h-2 rounded-full ${currentMode.heatBlip}`} />

          {/* Target Identity Tag */}
          <div className="absolute -top-4.5 bg-black/90 px-2 py-0.5 border text-[9px] font-mono font-bold tracking-wider" style={{ borderColor: currentMode.crosshair, color: currentMode.hudColor }}>
            KİLİT: {targetName.substring(0, 12).toUpperCase()}
          </div>
          
          {/* Acquisition Confidence Tag */}
          <div className="absolute -bottom-4.5 bg-black/90 px-1.5 border text-[8px] font-mono text-emerald-400 font-bold" style={{ borderColor: currentMode.crosshair }}>
            T-ACQ 99.9% (KİLİTLİ)
          </div>
        </div>

        {/* HUD Overlay - Top Left (Gimbal & Flight Telemetry) */}
        <div className="absolute top-8 left-3 z-20 font-mono text-[9.5px] leading-snug bg-black/70 px-2 py-1 border border-black/50 pointer-events-none" style={{ color: currentMode.hudColor }}>
          <div>DRONE AÇISI: {currentHeading}° YAW</div>
          <div>AGL: {altitude}m | HIZ: {speed}km/s</div>
          <div>GÖRÜŞ AÇISI: {zoomLevel === 15 ? 'GENİŞ (0.5X / ~4 KM)' : zoomLevel === 16 ? 'STANDART (1.0X)' : zoomLevel === 17 ? 'YAKIN (2.0X)' : 'DETAY (4.0X)'}</div>
        </div>

        {/* HUD Overlay - Top Right (Laser & Recording) */}
        <div className="absolute top-8 right-3 z-20 font-mono text-[9.5px] text-right leading-snug bg-black/70 px-2 py-1 border border-black/50 pointer-events-none" style={{ color: currentMode.hudColor }}>
          <div className="text-red-400 font-bold flex items-center justify-end gap-1">
            <span className="w-1.5 h-1.5 rounded-full bg-red-500 animate-ping" />
            HD RECON REC
          </div>
          <div>LAZER TELEMETRE: {laserDistance}m</div>
          <div>HEDEF RAKIMI: {targetUser.altitude || 160}m</div>
        </div>

        {/* HUD Overlay - Bottom Left (Target Coordinates) */}
        <div className="absolute bottom-2.5 left-3 z-20 font-mono text-[9.5px] bg-black/80 px-2 py-0.5 border border-black/60 pointer-events-none" style={{ color: currentMode.hudColor }}>
          <div className="font-bold">{targetLat}°N, {targetLng}°E</div>
        </div>

        {/* HUD Overlay - Bottom Right (Camera Mode Tag) */}
        <div className="absolute bottom-2.5 right-3 z-20 font-mono text-[9.5px] text-right bg-black/80 px-2 py-0.5 border border-black/60 pointer-events-none" style={{ color: currentMode.hudColor }}>
          <div className="font-bold uppercase tracking-wider">{currentMode.tag}</div>
        </div>

      </div>

      {/* 3. FLIR Bottom Controls & Palette & FOV Switcher */}
      <div className="h-10 bg-[#030712] border-b-2 border-x-2 border-cyan-500/60 px-3 flex items-center justify-between text-[9.5px] font-mono">
        
        {/* Camera Palette Selector */}
        <div className="flex items-center gap-1.5">
          <button
            onClick={() => {
              setThermalMode('NATURAL_EO');
              soundFx.playSelect();
            }}
            className={`px-2 py-1 border cursor-pointer transition-colors ${
              thermalMode === 'NATURAL_EO' ? 'bg-[#00E5FF] text-black border-cyan-300 font-bold shadow-[0_0_10px_#00E5FF]' : 'border-slate-700 text-slate-300 hover:text-white'
            }`}
          >
            NET OPTİK (HD)
          </button>
          <button
            onClick={() => {
              setThermalMode('WHITE_HOT');
              soundFx.playSelect();
            }}
            className={`px-2 py-1 border cursor-pointer transition-colors ${
              thermalMode === 'WHITE_HOT' ? 'bg-slate-200 text-black border-white font-bold' : 'border-slate-700 text-slate-400 hover:text-white'
            }`}
          >
            FLIR BEYAZ
          </button>
          <button
            onClick={() => {
              setThermalMode('GREEN_NVG');
              soundFx.playSelect();
            }}
            className={`px-2 py-1 border cursor-pointer transition-colors ${
              thermalMode === 'GREEN_NVG' ? 'bg-emerald-600 text-white border-emerald-400 font-bold' : 'border-slate-700 text-slate-400 hover:text-white'
            }`}
          >
            NVG GECE
          </button>
          <button
            onClick={() => {
              setThermalMode('FLIR_AMBER');
              soundFx.playSelect();
            }}
            className={`px-2 py-1 border cursor-pointer transition-colors ${
              thermalMode === 'FLIR_AMBER' ? 'bg-[#FF4D26] text-white border-red-500 font-bold' : 'border-slate-700 text-slate-400 hover:text-white'
            }`}
          >
            TERMAL
          </button>
        </div>

        {/* FOV & Zoom Switcher (Geniş Açıdan Dar Açıya) */}
        <div className="flex items-center gap-1 border border-cyan-500/40 px-2 py-0.5 bg-[#02050D]">
          <span className="text-slate-400 text-[8.5px] font-bold">GÖRÜŞ ALANI:</span>
          {[
            { z: 15, label: '0.5X GENİŞ' },
            { z: 16, label: '1X' },
            { z: 17, label: '2X' },
            { z: 18, label: '4X KİLİT' }
          ].map((item) => (
            <button
              key={item.z}
              onClick={() => {
                setZoomLevel(item.z);
                soundFx.playSelect();
              }}
              className={`px-1.5 py-0.5 cursor-pointer font-bold transition-colors ${
                zoomLevel === item.z ? 'text-[#00E5FF] bg-cyan-950/80 border-b border-cyan-400' : 'text-slate-400 hover:text-white'
              }`}
            >
              {item.label}
            </button>
          ))}
        </div>

      </div>

    </div>
  );
}
