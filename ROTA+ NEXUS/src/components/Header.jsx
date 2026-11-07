import React, { useState, useEffect } from 'react';
import { 
  Radio, 
  Volume2, 
  VolumeX, 
  AlertTriangle, 
  Users, 
  Clock,
  MapPin,
  Layers,
  Compass,
  RadioTower,
  ShieldCheck,
  ClipboardList
} from 'lucide-react';

export default function Header({
  users = [],
  freshSosCount = 0,
  archiveSosCount = 0,
  dbStatus = { status: 'LIVE', message: '' },
  isMuted = true,
  onToggleMute = () => {},
  onCenterSos = () => {},
  onJumpSector = () => {},
  activeLayer = 'TOPO_ESRI',
  onSelectLayer = () => {},
  onOpenDispatchLog = () => {},
  dispatchedTeamsCount = 3
}) {
  const [time, setTime] = useState(new Date());

  useEffect(() => {
    const timer = setInterval(() => setTime(new Date()), 1000);
    return () => clearInterval(timer);
  }, []);

  const dateStr = time.toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric' });
  const timeStr = time.toLocaleTimeString('tr-TR', { hour12: false });
  const mappedCount = users.filter(u => u.hasCoords).length;

  return (
    <header className="relative z-50 h-12 bg-[#02050D] border-b border-[#00E5FF]/30 px-4 flex items-center justify-between select-none font-tactical">
      
      {/* LEFT: BRAND */}
      <div className="flex items-center gap-4">
        <div className="flex items-center gap-2">
          <h1 className="text-sm font-black tracking-widest text-white flex items-center gap-1">
            ROTA <span className="text-[#FF4D26] font-bold">+</span> NEXUS
          </h1>
          <span className="text-[10px] text-cyan-400/80 border border-cyan-500/30 px-1.5 py-0.2 tracking-wider">
            KOMUTA MERKEZİ
          </span>
        </div>
      </div>

      {/* CENTER: MODE TITLE */}
      <div className="hidden lg:flex items-center gap-2">
        <span className="text-xs font-bold text-[#00E5FF] tracking-[0.25em] flex items-center gap-2">
          <span className="w-2 h-2 rounded-full bg-[#00E5FF] animate-ping" />
          CANLI OPERASYON & SAHA TELEMETRİSİ
        </span>
      </div>

      {/* RIGHT: REAL STATUS INDICATORS, SECTORS, LAYERS & CLOCK */}
      <div className="flex items-center gap-3">
        
        {/* CLEAN STATUS INDICATORS (METEO & KANDILLI REMOVED PER USER REQUEST!) */}
        <div className="hidden xl:flex items-center gap-3 text-[10px] tracking-wider border-r border-slate-800 pr-3">
          <div className="flex items-center gap-1.5 text-slate-400">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
            <span className="text-slate-300">FİREBASE CANLI</span>
          </div>
          <div className="flex items-center gap-1.5 text-slate-400">
            <span className="w-1.5 h-1.5 rounded-full bg-[#00E5FF]" />
            <span className="text-[#00E5FF]">{mappedCount} GPS CİHAZ</span>
          </div>
        </div>

        {/* MAP TERRAIN LAYER SELECTOR (DOCKED CLEANLY IN HEADER) */}
        <div className="flex items-center gap-1 bg-[#040A18] border border-cyan-500/30 p-0.5 text-[10px]">
          {[
            { id: 'TOPO_ESRI', label: 'ESRI TOPO' },
            { id: 'OPENTOPO', label: 'İZOLİPS' },
            { id: 'SATELLITE_HYBRID', label: 'UYDU' },
            { id: 'TACTICAL_DARK', label: 'GECE' }
          ].map((layer) => (
            <button
              key={layer.id}
              onClick={() => onSelectLayer(layer.id)}
              className={`px-1.5 py-0.5 tracking-wider transition-all cursor-pointer ${
                activeLayer === layer.id
                  ? 'bg-[#00E5FF]/20 text-[#00E5FF] font-bold border border-[#00E5FF]/60 shadow-[0_0_8px_rgba(0,229,255,0.3)]'
                  : 'text-slate-400 hover:text-white'
              }`}
            >
              {layer.label}
            </button>
          ))}
        </div>

        {/* QUICK SECTORS */}
        <div className="flex items-center gap-1 text-[10px]">
          <button
            onClick={() => onJumpSector([38.43, 27.18], 12)}
            className="px-2 py-0.5 bg-[#FF4D26]/20 border border-[#FF4D26]/50 text-[#FF6E40] hover:bg-[#FF4D26]/30 font-bold transition-all cursor-pointer"
          >
            İZMİR ({mappedCount})
          </button>
          <button
            onClick={() => onJumpSector([39.0, 35.0], 6)}
            className="px-2 py-0.5 bg-slate-900 border border-slate-700 text-slate-300 hover:text-white transition-all cursor-pointer"
          >
            TÜRKİYE
          </button>
        </div>

        {/* GÖREV GÜNLÜĞÜ & SEVK MODALI BUTONU */}
        <button
          onClick={onOpenDispatchLog}
          className="px-2.5 py-0.5 bg-cyan-950/80 border border-cyan-400 text-cyan-200 hover:bg-cyan-900 font-bold text-[10px] flex items-center gap-1.5 shadow-[0_0_10px_rgba(0,229,255,0.3)] cursor-pointer"
          title="Harekat Görev Günlüğü & Sevk Edilen Ekipler / Ekipmanlar"
        >
          <ClipboardList className="w-3.5 h-3.5 text-cyan-400" />
          <span>GÖREV GÜNLÜĞÜ & SEVK ({dispatchedTeamsCount} TİM)</span>
        </button>

        {/* SOS STATUS BADGE */}
        {freshSosCount > 0 ? (
          <button
            onClick={onCenterSos}
            className="px-2 py-0.5 bg-red-950 border border-red-500 text-red-300 font-bold text-[10px] flex items-center gap-1 shadow-[0_0_12px_rgba(239,68,68,0.5)] animate-pulse cursor-pointer"
          >
            <AlertTriangle className="w-3 h-3 text-red-400" /> {freshSosCount} CANLI SOS
          </button>
        ) : null}

        {/* MILITARY TIMESTAMP */}
        <div className="text-[11px] font-bold text-slate-300 tracking-wider flex items-center gap-1 bg-[#040A18] px-2 py-0.5 border border-slate-800">
          <span className="text-slate-500">{dateStr}</span>
          <span className="text-cyan-400">{timeStr}</span>
          <span className="text-[9px] text-[#FF4D26]">TSİ</span>
        </div>

        {/* AUDIO SIREN TOGGLE */}
        <button
          onClick={onToggleMute}
          className={`px-2 py-0.5 border text-[10px] font-bold flex items-center gap-1 transition-all cursor-pointer ${
            !isMuted 
              ? 'bg-red-950/80 border-red-500 text-red-300 shadow-[0_0_10px_rgba(239,68,68,0.4)] animate-pulse' 
              : 'bg-slate-900/60 border-slate-800 text-slate-400 hover:text-slate-200'
          }`}
          title={isMuted ? "Siren Sesini Aç" : "Siren Sesini Kapat"}
        >
          {!isMuted ? <Volume2 className="w-3 h-3 text-red-400" /> : <VolumeX className="w-3 h-3 text-slate-500" />}
          <span>{!isMuted ? 'SİREN: AÇIK' : 'SESSİZ'}</span>
        </button>

      </div>

    </header>
  );
}
