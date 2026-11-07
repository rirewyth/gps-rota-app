import React, { useState } from 'react';
import { 
  AlertOctagon, 
  MapPin, 
  Mountain, 
  Battery, 
  PhoneCall, 
  Crosshair, 
  CheckCircle2,
  X,
  ChevronDown,
  ChevronUp,
  Heart,
  Radio
} from 'lucide-react';
import { soundFx } from '../audio';

export default function SosAlertBanner({
  sosUsers = [],
  onCenterTarget = () => {},
  onDismissSos = () => {}
}) {
  const [selectedIdx, setSelectedIdx] = useState(0);
  const [isMinimized, setIsMinimized] = useState(false);

  if (!sosUsers || sosUsers.length === 0) return null;

  const activeUser = sosUsers[selectedIdx] || sosUsers[0];

  return (
    <div className="absolute top-14 left-1/2 transform -translate-x-1/2 w-[420px] z-[500] pointer-events-auto select-none font-tactical animate-in fade-in slide-in-from-top-3 duration-200">
      
      {/* TACTICAL EMERGENCY BOX (IMAGE 2 SHARP RECTANGULAR STYLE) */}
      <div className="bg-[#150406]/98 border border-red-500 shadow-[0_0_30px_rgba(239,68,68,0.5)]">
        
        {/* Top Header Bar */}
        <div className="bg-red-950 px-3 py-1.5 flex items-center justify-between border-b border-red-700">
          <div className="flex items-center gap-2">
            <span className="w-2.5 h-2.5 bg-red-500 animate-ping rounded-none" />
            <h3 className="text-xs font-black text-white tracking-widest uppercase flex items-center gap-2">
              KRİTİK ACİL DURUM (SOS) ÇAĞRISI
              <span className="bg-red-600 px-1.5 py-0.2 text-[10px] font-mono">
                [{sosUsers.length}]
              </span>
            </h3>
          </div>

          <div className="flex items-center gap-1">
            <button
              onClick={() => setIsMinimized(!isMinimized)}
              className="text-red-300 hover:text-white p-0.5 cursor-pointer"
              title={isMinimized ? "Genişlet" : "Daralt"}
            >
              {isMinimized ? <ChevronDown className="w-3.5 h-3.5" /> : <ChevronUp className="w-3.5 h-3.5" />}
            </button>
            <button
              onClick={() => onDismissSos(activeUser.id)}
              className="text-red-400 hover:text-white p-0.5 cursor-pointer"
              title="Bu Alarmı Kapat"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          </div>
        </div>

        {!isMinimized && (
          <div className="p-3 flex flex-col gap-2.5 bg-[#120305]">
            
            {/* Multi SOS Switcher */}
            {sosUsers.length > 1 && (
              <div className="flex gap-1 overflow-x-auto pb-1 text-[10px] font-mono">
                {sosUsers.map((u, idx) => (
                  <button
                    key={u.id}
                    onClick={() => setSelectedIdx(idx)}
                    className={`px-2 py-0.5 border cursor-pointer transition-all ${
                      selectedIdx === idx
                        ? 'bg-red-600 text-white border-red-400 font-bold'
                        : 'bg-red-950/80 text-red-300 border-red-900 hover:bg-red-900'
                    }`}
                  >
                    {u.name.split(' ')[0]}
                  </button>
                ))}
              </div>
            )}

            {/* User Identity Card */}
            <div className="bg-red-950/60 border border-red-800 p-2.5 flex items-center gap-3">
              {activeUser.avatar ? (
                <img 
                  src={activeUser.avatar} 
                  alt={activeUser.name} 
                  className="w-11 h-11 rounded-none object-cover border border-red-500 shadow-md flex-shrink-0"
                />
              ) : (
                <div className="w-11 h-11 rounded-none bg-red-950 border border-red-500 flex items-center justify-center text-red-200 font-bold text-sm font-mono flex-shrink-0">
                  {activeUser.initials}
                </div>
              )}

              <div className="flex-1 min-w-0">
                <div className="text-white font-bold text-xs leading-tight uppercase truncate">
                  {activeUser.name}
                </div>
                <div className="text-[10px] text-red-300 truncate">
                  {activeUser.team}
                </div>
                {activeUser.kanGrubu && (
                  <div className="text-[10px] text-red-400 font-mono mt-0.5">
                    KAN GRUBU: {activeUser.kanGrubu}
                  </div>
                )}
              </div>
            </div>

            {/* Telemetry info */}
            <div className="grid grid-cols-2 gap-1.5 text-[10px] text-red-200 bg-red-950/40 p-2 border border-red-900/60 font-mono">
              <div className="flex items-center gap-1.5">
                <MapPin className="w-3.5 h-3.5 text-red-400" />
                <span className="truncate">
                  {activeUser.hasCoords 
                    ? `${activeUser.lat.toFixed(4)}, ${activeUser.lng.toFixed(4)}` 
                    : 'KONUM BEKLENİYOR'}
                </span>
              </div>
              <div className="flex items-center gap-1.5">
                <Mountain className="w-3.5 h-3.5 text-amber-400" />
                <span>{activeUser.altitude}m RAKIM</span>
              </div>
              <div className="flex items-center gap-1.5">
                <Battery className={`w-3.5 h-3.5 ${activeUser.battery < 25 ? 'text-red-400' : 'text-emerald-400'}`} />
                <span>%{activeUser.battery} BATARYA</span>
              </div>
              <div className="flex items-center gap-1.5">
                <PhoneCall className="w-3.5 h-3.5 text-cyan-400" />
                <span className="truncate">{activeUser.phone || 'TEL YOK'}</span>
              </div>
            </div>

            {/* Action buttons */}
            <div className="grid grid-cols-2 gap-1.5 pt-1">
              {activeUser.hasCoords && (
                <button
                  onClick={() => {
                    onCenterTarget(activeUser.coords, 15);
                    soundFx.playTargetLock();
                  }}
                  className="bg-[#050B17] hover:bg-slate-900 text-[#00E5FF] border border-cyan-500/50 py-1.5 text-xs font-bold flex items-center justify-center gap-1.5 cursor-pointer"
                >
                  <Crosshair className="w-3.5 h-3.5 text-[#00E5FF]" /> HEDEFE KİLİTLEN
                </button>
              )}

              <button
                onClick={() => {
                  onDismissSos(activeUser.id);
                  soundFx.playSelect();
                }}
                className={`bg-emerald-950/90 hover:bg-emerald-900 border border-emerald-600/70 text-emerald-200 py-1.5 text-xs font-bold flex items-center justify-center gap-1.5 cursor-pointer ${
                  !activeUser.hasCoords ? 'col-span-2' : ''
                }`}
              >
                <CheckCircle2 className="w-3.5 h-3.5" /> BİLDİRİMİ SÖNDÜR
              </button>
            </div>

          </div>
        )}

      </div>
    </div>
  );
}
