import React, { useState } from 'react';
import { 
  Users, 
  Search, 
  Battery, 
  Mountain, 
  MapPin, 
  Zap, 
  AlertTriangle,
  Radio,
  RadioTower
} from 'lucide-react';
import { soundFx } from '../audio';

export default function OperationsPanel({
  users = [],
  selectedUser = null,
  onSelectUser = () => {},
  onCenterUser = () => {},
  onToggleUserTestSos = () => {}
}) {
  const [activeTab, setActiveTab] = useState('MAPPED'); // MAPPED, ALL, LIVE_SOS, ARCHIVE
  const [searchQuery, setSearchQuery] = useState('');

  const freshSosCount = users.filter(u => u.isFreshSos || u.isTestSos).length;
  const archiveSosCount = users.filter(u => u.isArchiveSos && !u.isFreshSos && !u.isTestSos).length;
  const mappedCount = users.filter(u => u.hasCoords).length;

  // Filter users based on tab and search
  const filteredUsers = users.filter((u) => {
    const matchesSearch = 
      (u.name && u.name.toLowerCase().includes(searchQuery.toLowerCase())) ||
      (u.username && u.username.toLowerCase().includes(searchQuery.toLowerCase())) ||
      (u.team && u.team.toLowerCase().includes(searchQuery.toLowerCase()));
    
    if (!matchesSearch) return false;

    if (activeTab === 'LIVE_SOS') return Boolean(u.isFreshSos || u.isTestSos);
    if (activeTab === 'ARCHIVE') return Boolean(u.isArchiveSos && !u.isFreshSos && !u.isTestSos);
    if (activeTab === 'MAPPED') return u.hasCoords;
    return true;
  });

  return (
    <aside className="w-80 h-full bg-[#02050D] border-r border-[#00E5FF]/25 flex flex-col font-tactical select-none z-40">
      
      {/* 1. Header (Image 2 style: CANLI VAKALAR [count]) */}
      <div className="h-10 px-3 bg-[#040A18] border-b border-cyan-500/30 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="w-2 h-2 bg-[#FF4D26] rounded-none animate-pulse" />
          <h2 className="text-xs font-black tracking-widest text-white uppercase flex items-center gap-1.5">
            SAHA EKİP KADROSU
          </h2>
        </div>
        <span className="text-xs font-bold text-[#00E5FF] tracking-wider font-mono">
          [{filteredUsers.length}]
        </span>
      </div>

      {/* 2. Search & Category Tabs */}
      <div className="p-2 border-b border-slate-800 flex flex-col gap-1.5 bg-[#030713]">
        
        {/* Search */}
        <div className="relative">
          <Search className="w-3.5 h-3.5 absolute left-2.5 top-1/2 transform -translate-y-1/2 text-cyan-400" />
          <input
            type="text"
            placeholder="İSİM VEYA KULÜP ARA..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full bg-[#040A18] border border-cyan-500/30 text-xs py-1 pl-8 pr-2 text-white placeholder-slate-500 focus:outline-none focus:border-[#00E5FF] tracking-wider uppercase font-mono"
          />
        </div>

        {/* Sharp Tabs */}
        <div className="grid grid-cols-4 gap-1 text-[10px]">
          {[
            { id: 'MAPPED', label: `HARİTA (${mappedCount})` },
            { id: 'ALL', label: `TÜMÜ (${users.length})` },
            { 
              id: 'LIVE_SOS', 
              label: `SOS (${freshSosCount})`,
              isEmergencyTab: freshSosCount > 0
            },
            { id: 'ARCHIVE', label: `ARŞİV (${archiveSosCount})` }
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => {
                setActiveTab(tab.id);
                soundFx.playSelect();
              }}
              className={`py-1 text-center tracking-wider transition-all cursor-pointer font-bold border ${
                activeTab === tab.id
                  ? (tab.isEmergencyTab
                      ? 'bg-red-950 text-red-200 border-red-500 shadow-[0_0_8px_rgba(239,68,68,0.4)]'
                      : 'bg-[#00E5FF]/20 text-[#00E5FF] border-[#00E5FF]/60 shadow-[0_0_8px_rgba(0,229,255,0.3)]')
                  : 'bg-[#040A18]/60 text-slate-400 border-slate-800 hover:text-white'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>

      </div>

      {/* 3. User Cards List (Image 2 exact card style!) */}
      <div className="flex-1 overflow-y-auto p-2 space-y-1.5 custom-scrollbar">
        {filteredUsers.length === 0 ? (
          <div className="text-center py-12 text-xs text-slate-500 tracking-wider">
            {activeTab === 'LIVE_SOS'
              ? 'AKTİF BİR CANLI ACİL ÇAĞRI BULUNMUYOR.'
              : 'EŞLEŞEN KAYIT BULUNAMADI.'}
          </div>
        ) : (
          filteredUsers.map((user) => {
            const isSelected = selectedUser?.id === user.id;
            const isLiveSos = Boolean(user.isFreshSos || user.isTestSos);
            const isArchive = Boolean(user.isArchiveSos && !isLiveSos);

            return (
              <div
                key={user.id}
                onClick={() => {
                  onSelectUser(user);
                  if (user.hasCoords && user.coords) {
                    onCenterUser(user.coords);
                  }
                  soundFx.playSelect();
                }}
                className={`p-2 transition-all cursor-pointer border flex items-center gap-2.5 ${
                  isLiveSos
                    ? 'bg-red-950/80 border-red-500 shadow-[0_0_12px_rgba(239,68,68,0.3)] animate-pulse'
                    : isSelected
                    ? 'bg-[#00E5FF]/15 border-[#00E5FF] shadow-[0_0_10px_rgba(0,229,255,0.25)]'
                    : isArchive
                    ? 'bg-amber-950/20 border-amber-800/40 hover:bg-amber-950/40'
                    : 'bg-[#040A18]/80 border-cyan-500/20 hover:border-cyan-500/50 hover:bg-[#071329]'
                }`}
              >
                {/* Photo or Initials */}
                {user.avatar ? (
                  <img 
                    src={user.avatar} 
                    alt={user.name} 
                    className={`w-9 h-9 rounded-none object-cover border flex-shrink-0 ${
                      isLiveSos ? 'border-red-500' : isSelected ? 'border-[#00E5FF]' : 'border-slate-700'
                    }`}
                  />
                ) : (
                  <div className={`w-9 h-9 rounded-none border flex items-center justify-center font-bold text-xs flex-shrink-0 ${
                    isLiveSos 
                      ? 'bg-red-950 border-red-500 text-red-300' 
                      : isSelected 
                      ? 'bg-[#00E5FF]/20 border-[#00E5FF] text-[#00E5FF]' 
                      : 'bg-slate-900 border-slate-700 text-slate-400'
                  }`}>
                    {user.initials}
                  </div>
                )}

                {/* Card Content (Image 2 Style) */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between mb-0.5">
                    <span className="text-[9px] text-cyan-400 font-mono tracking-wider">
                      ID: {user.id.substring(0, 8)}
                    </span>
                    {isLiveSos ? (
                      <span className="text-[9px] bg-red-600 text-white font-black px-1 leading-tight animate-bounce">
                        🚨 SOS
                      </span>
                    ) : isArchive ? (
                      <span className="text-[9px] text-amber-400 border border-amber-800 px-1 leading-tight">
                        ARŞİV
                      </span>
                    ) : user.hasCoords ? (
                      <span className="text-[9px] text-emerald-400 border border-emerald-800/60 px-1 leading-tight">
                        GPS
                      </span>
                    ) : null}
                  </div>

                  {/* Name and Team (Bold Orange/White like Image 2) */}
                  <div className={`font-bold text-xs uppercase truncate ${
                    isLiveSos ? 'text-red-300' : isSelected ? 'text-white' : 'text-[#FF6E40]'
                  }`}>
                    {user.name}
                  </div>

                  <div className="text-[10px] text-slate-400 truncate tracking-tight">
                    {user.team}
                  </div>

                  {/* Telemetry info line */}
                  <div className="flex items-center justify-between text-[10px] text-slate-500 font-mono mt-1 pt-1 border-t border-slate-800/60">
                    <span className="text-cyan-400/80">
                      {user.hasCoords ? `${user.lat.toFixed(2)}, ${user.lng.toFixed(2)}` : 'KONUMSUZ'}
                    </span>
                    <span className="flex items-center gap-1.5 text-slate-400">
                      {user.altitude > 0 && <span>{user.altitude}m</span>}
                      <span className={user.battery < 25 ? 'text-red-400' : 'text-emerald-400'}>
                        %{user.battery}
                      </span>
                    </span>
                  </div>
                </div>

                {/* Quick SOS Test Zap Button */}
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    onToggleUserTestSos(user.id);
                  }}
                  className={`p-1 border transition-all cursor-pointer flex-shrink-0 ${
                    isLiveSos 
                      ? 'bg-red-700 hover:bg-red-600 text-white border-red-400' 
                      : 'bg-[#02050D] hover:bg-slate-800 text-slate-500 hover:text-amber-300 border-slate-800'
                  }`}
                  title={isLiveSos ? "SOS'i Kapat" : "SOS Testi Başlat"}
                >
                  <Zap className={`w-3.5 h-3.5 ${isLiveSos ? 'text-yellow-300 fill-yellow-300 animate-spin' : ''}`} />
                </button>
              </div>
            );
          })
        )}
      </div>

    </aside>
  );
}
