import React, { useState } from 'react';
import { 
  ClipboardList, 
  Users, 
  Package, 
  Clock, 
  CheckCircle2, 
  AlertCircle, 
  Send, 
  Shield, 
  Radio, 
  MapPin, 
  ChevronRight, 
  Plus, 
  FileText,
  X,
  Compass,
  Zap,
  Flame,
  Check,
  Award
} from 'lucide-react';
import { soundFx } from '../audio';

export const DEFAULT_EQUIPMENT_LIST = [
  { id: 'eq-cig-sonda', name: 'Çığ Sondası (320cm Karbon)', category: 'ÇIĞ', icon: '🎿', code: 'PRB-320' },
  { id: 'eq-arva', name: 'ARVA / BLE Çığ Dedektörü', category: 'ÇIĞ / ARAMA', icon: '📡', code: 'ARVA-457' },
  { id: 'eq-kurek', name: 'Alüminyum Kar Küreği', category: 'ÇIĞ', icon: '⛏️', code: 'SHV-ALU' },
  { id: 'eq-sedye', name: 'Vakum Sedye & Hipotermi Tulumu', category: 'MEDİKAL', icon: '🚑', code: 'MED-VAC' },
  { id: 'eq-termal-drone', name: 'Termal Drone (FLIR SAR-1)', category: 'HAVA KEŞİF', icon: '🚁', code: 'UAV-FLIR' },
  { id: 'eq-halat', name: 'Statik Dağcılık Halatı (100m 11mm)', category: 'TEKNİK', icon: '🧗', code: 'ROP-100' },
  { id: 'eq-travma', name: 'Travma Çantası & Taşınabilir Oksijen', category: 'MEDİKAL', icon: '🧰', code: 'TRW-O2' },
  { id: 'eq-jenerator', name: 'Mobil Saha Aydınlatma & Telsiz Rölesi', category: 'LOJİSTİK', icon: '⚡', code: 'PWR-REL' },
];

export const INITIAL_TEAMS = [
  {
    id: 'team-1',
    name: '1. ÇIĞ & DAĞ ARAMA MANGASI (AFAD)',
    shortName: 'AFAD TİM-1',
    leader: 'Yzb. Arda Demir',
    personnel: 6,
    radioChannel: 'CH-08 (446.093 MHz)',
    role: 'Arama & Sondalama',
    status: 'SEKTÖRDE',
    color: '#00E5FF',
    coords: [38.375, 27.030],
    equipment: ['ÇIĞ SONDASI', 'ARVA DEDEKTÖR', 'KAR KÜREĞİ', 'TERMAL DRONE'],
    dispatchedAt: '09:22'
  },
  {
    id: 'team-2',
    name: '2. ACİL MEDİKAL MÜDAHALE TİMİ (UMKE)',
    shortName: 'UMKE TİM-2',
    leader: 'Dr. Selin Kaya',
    personnel: 4,
    radioChannel: 'CH-12 (446.143 MHz)',
    role: 'Medikal Tahliye & Hipotermi',
    status: 'İNTİKALDE',
    color: '#10B981',
    coords: [38.388, 27.038],
    equipment: ['SEDYE & İLK YARDIM', 'TRAVMA ÇANTASI', 'HİPOTERMİ TULUMU'],
    dispatchedAt: '09:25'
  },
  {
    id: 'team-3',
    name: '3. TEKNİK İP & SARP GEÇİŞ BİRLİĞİ (AKUT)',
    shortName: 'AKUT TİM-3',
    leader: 'Murat Yıldız',
    personnel: 5,
    radioChannel: 'CH-05 (446.056 MHz)',
    role: 'Sarp Yamaç Emniyeti',
    status: 'BEKLEMEDE',
    color: '#F59E0B',
    coords: [38.365, 27.020],
    equipment: ['TIRMANIŞ HALATI', 'ÇIĞ SONDASI', 'ALÜMİNYUM KÜREK'],
    dispatchedAt: '09:30'
  }
];

export const INITIAL_STORYLINE = [
  {
    id: 'ev-1',
    stepNumber: 1,
    time: '09:15',
    title: 'Acil SOS Çağrısı Alındı',
    desc: 'Mobil uygulama ROTA+ Emniyetteyim üzerinden acil SOS sinyali tetiklendi. Son GPS konumu ve telemetri teyit edildi.',
    status: 'completed',
    team: 'KOMUTA MERKEZİ',
    coords: [38.384, 27.032],
    highlight: true
  },
  {
    id: 'ev-2',
    stepNumber: 2,
    time: '09:22',
    title: 'Ekipler ve Özel Ekipman Sevk Edildi',
    desc: '1. Çığ & Arama Mangası (AFAD) ve UMKE sevk edildi. Sahaya Çığ Sondası (PRB-320), ARVA Dedektör ve Termal Drone tahsis edildi.',
    status: 'completed',
    team: 'AFAD & UMKE',
    coords: [38.392, 27.035],
    highlight: false
  },
  {
    id: 'ev-3',
    stepNumber: 3,
    time: '09:40',
    title: 'Sektöre Varış & Akıllı Arama Konisi Tarandı',
    desc: 'Kazazedenin son yürüme hızı (3.8 km/s) ve yönü (65° KD) baz alınarak hesaplanan Akıllı Arama Alanı Bayraktar SAR-1 İHA ile tarandı.',
    status: 'completed',
    team: 'İHA & AFAD TİM-1',
    coords: [38.378, 27.028],
    highlight: true
  },
  {
    id: 'ev-4',
    stepNumber: 4,
    time: '10:05',
    title: 'ARVA & Akustik Sinyal Tespiti (Temas)',
    desc: 'Kazazedenin ROTA+ Çığ Modülü BLE alıcı-verici 2.6 kHz piezo ses sinyali ARVA dedektörüyle 14 metreden tespit edildi.',
    status: 'in_progress',
    team: '1. ÇIĞ MANGASI',
    coords: [38.371, 27.023],
    highlight: true
  },
  {
    id: 'ev-5',
    stepNumber: 5,
    time: '10:20',
    title: 'İlk Tıbbi Müdahale & Vakum Sedye Sabitleme',
    desc: 'Hipotermi sarmalı uygulandı, vital bulgular stabilize edildi ve kazazede vakum sedyeye alındı.',
    status: 'pending',
    team: 'UMKE TİM-2',
    coords: [38.371, 27.023],
    highlight: false
  },
  {
    id: 'ev-6',
    stepNumber: 6,
    time: '10:50',
    title: 'Heliport / Güvenli Bölgeye Tahliye',
    desc: 'Dokuz Eylül Acil Heliport pistine ambulans ve hava nakil unsurlarıyla nihai tahliye tamamlanacak.',
    status: 'pending',
    team: 'ORTAK HAREKAT',
    coords: [38.392, 27.035],
    highlight: false
  }
];

export default function DispatchMissionLog({
  isOpen = false,
  onClose = () => {},
  selectedUser = null,
  teams = INITIAL_TEAMS,
  onUpdateTeams = () => {},
  onAddTeam = () => {},
  onRemoveTeam = () => {},
  onDirectTeam = () => {},
  onDispatchToCasualty = () => {},
  onStartDirectingOnMap = () => {},
  storyline = INITIAL_STORYLINE,
  onUpdateStoryline = () => {},
  onCenterMap = () => {}
}) {
  const [activeTab, setActiveTab] = useState('log'); // 'log' | 'teams' | 'equipment' | 'storyline'
  const [newEventText, setNewEventText] = useState('');
  const [selectedTeamForEquipment, setSelectedTeamForEquipment] = useState(teams[0]?.id || 'team-1');
  
  // NEW TEAM FORM STATE
  const [isAddingTeam, setIsAddingTeam] = useState(false);
  const [formName, setFormName] = useState('');
  const [formShortName, setFormShortName] = useState('');
  const [formLeader, setFormLeader] = useState('');
  const [formPersonnel, setFormPersonnel] = useState(4);
  const [formRole, setFormRole] = useState('Arama & Çığ');
  const [formRadio, setFormRadio] = useState('CH-09 (446.105 MHz)');
  const [formColor, setFormColor] = useState('#00E5FF');
  const [formEquipment, setFormEquipment] = useState(['ÇIĞ SONDASI', 'ARVA DEDEKTÖR']);

  if (!isOpen) return null;

  const handleApplyTemplate = (tpl) => {
    setFormName(tpl.name);
    setFormShortName(tpl.shortName);
    setFormLeader(tpl.leader);
    setFormPersonnel(tpl.personnel);
    setFormRole(tpl.role);
    setFormRadio(tpl.radio);
    setFormColor(tpl.color);
    setFormEquipment(tpl.equipment);
    soundFx.playSelect();
  };

  const handleCreateTeamSubmit = (e) => {
    e.preventDefault();
    if (!formName.trim()) return;

    const newId = `team-${Date.now()}`;
    const baseCoords = selectedUser?.coords 
      ? [selectedUser.coords[0] - 0.008 + (Math.random() - 0.5) * 0.004, selectedUser.coords[1] - 0.008 + (Math.random() - 0.5) * 0.004]
      : [38.380, 27.030];

    const now = new Date();
    const timeStr = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;

    const newTeamObj = {
      id: newId,
      name: formName.trim().toUpperCase(),
      shortName: formShortName.trim() || formName.trim().substring(0, 10).toUpperCase(),
      leader: formLeader.trim() || 'Tim Sorumlusu',
      personnel: parseInt(formPersonnel) || 4,
      radioChannel: formRadio.trim() || 'CH-01',
      role: formRole,
      status: 'SEKTÖRDE',
      color: formColor,
      coords: baseCoords,
      targetCoords: null,
      equipment: formEquipment,
      dispatchedAt: timeStr
    };

    onAddTeam(newTeamObj);
    setIsAddingTeam(false);
    setFormName('');
    setFormShortName('');
    setFormLeader('');
    soundFx.playSuccess();
  };

  const handleAddStorylineEvent = (e) => {
    e.preventDefault();
    if (!newEventText.trim()) return;

    const now = new Date();
    const timeStr = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;

    const newEvent = {
      id: `ev-${Date.now()}`,
      stepNumber: storyline.length + 1,
      time: timeStr,
      title: 'Saha Olay Güncellemesi',
      desc: newEventText.trim(),
      status: 'completed',
      team: 'SAHA UNSURLARI',
      coords: selectedUser?.coords || [38.375, 27.030],
      highlight: true
    };

    onUpdateStoryline([newEvent, ...storyline]);
    setNewEventText('');
    soundFx.playSuccess();
  };

  const toggleEquipmentForTeam = (teamId, equipName) => {
    const updated = teams.map((t) => {
      if (t.id !== teamId) return t;
      const exists = t.equipment.includes(equipName);
      const newEquip = exists 
        ? t.equipment.filter((item) => item !== equipName)
        : [...t.equipment, equipName];
      return { ...t, equipment: newEquip };
    });
    onUpdateTeams(updated);
    soundFx.playSelect();
  };

  const toggleTeamStatus = (teamId) => {
    const statusCycle = ['BEKLEMEDE', 'İNTİKALDE', 'SEKTÖRDE', 'GÖREVDE'];
    const updated = teams.map((t) => {
      if (t.id !== teamId) return t;
      const nextIdx = (statusCycle.indexOf(t.status) + 1) % statusCycle.length;
      return { ...t, status: statusCycle[nextIdx] };
    });
    onUpdateTeams(updated);
    soundFx.playSelect();
  };

  return (
    <div className="fixed inset-0 z-[1000] bg-black/80 backdrop-blur-md flex items-center justify-center p-4 sm:p-6 font-tactical select-none animate-fadeIn">
      <div className="bg-[#030712] border-2 border-cyan-500/70 w-full max-w-5xl h-[88vh] flex flex-col shadow-[0_0_60px_rgba(0,229,255,0.25)] relative overflow-hidden">
        
        {/* Top Header */}
        <div className="h-14 bg-[#050D1A] border-b border-cyan-500/40 px-5 flex items-center justify-between shrink-0">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded border border-cyan-400 bg-cyan-950/60 flex items-center justify-center text-cyan-300">
              <ClipboardList className="w-4 h-4" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-white font-black text-sm tracking-widest uppercase">
                  HAREKAT GÖREV GÜNLÜĞÜ & SEVK YÖNETİMİ
                </span>
                <span className="bg-red-950/80 border border-red-500 text-red-400 text-[10px] px-2 py-0.2 font-mono font-bold animate-pulse">
                  CANLI OPERASYONEL
                </span>
              </div>
              <div className="text-[10.5px] text-slate-400 font-mono">
                HEDEF: <span className="text-cyan-300 font-bold">{selectedUser?.name || 'KAZAZEDE'}</span> | 
                LKP: <span className="text-slate-300">{selectedUser?.lat ? `${selectedUser.lat.toFixed(4)}°N, ${selectedUser.lng.toFixed(4)}°E` : '38.3842°N, 27.0320°E'}</span>
              </div>
            </div>
          </div>

          <div className="flex items-center gap-2">
            {/* Tabs */}
            <div className="flex items-center bg-black/60 border border-cyan-500/30 p-0.5 rounded">
              <button
                onClick={() => { setActiveTab('log'); soundFx.playSelect(); }}
                className={`px-3 py-1 text-xs font-bold transition-all ${
                  activeTab === 'log' ? 'bg-[#00E5FF] text-black shadow-[0_0_10px_#00E5FF]' : 'text-slate-400 hover:text-white'
                }`}
              >
                GÖREV GÜNLÜĞÜ
              </button>
              <button
                onClick={() => { setActiveTab('teams'); soundFx.playSelect(); }}
                className={`px-3 py-1 text-xs font-bold transition-all ${
                  activeTab === 'teams' ? 'bg-[#00E5FF] text-black shadow-[0_0_10px_#00E5FF]' : 'text-slate-400 hover:text-white'
                }`}
              >
                SEVK EDİLEN EKİPLER ({teams.length})
              </button>
              <button
                onClick={() => { setActiveTab('equipment'); soundFx.playSelect(); }}
                className={`px-3 py-1 text-xs font-bold transition-all ${
                  activeTab === 'equipment' ? 'bg-[#00E5FF] text-black shadow-[0_0_10px_#00E5FF]' : 'text-slate-400 hover:text-white'
                }`}
              >
                EKİPMAN SEVKİ
              </button>
              <button
                onClick={() => { setActiveTab('storyline'); soundFx.playSelect(); }}
                className={`px-3 py-1 text-xs font-bold transition-all ${
                  activeTab === 'storyline' ? 'bg-[#00E5FF] text-black shadow-[0_0_10px_#00E5FF]' : 'text-slate-400 hover:text-white'
                }`}
              >
                OLAY ÖRGÜSÜ ({storyline.length})
              </button>
            </div>

            <button
              onClick={onClose}
              className="text-slate-400 hover:text-red-400 p-1.5 transition-colors cursor-pointer"
              title="Kapat"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Content Body */}
        <div className="flex-1 overflow-y-auto p-5 custom-scrollbar bg-[#02050D]">
          
          {/* TAB 1: GÖREV GÜNLÜĞÜ GENEL ÖZET */}
          {activeTab === 'log' && (
            <div className="space-y-5">
              {/* Tactical Stats Banner */}
              <div className="grid grid-cols-4 gap-3">
                <div className="bg-[#050B18] border border-cyan-500/30 p-3">
                  <div className="text-[10px] text-slate-400 uppercase font-mono">SEVK EDİLEN EKİP</div>
                  <div className="text-xl font-black text-cyan-400">{teams.length} TİM</div>
                  <div className="text-[10px] text-slate-400 font-mono mt-0.5">Toplam 15 SAR Personeli</div>
                </div>
                <div className="bg-[#050B18] border border-cyan-500/30 p-3">
                  <div className="text-[10px] text-slate-400 uppercase font-mono">SEVK EDİLEN EKİPMAN</div>
                  <div className="text-xl font-black text-amber-400">
                    {teams.reduce((acc, t) => acc + t.equipment.length, 0)} PARÇA
                  </div>
                  <div className="text-[10px] text-slate-400 font-mono mt-0.5">Çığ Sondası, ARVA, Sedye</div>
                </div>
                <div className="bg-[#050B18] border border-cyan-500/30 p-3">
                  <div className="text-[10px] text-slate-400 uppercase font-mono">AKILLI ARAMA ALANI</div>
                  <div className="text-xl font-black text-emerald-400">19.8 km²</div>
                  <div className="text-[10px] text-slate-400 font-mono mt-0.5">3.8 km/s | 65° KD Vektörü</div>
                </div>
                <div className="bg-[#050B18] border border-cyan-500/30 p-3">
                  <div className="text-[10px] text-slate-400 uppercase font-mono">OLAY ÖRGÜSÜ AŞAMASI</div>
                  <div className="text-xl font-black text-red-400">4 / 6 ADIM</div>
                  <div className="text-[10px] text-slate-400 font-mono mt-0.5">Sinyal Teması Sağlandı</div>
                </div>
              </div>

              {/* Main Log Table */}
              <div className="border border-cyan-500/30 bg-[#040814]">
                <div className="px-4 py-2.5 bg-[#081224] border-b border-cyan-500/40 flex items-center justify-between">
                  <span className="text-xs font-bold text-cyan-300 tracking-wider">
                    RESMİ HAREKAT VE SEVK PROTOKOLÜ (CANLI TAKİP)
                  </span>
                  <span className="text-[10px] font-mono text-slate-400">TELSİZ FREKANSI: AFAD NET-01</span>
                </div>

                <div className="divide-y divide-slate-800">
                  {teams.map((team) => (
                    <div key={team.id} className="p-4 flex items-start justify-between gap-4 hover:bg-slate-900/40 transition-colors">
                      <div className="flex-1">
                        <div className="flex items-center gap-2">
                          <span className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: team.color }} />
                          <span className="text-sm font-bold text-white">{team.name}</span>
                          <span className="text-[10px] font-mono bg-cyan-950/80 text-cyan-300 border border-cyan-500/40 px-1.5 py-0.5">
                            LİDER: {team.leader}
                          </span>
                          <span className="text-[10px] font-mono bg-black/60 text-slate-300 px-1.5 py-0.5 border border-slate-700">
                            {team.personnel} PERSONEL
                          </span>
                        </div>
                        <div className="text-xs text-slate-400 mt-1 font-mono">
                          GÖREV: <span className="text-slate-200">{team.role}</span> | TELSİZ: <span className="text-cyan-400">{team.radioChannel}</span> | SEVK SAATİ: <span className="text-amber-400">{team.dispatchedAt}</span>
                        </div>

                        {/* Equipped Items Badges */}
                        <div className="flex flex-wrap gap-1.5 mt-2.5">
                          <span className="text-[10px] text-slate-500 font-mono py-0.5">SEVK EDİLEN EKİPMANLAR:</span>
                          {team.equipment.map((eq, i) => (
                            <span 
                              key={i} 
                              className="text-[10px] font-mono font-bold bg-[#0A1628] border border-cyan-500/60 text-cyan-200 px-2 py-0.5 rounded flex items-center gap-1 shadow-sm"
                            >
                              <Check className="w-3 h-3 text-cyan-400" />
                              {eq}
                            </span>
                          ))}
                        </div>
                      </div>

                      <div className="flex flex-col items-end gap-2 shrink-0">
                        <button
                          onClick={() => toggleTeamStatus(team.id)}
                          className={`px-3 py-1 text-xs font-mono font-bold cursor-pointer border transition-colors ${
                            team.status === 'SEKTÖRDE'
                              ? 'bg-emerald-950/80 text-emerald-300 border-emerald-500 shadow-[0_0_10px_rgba(16,185,129,0.3)]'
                              : team.status === 'İNTİKALDE'
                              ? 'bg-amber-950/80 text-amber-300 border-amber-500 animate-pulse'
                              : 'bg-slate-900 text-slate-400 border-slate-700'
                          }`}
                        >
                          DURUM: {team.status}
                        </button>

                        <button
                          onClick={() => {
                            onCenterMap(team.coords, 16);
                            onClose();
                            soundFx.playTargetLock();
                          }}
                          className="px-2.5 py-0.5 text-[10px] font-mono text-cyan-400 border border-cyan-500/40 hover:bg-cyan-950 cursor-pointer flex items-center gap-1"
                        >
                          <MapPin className="w-3 h-3" />
                          HARİTADA GÖSTER
                        </button>

                        <div className="flex items-center gap-1">
                          <button
                            onClick={() => {
                              onStartDirectingOnMap(team.id);
                              onClose();
                              soundFx.playTargetLock();
                            }}
                            className="px-2 py-0.5 text-[9.5px] font-mono text-cyan-300 border border-cyan-500/50 hover:bg-cyan-900 cursor-pointer"
                            title="Timi haritada yeni mevkiye sevk et"
                          >
                            🎯 YÖNLENDİR
                          </button>
                          <button
                            onClick={() => {
                              if (window.confirm(`${team.name} görevden çekilsin mi?`)) {
                                onRemoveTeam(team.id);
                                soundFx.playSelect();
                              }
                            }}
                            className="px-1.5 py-0.5 text-[9.5px] font-mono text-red-400 border border-red-800 hover:bg-red-950 cursor-pointer"
                            title="Timi Görevden Çek / Sil"
                          >
                            ✕ SİL
                          </button>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Quick Add Log Note */}
              <form onSubmit={handleAddStorylineEvent} className="flex gap-2">
                <input
                  type="text"
                  placeholder="Harekat Günlüğüne resmi operasyonel not / olay kaydı ekle (Örn: Kazazedenin termal izi doğrulandı)..."
                  value={newEventText}
                  onChange={(e) => setNewEventText(e.target.value)}
                  className="flex-1 bg-[#050C1A] border border-cyan-500/50 text-white font-mono text-xs px-3 py-2 outline-none focus:border-cyan-400"
                />
                <button
                  type="submit"
                  className="bg-[#00E5FF] text-black font-black text-xs px-4 py-2 flex items-center gap-1.5 hover:bg-cyan-300 cursor-pointer transition-all shadow-[0_0_15px_#00E5FF]"
                >
                  <Send className="w-3.5 h-3.5" />
                  GÜNLÜĞE İŞLE
                </button>
              </form>
            </div>
          )}

          {/* TAB 2: SEVK EDİLEN EKİPLER */}
          {activeTab === 'teams' && (
            <div className="space-y-4">
              {/* Teams Action Bar */}
              <div className="flex items-center justify-between bg-[#050D1D] p-3 border border-cyan-500/30">
                <div className="flex items-center gap-2">
                  <span className="text-xs font-bold text-white tracking-wider">
                    OPERASYONDAKİ ARAMA KURTARMA UNSURLARI ({teams.length} TİM)
                  </span>
                  <span className="text-[10px] text-slate-400 font-mono">
                    (Harita üzerinde timleri sürükleyebilir veya hedef belirleyerek yönlendirebilirsiniz)
                  </span>
                </div>

                <button
                  onClick={() => {
                    setIsAddingTeam(!isAddingTeam);
                    soundFx.playSelect();
                  }}
                  className="bg-[#00E5FF] hover:bg-cyan-300 text-black font-black text-xs px-3.5 py-1.5 flex items-center gap-1.5 shadow-[0_0_15px_#00E5FF] cursor-pointer transition-all"
                >
                  <Plus className="w-4 h-4" />
                  {isAddingTeam ? 'FORMU KAPAT' : 'YENİ EKİP EKLE & SEVK ET'}
                </button>
              </div>

              {/* NEW TEAM CREATION FORM */}
              {isAddingTeam && (
                <form onSubmit={handleCreateTeamSubmit} className="bg-[#040918] border-2 border-cyan-400 p-4 shadow-[0_0_25px_rgba(0,229,255,0.2)] space-y-4 animate-fadeIn">
                  <div className="flex items-center justify-between border-b border-cyan-500/30 pb-2">
                    <span className="text-xs font-black text-cyan-300 tracking-wider flex items-center gap-2">
                      <Shield className="w-4 h-4 text-cyan-400" />
                      YENİ ARAMA KURTARMA BİRLİĞİ OLUŞTURMA & SEVK PROTOKOLÜ
                    </span>
                    <span className="text-[10px] text-slate-400 font-mono">HAREKAT BİRLİĞİ PROTOKOLÜ</span>
                  </div>

                  {/* Fast Templates */}
                  <div className="flex items-center gap-2 flex-wrap">
                    <span className="text-[10px] text-slate-400 font-mono">HIZLI ŞABLON:</span>
                    {[
                      { name: 'Jandarma Arama Kurtarma (JAK)', shortName: 'JAK TİM-4', leader: 'Kd. Bçvş. Murat Kaya', personnel: 5, radio: 'CH-10 (446.118 MHz)', role: 'Sarp Arazi & Dağ', color: '#3B82F6', equipment: ['ÇIĞ SONDASI', 'ARVA DEDEKTÖR', 'STATİK HALAT'] },
                      { name: 'K9 Köpekli İz Takip Timi', shortName: 'K9 TİM-5', leader: 'Uzm. Çvş. Emre Kurt', personnel: 3, radio: 'CH-07 (446.081 MHz)', role: 'K9 Canlı Arama', color: '#10B981', equipment: ['ARVA DEDEKTÖR', 'TRAVMA ÇANTASI'] },
                      { name: 'İzmir İtfaiyesi Arama Timi', shortName: 'İTFAİYE TİM-6', leader: 'Çvş. Barış Doğan', personnel: 6, radio: 'CH-14 (446.168 MHz)', role: 'Kanyon Tabanı', color: '#EF4444', equipment: ['KAR KÜREĞİ', 'VAKUM SEDYE', 'JENERATÖR'] },
                      { name: 'Özel İHA & Keşif Mangası', shortName: 'İHA TİM-7', leader: 'Müh. Kpt. Zafer Eren', personnel: 3, radio: 'CH-03 (446.031 MHz)', role: 'Hava Keşif', color: '#F59E0B', equipment: ['TERMAL DRONE', 'JENERATÖR'] },
                    ].map((tpl, i) => (
                      <button
                        type="button"
                        key={i}
                        onClick={() => handleApplyTemplate(tpl)}
                        className="px-2 py-1 bg-black/60 border border-cyan-500/40 text-[10px] text-cyan-200 hover:bg-cyan-950 font-mono cursor-pointer"
                      >
                        + {tpl.shortName}
                      </button>
                    ))}
                  </div>

                  <div className="grid grid-cols-3 gap-3 text-xs font-mono">
                    <div>
                      <label className="text-slate-400 text-[10px] block mb-1">BİRLİK / EKİP TAM ADI:</label>
                      <input
                        type="text"
                        required
                        placeholder="Örn: 4. Jandarma JAK Timi"
                        value={formName}
                        onChange={(e) => setFormName(e.target.value)}
                        className="w-full bg-black border border-cyan-500/50 text-white px-2.5 py-1.5 outline-none focus:border-cyan-300"
                      />
                    </div>

                    <div>
                      <label className="text-slate-400 text-[10px] block mb-1">HARİTA KISA KODU:</label>
                      <input
                        type="text"
                        placeholder="Örn: JAK TİM-4"
                        value={formShortName}
                        onChange={(e) => setFormShortName(e.target.value)}
                        className="w-full bg-black border border-cyan-500/50 text-white px-2.5 py-1.5 outline-none focus:border-cyan-300"
                      />
                    </div>

                    <div>
                      <label className="text-slate-400 text-[10px] block mb-1">TİM LİDERİ:</label>
                      <input
                        type="text"
                        required
                        placeholder="Örn: Kd. Bçvş. Murat Kaya"
                        value={formLeader}
                        onChange={(e) => setFormLeader(e.target.value)}
                        className="w-full bg-black border border-cyan-500/50 text-white px-2.5 py-1.5 outline-none focus:border-cyan-300"
                      />
                    </div>

                    <div>
                      <label className="text-slate-400 text-[10px] block mb-1">PERSONEL SAYISI:</label>
                      <input
                        type="number"
                        min="1"
                        max="20"
                        value={formPersonnel}
                        onChange={(e) => setFormPersonnel(e.target.value)}
                        className="w-full bg-black border border-cyan-500/50 text-white px-2.5 py-1.5 outline-none focus:border-cyan-300"
                      />
                    </div>

                    <div>
                      <label className="text-slate-400 text-[10px] block mb-1">TELSİZ FREKANSI / KANAL:</label>
                      <input
                        type="text"
                        value={formRadio}
                        onChange={(e) => setFormRadio(e.target.value)}
                        className="w-full bg-black border border-cyan-500/50 text-white px-2.5 py-1.5 outline-none focus:border-cyan-300"
                      />
                    </div>

                    <div>
                      <label className="text-slate-400 text-[10px] block mb-1">GÖREV & UZMANLIK ROLÜ:</label>
                      <select
                        value={formRole}
                        onChange={(e) => setFormRole(e.target.value)}
                        className="w-full bg-black border border-cyan-500/50 text-cyan-200 px-2.5 py-1.5 outline-none"
                      >
                        <option value="Arama & Çığ">Arama & Çığ Sondalama</option>
                        <option value="Medikal Tahliye">Acil Medikal Tahliye</option>
                        <option value="K9 Canlı Arama">K9 Köpekli Canlı Arama</option>
                        <option value="Sarp İp Hattı">Sarp Yamaç ve İp Emniyeti</option>
                        <option value="Hava Keşif">Termal Drone & Hava Keşif</option>
                        <option value="Lojistik Destek">Lojistik ve Aydınlatma</option>
                      </select>
                    </div>
                  </div>

                  {/* Initial Equipment Checklist */}
                  <div>
                    <label className="text-slate-400 text-[10px] font-mono block mb-1.5">ZİMMETLENECEK EKİPMANLAR:</label>
                    <div className="grid grid-cols-4 gap-2">
                      {DEFAULT_EQUIPMENT_LIST.map((eq) => {
                        const checked = formEquipment.includes(eq.name);
                        return (
                          <div
                            key={eq.id}
                            onClick={() => {
                              if (checked) {
                                setFormEquipment(formEquipment.filter(item => item !== eq.name));
                              } else {
                                setFormEquipment([...formEquipment, eq.name]);
                              }
                            }}
                            className={`p-1.5 border text-[10px] font-mono flex items-center gap-2 cursor-pointer transition-colors ${
                              checked ? 'bg-cyan-950 border-cyan-400 text-cyan-200' : 'bg-black border-slate-800 text-slate-500'
                            }`}
                          >
                            <span>{eq.icon}</span>
                            <span className="truncate">{eq.name.split('(')[0]}</span>
                          </div>
                        );
                      })}
                    </div>
                  </div>

                  {/* Submit Button */}
                  <div className="flex justify-end gap-2 pt-2 border-t border-cyan-500/20">
                    <button
                      type="button"
                      onClick={() => setIsAddingTeam(false)}
                      className="px-4 py-2 border border-slate-700 text-slate-300 hover:text-white text-xs font-mono cursor-pointer"
                    >
                      İPTAL
                    </button>
                    <button
                      type="submit"
                      className="bg-[#00E5FF] text-black font-black text-xs px-6 py-2 flex items-center gap-1.5 hover:bg-cyan-300 cursor-pointer shadow-[0_0_15px_#00E5FF]"
                    >
                      <Shield className="w-4 h-4" />
                      TİMİ OLUŞTUR VE SAHAYA SEVK ET
                    </button>
                  </div>
                </form>
              )}

              {/* TEAMS GRID LIST */}
              <div className="grid grid-cols-3 gap-4">
                {teams.map((team) => (
                  <div key={team.id} className="bg-[#050D1D] border border-cyan-500/40 p-4 flex flex-col justify-between relative group shadow-md hover:border-cyan-400 transition-all">
                    <div>
                      {/* Top Header */}
                      <div className="flex items-center justify-between border-b border-cyan-500/30 pb-2 mb-3">
                        <div className="flex items-center gap-2">
                          <span className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: team.color || '#00E5FF' }} />
                          <span className="font-bold text-white text-xs">{team.shortName}</span>
                        </div>
                        <span className="text-[10px] font-mono bg-cyan-950 text-cyan-300 px-1.5 border border-cyan-500/40 font-bold">
                          {team.status}
                        </span>
                      </div>

                      {/* Info details */}
                      <div className="space-y-1.5 text-xs font-mono text-slate-300 mb-3">
                        <div><span className="text-slate-500">TİM ADI:</span> {team.name}</div>
                        <div><span className="text-slate-500">LİDER:</span> <span className="text-white font-bold">{team.leader}</span> ({team.personnel} Kişi)</div>
                        <div><span className="text-slate-500">TELSİZ:</span> <span className="text-cyan-400 font-bold">{team.radioChannel}</span></div>
                        <div><span className="text-slate-500">GÖREV:</span> {team.role}</div>
                        <div><span className="text-slate-500">MEVKİİ:</span> <span className="text-slate-200">{team.coords ? `${team.coords[0].toFixed(4)}°N, ${team.coords[1].toFixed(4)}°E` : '--'}</span></div>
                        {team.targetCoords && (
                          <div className="bg-amber-950/40 border border-amber-500/50 p-1 text-[10px] text-amber-300 font-bold">
                            🎯 İNTİKAL HEDEFİ: {team.targetCoords[0].toFixed(4)}°N, {team.targetCoords[1].toFixed(4)}°E
                          </div>
                        )}
                      </div>

                      {/* Equipment Badges */}
                      <div className="border-t border-slate-800 pt-2">
                        <div className="text-[10px] text-slate-400 font-mono mb-1.5">ZİMMETLİ EKİPMANLAR ({team.equipment?.length || 0}):</div>
                        <div className="flex flex-wrap gap-1">
                          {team.equipment?.map((eq, i) => (
                            <span key={i} className="text-[9px] font-mono bg-cyan-950/60 border border-cyan-500/50 text-cyan-300 px-1.5 py-0.5">
                              {eq}
                            </span>
                          ))}
                        </div>
                      </div>
                    </div>

                    {/* Operational Directing & Deletion Actions */}
                    <div className="mt-4 pt-3 border-t border-slate-800 space-y-2">
                      <div className="grid grid-cols-2 gap-1.5">
                        <button
                          onClick={() => {
                            onStartDirectingOnMap(team.id);
                            onClose();
                            soundFx.playTargetLock();
                          }}
                          className="bg-cyan-950 hover:bg-cyan-900 border border-cyan-400 text-cyan-200 text-[10px] font-mono py-1.5 font-bold cursor-pointer flex items-center justify-center gap-1 shadow-sm"
                          title="Harita üzerinden hedef belirleyerek timi sevk edin"
                        >
                          <Compass className="w-3.5 h-3.5 text-cyan-400" />
                          HEDEF BELİRLE
                        </button>

                        <button
                          onClick={() => {
                            onDispatchToCasualty(team.id);
                            soundFx.playTargetLock();
                          }}
                          className="bg-red-950/80 hover:bg-red-900 border border-red-500 text-red-300 text-[10px] font-mono py-1.5 font-bold cursor-pointer flex items-center justify-center gap-1"
                          title="Timi doğrudan kazazede/LKP koordinatına sevk et"
                        >
                          <Zap className="w-3.5 h-3.5 text-red-400" />
                          KAZAZEDEYE GİT
                        </button>
                      </div>

                      <div className="flex gap-1.5">
                        <button
                          onClick={() => toggleTeamStatus(team.id)}
                          className="flex-1 bg-black hover:bg-slate-900 border border-slate-700 text-slate-300 text-[10px] font-mono py-1 cursor-pointer font-bold"
                        >
                          DURUMU GÜNCELLE
                        </button>

                        <button
                          onClick={() => {
                            onCenterMap(team.coords, 16);
                            onClose();
                          }}
                          className="bg-black hover:bg-slate-900 border border-slate-700 text-slate-300 text-[10px] font-mono px-2 py-1 cursor-pointer"
                          title="Haritada Tim Konumuna Odaklan"
                        >
                          <MapPin className="w-3.5 h-3.5 text-cyan-400" />
                        </button>

                        <button
                          onClick={() => {
                            if (window.confirm(`${team.name} görevden çekilsin ve silinsin mi?`)) {
                              onRemoveTeam(team.id);
                              soundFx.playSelect();
                            }
                          }}
                          className="bg-red-950/50 hover:bg-red-900/80 border border-red-800 text-red-400 text-[10px] font-mono px-2 py-1 cursor-pointer"
                          title="Timi Görevden Çek / Sil"
                        >
                          <X className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* TAB 3: EKİPMAN SEVKİ (EQUIPMENT DISPATCH CHECKLIST) */}

          {/* TAB 3: EKİPMAN SEVKİ (EQUIPMENT DISPATCH CHECKLIST) */}
          {activeTab === 'equipment' && (
            <div className="space-y-4">
              <div className="flex items-center gap-3 bg-[#050D1D] p-3 border border-cyan-500/30">
                <span className="text-xs text-slate-300 font-mono">EKİPMAN SEVK EDİLECEK TİMİ SEÇİN:</span>
                <select
                  value={selectedTeamForEquipment}
                  onChange={(e) => setSelectedTeamForEquipment(e.target.value)}
                  className="bg-black border border-cyan-500 text-cyan-300 text-xs font-mono px-3 py-1 outline-none"
                >
                  {teams.map((t) => (
                    <option key={t.id} value={t.id}>{t.name} ({t.leader})</option>
                  ))}
                </select>
              </div>

              <div className="grid grid-cols-2 gap-3">
                {DEFAULT_EQUIPMENT_LIST.map((eq) => {
                  const currentTeam = teams.find((t) => t.id === selectedTeamForEquipment);
                  const isAssigned = currentTeam?.equipment.includes(eq.name);

                  return (
                    <div 
                      key={eq.id}
                      onClick={() => toggleEquipmentForTeam(selectedTeamForEquipment, eq.name)}
                      className={`p-3 border cursor-pointer flex items-center justify-between transition-all ${
                        isAssigned 
                          ? 'bg-cyan-950/50 border-cyan-400 text-white shadow-[0_0_10px_rgba(0,229,255,0.2)]' 
                          : 'bg-[#040814] border-slate-800 text-slate-400 hover:border-slate-700'
                      }`}
                    >
                      <div className="flex items-center gap-3">
                        <span className="text-xl">{eq.icon}</span>
                        <div>
                          <div className="text-xs font-bold">{eq.name}</div>
                          <div className="text-[10px] font-mono text-slate-400">
                            KOD: <span className="text-cyan-300">{eq.code}</span> | KATEGORİ: {eq.category}
                          </div>
                        </div>
                      </div>

                      <div className={`w-5 h-5 border flex items-center justify-center ${
                        isAssigned ? 'border-cyan-400 bg-[#00E5FF] text-black font-bold' : 'border-slate-700'
                      }`}>
                        {isAssigned && <Check className="w-3.5 h-3.5" />}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {/* TAB 4: OLAY ÖRGÜSÜ (CHRONOLOGICAL INCIDENT STORYLINE) */}
          {activeTab === 'storyline' && (
            <div className="space-y-4">
              <div className="text-xs font-mono text-slate-300 bg-[#050D1D] p-3 border border-cyan-500/30 flex items-center justify-between">
                <span>SAR OLAY ÖRGÜSÜ & MÜDAHALE ADIMLARI (KRONOLOJİK)</span>
                <span className="text-cyan-400 font-bold">TOPLAM {storyline.length} OPERASYONEL FAZ</span>
              </div>

              <div className="relative pl-6 space-y-6 before:content-[''] before:absolute before:left-2 before:top-2 before:bottom-2 before:w-0.5 before:bg-cyan-500/30">
                {storyline.map((ev, index) => {
                  const isCompleted = ev.status === 'completed';
                  const isInProgress = ev.status === 'in_progress';

                  return (
                    <div key={ev.id} className="relative group">
                      {/* Step Circle Pin */}
                      <div className={`absolute -left-[27px] top-0 w-6 h-6 rounded-full border-2 flex items-center justify-center text-[10px] font-mono font-bold ${
                        isCompleted 
                          ? 'border-emerald-400 bg-emerald-950 text-emerald-300 shadow-[0_0_10px_#10B981]' 
                          : isInProgress 
                          ? 'border-amber-400 bg-amber-950 text-amber-300 animate-pulse' 
                          : 'border-slate-700 bg-black text-slate-500'
                      }`}>
                        {ev.stepNumber || index + 1}
                      </div>

                      <div className={`p-4 border transition-all ${
                        isInProgress 
                          ? 'bg-[#061426] border-amber-500/80 shadow-[0_0_20px_rgba(245,158,11,0.2)]' 
                          : isCompleted 
                          ? 'bg-[#030915] border-cyan-500/40' 
                          : 'bg-[#02050D] border-slate-800 opacity-60'
                      }`}>
                        <div className="flex items-center justify-between mb-1">
                          <div className="flex items-center gap-2">
                            <span className="text-xs font-mono font-bold text-amber-400">[{ev.time}]</span>
                            <span className="text-sm font-bold text-white">{ev.title}</span>
                            <span className="text-[10px] font-mono bg-cyan-950 text-cyan-300 px-1.5 border border-cyan-500/40">
                              {ev.team}
                            </span>
                          </div>

                          <div className="flex items-center gap-2">
                            <span className={`text-[10px] font-mono font-bold px-2 py-0.5 border ${
                              isCompleted ? 'text-emerald-300 border-emerald-500/50 bg-emerald-950/60' :
                              isInProgress ? 'text-amber-300 border-amber-500 bg-amber-950/80 animate-pulse' :
                              'text-slate-400 border-slate-700'
                            }`}>
                              {isCompleted ? 'TAMAMLANDI' : isInProgress ? 'DEVAM EDİYOR' : 'SIRADAKİ ADIM'}
                            </span>

                            {ev.coords && (
                              <button
                                onClick={() => {
                                  onCenterMap(ev.coords, 16);
                                  onClose();
                                  soundFx.playTargetLock();
                                }}
                                className="text-[10px] font-mono text-cyan-400 hover:text-white border border-cyan-500/40 px-2 py-0.5 cursor-pointer flex items-center gap-1"
                              >
                                <MapPin className="w-3 h-3" />
                                MEVKİ
                              </button>
                            )}
                          </div>
                        </div>

                        <p className="text-xs text-slate-300 font-mono mt-1 leading-relaxed">
                          {ev.desc}
                        </p>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}

        </div>

        {/* Footer */}
        <div className="h-11 bg-[#050D1A] border-t border-cyan-500/40 px-5 flex items-center justify-between shrink-0 text-xs font-mono text-slate-400">
          <div>
            ROTA+ HAREKAT GÖREV GÜNLÜĞÜ // T.C. İÇİŞLERİ AFAD & TDF TELSİZ KOORDİNASYONU
          </div>
          <div className="flex items-center gap-3">
            <span className="text-emerald-400 font-bold">● TELSİZ VE GPS TELEMETRİ CANLI</span>
            <button
              onClick={() => {
                window.print();
                soundFx.playSelect();
              }}
              className="text-cyan-300 hover:text-white border border-cyan-500/50 px-2.5 py-1 text-[11px] font-bold cursor-pointer flex items-center gap-1.5"
            >
              <FileText className="w-3.5 h-3.5" />
              GÖREV PROTOKOLÜ YAZDIR
            </button>
          </div>
        </div>

      </div>
    </div>
  );
}
