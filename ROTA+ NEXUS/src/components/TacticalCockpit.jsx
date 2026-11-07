import React, { useState, useMemo } from 'react';
import { 
  Crosshair, 
  MapPin, 
  Mountain, 
  Battery, 
  Heart, 
  PhoneCall, 
  Radio, 
  Zap, 
  Compass, 
  X, 
  ShieldCheck, 
  AlertTriangle,
  UserCheck,
  Copy,
  Check,
  Navigation,
  Activity,
  Users,
  Footprints,
  Wind,
  CloudFog,
  TrendingUp,
  AlertOctagon,
  ArrowUpRight,
  Send,
  FileText,
  Timer,
  PlaneTakeoff,
  Clock,
  ClipboardList
} from 'lucide-react';
import { soundFx } from '../audio';
import { 
  analyzeLocation, 
  getSignalFreshness, 
  getElevationProfile, 
  getTacticalMicroWeather,
  calculateSearchZoneProbability,
  calculateSurvivalMetrics
} from '../utils/geoAnalysis';

// --- SUB-COMPONENT: SVG ELEVATION & SLOPE CROSS-SECTION CHART (FEATURE 2) ---
function ElevationProfileHUD({ profile }) {
  if (!profile || !profile.points || profile.points.length === 0) return null;

  const width = 290;
  const height = 90;
  const padding = { top: 12, right: 12, bottom: 20, left: 32 };

  const innerW = width - padding.left - padding.right;
  const innerH = height - padding.top - padding.bottom;

  const minAlt = Math.max(0, profile.minAlt - 20);
  const maxAlt = profile.maxAlt + 30;
  const altRange = Math.max(40, maxAlt - minAlt);

  // Map data points to SVG coordinates
  const coords = profile.points.map((pt, idx) => {
    const x = padding.left + (idx / (profile.points.length - 1)) * innerW;
    const y = padding.top + innerH - ((pt.alt - minAlt) / altRange) * innerH;
    return { x, y, alt: pt.alt, dist: pt.dist };
  });

  const pathD = coords.reduce((acc, pt, idx) => {
    return `${acc} ${idx === 0 ? 'M' : 'L'} ${pt.x.toFixed(1)} ${pt.y.toFixed(1)}`;
  }, '');

  const areaD = `${pathD} L ${coords[coords.length - 1].x.toFixed(1)} ${(padding.top + innerH).toFixed(1)} L ${coords[0].x.toFixed(1)} ${(padding.top + innerH).toFixed(1)} Z`;
  const lastPt = coords[coords.length - 1];

  return (
    <div className="tactical-box p-2.5 flex flex-col gap-1.5 font-tactical">
      
      {/* HUD Header */}
      <div className="flex items-center justify-between border-b border-slate-800 pb-1">
        <span className="text-[9px] text-cyan-400 font-bold tracking-widest uppercase flex items-center gap-1">
          <TrendingUp className="w-3 h-3 text-[#FF4D26]" /> ARAZİ İRTİFA & EĞİM PROFİLİ
        </span>
        <span className="text-[9px] font-mono font-bold text-amber-300">
          EĞİM: %{profile.slopePercent}
        </span>
      </div>

      {/* SVG Chart */}
      <div className="relative w-full bg-[#020714] border border-cyan-500/20 overflow-hidden">
        <svg viewBox={`0 0 ${width} ${height}`} className="w-full h-22 overflow-visible">
          <defs>
            <linearGradient id="elevGrad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#FF4D26" stopOpacity="0.45" />
              <stop offset="60%" stopColor="#00E5FF" stopOpacity="0.15" />
              <stop offset="100%" stopColor="#00E5FF" stopOpacity="0.0" />
            </linearGradient>
            <linearGradient id="elevStroke" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%" stopColor="#00E5FF" />
              <stop offset="70%" stopColor="#FF6E40" />
              <stop offset="100%" stopColor="#FF4D26" />
            </linearGradient>
          </defs>

          {/* Grid lines */}
          <line 
            x1={padding.left} 
            y1={padding.top} 
            x2={width - padding.right} 
            y2={padding.top} 
            stroke="rgba(0, 229, 255, 0.12)" 
            strokeDasharray="2 3" 
          />
          <line 
            x1={padding.left} 
            y1={padding.top + innerH / 2} 
            x2={width - padding.right} 
            y2={padding.top + innerH / 2} 
            stroke="rgba(0, 229, 255, 0.12)" 
            strokeDasharray="2 3" 
          />
          <line 
            x1={padding.left} 
            y1={padding.top + innerH} 
            x2={width - padding.right} 
            y2={padding.top + innerH} 
            stroke="rgba(0, 229, 255, 0.25)" 
          />

          {/* Altitude Labels on Y Axis */}
          <text x={padding.left - 4} y={padding.top + 4} fill="#64748B" fontSize="8" fontFamily="monospace" textAnchor="end">
            {maxAlt}m
          </text>
          <text x={padding.left - 4} y={padding.top + innerH} fill="#64748B" fontSize="8" fontFamily="monospace" textAnchor="end">
            {minAlt}m
          </text>

          {/* Area Fill */}
          <path d={areaD} fill="url(#elevGrad)" />

          {/* Elevation Curve Line */}
          <path d={pathD} fill="none" stroke="url(#elevStroke)" strokeWidth="2" strokeLinecap="round" />

          {/* Target Current Position Marker */}
          {lastPt && (
            <g>
              <circle cx={lastPt.x} cy={lastPt.y} r="5" fill="#EF4444" opacity="0.4" className="animate-ping" />
              <circle cx={lastPt.x} cy={lastPt.y} r="3.5" fill="#FF4D26" stroke="#FFFFFF" strokeWidth="1" />
              <text x={lastPt.x - 4} y={lastPt.y - 6} fill="#F8FAFC" fontSize="8.5" fontFamily="monospace" fontWeight="bold" textAnchor="end">
                {profile.baseAlt}m
              </text>
            </g>
          )}
        </svg>
      </div>

      {/* Slope Footer */}
      <div className="flex items-center justify-between text-[9px] font-mono pt-0.5">
        <span className="text-slate-400">{profile.slopeCategory}</span>
        <span className="text-emerald-400 font-bold">▲ +{profile.totalGain}m İrtifa</span>
      </div>

      {profile.hazardWarning && (
        <div className="bg-red-950/60 border border-red-500/80 p-1.5 flex items-center gap-1.5 text-[9px] text-red-200">
          <AlertOctagon className="w-3.5 h-3.5 text-red-400 flex-shrink-0 animate-pulse" />
          <span>{profile.hazardWarning}</span>
        </div>
      )}

    </div>
  );
}

// --- SUB-COMPONENT: MOUNTAIN MICRO-WEATHER & WIND ROSE WIDGET (FEATURE 2) ---
function TacticalWeatherHUD({ weather, sectorName }) {
  if (!weather) return null;

  return (
    <div className="tactical-box p-2.5 flex flex-col gap-1.5 font-tactical">
      
      <div className="flex items-center justify-between border-b border-slate-800 pb-1">
        <span className="text-[9px] text-cyan-400 font-bold tracking-widest uppercase flex items-center gap-1">
          <Wind className="w-3 h-3 text-[#00E5FF]" /> MİKRO METEOROLOJİ & RÜZGAR
        </span>
        <span className="text-[9px] font-mono text-slate-400">
          {sectorName ? sectorName.split('/')[0] : 'DAĞLIK SEKTÖR'}
        </span>
      </div>

      <div className="grid grid-cols-3 gap-1.5 items-center">
        
        {/* Rotating Wind Rose Compass */}
        <div className="bg-[#030917] border border-cyan-500/20 p-2 flex flex-col items-center justify-center relative">
          <div className="w-10 h-10 rounded-full border border-cyan-500/30 flex items-center justify-center relative">
            <span className="absolute top-0 text-[7px] text-slate-500 font-bold">K</span>
            <span className="absolute bottom-0 text-[7px] text-slate-500 font-bold">G</span>
            <span className="absolute left-0.5 text-[7px] text-slate-500 font-bold">B</span>
            <span className="absolute right-0.5 text-[7px] text-slate-500 font-bold">D</span>
            
            <div 
              className="w-1 h-7 bg-transparent flex flex-col items-center justify-between transition-transform duration-700 ease-out"
              style={{ transform: `rotate(${weather.windDegrees}deg)` }}
            >
              <div className="w-1.5 h-3 bg-[#FF4D26]" />
              <div className="w-1 h-3 bg-cyan-400" />
            </div>
          </div>
          <div className="text-[8px] font-mono text-cyan-300 font-bold mt-1">
            {weather.windDegrees}° {weather.windCardinal.split(' ')[0]}
          </div>
        </div>

        {/* Temperature */}
        <div className="bg-[#030917] border border-cyan-500/20 p-2 flex flex-col justify-center text-center">
          <div className="text-[8px] text-slate-400 uppercase">ZİRVE SICAKLIK</div>
          <div className="text-base font-black text-amber-300 font-mono">
            {weather.temp}°C
          </div>
          <div className="text-[8px] text-slate-400 font-mono">
            Hissedilen: <span className="text-white">{weather.apparentTemp}°C</span>
          </div>
        </div>

        {/* Wind Speed */}
        <div className="bg-[#030917] border border-cyan-500/20 p-2 flex flex-col justify-center text-center">
          <div className="text-[8px] text-slate-400 uppercase">RÜZGAR HIZI</div>
          <div className="text-base font-black text-[#00E5FF] font-mono">
            {weather.windSpeed} <span className="text-[9px] font-normal">km/s</span>
          </div>
          <div className="text-[8px] text-slate-400 font-mono">
            Nem: %{weather.humidity}
          </div>
        </div>

      </div>

      {/* Visibility status */}
      <div className={`p-1.5 border flex items-center justify-between text-[9px] font-mono ${
        weather.isFoggy 
          ? 'bg-amber-950/40 border-amber-500/70 text-amber-300' 
          : 'bg-[#030917] border-slate-800 text-slate-300'
      }`}>
        <span className="flex items-center gap-1">
          <CloudFog className="w-3 h-3 text-cyan-400" /> GÖRÜŞ MESAFESİ:
        </span>
        <span className="font-bold">{weather.visibility}</span>
      </div>

    </div>
  );
}

// --- SUB-COMPONENT: SURVIVAL & BATTERY COUNTDOWN HUD (FEATURE 5) ---
function SurvivalCountdownHUD({ survival }) {
  if (!survival) return null;

  return (
    <div className="tactical-box p-2.5 flex flex-col gap-1.5 font-tactical">
      
      {/* Header */}
      <div className="flex items-center justify-between border-b border-slate-800 pb-1">
        <span className="text-[9px] text-cyan-400 font-bold tracking-widest uppercase flex items-center gap-1">
          <Timer className="w-3 h-3 text-amber-400" /> TAKTİK HAYATTA KALMA SAYACI
        </span>
        <span className="text-[9px] font-mono font-bold" style={{ color: survival.statusColor }}>
          {survival.statusLevel}
        </span>
      </div>

      {/* Metrics Row */}
      <div className="grid grid-cols-2 gap-1.5">
        
        {/* Remaining Transmission Time */}
        <div className="bg-[#030917] border border-cyan-500/20 p-2">
          <div className="text-[8px] text-slate-400 uppercase">GPS SİNYAL BİTİŞİ</div>
          <div className="text-sm font-black font-mono text-white mt-0.5 flex items-center gap-1">
            <Clock className="w-3 h-3 text-cyan-400" />
            <span>~{survival.countdownText}</span>
          </div>
          <div className="text-[8px] text-slate-500 font-mono mt-0.5">
            Tüketim: %{survival.drainRatePerHour}/saat
          </div>
        </div>

        {/* Hypothermia Threshold */}
        <div className="bg-[#030917] border border-cyan-500/20 p-2">
          <div className="text-[8px] text-slate-400 uppercase">HİPOTERMİ EŞİĞİ</div>
          <div className="text-xs font-bold font-mono mt-0.5" style={{ color: survival.statusColor }}>
            {survival.hypothermiaRiskLevel}
          </div>
          <div className="text-[8px] text-slate-400 font-mono mt-0.5 truncate">
            {survival.hypothermiaTimeText}
          </div>
        </div>

      </div>

      {/* Battery Gauge Bar */}
      <div className="w-full bg-slate-900 h-1.5 border border-slate-700 relative overflow-hidden">
        <div 
          className="h-full transition-all duration-500"
          style={{ 
            width: `${survival.battery}%`,
            backgroundColor: survival.statusColor
          }}
        />
      </div>

    </div>
  );
}

// --- MAIN TACTICAL COCKPIT COMPONENT ---
// --- SUB-COMPONENT: AKILLI ARAMA ALANI (SMART DIRECTIONAL SEARCH CONE HUD) ---
function SmartSearchConeHUD({ smartSearchCone, coneParams = {}, onUpdateConeParams = () => {} }) {
  if (!smartSearchCone) return null;

  return (
    <div className="tactical-box p-2.5 flex flex-col gap-2 font-tactical border-amber-500/50 bg-[#070D1A]">
      <div className="flex items-center justify-between border-b border-amber-500/30 pb-1">
        <span className="text-[9.5px] text-amber-300 font-bold tracking-widest uppercase flex items-center gap-1.5">
          <Navigation className="w-3.5 h-3.5 text-amber-400" />
          AKILLI ARAMA ALANI (SEKTÖR ANALİZİ)
        </span>
        <span className="text-[9px] font-mono font-bold text-emerald-400">
          {smartSearchCone.searchAreaKm2} km²
        </span>
      </div>

      {/* Sliders / Dynamic Parameters */}
      <div className="space-y-1.5 text-[9px] font-mono">
        <div className="flex items-center justify-between text-slate-300">
          <span>ORT. YÜRÜYÜŞ HIZI: <strong className="text-white">{coneParams.avgSpeedKmh || 3.8} km/s</strong></span>
          <input
            type="range"
            min="1.5"
            max="6.0"
            step="0.1"
            value={coneParams.avgSpeedKmh || 3.8}
            onChange={(e) => onUpdateConeParams({ ...coneParams, avgSpeedKmh: parseFloat(e.target.value) })}
            className="w-24 accent-amber-400 cursor-pointer"
          />
        </div>

        <div className="flex items-center justify-between text-slate-300">
          <span>YÜRÜME / AÇIK SÜRE: <strong className="text-white">{coneParams.walkHours || 1.5} Sa</strong></span>
          <input
            type="range"
            min="0.5"
            max="6.0"
            step="0.5"
            value={coneParams.walkHours || 1.5}
            onChange={(e) => onUpdateConeParams({ ...coneParams, walkHours: parseFloat(e.target.value) })}
            className="w-24 accent-amber-400 cursor-pointer"
          />
        </div>

        <div className="flex items-center justify-between text-slate-300">
          <span>GİTTİĞİ YÖN: <strong className="text-white">{coneParams.headingDeg || 65}° ({smartSearchCone.cardinalLabel})</strong></span>
          <input
            type="range"
            min="0"
            max="360"
            step="5"
            value={coneParams.headingDeg || 65}
            onChange={(e) => onUpdateConeParams({ ...coneParams, headingDeg: parseInt(e.target.value) })}
            className="w-24 accent-amber-400 cursor-pointer"
          />
        </div>
      </div>

      {/* Calculated Military Summary Badge */}
      <div className="grid grid-cols-2 gap-1 text-[9px] font-mono bg-black/60 p-1.5 border border-amber-500/30">
        <div>TOPLAM ERİŞİM: <span className="text-amber-300 font-bold">{smartSearchCone.totalDistanceKm} km</span></div>
        <div>ÇEKİRDEK ALAN: <span className="text-red-400 font-bold">{smartSearchCone.report.probabilityCoreKm} km</span></div>
      </div>

      <div className="text-[8.5px] text-slate-400 font-mono leading-tight bg-amber-950/30 p-1 border border-amber-500/20">
        {smartSearchCone.report.summaryNote}
      </div>
    </div>
  );
}

export default function TacticalCockpit({
  user = null,
  allUsers = [],
  onClose = () => {},
  onCenterTarget = () => {},
  onSelectUser = () => {},
  onToggleUserTestSos = () => {},
  onLaunchUav = () => {},
  onOpenBriefing = () => {},
  onOpenDispatchLog = () => {},
  smartSearchCone = null,
  coneParams = {},
  onUpdateConeParams = () => {},
  allUsersCount = 0,
  mappedCount = 0,
  freshSosCount = 0
}) {
  const [copied, setCopied] = useState(false);

  const isLiveSos = Boolean(user && (user.isFreshSos || user.isTestSos));
  const signalInfo = user ? getSignalFreshness(user) : null;
  const analysis = useMemo(() => user ? analyzeLocation(user, allUsers) : null, [user, allUsers]);
  const elevationProfile = useMemo(() => user ? getElevationProfile(user) : null, [user]);
  const microWeather = useMemo(() => user ? getTacticalMicroWeather(user) : null, [user]);
  const searchZone = useMemo(() => (user && signalInfo?.isLost) ? calculateSearchZoneProbability(user) : null, [user, signalInfo]);
  const survivalMetrics = useMemo(() => user ? calculateSurvivalMetrics(user, microWeather) : null, [user, microWeather]);

  // Copy coordinates to clipboard
  const handleCopyCoords = () => {
    if (user && user.hasCoords) {
      const text = `${user.lat.toFixed(6)}, ${user.lng.toFixed(6)}`;
      navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
      soundFx.playSelect();
    }
  };

  // Dispatch nearest team member
  const handleDispatchNearest = (comrade) => {
    if (!comrade) return;
    const comradeUser = allUsers.find(u => u.id === comrade.id);
    if (comradeUser) {
      onSelectUser(comradeUser);
      if (comradeUser.coords) {
        onCenterTarget(comradeUser.coords, 16);
      }
      soundFx.playTargetLock();
    }
  };

  // IF NO USER IS SELECTED: SHOW COMMAND CENTER SUMMARY (STANDBY HUD)
  if (!user) {
    return (
      <aside className="w-88 h-full bg-[#02050D] border-l border-[#00E5FF]/25 flex flex-col font-tactical select-none z-40">
        
        {/* Panel Header */}
        <div className="h-10 px-3 bg-[#040A18] border-b border-cyan-500/30 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <span className="w-2 h-2 bg-[#00E5FF] rounded-none animate-pulse" />
            <h2 className="text-xs font-bold text-[#00E5FF] tracking-widest uppercase">
              KOMUTA KOKPİTİ: STANDBY
            </h2>
          </div>
          <span className="text-[10px] text-slate-500 font-mono">SEKTÖR İZMİR</span>
        </div>

        <div className="p-3 flex flex-col gap-3 flex-1 overflow-y-auto custom-scrollbar">
          
          {/* General Stats Grid */}
          <div className="grid grid-cols-2 gap-1.5">
            <div className="tactical-box p-2">
              <div className="text-[9px] text-cyan-400 font-bold tracking-wider">TOPLAM KADRO</div>
              <div className="text-base font-black text-white mt-0.5">{allUsersCount} ÜYE</div>
            </div>
            <div className="tactical-box p-2">
              <div className="text-[9px] text-emerald-400 font-bold tracking-wider">GPS TELEMETRİ</div>
              <div className="text-base font-black text-[#00E5FF] mt-0.5">{mappedCount} AKTİF</div>
            </div>
            <div className="tactical-box p-2">
              <div className="text-[9px] text-amber-400 font-bold tracking-wider">SEKTÖR ODAĞI</div>
              <div className="text-xs font-bold text-white mt-0.5">İZMİR & EGE</div>
            </div>
            <div className={`p-2 border ${freshSosCount > 0 ? 'bg-red-950/70 border-red-500 shadow-[0_0_12px_rgba(239,68,68,0.5)]' : 'tactical-box'}`}>
              <div className="text-[9px] text-slate-400 font-bold tracking-wider">CANLI ACİL SOS</div>
              <div className={`text-base font-black mt-0.5 ${freshSosCount > 0 ? 'text-red-400 animate-pulse' : 'text-slate-300'}`}>
                {freshSosCount > 0 ? `🚨 ${freshSosCount}` : '0 AKTİF'}
              </div>
            </div>
          </div>

          {/* Standby Feature Summary */}
          <div className="tactical-box p-3 border-dashed border-cyan-500/30 text-[11px] leading-relaxed text-slate-400">
            <div className="text-[#00E5FF] font-bold text-xs mb-1 tracking-wider flex items-center gap-1.5">
              <Navigation className="w-3.5 h-3.5 text-[#00E5FF]" /> TAKTİK SAR & DAĞ ANALİZİ
            </div>
            Haritadan veya sol listeden herhangi bir saha üyesini seçtiğinizde:
            <ul className="mt-1.5 space-y-1.5 text-[10px] text-slate-300 list-disc list-inside">
              <li><strong className="text-white">🛰️ İHA FLIR Keşfi:</strong> Termal ve gece görüş vizörü</li>
              <li><strong className="text-white">📄 Görev Brifingi:</strong> Tek tuşla resmi A4 PDF çıkartma</li>
              <li><strong className="text-white">🔋 Hayatta Kalma Sayacı:</strong> Pil & hipotermi süresi</li>
              <li><strong className="text-white">⚡ Geofencing:</strong> Uçurum ve çığ bölgesi erken uyarısı</li>
              <li><strong className="text-white">⏱️ Zaman Tüneli:</strong> 24 saatlik operasyon oynatıcısı</li>
            </ul>
          </div>

          {/* Quick Standby Actions */}
          <div className="flex flex-col gap-1.5 mt-auto">
            <div className="text-[10px] text-slate-500 tracking-widest uppercase">OPERASYONEL YÖNETİM</div>
            <button
              onClick={() => {
                onOpenDispatchLog();
                soundFx.playSelect();
              }}
              className="tactical-btn py-2 text-xs flex items-center justify-center gap-2 text-cyan-300 border-cyan-500/60 bg-cyan-950/40"
            >
              <ClipboardList className="w-3.5 h-3.5 text-cyan-400" /> HAREKAT GÖREV GÜNLÜĞÜ & SEVK
            </button>
            <div className="text-[10px] text-slate-500 tracking-widest uppercase mt-1">HIZLI ODAKLANMA</div>
            <button
              onClick={() => onCenterTarget([38.43, 27.18], 12)}
              className="tactical-btn py-2 text-xs flex items-center justify-center gap-2"
            >
              <Compass className="w-3.5 h-3.5" /> İZMİR MERKEZ SEKTÖRÜ
            </button>
            <button
              onClick={() => onCenterTarget([39.0, 35.0], 6)}
              className="tactical-btn py-2 text-xs flex items-center justify-center gap-2 text-slate-300 border-slate-700 hover:text-white"
            >
              <Crosshair className="w-3.5 h-3.5 text-cyan-400" /> TÜRKİYE KUŞBAKIŞI
            </button>
          </div>

        </div>

      </aside>
    );
  }

  // USER SELECTED: FULL TACTICAL SAR COCKPIT
  return (
    <aside className={`w-88 h-full bg-[#02050D] border-l flex flex-col font-tactical select-none z-40 ${
      isLiveSos ? 'border-red-500 shadow-[-5px_0_20px_rgba(239,68,68,0.25)]' : 'border-[#00E5FF]/30'
    }`}>
      
      {/* 1. Header with Status */}
      <div className={`h-11 px-3 flex items-center justify-between border-b ${
        isLiveSos ? 'bg-red-950 border-red-500' : 'bg-[#040A18] border-cyan-500/30'
      }`}>
        <div className="flex items-center gap-2 min-w-0">
          <span className={`w-2.5 h-2.5 rounded-none ${
            isLiveSos ? 'bg-red-500 animate-ping' : signalInfo.isLost ? 'bg-amber-500 animate-pulse' : 'bg-[#00E5FF]'
          }`} />
          <h2 className="text-xs font-black tracking-widest text-white uppercase truncate">
            {isLiveSos ? '🚨 ACİL DURUM VAKASI' : 'KULLANICI KOKPİTİ'}: <span className="text-[#00E5FF]">{user.name.split(' ')[0]}</span>
          </h2>
        </div>

        <button
          onClick={onClose}
          className="text-slate-400 hover:text-white p-1 transition-colors cursor-pointer"
          title="Kokpiti Kapat"
        >
          <X className="w-4 h-4" />
        </button>
      </div>

      {/* 2. Cockpit Scrollable Body */}
      <div className="p-3 flex flex-col gap-2.5 flex-1 overflow-y-auto custom-scrollbar">
        
        {/* User Identity Card with Photo */}
        <div className={`p-2.5 flex items-center gap-3 border ${
          isLiveSos ? 'tactical-box-red' : 'tactical-box-orange'
        }`}>
          {user.avatar ? (
            <img 
              src={user.avatar} 
              alt={user.name} 
              className={`w-11 h-11 rounded-none object-cover border flex-shrink-0 ${
                isLiveSos ? 'border-red-500 shadow-[0_0_10px_rgba(239,68,68,0.6)]' : 'border-[#FF4D26]'
              }`}
            />
          ) : (
            <div className={`w-11 h-11 rounded-none border flex items-center justify-center font-bold text-sm flex-shrink-0 ${
              isLiveSos ? 'border-red-500 bg-red-950 text-red-200' : 'border-[#FF4D26] bg-[#120705] text-[#FF6E40]'
            }`}>
              {user.initials}
            </div>
          )}

          <div className="min-w-0 flex-1">
            <div className="text-xs font-bold text-white uppercase truncate tracking-wider">
              {user.name}
            </div>
            <div className="text-[10px] text-[#FF6E40] tracking-wider truncate">
              {user.team}
            </div>
            <div className="text-[9px] text-slate-400 truncate font-mono">
              {user.role || 'SAHA ÜYESİ'}
            </div>
          </div>
        </div>

        {/* --- FEATURE 3: SİNYAL KAYBI (LKP) & SAR ARAMA ÇEMBERİ KARTI --- */}
        {signalInfo.isLost && searchZone && (
          <div className="bg-amber-950/40 border border-amber-600/90 p-2.5 text-[10px] text-amber-200 flex flex-col gap-1.5 shadow-[0_0_15px_rgba(245,158,11,0.15)]">
            <div className="flex items-center justify-between font-bold text-amber-300 tracking-wider">
              <span className="flex items-center gap-1.5">
                <AlertTriangle className="w-3.5 h-3.5 text-amber-400 animate-pulse" />
                SİNYAL KESİNTİSİ (LKP PROTOKOLÜ)
              </span>
              <span className="text-[9px] text-amber-400 font-mono">
                {signalInfo.elapsedText}
              </span>
            </div>
            <div className="text-[9px] text-slate-300 leading-normal">
              Haritada sarı kesik çizgili <strong className="text-amber-300">OLASI SAR ARAMA ÇEMBERİ</strong> aktif edildi:
            </div>
            <div className="grid grid-cols-2 gap-1 font-mono text-[9px] bg-black/40 p-1.5 border border-amber-600/40">
              <div>ÇAP: <span className="text-white font-bold">{searchZone.radiusMeters} metre</span></div>
              <div>ALAN: <span className="text-amber-300 font-bold">~{searchZone.areaKm2} km²</span></div>
            </div>
          </div>
        )}

        {/* 2x2 Telemetry Grid */}
        <div className="grid grid-cols-2 gap-1.5">
          <div className="tactical-box p-2">
            <div className="text-[9px] text-cyan-400 font-bold tracking-wider uppercase">KOORDİNAT</div>
            <div className="text-xs font-bold text-white mt-0.5 font-mono truncate">
              {user.hasCoords ? `${user.lat.toFixed(4)}, ${user.lng.toFixed(4)}` : 'SİNYAL YOK'}
            </div>
          </div>

          <div className="tactical-box p-2">
            <div className="text-[9px] text-cyan-400 font-bold tracking-wider uppercase">SİNYAL DURUMU</div>
            <div className="text-xs font-bold mt-0.5 font-mono truncate" style={{ color: signalInfo.color }}>
              {signalInfo.status === 'LIVE' ? 'CANLI GPS' : signalInfo.elapsedText}
            </div>
          </div>

          <div className="tactical-box p-2">
            <div className="text-[9px] text-cyan-400 font-bold tracking-wider uppercase">ANLIK RAKIM</div>
            <div className="text-xs font-bold text-amber-300 mt-0.5 font-mono">
              {user.altitude > 0 ? `${user.altitude} METRE` : '0 m'}
            </div>
          </div>

          <div className="tactical-box p-2">
            <div className="text-[9px] text-cyan-400 font-bold tracking-wider uppercase">BATARYA & KAN</div>
            <div className="text-xs font-bold text-emerald-400 mt-0.5 font-mono flex items-center gap-1.5">
              <span>%{user.battery}</span>
              {user.kanGrubu && <span className="text-red-400 font-bold">({user.kanGrubu})</span>}
            </div>
          </div>
        </div>

        {/* --- AKILLI ARAMA ALANI (SMART DIRECTIONAL SEARCH CONE HUD) --- */}
        {smartSearchCone && (
          <SmartSearchConeHUD 
            smartSearchCone={smartSearchCone} 
            coneParams={coneParams} 
            onUpdateConeParams={onUpdateConeParams} 
          />
        )}

        {/* --- FEATURE 5: TAKTİK HAYATTA KALMA SAYACI & PİL TÜKENME HUD --- */}
        <SurvivalCountdownHUD survival={survivalMetrics} />

        {/* --- FEATURE 2: 3D YÜKSEKLİK & EĞİM KESİT PROFİLİ HUD --- */}
        <ElevationProfileHUD profile={elevationProfile} />

        {/* --- FEATURE 2: DAĞ MİKRO-METEOROLOJİSİ & RÜZGAR GÜLÜ --- */}
        <TacticalWeatherHUD weather={microWeather} sectorName={analysis?.sectorName} />

        {/* DETAILED LOCATION & MEVKİİ ANALYSIS */}
        <div className="tactical-box p-2.5 flex flex-col gap-1.5 text-[10px]">
          <div className="text-[9px] text-cyan-400 font-bold tracking-widest uppercase flex items-center justify-between border-b border-slate-800 pb-1">
            <span className="flex items-center gap-1">
              <MapPin className="w-3 h-3 text-[#FF4D26]" /> MEVKİİ & ÇEVRE ANALİZİ
            </span>
            <span className="text-[8.5px] text-amber-400 font-mono">
              RİSK: {analysis?.hazardLevel || 'ORTA'}
            </span>
          </div>

          {/* Named Sector / Mevkii */}
          <div className="flex items-start justify-between gap-1 pt-0.5">
            <span className="text-slate-400">TESPİT EDİLEN MEVKİİ:</span>
            <span className="text-white font-bold text-right text-[11px] text-[#00E5FF]">
              {analysis?.sectorName}
            </span>
          </div>

          {/* Terrain / Slope Type */}
          <div className="flex items-center justify-between text-slate-400">
            <span>ARAZİ TİPİ:</span>
            <span className="text-amber-300 font-semibold">{analysis?.terrainType}</span>
          </div>

          {/* Nearest Summit / Water Landmark */}
          {analysis?.nearestLandmark && (
            <div className="flex items-start justify-between text-slate-400 pt-1 border-t border-slate-800/60">
              <span>EN YAKIN ZİRVE:</span>
              <span className="text-slate-200 font-semibold text-right">
                {analysis.nearestLandmark.name} (~{(analysis.nearestLandmark.distMeters / 1000).toFixed(1)} km)
              </span>
            </div>
          )}

          {/* Nearest Hospital / Evac */}
          {analysis?.nearestHospital && (
            <div className="flex items-start justify-between text-slate-400">
              <span>ACİL TAHLİYE / AFAD:</span>
              <span className="text-emerald-400 font-semibold text-right">
                {analysis.nearestHospital.name} (~{(analysis.nearestHospital.distMeters / 1000).toFixed(1)} km)
              </span>
            </div>
          )}
        </div>

        {/* --- FEATURE 1: EN YAKIN EKİP ARKADAŞLARI & TAKTİK İNTİKAL KORİDORU --- */}
        {analysis?.nearestComrades && analysis.nearestComrades.length > 0 && (
          <div className="tactical-box p-2.5 flex flex-col gap-1.5">
            <div className="text-[9px] text-cyan-400 font-bold tracking-widest uppercase flex items-center justify-between border-b border-slate-800 pb-1">
              <span className="flex items-center gap-1">
                <Users className="w-3 h-3 text-cyan-400" /> EN YAKIN EKİPLER (İNTİKAL)
              </span>
              <span className="text-slate-500 font-mono text-[8.5px]">PUSULA & MESAFE</span>
            </div>

            <div className="space-y-1">
              {analysis.nearestComrades.map((comrade) => (
                <div
                  key={comrade.id}
                  onClick={() => {
                    onSelectUser(allUsers.find(u => u.id === comrade.id));
                    soundFx.playSelect();
                  }}
                  className="p-1.5 bg-[#030917] hover:bg-[#071329] border border-slate-800 hover:border-cyan-500/50 flex items-center justify-between cursor-pointer transition-colors text-[10px]"
                >
                  <div className="flex items-center gap-2 min-w-0">
                    <span className="text-white font-bold truncate max-w-[110px]">
                      {comrade.name}
                    </span>
                    <span className="text-amber-400 font-mono text-[8.5px]">
                      {comrade.bearing?.short} ({comrade.bearing?.degrees}°)
                    </span>
                  </div>

                  <div className="text-right flex items-center gap-1.5 font-mono">
                    <span className="text-[#00E5FF] font-bold">
                      {comrade.distFormatted}
                    </span>
                    <span className="text-slate-500 text-[8.5px]">
                      (~{comrade.estWalkMinutes}dk)
                    </span>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handleDispatchNearest(comrade);
                      }}
                      className="text-cyan-400 hover:text-white p-0.5 hover:bg-cyan-950 border border-cyan-500/30 ml-1"
                      title="Bu ekibe kilitlen"
                    >
                      <ArrowUpRight className="w-3 h-3" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* 3. Control Commands (REVAMPED WITH UAV & PDF BRIEFING BUTTONS) */}
        <div className="flex flex-col gap-1.5 mt-auto pt-2 border-t border-slate-800">
          <div className="text-[10px] text-cyan-400 font-bold tracking-widest uppercase">
            SAHA KONTROL KOMUTLARI
          </div>

          {/* Action A: Launch UAV Reconnaissance (FEATURE 1) */}
          {user.hasCoords && (
            <button
              onClick={() => {
                onLaunchUav(user);
                soundFx.playDroneLaunch();
              }}
              className="tactical-btn py-2 text-xs flex items-center justify-center gap-2 text-cyan-300 hover:text-white"
            >
              <PlaneTakeoff className="w-4 h-4 text-[#00E5FF] animate-pulse" />
              <span>🛰️ İHA TERMAL KEŞİF BAŞLAT (FLIR)</span>
            </button>
          )}

          {/* Action B: Official Incident Briefing (FEATURE 2) */}
          <button
            onClick={() => {
              onOpenBriefing(user);
              soundFx.playPrint();
            }}
            className="tactical-btn py-2 text-xs flex items-center justify-center gap-2 text-amber-300 hover:text-white border-amber-600/50"
          >
            <FileText className="w-4 h-4 text-amber-400" />
            <span>📄 GÖREV BRİFİNGİ (A4 / PDF YAZDIR)</span>
          </button>

          {/* Action C: Open Dispatch Mission Log */}
          <button
            onClick={() => {
              onOpenDispatchLog();
              soundFx.playSelect();
            }}
            className="tactical-btn py-2 text-xs flex items-center justify-center gap-2 text-cyan-300 hover:text-white border-cyan-500/60 bg-cyan-950/40"
          >
            <ClipboardList className="w-4 h-4 text-[#00E5FF]" />
            <span>📋 GÖREV GÜNLÜĞÜ & EKİP SEVKİ</span>
          </button>

          {/* Command 1: Lock and Zoom */}
          {user.hasCoords && (
            <button
              onClick={() => {
                onCenterTarget(user.coords, 16);
                soundFx.playTargetLock();
              }}
              className="tactical-btn py-2 text-xs flex items-center justify-center gap-2"
            >
              <Crosshair className="w-4 h-4 text-[#00E5FF]" /> HEDEFE KİLİTLEN (16x ZOOM)
            </button>
          )}

          {/* Command 2: Copy Coordinates */}
          {user.hasCoords && (
            <button
              onClick={handleCopyCoords}
              className="tactical-btn py-2 text-xs flex items-center justify-center gap-2 text-slate-300 border-slate-700 hover:text-white"
            >
              {copied ? <Check className="w-4 h-4 text-emerald-400" /> : <Copy className="w-4 h-4 text-cyan-400" />}
              <span>{copied ? 'KOORDİNAT KOPYALANDI!' : 'KOORDİNATI KOPYALA / PAYLAŞ'}</span>
            </button>
          )}

          {/* Command 3: Direct Emergency Phone Call */}
          {user.phone && (
            <a
              href={`tel:${user.phone}`}
              className="tactical-btn py-2 text-xs flex items-center justify-center gap-2 text-emerald-400 border-emerald-600/50 hover:bg-emerald-950/40"
            >
              <PhoneCall className="w-4 h-4" /> ACİL TELEFON ARA: {user.phone}
            </a>
          )}

          {/* Command 4: Test / Toggle SOS */}
          <button
            onClick={() => {
              onToggleUserTestSos(user.id);
              soundFx.playSelect();
            }}
            className={`py-2 text-xs flex items-center justify-center gap-2 font-tactical font-bold transition-all cursor-pointer border ${
              isLiveSos
                ? 'bg-red-700 hover:bg-red-600 text-white border-red-400 shadow-[0_0_12px_rgba(239,68,68,0.5)]'
                : 'tactical-btn-orange'
            }`}
          >
            <Zap className={`w-4 h-4 ${isLiveSos ? 'text-yellow-300 fill-yellow-300 animate-spin' : 'text-[#FF4D26]'}`} />
            <span>{isLiveSos ? 'ACİL DURUM ALARMINI SÖNDÜR' : 'ACİL DURUM (SOS) TEST SİNYALİ GÖNDER'}</span>
          </button>
        </div>

      </div>

    </aside>
  );
}
