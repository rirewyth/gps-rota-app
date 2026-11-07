import React from 'react';
import { 
  Battery, 
  Mountain, 
  Gauge, 
  Radio, 
  MapPin, 
  Compass, 
  X, 
  PhoneCall, 
  Heart,
  Zap,
  AlertTriangle
} from 'lucide-react';
import { soundFx } from '../audio';

export default function TeamCard({
  user = null,
  onClose = () => {},
  onCenterTarget = () => {},
  onToggleUserTestSos = () => {}
}) {
  if (!user) return null;

  const isLiveSos = Boolean(user.isFreshSos || user.isTestSos);

  return (
    <div className="absolute right-80 bottom-20 w-84 z-[500] pointer-events-auto select-none animate-in fade-in slide-in-from-bottom-4 duration-200">
      <div className={`backdrop-blur-xl border rounded-xl p-4 shadow-2xl flex flex-col gap-3 tactical-border-bracket ${
        isLiveSos 
          ? 'bg-[#150406]/95 border-red-500 shadow-[0_0_25px_rgba(239,68,68,0.4)]' 
          : 'bg-[#050A17]/95 border-[#FF4D26]/40 shadow-[#FF4D26]/10'
      }`}>
        
        {/* Header with Photo */}
        <div className="flex items-center justify-between border-b border-slate-800 pb-3">
          <div className="flex items-center gap-3">
            {user.avatar ? (
              <img 
                src={user.avatar} 
                alt={user.name} 
                className={`w-11 h-11 rounded-full object-cover border-2 shadow-md ${
                  isLiveSos 
                    ? 'border-red-500 shadow-red-500/50' 
                    : 'border-[#FF4D26] shadow-[#FF4D26]/30'
                }`}
              />
            ) : (
              <div className={`w-11 h-11 rounded-full border-2 flex items-center justify-center font-bold text-sm font-mono ${
                isLiveSos
                  ? 'bg-red-950 border-red-500 text-red-200'
                  : 'bg-slate-800 border-[#FF4D26]/50 text-[#FF6E40]'
              }`}>
                {user.initials}
              </div>
            )}
            
            <div className="min-w-0">
              <h3 className="text-xs font-bold text-slate-100 leading-tight truncate max-w-[170px]">{user.name}</h3>
              <span className="text-[10px] text-[#FF6E40] font-mono truncate block">{user.team}</span>
              {user.username && <span className="text-[9px] text-slate-500 font-mono block">@{user.username}</span>}
            </div>
          </div>

          <button
            onClick={onClose}
            className="text-slate-500 hover:text-slate-300 p-1 rounded hover:bg-slate-800 transition-colors cursor-pointer"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Telemetry Stats */}
        <div className="grid grid-cols-2 gap-2 text-xs font-mono">
          <div className="bg-slate-900/60 p-2 rounded border border-slate-800/80">
            <div className="text-[10px] text-slate-500 font-bold flex items-center gap-1">
              <Mountain className="w-3 h-3 text-amber-400" /> RAKIM
            </div>
            <div className="text-sm font-bold text-slate-200 mt-0.5">{user.altitude} m</div>
          </div>

          <div className="bg-slate-900/60 p-2 rounded border border-slate-800/80">
            <div className="text-[10px] text-slate-500 font-bold flex items-center gap-1">
              <Battery className={`w-3 h-3 ${user.battery < 25 ? 'text-red-400' : 'text-emerald-400'}`} /> BATARYA
            </div>
            <div className="text-sm font-bold text-slate-200 mt-0.5">%{user.battery}</div>
          </div>

          {user.kanGrubu && (
            <div className="bg-slate-900/60 p-2 rounded border border-slate-800/80">
              <div className="text-[10px] text-slate-500 font-bold flex items-center gap-1">
                <Heart className="w-3 h-3 text-red-400" /> KAN GRUBU
              </div>
              <div className="text-sm font-bold text-red-400 mt-0.5">{user.kanGrubu}</div>
            </div>
          )}

          <div className="bg-slate-900/60 p-2 rounded border border-slate-800/80">
            <div className="text-[10px] text-slate-500 font-bold flex items-center gap-1">
              <Radio className="w-3 h-3 text-cyan-400" /> SİNYAL
            </div>
            <div className="text-xs font-bold text-cyan-300 mt-0.5">{user.signalStrength}</div>
          </div>
        </div>

        {/* Coordinates readout or Offline note */}
        <div className="bg-slate-900/40 p-2 rounded border border-slate-800/80 flex items-center justify-between text-[11px] font-mono text-slate-400">
          {user.hasCoords ? (
            <>
              <span className="flex items-center gap-1 text-slate-200">
                <MapPin className="w-3.5 h-3.5 text-[#FF4D26]" />
                {user.lat.toFixed(4)}° N, {user.lng.toFixed(4)}° E
              </span>
              <span className="text-[10px] text-emerald-400 font-bold">GPS AKTİF</span>
            </>
          ) : (
            <span className="text-slate-500 text-[10px]">Cihaz GPS konumu henüz paylaşılmadı</span>
          )}
        </div>

        {/* Phone Contact */}
        {user.phone && (
          <div className="flex items-center justify-between text-xs font-mono text-slate-300 bg-slate-900/40 p-2 rounded border border-slate-800/80">
            <span className="text-slate-500 text-[10px]">İLETİŞİM:</span>
            <a href={`tel:${user.phone}`} className="text-[#FF6E40] hover:underline flex items-center gap-1 font-bold">
              <PhoneCall className="w-3 h-3" /> {user.phone}
            </a>
          </div>
        )}

        {/* Actions Grid */}
        <div className="grid grid-cols-2 gap-2 pt-1">
          {user.hasCoords && (
            <button
              onClick={() => {
                onCenterTarget(user.coords);
                soundFx.playSelect();
              }}
              className="bg-[#FF4D26] hover:bg-[#FF6E40] text-white font-bold py-2 rounded-lg text-xs font-mono flex items-center justify-center gap-1.5 transition-colors cursor-pointer shadow-lg shadow-[#FF4D26]/20"
            >
              <Compass className="w-3.5 h-3.5" /> ODAKLAN
            </button>
          )}

          <button
            onClick={() => {
              onToggleUserTestSos(user.id);
              soundFx.playSelect();
            }}
            className={`py-2 rounded-lg text-xs font-mono font-bold flex items-center justify-center gap-1.5 transition-colors cursor-pointer border ${
              !user.hasCoords ? 'col-span-2' : ''
            } ${
              isLiveSos
                ? 'bg-red-700 hover:bg-red-600 text-white border-red-400 shadow-md'
                : 'bg-slate-900 hover:bg-slate-800 text-amber-300 border-amber-600/60'
            }`}
          >
            <Zap className={`w-3.5 h-3.5 ${isLiveSos ? 'text-yellow-300 fill-yellow-300' : 'text-amber-400'}`} />
            <span>{isLiveSos ? 'SOS SÖNDÜR' : 'SOS TEST ET'}</span>
          </button>
        </div>

      </div>
    </div>
  );
}
