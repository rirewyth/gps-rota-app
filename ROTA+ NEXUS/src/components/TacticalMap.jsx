import React, { useState, useEffect, useRef, useMemo } from 'react';
import { 
  MapContainer, 
  TileLayer, 
  Marker, 
  Popup, 
  Circle, 
  Polyline,
  Polygon,
  Tooltip,
  useMap, 
  useMapEvents 
} from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { 
  Compass, 
  Crosshair, 
  MapPin, 
  Battery, 
  Mountain, 
  Eye, 
  Heart, 
  PhoneCall,
  Zap,
  Activity,
  Radio,
  Radar,
  Grid,
  Footprints,
  Navigation2,
  AlertTriangle,
  Route,
  ShieldAlert,
  PlaneTakeoff,
  Shield,
  Plus,
  Check,
  Trash2,
  X
} from 'lucide-react';
import { soundFx } from '../audio';
import { 
  getSignalFreshness, 
  getUserBreadcrumbTrail, 
  generateTacticalSearchGrid, 
  analyzeLocation,
  calculateSearchZoneProbability,
  DEFAULT_HAZARD_ZONES,
  interpolateUserTrack,
  calculateDistanceMeters,
  calculateEtaMinutes
} from '../utils/geoAnalysis';

// --- CUSTOM TACTICAL AVATAR MARKERS ---
const createTacticalAvatarMarker = (user, isSelected = false) => {
  const isEmergency = Boolean(user.isFreshSos || user.isTestSos);
  const isArchive = Boolean(user.isArchiveSos && !isEmergency);
  const signal = getSignalFreshness(user);
  const isLostSignal = signal.isLost && !isEmergency;

  const color = isEmergency 
    ? '#EF4444' 
    : (isSelected 
      ? '#00E5FF' 
      : (isLostSignal
        ? '#F59E0B'
        : (isArchive 
          ? '#D97706' 
          : (user.role === 'KOMUTAN' ? '#FF8A00' : '#FF4D26'))));
  
  const avatar = user.avatar;
  const initials = user.initials || 'RP';
  const displayName = user.name ? user.name.split(' ')[0] : 'Kullanıcı';

  const avatarHtml = avatar 
    ? `<img src="${avatar}" style="width: 100%; height: 100%; object-fit: cover; border-radius: 0px;" />`
    : `<span style="font-weight: 800; font-size: 11px; letter-spacing: -0.5px; color: ${color}; font-family: monospace;">${initials}</span>`;

  return L.divIcon({
    className: 'tactical-user-marker',
    html: `
      <div style="position: relative; width: 44px; height: 44px; display: flex; align-items: center; justify-content: center; cursor: pointer;">
        ${isEmergency ? `
          <div style="position: absolute; inset: -14px; background: rgba(239, 68, 68, 0.45); border-radius: 50%; animation: ping 1.2s cubic-bezier(0, 0, 0.2, 1) infinite;"></div>
          <div style="position: absolute; inset: -6px; background: rgba(239, 68, 68, 0.65); border-radius: 50%; animation: pulse 1.8s ease-in-out infinite;"></div>
        ` : isSelected ? `
          <div style="position: absolute; inset: -5px; border: 1.5px dashed #00E5FF; border-radius: 0px; animation: spin 10s linear infinite;"></div>
        ` : isLostSignal ? `
          <div style="position: absolute; inset: -3px; border: 1px dashed #F59E0B; border-radius: 0px; opacity: 0.8;"></div>
        ` : `
          <div style="position: absolute; inset: 2px; background: ${color}; opacity: 0.12; border-radius: 0px;"></div>
        `}
        <div style="
          position: relative; 
          width: 34px; 
          height: 34px; 
          background: #02050D; 
          border: 1.5px ${isLostSignal ? 'dashed' : 'solid'} ${color}; 
          border-radius: 0px; 
          display: flex; 
          align-items: center; 
          justify-content: center; 
          box-shadow: 0 0 14px ${color}88, 0 4px 10px rgba(0,0,0,0.9);
          overflow: hidden;
        ">
          ${avatarHtml}
        </div>
        <div style="
          position: absolute; 
          bottom: -15px; 
          background: rgba(2, 5, 13, 0.95); 
          border: 1px solid ${color}cc; 
          color: #F8FAFC; 
          font-size: 8.5px; 
          font-weight: 800; 
          padding: 0px 5px; 
          border-radius: 0px; 
          white-space: nowrap;
          box-shadow: 0 2px 6px rgba(0,0,0,0.85);
          max-width: 95px;
          overflow: hidden;
          text-overflow: ellipsis;
          font-family: monospace;
          letter-spacing: 0.05em;
        ">
          ${isEmergency ? '🚨 SOS' : isLostSignal ? `📡 LKP (${displayName})` : displayName}
        </div>
      </div>
    `,
    iconSize: [44, 44],
    iconAnchor: [22, 22],
    popupAnchor: [0, -22]
  });
};

// --- CUSTOM TACTICAL VECTOR MIDPOINT BADGE ---
const createTacticalVectorBadge = (comrade) => {
  return L.divIcon({
    className: 'tactical-vector-badge',
    html: `
      <div style="
        background: rgba(2, 6, 18, 0.95);
        border: 1px solid #00E5FF;
        color: #00E5FF;
        padding: 2px 6px;
        font-family: 'Share Tech Mono', monospace;
        font-size: 9px;
        font-weight: bold;
        letter-spacing: 0.05em;
        white-space: nowrap;
        box-shadow: 0 0 10px rgba(0, 229, 255, 0.4);
        display: flex;
        align-items: center;
        gap: 4px;
        transform: translate(-50%, -50%);
        pointer-events: none;
      ">
        <span style="color: #FF4D26;">➔</span>
        <span>${comrade.distFormatted}</span>
        <span style="color: #F59E0B;">(${comrade.bearing.short})</span>
        <span style="color: #94A3B8;">~${comrade.estWalkMinutes}dk</span>
      </div>
    `,
    iconSize: [0, 0],
    iconAnchor: [0, 0]
  });
};

// --- CUSTOM UAV DRONE IN-FLIGHT ICON ---
const createUavMarkerIcon = (angle = 0) => {
  return L.divIcon({
    className: 'tactical-uav-marker',
    html: `
      <div style="
        width: 40px; 
        height: 40px; 
        display: flex; 
        align-items: center; 
        justify-content: center;
        transform: rotate(${angle}deg);
        filter: drop-shadow(0 0 10px #00E5FF);
      ">
        <svg viewBox="0 0 24 24" width="34" height="34" fill="#00E5FF">
          <path d="M12 2L9 9H2L7 13L5 21L12 17L19 21L17 13L22 9H15L12 2Z" />
        </svg>
      </div>
    `,
    iconSize: [40, 40],
    iconAnchor: [20, 20]
  });
};

// --- CUSTOM DISPATCHED RESCUE TEAM MARKER ICON ---
const createDispatchedTeamMarkerIcon = (team) => {
  const primaryEquip = (team.equipment && team.equipment[0]) ? team.equipment[0] : 'SAR';
  const color = team.color || '#00E5FF';

  return L.divIcon({
    className: 'tactical-team-marker',
    html: `
      <div style="
        display: flex;
        flex-direction: column;
        align-items: center;
        transform: translate(-50%, -100%);
      ">
        <div style="
          background: #02050D;
          border: 1.5px solid ${color};
          padding: 2px 6px;
          border-radius: 2px;
          box-shadow: 0 0 12px ${color};
          display: flex;
          align-items: center;
          gap: 5px;
          font-family: monospace;
          white-space: nowrap;
        ">
          <span style="display: inline-block; width: 6px; height: 6px; border-radius: 50%; background: ${color};"></span>
          <span style="font-weight: 900; font-size: 9.5px; color: #FFFFFF; letter-spacing: 0.5px;">${team.shortName || team.name}</span>
          <span style="font-size: 8px; color: #F59E0B; background: #000; padding: 1px 4px; border: 0.5px solid #F59E0B; font-weight: bold;">
            [${primaryEquip}]
          </span>
        </div>
        <div style="
          width: 0; 
          height: 0; 
          border-left: 5px solid transparent;
          border-right: 5px solid transparent;
          border-top: 6px solid ${color};
        "></div>
      </div>
    `,
    iconSize: [0, 0],
    iconAnchor: [0, 0]
  });
};

// --- CUSTOM INCIDENT STORYLINE WAYPOINT ICON ---
const createStorylineWaypointIcon = (step) => {
  const isCompleted = step.status === 'completed';
  const isInProgress = step.status === 'in_progress';
  const color = isCompleted ? '#10B981' : isInProgress ? '#F59E0B' : '#64748B';

  return L.divIcon({
    className: 'tactical-storyline-marker',
    html: `
      <div style="
        display: flex;
        align-items: center;
        gap: 4px;
        transform: translate(-50%, -50%);
        font-family: monospace;
      ">
        <div style="
          width: 22px;
          height: 22px;
          border-radius: 50%;
          background: #02050D;
          border: 2px solid ${color};
          color: ${color};
          display: flex;
          align-items: center;
          justify-content: center;
          font-weight: 900;
          font-size: 10px;
          box-shadow: 0 0 10px ${color};
        ">
          ${step.stepNumber || '•'}
        </div>
        <div style="
          background: rgba(2, 5, 13, 0.9);
          border: 1px solid ${color};
          padding: 1px 5px;
          font-size: 8.5px;
          color: #FFF;
          white-space: nowrap;
          box-shadow: 0 0 6px rgba(0,0,0,0.8);
        ">
          <span style="color: #F59E0B;">[${step.time}]</span> ${step.title.substring(0, 18)}
        </div>
      </div>
    `,
    iconSize: [0, 0],
    iconAnchor: [0, 0]
  });
};

// --- CUSTOM TEAM DIRECTED TARGET WAYPOINT ICON ---
const createTeamTargetIcon = (team, distanceMeters, etaMin) => {
  const color = team.color || '#00E5FF';
  return L.divIcon({
    className: 'tactical-team-target-marker',
    html: `
      <div style="
        display: flex;
        flex-direction: column;
        align-items: center;
        transform: translate(-50%, -50%);
        font-family: monospace;
      ">
        <div style="
          width: 26px;
          height: 26px;
          border-radius: 50%;
          border: 2px dashed ${color};
          display: flex;
          align-items: center;
          justify-content: center;
          background: rgba(2, 5, 13, 0.85);
          box-shadow: 0 0 14px ${color};
        ">
          <div style="width: 8px; height: 8px; border-radius: 50%; background: ${color};"></div>
        </div>
        <div style="
          background: #02050D;
          border: 1px solid ${color};
          padding: 2px 6px;
          color: #FFF;
          font-size: 8.5px;
          white-space: nowrap;
          margin-top: 3px;
          box-shadow: 0 0 8px rgba(0,0,0,0.9);
        ">
          <span style="color: ${color}; font-weight: bold;">🎯 ${team.shortName || team.name}</span>
          <span style="color: #F59E0B;"> (~${etaMin}dk / ${distanceMeters}m)</span>
        </div>
      </div>
    `,
    iconSize: [0, 0],
    iconAnchor: [0, 0]
  });
};

// Map Layer Configurations
const MAP_LAYERS = {
  TOPO_ESRI: {
    id: 'TOPO_ESRI',
    name: 'ESRI Topo & Arazi',
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
    attribution: 'Esri, DeLorme, USGS, NPS',
    maxZoom: 19
  },
  OPENTOPO: {
    id: 'OPENTOPO',
    name: 'OpenTopo (İzolips & Dağ)',
    url: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
    attribution: '© OpenTopoMap',
    maxZoom: 17
  },
  SATELLITE_HYBRID: {
    id: 'SATELLITE_HYBRID',
    name: 'Uydu Hibrit',
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    overlayUrl: 'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
    attribution: 'Esri, Maxar',
    maxZoom: 19
  },
  TACTICAL_DARK: {
    id: 'TACTICAL_DARK',
    name: 'Taktik Karanlık Gece',
    url: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
    attribution: '© CARTO',
    maxZoom: 19
  }
};

// Map Camera Controller
function MapCameraController({ targetCoords }) {
  const map = useMap();
  useEffect(() => {
    if (!targetCoords) return;
    const coords = Array.isArray(targetCoords) ? targetCoords : targetCoords.coords;
    const zoomLevel = (!Array.isArray(targetCoords) && targetCoords.zoom) ? targetCoords.zoom : 14;
    if (coords && coords[0] && coords[1]) {
      map.flyTo(coords, zoomLevel, {
        animate: true,
        duration: 1.2,
        easeLinearity: 0.25
      });
    }
  }, [targetCoords, map]);
  return null;
}

// Coordinate & Directing Map Interactions Tracker
function MapInteractionsTracker({ onCoordsChange, onMapClick, isDirecting }) {
  useMapEvents({
    mousemove(e) {
      onCoordsChange([e.latlng.lat, e.latlng.lng]);
    },
    click(e) {
      if (isDirecting && onMapClick) {
        onMapClick([e.latlng.lat, e.latlng.lng]);
      }
    }
  });
  return null;
}

export default function TacticalMap({
  users = [],
  selectedUser = null,
  onSelectUser = () => {},
  targetCoords = null,
  activeSosUser = null,
  activeLayer = 'TOPO_ESRI',
  uavTargetUser = null,
  uavOrbitAngle = 0,
  hazardZones = DEFAULT_HAZARD_ZONES,
  playbackProgress = 1.0,
  onCenterTarget = () => {},
  smartSearchCone = null,
  showSmartCone = true,
  dispatchedTeams = [],
  showDispatchedTeams = true,
  incidentStoryline = [],
  showStoryline = true,
  directingTeamId = null,
  onStartDirecting = () => {},
  onMapDirectTeam = () => {},
  onCancelDirecting = () => {},
  onUpdateTeamCoords = () => {},
  onRemoveTeam = () => {},
  onDispatchToCasualty = () => {},
  onCompleteTransit = () => {},
  onOpenAddTeam = () => {}
}) {
  const [mouseCoords, setMouseCoords] = useState([38.43, 27.18]);
  const [enableRadarEffect, setEnableRadarEffect] = useState(true);
  const [showBreadcrumbs, setShowBreadcrumbs] = useState(true);
  const [showSarVectors, setShowSarVectors] = useState(true);
  const [showSarGrid, setShowSarGrid] = useState(false);
  const [showHazards, setShowHazards] = useState(true);
  const [enableSmartCone, setEnableSmartCone] = useState(true);
  const [enableTeams, setEnableTeams] = useState(true);
  const [enableStoryline, setEnableStoryline] = useState(true);
  const markerRefs = useRef({});

  const directingTeam = useMemo(() => {
    return dispatchedTeams.find((t) => t.id === directingTeamId) || null;
  }, [dispatchedTeams, directingTeamId]);

  const mappedUsers = useMemo(() => users.filter((u) => u.hasCoords && u.coords), [users]);
  const currentLayerConfig = MAP_LAYERS[activeLayer] || MAP_LAYERS.TOPO_ESRI;

  // Selected or active user's tactical analysis
  const focalUser = selectedUser || activeSosUser || null;
  const analysis = useMemo(() => {
    if (!focalUser) return null;
    return analyzeLocation(focalUser, users);
  }, [focalUser, users]);

  // Breadcrumb Trail for selected user (Feature 1)
  const breadcrumbTrail = useMemo(() => {
    if (!focalUser || !showBreadcrumbs) return [];
    return getUserBreadcrumbTrail(focalUser);
  }, [focalUser, showBreadcrumbs]);

  // SAR Tactical Search Grid (Feature 1)
  const sarGrid = useMemo(() => {
    return generateTacticalSearchGrid();
  }, []);

  // LKP Probability Search Circle for Offline / Lost Signal Users (Feature 3)
  const lkpProbability = useMemo(() => {
    if (!focalUser) return null;
    const signal = getSignalFreshness(focalUser);
    if (!signal.isLost) return null;
    return calculateSearchZoneProbability(focalUser);
  }, [focalUser]);

  // Compute live orbiting UAV position
  const uavPosition = useMemo(() => {
    if (!uavTargetUser || !uavTargetUser.hasCoords) return null;
    const rad = (uavOrbitAngle * Math.PI) / 180;
    const orbitLat = uavTargetUser.lat + 0.0055 * Math.cos(rad);
    const orbitLng = uavTargetUser.lng + 0.0075 * Math.sin(rad);
    return [orbitLat, orbitLng];
  }, [uavTargetUser, uavOrbitAngle]);

  // Handle detailed cockpit selection
  const handleDirectSelect = (user) => {
    onSelectUser(user);
    if (user.hasCoords && user.coords) {
      onCenterTarget(user.coords, 15);
    }
    soundFx.playTargetLock();
  };

  return (
    <div className="relative w-full h-full bg-[#02040A] overflow-hidden select-none font-tactical">
      
      {/* 1. TACTICAL VIGNETTE & CORNER HUD RETICLES */}
      <div className="absolute inset-0 tactical-vignette z-20 pointer-events-none" />

      {/* 4 Corner Crosshairs */}
      <div className="absolute top-2 left-2 z-20 pointer-events-none text-cyan-500/50 text-[10px] font-mono flex items-center gap-1">
        <span>+</span><span>RETICLE_TL [38.5N]</span>
      </div>
      <div className="absolute top-2 right-2 z-20 pointer-events-none text-cyan-500/50 text-[10px] font-mono flex items-center gap-1">
        <span>RETICLE_TR [27.2E]</span><span>+</span>
      </div>
      <div className="absolute bottom-10 left-2 z-20 pointer-events-none text-cyan-500/40 text-[10px] font-mono">
        + SECTOR_WEST_GRID
      </div>
      <div className="absolute bottom-10 right-2 z-20 pointer-events-none text-cyan-500/40 text-[10px] font-mono">
        SECTOR_EAST_GRID +
      </div>

      {/* TACTICAL RADAR BEAM SWEEP EFFECT */}
      {enableRadarEffect && (
        <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-[700px] h-[700px] z-10 pointer-events-none overflow-hidden">
          <div className="radar-sweep-beam" />
          <div className="absolute inset-0 border border-cyan-500/10 rounded-full" />
          <div className="absolute inset-[15%] border border-cyan-500/10 rounded-full" />
          <div className="absolute inset-[30%] border border-cyan-500/10 rounded-full" />
        </div>
      )}

      {/* 2. TOP-CENTER FLOATING TACTICAL STATS & FEATURE TOGGLE BAR */}
      <div className="absolute top-3 left-1/2 transform -translate-x-1/2 z-[400] flex flex-col items-center gap-2 pointer-events-none">
        
        {/* HUD Box Group 1: Stats */}
        <div className="flex items-center gap-2 pointer-events-auto">
          {/* HUD Box 1: Toplam Kadro */}
          <div className="tactical-box px-3 py-1 flex items-center gap-2">
            <div className="text-[9px] text-cyan-400 font-bold tracking-widest uppercase">
              TOPLAM KADRO
            </div>
            <span className="text-sm font-black text-white font-mono">
              {users.length}
            </span>
          </div>

          {/* HUD Box 2: GPS Telemetri */}
          <div className="tactical-box px-3 py-1 flex items-center gap-2">
            <div className="text-[9px] text-emerald-400 font-bold tracking-widest uppercase flex items-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
              GPS TELEMETRİ
            </div>
            <span className="text-sm font-black text-[#00E5FF] font-mono">
              {mappedUsers.length}
            </span>
          </div>

          {/* HUD Box 3: Canlı Acil Durum */}
          <div className={`px-3 py-1 flex items-center gap-2 border ${
            activeSosUser 
              ? 'bg-red-950/90 border-red-500 shadow-[0_0_12px_rgba(239,68,68,0.5)] animate-pulse' 
              : 'tactical-box'
          }`}>
            <div className="text-[9px] font-bold tracking-widest uppercase flex items-center gap-1">
              {activeSosUser ? <span className="w-1.5 h-1.5 rounded-full bg-red-500 animate-ping" /> : null}
              <span className={activeSosUser ? 'text-red-200' : 'text-slate-400'}>CANLI ACİL SOS</span>
            </div>
            <span className={`text-sm font-black font-mono ${activeSosUser ? 'text-red-400' : 'text-slate-300'}`}>
              {activeSosUser ? '🚨 AKTİF' : '0'}
            </span>
          </div>
        </div>

        {/* HUD Box Group 2: Tactical Layer Feature Toggles (1-2-3-4-7 FEATURES) */}
        <div className="bg-[#02050D]/90 backdrop-blur-md border border-cyan-500/30 px-3 py-1 flex items-center gap-2 pointer-events-auto text-[10px] font-mono flex-wrap justify-center">
          
          {/* Toggle 1: Breadcrumb Trail (Fikir 1) */}
          <button
            onClick={() => {
              setShowBreadcrumbs(!showBreadcrumbs);
              soundFx.playSelect();
            }}
            className={`px-2 py-0.5 border flex items-center gap-1 transition-colors cursor-pointer ${
              showBreadcrumbs 
                ? 'border-[#FF4D26] bg-[#FF4D26]/20 text-[#FF6E40] font-bold' 
                : 'border-slate-800 text-slate-500 hover:text-slate-300'
            }`}
          >
            <Route className="w-3 h-3" />
            <span>ROTA: {showBreadcrumbs ? 'AÇIK' : 'KAPALI'}</span>
          </button>

          {/* Toggle 2: Tactical SAR Interception Vectors (Fikir 1) */}
          <button
            onClick={() => {
              setShowSarVectors(!showSarVectors);
              soundFx.playSelect();
            }}
            className={`px-2 py-0.5 border flex items-center gap-1 transition-colors cursor-pointer ${
              showSarVectors 
                ? 'border-[#00E5FF] bg-[#00E5FF]/20 text-[#00E5FF] font-bold' 
                : 'border-slate-800 text-slate-500 hover:text-slate-300'
            }`}
          >
            <Navigation2 className="w-3 h-3" />
            <span>İNTİKAL: {showSarVectors ? 'AÇIK' : 'KAPALI'}</span>
          </button>

          {/* Toggle 3: Military SAR 1km Grid (Fikir 1) */}
          <button
            onClick={() => {
              setShowSarGrid(!showSarGrid);
              soundFx.playSelect();
            }}
            className={`px-2 py-0.5 border flex items-center gap-1 transition-colors cursor-pointer ${
              showSarGrid 
                ? 'border-emerald-500 bg-emerald-500/20 text-emerald-400 font-bold' 
                : 'border-slate-800 text-slate-500 hover:text-slate-300'
            }`}
          >
            <Grid className="w-3 h-3" />
            <span>SAR IZGARA: {showSarGrid ? 'AÇIK' : 'KAPALI'}</span>
          </button>

          {/* Toggle 4: Geofence Hazards (Fikir 4) */}
          <button
            onClick={() => {
              setShowHazards(!showHazards);
              soundFx.playSelect();
            }}
            className={`px-2 py-0.5 border flex items-center gap-1 transition-colors cursor-pointer ${
              showHazards 
                ? 'border-red-500 bg-red-950/40 text-red-300 font-bold' 
                : 'border-slate-800 text-slate-500 hover:text-slate-300'
            }`}
          >
            <ShieldAlert className="w-3 h-3 text-red-400" />
            <span>TEHLİKE BÖLGELERİ: {showHazards ? 'AÇIK' : 'KAPALI'}</span>
          </button>

        </div>

      </div>

      {/* 2. TOP TARGETING NOTIFICATION BANNER */}
      {directingTeam && (
        <div className="absolute top-12 left-1/2 transform -translate-x-1/2 z-[500] bg-[#02050D]/95 border-2 border-amber-400 p-2.5 px-4 shadow-[0_0_30px_rgba(245,158,11,0.6)] flex items-center gap-3 animate-pulse font-tactical">
          <Compass className="w-5 h-5 text-amber-400 animate-spin" />
          <div>
            <div className="text-xs font-black text-amber-300 font-mono tracking-wider">
              🎯 HAREKAT YÖNLENDİRME: {directingTeam.name}
            </div>
            <div className="text-[10px] text-white font-mono">
              Harita üzerinde sevk etmek istediğiniz hedef mevkiye tıklayın (veya timi sürükleyin)
            </div>
          </div>
          <div className="flex items-center gap-2 ml-2">
            {focalUser?.coords && (
              <button
                onClick={() => onDispatchToCasualty(directingTeam.id)}
                className="bg-red-700 hover:bg-red-600 text-white font-mono text-[10px] px-2.5 py-1 font-bold cursor-pointer"
              >
                KAZAZEDEYE GÖNDER
              </button>
            )}
            <button
              onClick={onCancelDirecting}
              className="bg-slate-800 hover:bg-slate-700 text-slate-300 font-mono text-[10px] px-2 py-1 cursor-pointer"
            >
              İPTAL
            </button>
          </div>
        </div>
      )}

      {/* 3. FLOATING QUICK RESCUE TEAM DISPATCH BAR */}
      <div className="absolute top-14 left-3 z-[400] bg-[#02050D]/90 backdrop-blur-md border border-cyan-500/40 p-2 text-xs font-mono select-none w-72 shadow-[0_0_20px_rgba(0,0,0,0.8)]">
        <div className="flex items-center justify-between border-b border-cyan-500/30 pb-1 mb-1.5">
          <span className="text-[10px] font-bold text-cyan-300 flex items-center gap-1.5">
            <Shield className="w-3.5 h-3.5 text-cyan-400" />
            SEVK EDİLEN EKİPLER ({dispatchedTeams.length})
          </span>
          <button
            onClick={onOpenAddTeam}
            className="text-[9px] bg-cyan-950 hover:bg-cyan-900 border border-cyan-400 text-cyan-200 px-1.5 py-0.2 font-bold cursor-pointer flex items-center gap-0.5"
            title="Yeni arama kurtarma ekibi oluştur ve sevk et"
          >
            <Plus className="w-2.5 h-2.5" /> EKİP EKLE
          </button>
        </div>

        <div className="space-y-1 max-h-36 overflow-y-auto custom-scrollbar pr-1">
          {dispatchedTeams.length === 0 ? (
            <div className="text-[10px] text-slate-500 text-center py-2">
              Henüz sevk edilmiş ekip yok. (+ EKİP EKLE)
            </div>
          ) : (
            dispatchedTeams.map((t) => {
              const hasTarget = Boolean(t.targetCoords);
              const isDirectingThis = directingTeamId === t.id;

              return (
                <div
                  key={t.id}
                  className={`p-1.5 border flex items-center justify-between text-[10px] transition-colors ${
                    isDirectingThis
                      ? 'border-amber-400 bg-amber-950/60 shadow-[0_0_10px_rgba(245,158,11,0.3)]'
                      : 'border-slate-800 bg-[#040816] hover:border-slate-700'
                  }`}
                >
                  <div 
                    onClick={() => onCenterTarget(t.coords, 16)}
                    className="flex items-center gap-1.5 cursor-pointer truncate mr-2 flex-1"
                    title="Haritada Tim Konumuna Git"
                  >
                    <span className="w-2 h-2 rounded-full shrink-0" style={{ backgroundColor: t.color || '#00E5FF' }} />
                    <span className="font-bold text-white truncate">{t.shortName}</span>
                    <span className="text-[8.5px] text-slate-400">({t.personnel}p)</span>
                  </div>

                  <div className="flex items-center gap-1 shrink-0">
                    {hasTarget && (
                      <span className="text-[8.5px] text-amber-300 font-bold bg-amber-950 px-1 border border-amber-600/50 animate-pulse">
                        İNTİKALDE
                      </span>
                    )}
                    <button
                      onClick={() => {
                        if (isDirectingThis) {
                          onCancelDirecting();
                        } else {
                          onStartDirecting(t.id);
                          soundFx.playTargetLock();
                        }
                      }}
                      className={`px-1.5 py-0.5 text-[8.5px] font-bold cursor-pointer border ${
                        isDirectingThis
                          ? 'bg-amber-400 text-black border-amber-300 font-black'
                          : 'bg-cyan-950 text-cyan-200 border-cyan-500/40 hover:bg-cyan-900'
                      }`}
                      title="Bu tim için haritada hedef belirle"
                    >
                      {isDirectingThis ? 'HEDEF SEÇ' : 'YÖNLENDİR'}
                    </button>

                    <button
                      onClick={() => {
                        if (window.confirm(`${t.name} görevden çekilsin mi?`)) {
                          onRemoveTeam(t.id);
                          soundFx.playSelect();
                        }
                      }}
                      className="p-0.5 text-slate-500 hover:text-red-400 cursor-pointer"
                      title="Timi Sil / Görevden Çek"
                    >
                      <X className="w-3 h-3" />
                    </button>
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>

      {/* 4. LEAFLET MAP VIEWPORT */}
      <MapContainer
        center={[38.43, 27.18]}
        zoom={12}
        zoomControl={false}
        className="w-full h-full z-10"
      >
        <MapCameraController targetCoords={targetCoords} />
        <MapInteractionsTracker 
          onCoordsChange={setMouseCoords} 
          onMapClick={onMapDirectTeam} 
          isDirecting={Boolean(directingTeamId)} 
        />

        {/* Primary Map Layer */}
        <TileLayer
          key={activeLayer}
          url={currentLayerConfig.url}
          attribution={currentLayerConfig.attribution}
          maxZoom={currentLayerConfig.maxZoom}
        />

        {/* Satellite Place/Road Overlay */}
        {currentLayerConfig.overlayUrl && (
          <TileLayer
            key={`${activeLayer}-overlay`}
            url={currentLayerConfig.overlayUrl}
            maxZoom={currentLayerConfig.maxZoom}
            opacity={0.85}
          />
        )}

        {/* --- FEATURE 4: GEOFENCING & TEHLİKE BÖLGELERİ --- */}
        {showHazards && hazardZones.map((hz) => (
          <Circle
            key={hz.id}
            center={[hz.lat, hz.lng]}
            radius={hz.radius}
            pathOptions={{
              color: hz.color || '#EF4444',
              weight: 1.8,
              dashArray: '6 8',
              fillColor: hz.color || '#EF4444',
              fillOpacity: 0.12
            }}
          >
            <Tooltip direction="top" opacity={0.9} permanent>
              <div className="bg-[#02050D] border border-red-500 text-red-300 font-mono text-[8.5px] px-1.5 py-0.5 shadow-lg">
                ⚠️ {hz.name} ({hz.type})
              </div>
            </Tooltip>
          </Circle>
        ))}

        {/* --- FEATURE 1: ASKERİ 1x1 KM SAR SEKTÖR IZGARASI --- */}
        {showSarGrid && sarGrid.map((grid) => (
          <Polygon
            key={grid.id}
            positions={grid.bounds}
            pathOptions={{
              color: '#00E5FF',
              weight: 0.8,
              dashArray: '2 4',
              fillColor: '#00E5FF',
              fillOpacity: 0.03
            }}
          >
            <Tooltip
              direction="center"
              permanent
              className="tactical-grid-label"
              opacity={0.7}
            >
              <span className="text-[8px] font-mono font-bold text-cyan-400/80 bg-black/60 px-1 border border-cyan-500/20">
                {grid.label}
              </span>
            </Tooltip>
          </Polygon>
        ))}

        {/* --- FEATURE 1: CANLI ROTA İZİ & EKMEK KIRINTISI --- */}
        {showBreadcrumbs && breadcrumbTrail.length > 1 && (
          <>
            <Polyline
              positions={breadcrumbTrail}
              pathOptions={{
                color: focalUser?.isFreshSos ? '#EF4444' : '#FF4D26',
                weight: 6,
                opacity: 0.35,
                lineCap: 'round',
                lineJoin: 'round'
              }}
            />
            <Polyline
              positions={breadcrumbTrail}
              pathOptions={{
                color: focalUser?.isFreshSos ? '#FFA39E' : '#FF8A00',
                weight: 2.5,
                opacity: 0.95,
                dashArray: '6 4',
                lineCap: 'round'
              }}
            />
            {breadcrumbTrail.map((coord, idx) => (
              <Circle
                key={`wp-${idx}`}
                center={coord}
                radius={idx === breadcrumbTrail.length - 1 ? 25 : 12}
                pathOptions={{
                  color: '#FF4D26',
                  fillColor: idx === breadcrumbTrail.length - 1 ? '#00E5FF' : '#FF4D26',
                  fillOpacity: 0.8,
                  weight: 1
                }}
              />
            ))}
          </>
        )}

        {/* --- FEATURE 1: TAKTİK İNTİKAL KORİDORU --- */}
        {showSarVectors && focalUser && analysis?.nearestComrades && (
          analysis.nearestComrades.map((comrade) => {
            if (!comrade.coords) return null;
            const midLat = (focalUser.lat + comrade.lat) / 2;
            const midLng = (focalUser.lng + comrade.lng) / 2;
            const badgeIcon = createTacticalVectorBadge(comrade);

            return (
              <React.Fragment key={`vec-${comrade.id}`}>
                <Polyline
                  positions={[focalUser.coords, comrade.coords]}
                  pathOptions={{
                    color: focalUser.isFreshSos ? '#EF4444' : '#00E5FF',
                    weight: 1.5,
                    dashArray: '5 7',
                    opacity: 0.85
                  }}
                />
                <Marker
                  position={[midLat, midLng]}
                  icon={badgeIcon}
                  interactive={false}
                />
              </React.Fragment>
            );
          })
        )}

        {/* --- FEATURE 3: LKP SİNYAL KAYBI & DEAD RECKONING ARAMA ÇEMBERİ --- */}
        {lkpProbability && focalUser && focalUser.coords && (
          <Circle
            center={focalUser.coords}
            radius={lkpProbability.radiusMeters}
            pathOptions={{
              color: '#F59E0B',
              weight: 1.5,
              dashArray: '6 6',
              fillColor: '#F59E0B',
              fillOpacity: 0.08
            }}
          >
            <Tooltip direction="top" opacity={0.9} permanent>
              <div className="bg-[#02050D] border border-amber-500 text-amber-300 font-mono text-[9px] px-1.5 py-0.5">
                📡 OLASI SAR ARAMA ALANI (R: {lkpProbability.radiusMeters}m | ~{lkpProbability.areaKm2} km²)
              </div>
            </Tooltip>
          </Circle>
        )}

        {/* --- FEATURE 1: UAV DRONE ORBITING FLIGHT & SENSOR BEAM --- */}
        {uavPosition && uavTargetUser && (
          <>
            {/* Drone Orbital Flight Ring */}
            <Circle
              center={uavTargetUser.coords}
              radius={650}
              pathOptions={{
                color: '#00E5FF',
                weight: 1,
                dashArray: '4 6',
                fillOpacity: 0
              }}
            />
            {/* Sensor Scan Cone Line to Target */}
            <Polyline
              positions={[uavPosition, uavTargetUser.coords]}
              pathOptions={{
                color: '#00E5FF',
                weight: 1.5,
                dashArray: '3 3',
                opacity: 0.75
              }}
            />
            {/* UAV Drone Marker */}
            <Marker
              position={uavPosition}
              icon={createUavMarkerIcon(uavOrbitAngle + 90)}
              interactive={false}
            />
          </>
        )}

        {/* --- AKILLI ARAMA ALANI (SMART DIRECTIONAL SEARCH CONE) --- */}
        {showSmartCone && enableSmartCone && smartSearchCone && (
          <>
            {/* 1. Geniş Arama Sektör Konisi (±35° Dağlık Açı) */}
            <Polygon
              positions={smartSearchCone.conePolygon}
              pathOptions={{
                color: '#F59E0B',
                weight: 2,
                dashArray: '5 5',
                fillColor: '#F59E0B',
                fillOpacity: 0.14
              }}
            >
              <Tooltip direction="top" opacity={0.95}>
                <div className="bg-[#02050D] border border-amber-500 text-amber-300 font-mono text-[9px] p-1.5 shadow-lg">
                  🎯 AKILLI ARAMA KONİSİ: {smartSearchCone.totalDistanceKm} km | {smartSearchCone.searchAreaKm2} km²
                  <br />
                  <span className="text-white">YÖN: {smartSearchCone.headingDeg}° [{smartSearchCone.cardinalLabel}] | HIZ: {smartSearchCone.avgSpeedKmh} km/s</span>
                </div>
              </Tooltip>
            </Polygon>

            {/* 2. Öncelikli Çekirdek Alan (%45 Mesafe) */}
            <Polygon
              positions={smartSearchCone.corePolygon}
              pathOptions={{
                color: '#EF4444',
                weight: 1.5,
                fillColor: '#EF4444',
                fillOpacity: 0.22
              }}
            >
              <Tooltip direction="center" opacity={0.9} permanent>
                <span className="text-[8.5px] font-mono font-bold text-red-400 bg-black/85 px-1.5 py-0.5 border border-red-500/60">
                  ÖNCELİKLİ ÇEKİRDEK: {smartSearchCone.report.probabilityCoreKm} km
                </span>
              </Tooltip>
            </Polygon>

            {/* 3. Ana İlerleme / Yön Vektör Oku */}
            <Polyline
              positions={[smartSearchCone.lkp, smartSearchCone.apexPoint]}
              pathOptions={{
                color: '#F59E0B',
                weight: 2.5,
                dashArray: '6 4',
                opacity: 0.95
              }}
            />
          </>
        )}

        {/* --- SEVK EDİLEN ARAMA KURTARMA EKİPLERİ VE EKİPMANLARI (CANLI YÖNLENDİRME) --- */}
        {showDispatchedTeams && enableTeams && dispatchedTeams.map((team) => {
          const hasTarget = Boolean(team.targetCoords && team.targetCoords.length === 2);
          const distMeters = hasTarget ? calculateDistanceMeters(team.coords[0], team.coords[1], team.targetCoords[0], team.targetCoords[1]) : 0;
          const etaMin = hasTarget ? calculateEtaMinutes(distMeters, 4.5) : 0;

          return (
            <React.Fragment key={team.id}>
              {/* Coverage radius */}
              <Circle
                center={team.coords}
                radius={180}
                pathOptions={{
                  color: team.color || '#00E5FF',
                  weight: 1.2,
                  dashArray: '4 4',
                  fillColor: team.color || '#00E5FF',
                  fillOpacity: 0.08
                }}
              />

              {/* Approach route vector if team has a destination */}
              {hasTarget && (
                <>
                  <Polyline
                    positions={[team.coords, team.targetCoords]}
                    pathOptions={{
                      color: team.color || '#F59E0B',
                      weight: 2.5,
                      dashArray: '6 6',
                      opacity: 0.85
                    }}
                  />
                  {/* Target Waypoint Marker */}
                  <Marker
                    position={team.targetCoords}
                    icon={createTeamTargetIcon(team, distMeters, etaMin)}
                  >
                    <Popup>
                      <div className="p-2.5 bg-[#02050D] border border-amber-400 text-white font-mono text-xs max-w-64 shadow-[0_0_20px_rgba(0,0,0,0.9)]">
                        <div className="font-bold text-amber-300 mb-1">
                          🎯 {team.name} İNTİKAL HEDEFİ
                        </div>
                        <div className="text-[10px] text-slate-300 space-y-0.5 mb-2">
                          <div>HEDEF MESAFESİ: <span className="text-white font-bold">{distMeters} metre</span></div>
                          <div>TAHMİNİ VARIŞ SÜRESİ: <span className="text-amber-400 font-bold">~{etaMin} dakika</span></div>
                        </div>
                        <button
                          onClick={() => onCompleteTransit(team.id)}
                          className="w-full bg-emerald-700 hover:bg-emerald-600 text-white font-bold py-1 text-[10px] cursor-pointer"
                        >
                          ✅ VARIŞI ONAYLA (MEVKİYE ULAŞTI)
                        </button>
                      </div>
                    </Popup>
                  </Marker>
                </>
              )}

              {/* Sürüklenebilir ve Tıklanabilir Tim İşaretçisi */}
              <Marker
                position={team.coords}
                draggable={true}
                icon={createDispatchedTeamMarkerIcon(team)}
                eventHandlers={{
                  dragend: (e) => {
                    const latlng = e.target.getLatLng();
                    onUpdateTeamCoords(team.id, [latlng.lat, latlng.lng]);
                    soundFx.playSelect();
                  }
                }}
              >
                <Popup>
                  <div className="p-3 bg-[#02050D] border border-cyan-500/50 text-white font-tactical text-xs min-w-64 shadow-[0_0_20px_rgba(0,0,0,0.9)]">
                    <div className="flex items-center justify-between border-b border-cyan-500/30 pb-1.5 mb-2">
                      <div className="flex items-center gap-1.5 font-bold text-cyan-300">
                        <span className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: team.color || '#00E5FF' }} />
                        <span className="text-xs uppercase">{team.name}</span>
                      </div>
                      <span className="text-[9px] font-mono bg-cyan-950 text-cyan-300 px-1.5 py-0.2 border border-cyan-500/40 font-bold">
                        {team.status}
                      </span>
                    </div>

                    <div className="space-y-1 font-mono text-[10px] text-slate-300 mb-2">
                      <div>LİDER: <span className="text-white font-bold">{team.leader}</span> ({team.personnel} Kişi)</div>
                      <div>TELSİZ: <span className="text-cyan-400 font-bold">{team.radioChannel}</span></div>
                      <div>MEVKİ: <span className="text-slate-200">{team.coords[0].toFixed(4)}°N, {team.coords[1].toFixed(4)}°E</span> <span className="text-amber-400 font-bold">(Tut & Sürükle)</span></div>
                      {hasTarget && (
                        <div className="bg-amber-950/40 border border-amber-500/50 p-1 text-[10px] text-amber-300 font-bold">
                          🎯 HEDEF: ~{etaMin}dk ({distMeters}m)
                        </div>
                      )}
                    </div>

                    {/* Zimmetli Ekipmanlar */}
                    <div className="border-t border-slate-800 pt-1.5 mb-2.5">
                      <div className="text-[8.5px] text-slate-400 font-mono mb-1 font-bold">ZİMMETLİ EKİPMANLAR ({team.equipment?.length || 0}):</div>
                      <div className="flex flex-wrap gap-1">
                        {team.equipment?.map((eq, i) => (
                          <span key={i} className="text-[8.5px] font-mono bg-cyan-950 border border-cyan-500/40 text-cyan-200 px-1.5 py-0.2">
                            {eq}
                          </span>
                        ))}
                      </div>
                    </div>

                    {/* Yönlendirme ve Yönetim Butonları */}
                    <div className="space-y-1.5 border-t border-slate-800 pt-2">
                      <div className="grid grid-cols-2 gap-1 font-mono text-[9.5px]">
                        <button
                          onClick={() => {
                            onStartDirecting(team.id);
                            soundFx.playTargetLock();
                          }}
                          className="bg-cyan-950 hover:bg-cyan-900 border border-cyan-400 text-cyan-200 py-1 font-bold cursor-pointer flex items-center justify-center gap-1 shadow-sm"
                          title="Harita üzerinden hedef nokta seç"
                        >
                          <Compass className="w-3 h-3 text-cyan-400" />
                          HEDEF BELİRLE
                        </button>

                        <button
                          onClick={() => {
                            onDispatchToCasualty(team.id);
                            soundFx.playTargetLock();
                          }}
                          className="bg-red-950/80 hover:bg-red-900 border border-red-500 text-red-300 py-1 font-bold cursor-pointer flex items-center justify-center gap-1"
                          title="Kazazedeye doğrudan sevk et"
                        >
                          <Zap className="w-3 h-3 text-red-400" />
                          KAZAZEDEYE GİT
                        </button>
                      </div>

                      {hasTarget && (
                        <button
                          onClick={() => {
                            onCompleteTransit(team.id);
                            soundFx.playSuccess();
                          }}
                          className="w-full bg-emerald-950 hover:bg-emerald-900 border border-emerald-500 text-emerald-300 py-1 text-[9.5px] font-mono font-bold cursor-pointer"
                        >
                          ✅ HEDEFE VARIŞI ONAYLA (MEVKİYE GİRDİ)
                        </button>
                      )}

                      <button
                        onClick={() => {
                          if (window.confirm(`${team.name} görevden çekilsin ve silinsin mi?`)) {
                            onRemoveTeam(team.id);
                            soundFx.playSelect();
                          }
                        }}
                        className="w-full bg-black hover:bg-red-950 border border-slate-800 hover:border-red-600 text-slate-400 hover:text-red-300 py-1 text-[9px] font-mono cursor-pointer flex items-center justify-center gap-1"
                      >
                        <Trash2 className="w-3 h-3 text-red-400" />
                        EKİBİ GÖREVDEN ÇEK / SİL
                      </button>
                    </div>

                  </div>
                </Popup>
              </Marker>
            </React.Fragment>
          );
        })}

        {/* --- SAR OLAY ÖRGÜSÜ & KRONOLOJİK ADIMLAR --- */}
        {showStoryline && enableStoryline && incidentStoryline && incidentStoryline.length > 0 && (
          <>
            <Polyline
              positions={incidentStoryline.filter(s => s.coords).map(s => s.coords)}
              pathOptions={{
                color: '#10B981',
                weight: 2,
                dashArray: '4 4',
                opacity: 0.65
              }}
            />
            {incidentStoryline.filter(s => s.coords).map((step) => (
              <Marker
                key={step.id}
                position={step.coords}
                icon={createStorylineWaypointIcon(step)}
              >
                <Popup>
                  <div className="p-2.5 bg-[#02050D] border border-emerald-500/50 text-white font-tactical text-xs max-w-68 shadow-[0_0_20px_rgba(0,0,0,0.9)]">
                    <div className="flex items-center gap-1.5 font-bold text-emerald-400 border-b border-emerald-500/30 pb-1 mb-1.5">
                      <span>ADIM {step.stepNumber}: [{step.time}]</span>
                      <span>{step.title}</span>
                    </div>
                    <p className="text-[10px] text-slate-300 font-mono mb-1.5 leading-relaxed">{step.desc}</p>
                    <div className="text-[9px] text-slate-400 font-mono">
                      SORUMLU: <span className="text-cyan-300 font-bold">{step.team}</span>
                    </div>
                  </div>
                </Popup>
              </Marker>
            ))}
          </>
        )}

        {/* Real User Pins (Supports Playback Interpolation - Feature 7) */}
        {mappedUsers.map((user) => {
          const isSelected = selectedUser?.id === user.id;
          const displayCoords = playbackProgress < 0.99 
            ? (interpolateUserTrack(user, playbackProgress) || user.coords)
            : user.coords;

          const icon = createTacticalAvatarMarker(user, isSelected);

          return (
            <Marker
              key={user.id}
              position={displayCoords}
              icon={icon}
              ref={(ref) => {
                if (ref) markerRefs.current[user.id] = ref;
              }}
              eventHandlers={{
                click: () => {
                  handleDirectSelect(user);
                }
              }}
            >
              <Popup>
                <div className="w-68 p-3 bg-[#02050D] border border-cyan-500/40 text-slate-100 font-tactical select-none shadow-[0_0_20px_rgba(0,0,0,0.9)]">
                  
                  {/* Popup Header */}
                  <div className="flex items-center gap-2.5 border-b border-cyan-500/20 pb-2 mb-2">
                    {user.avatar ? (
                      <img 
                        src={user.avatar} 
                        alt={user.name} 
                        className="w-10 h-10 rounded-none object-cover border border-[#00E5FF] flex-shrink-0"
                      />
                    ) : (
                      <div className="w-10 h-10 rounded-none bg-slate-900 border border-[#00E5FF] flex items-center justify-center text-[#00E5FF] font-bold text-xs flex-shrink-0 font-mono">
                        {user.initials}
                      </div>
                    )}
                    
                    <div className="min-w-0">
                      <div className="font-bold text-xs text-white uppercase truncate tracking-wider">
                        {user.name}
                      </div>
                      <div className="text-[10px] text-[#FF6E40] truncate">
                        {user.team}
                      </div>
                      <div className="text-[9px] text-cyan-400 font-mono truncate">
                        {user.lat.toFixed(4)}, {user.lng.toFixed(4)}
                      </div>
                    </div>
                  </div>

                  {/* Telemetry row */}
                  <div className="grid grid-cols-2 gap-1 text-[10px] text-slate-300 mb-2 font-mono bg-[#030917] p-1.5 border border-slate-800">
                    <div>RAKIM: <span className="text-amber-300 font-bold">{user.altitude}m</span></div>
                    <div>BATARYA: <span className="text-emerald-400 font-bold">%{user.battery}</span></div>
                  </div>

                  {/* DETAYLI KOKPİTE AL BUTONU */}
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      handleDirectSelect(user);
                      if (markerRefs.current[user.id]) {
                        markerRefs.current[user.id].closePopup();
                      }
                    }}
                    className="w-full tactical-btn py-1.5 text-[11px] flex items-center justify-center gap-1.5"
                  >
                    <Eye className="w-3.5 h-3.5 text-[#00E5FF]" /> DETAYLI KOKPİTE AL
                  </button>

                </div>
              </Popup>
            </Marker>
          );
        })}
      </MapContainer>

      {/* 4. BOTTOM-CENTER CURSOR COORDINATES & RADAR TOGGLE */}
      <div className="absolute bottom-2 left-1/2 transform -translate-x-1/2 z-[400] pointer-events-none select-none">
        <div className="bg-[#02050D]/90 backdrop-blur-md border border-cyan-500/30 px-4 py-1 flex items-center gap-4 text-[10px] font-mono text-slate-300 pointer-events-auto">
          <div className="flex items-center gap-1 text-cyan-400">
            <Crosshair className="w-3 h-3 text-[#00E5FF]" />
            <span className="text-slate-400">KURSÖR:</span>
            <span className="font-bold text-white">{mouseCoords[0].toFixed(4)}°N, {mouseCoords[1].toFixed(4)}°E</span>
          </div>
          
          <div className="w-[1px] h-3 bg-slate-800" />
          <div className="text-amber-400 font-bold">
            SEKTÖR: {analysis?.sectorName ? analysis.sectorName.split('/')[0] : 'İZMİR'}
          </div>
          
          <div className="w-[1px] h-3 bg-slate-800" />
          <button
            onClick={() => setEnableSmartCone(!enableSmartCone)}
            className={`cursor-pointer transition-colors ${
              enableSmartCone ? 'text-amber-300 font-bold' : 'text-slate-600'
            }`}
            title="Akıllı Arama Konisini Aç/Kapat"
          >
            🎯 KONİ: {enableSmartCone ? 'AÇIK' : 'KAPALI'}
          </button>

          <div className="w-[1px] h-3 bg-slate-800" />
          <button
            onClick={() => setEnableTeams(!enableTeams)}
            className={`cursor-pointer transition-colors ${
              enableTeams ? 'text-cyan-400 font-bold' : 'text-slate-600'
            }`}
            title="Sevk Edilen Ekipleri Aç/Kapat"
          >
            🛡️ EKİP ({dispatchedTeams.length}): {enableTeams ? 'AÇIK' : 'KAPALI'}
          </button>

          <div className="w-[1px] h-3 bg-slate-800" />
          <button
            onClick={() => setEnableStoryline(!enableStoryline)}
            className={`cursor-pointer transition-colors ${
              enableStoryline ? 'text-emerald-400 font-bold' : 'text-slate-600'
            }`}
            title="Olay Örgüsü Adımlarını Aç/Kapat"
          >
            📋 OLAY ÖRGÜSÜ: {enableStoryline ? 'AÇIK' : 'KAPALI'}
          </button>

          <div className="w-[1px] h-3 bg-slate-800" />
          <button
            onClick={() => setEnableRadarEffect(!enableRadarEffect)}
            className={`flex items-center gap-1 cursor-pointer transition-colors ${
              enableRadarEffect ? 'text-[#00E5FF] font-bold' : 'text-slate-500'
            }`}
            title="Radar Tarama Efektini Aç/Kapat"
          >
            <Radar className={`w-3 h-3 ${enableRadarEffect ? 'animate-spin' : ''}`} />
            <span>RADAR: {enableRadarEffect ? 'AÇIK' : 'KAPALI'}</span>
          </button>
        </div>
      </div>

    </div>
  );
}
