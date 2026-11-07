import React from 'react';
import { 
  X, 
  Printer, 
  ShieldAlert, 
  FileText, 
  MapPin, 
  Users, 
  Mountain, 
  Wind, 
  PhoneCall, 
  Heart,
  CheckCircle2,
  Calendar,
  Clock
} from 'lucide-react';
import { soundFx } from '../audio';
import { analyzeLocation, getElevationProfile, getTacticalMicroWeather } from '../utils/geoAnalysis';

export default function MissionBriefingModal({
  user = null,
  allUsers = [],
  onClose = () => {}
}) {
  if (!user) return null;

  const analysis = analyzeLocation(user, allUsers);
  const profile = getElevationProfile(user);
  const weather = getTacticalMicroWeather(user);

  const incidentCode = `SAR-TR-${(user.id || '9999').substring(0, 6).toUpperCase()}`;
  const now = new Date();
  const dateStr = now.toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric' });
  const timeStr = now.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit', second: '2-digit' });

  // Convert decimal to DMS (Degrees Minutes Seconds)
  const toDms = (val, isLat) => {
    const abs = Math.abs(val);
    const deg = Math.floor(abs);
    const min = Math.floor((abs - deg) * 60);
    const sec = ((abs - deg - min / 60) * 3600).toFixed(1);
    const dir = isLat ? (val >= 0 ? 'N' : 'S') : (val >= 0 ? 'E' : 'W');
    return `${deg}° ${min}' ${sec}" ${dir}`;
  };

  const dmsLat = user.lat ? toDms(user.lat, true) : '38° 25\' 48.0" N';
  const dmsLng = user.lng ? toDms(user.lng, false) : '27° 10\' 48.0" E';

  const handlePrint = () => {
    soundFx.playPrint();
    window.print();
  };

  return (
    <div className="fixed inset-0 z-[99999] bg-black/85 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto font-tactical select-none">
      
      {/* Modal Container */}
      <div className="relative w-full max-w-3xl bg-[#030712] border-2 border-[#00E5FF] text-slate-100 shadow-[0_0_50px_rgba(0,229,255,0.3)] my-auto">
        
        {/* Top Control Bar (Hidden in Print) */}
        <div className="print:hidden h-10 bg-[#040D21] border-b border-cyan-500/40 px-4 flex items-center justify-between">
          <div className="flex items-center gap-2 text-cyan-400 font-bold text-xs tracking-wider">
            <FileText className="w-4 h-4 text-[#FF4D26]" />
            <span>RESMİ AFAD & ROTA+ TAKTİK İNTİKAL GÖREV BRİFİNGİ</span>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={handlePrint}
              className="tactical-btn-orange px-3 py-1 text-xs flex items-center gap-1.5 cursor-pointer font-bold"
            >
              <Printer className="w-3.5 h-3.5" /> YAZDIR / PDF ÇIKTISI AL
            </button>
            <button
              onClick={onClose}
              className="text-slate-400 hover:text-white p-1 transition-colors cursor-pointer"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* Printable Document Body */}
        <div className="p-6 text-slate-200 print:text-black print:bg-white print:p-8 space-y-4">
          
          {/* Header */}
          <div className="border-b-2 border-cyan-500 pb-3 flex items-start justify-between">
            <div>
              <div className="text-[10px] tracking-widest text-slate-400 font-bold print:text-slate-600">
                T.C. İÇİŞLERİ BAKANLIĞI AFAD & ROTA+ DAĞCILIK KOORDİNASYON MERKEZİ
              </div>
              <h1 className="text-xl font-black text-white tracking-wider mt-0.5 print:text-black">
                ARAMA-KURTARMA (SAR) TAKTİK GÖREV BRİFİNGİ
              </h1>
              <div className="text-xs text-[#00E5FF] font-mono mt-0.5 print:text-red-700 font-bold">
                VAKA REFERANS KODU: {incidentCode}
              </div>
            </div>

            <div className="text-right text-[10px] font-mono text-slate-300 print:text-slate-700">
              <div className="flex items-center justify-end gap-1 font-bold">
                <Calendar className="w-3 h-3 text-cyan-400" /> {dateStr}
              </div>
              <div className="flex items-center justify-end gap-1">
                <Clock className="w-3 h-3 text-cyan-400" /> {timeStr} TSİ
              </div>
              <div className="text-amber-400 font-bold mt-1">ÖNCELİK: YÜKSEK (ACİL)</div>
            </div>
          </div>

          {/* Section 1: Subject / Casualty Identity */}
          <div className="grid grid-cols-2 gap-3 bg-[#02050D] border border-cyan-500/30 p-3 print:bg-slate-50 print:border-slate-300">
            <div>
              <div className="text-[9px] text-cyan-400 font-bold tracking-wider uppercase print:text-slate-600">
                KAZAZEDE / PERSONEL KİMLİĞİ
              </div>
              <div className="text-base font-black text-white mt-0.5 print:text-black">
                {user.name}
              </div>
              <div className="text-xs text-[#FF6E40] font-semibold print:text-slate-800">
                Kulüp / Ekip: {user.team}
              </div>
              <div className="text-[10px] text-slate-400 mt-1">
                Görevi: {user.role || 'Saha Üyesi'}
              </div>
            </div>

            <div className="space-y-1 text-xs font-mono">
              <div className="flex justify-between border-b border-slate-800 pb-1 print:border-slate-200">
                <span className="text-slate-400 print:text-slate-600">KAN GRUBU:</span>
                <span className="text-red-400 font-bold">{user.kanGrubu || 'BİLİNMİYOR (0 Rh+ Olası)'}</span>
              </div>
              <div className="flex justify-between border-b border-slate-800 pb-1 print:border-slate-200">
                <span className="text-slate-400 print:text-slate-600">BATARYA:</span>
                <span className="text-emerald-400 font-bold">%{user.battery}</span>
              </div>
              <div className="flex justify-between border-b border-slate-800 pb-1 print:border-slate-200">
                <span className="text-slate-400 print:text-slate-600">ACİL TELEFON:</span>
                <span className="text-white font-bold">{user.phone || 'Kayıtsız'}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400 print:text-slate-600">DURUM:</span>
                <span className="text-red-400 font-bold">{user.isFreshSos ? '🚨 ACİL SOS ÇAĞRISI' : 'CANLI TELEMETRİ'}</span>
              </div>
            </div>
          </div>

          {/* Section 2: Precise Coordinates & Mountain Topography */}
          <div className="grid grid-cols-2 gap-3">
            
            {/* Box A: Coordinates */}
            <div className="bg-[#02050D] border border-cyan-500/30 p-3 print:bg-slate-50 print:border-slate-300">
              <div className="text-[9px] text-cyan-400 font-bold tracking-wider uppercase mb-1.5 print:text-slate-600">
                HASSAS COĞRAFİ KOORDİNATLAR
              </div>
              <div className="space-y-1 text-xs font-mono">
                <div>
                  <span className="text-slate-400">DD (Ondalık): </span>
                  <span className="text-white font-bold">{user.lat?.toFixed(6)}°N, {user.lng?.toFixed(6)}°E</span>
                </div>
                <div>
                  <span className="text-slate-400">DMS: </span>
                  <span className="text-cyan-300 font-bold">{dmsLat} / {dmsLng}</span>
                </div>
                <div>
                  <span className="text-slate-400">RAKIM / İRTİFA: </span>
                  <span className="text-amber-400 font-bold">{user.altitude || 160} Metre</span>
                </div>
                <div>
                  <span className="text-slate-400">SEKTÖR: </span>
                  <span className="text-[#00E5FF] font-bold">{analysis?.sectorName}</span>
                </div>
              </div>
            </div>

            {/* Box B: Topography & Slope */}
            <div className="bg-[#02050D] border border-cyan-500/30 p-3 print:bg-slate-50 print:border-slate-300">
              <div className="text-[9px] text-cyan-400 font-bold tracking-wider uppercase mb-1.5 print:text-slate-600">
                TOPOGRAFYA & EĞİM RİSKİ
              </div>
              <div className="space-y-1 text-xs font-mono">
                <div>
                  <span className="text-slate-400">ZEMİN KARAKTERİ: </span>
                  <span className="text-amber-300 font-bold">{analysis?.terrainType}</span>
                </div>
                <div>
                  <span className="text-slate-400">EĞİM DERECESİ: </span>
                  <span className="text-white font-bold">%{profile.slopePercent} ({profile.slopeCategory})</span>
                </div>
                <div>
                  <span className="text-slate-400">EN YAKIN ZİRVE: </span>
                  <span className="text-slate-200">{analysis?.nearestLandmark?.name || 'Mevcut Değil'}</span>
                </div>
                <div>
                  <span className="text-slate-400">EN YAKIN HASTANE: </span>
                  <span className="text-emerald-400 font-bold">{analysis?.nearestHospital?.name || 'AFAD Merkez'}</span>
                </div>
              </div>
            </div>

          </div>

          {/* Section 3: Weather & Survival Assessment */}
          <div className="bg-[#02050D] border border-cyan-500/30 p-3 print:bg-slate-50 print:border-slate-300">
            <div className="text-[9px] text-cyan-400 font-bold tracking-wider uppercase mb-1.5 print:text-slate-600">
              METEOROLOJİ & HİPOTERMİ EŞİĞİ
            </div>
            <div className="grid grid-cols-4 gap-2 text-xs font-mono text-center">
              <div className="border border-slate-800 p-1.5 print:border-slate-200">
                <div className="text-[9px] text-slate-400">ZİRVE SICAKLIK</div>
                <div className="text-sm font-bold text-amber-300">{weather.temp}°C</div>
              </div>
              <div className="border border-slate-800 p-1.5 print:border-slate-200">
                <div className="text-[9px] text-slate-400">RÜZGAR HIZI</div>
                <div className="text-sm font-bold text-[#00E5FF]">{weather.windSpeed} km/s {weather.windCardinal.split(' ')[0]}</div>
              </div>
              <div className="border border-slate-800 p-1.5 print:border-slate-200">
                <div className="text-[9px] text-slate-400">GÖRÜŞ DURUMU</div>
                <div className="text-sm font-bold text-white">{weather.isFoggy ? 'YOĞUN SİS' : 'AÇIK'}</div>
              </div>
              <div className="border border-slate-800 p-1.5 print:border-slate-200">
                <div className="text-[9px] text-slate-400">HİPOTERMİ RİSKİ</div>
                <div className="text-sm font-bold text-red-400">ORTA (4-6 Saat)</div>
              </div>
            </div>
          </div>

          {/* Section 4: Nearest Comrades for Tactical Dispatch */}
          <div className="bg-[#02050D] border border-cyan-500/30 p-3 print:bg-slate-50 print:border-slate-300">
            <div className="text-[9px] text-cyan-400 font-bold tracking-wider uppercase mb-2 print:text-slate-600">
              MÜDAHALE İÇİN EN YAKIN EKİPLER VE İNTİKAL HATTI
            </div>
            <table className="w-full text-xs font-mono text-left">
              <thead>
                <tr className="border-b border-slate-800 text-slate-400 text-[10px] print:border-slate-300">
                  <th className="py-1">EKİP ÜYESİ</th>
                  <th>KULÜP / BRANŞ</th>
                  <th>PUSULA YÖNÜ</th>
                  <th>MESAFE</th>
                  <th>TAHMİNİ İNTİKAL</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800 print:divide-slate-200">
                {analysis?.nearestComrades?.map((comrade, idx) => (
                  <tr key={idx} className="py-1">
                    <td className="py-1 font-bold text-white print:text-black">{comrade.name}</td>
                    <td className="text-slate-400">{comrade.team}</td>
                    <td className="text-amber-400">{comrade.bearing?.short} ({comrade.bearing?.degrees}°)</td>
                    <td className="font-bold text-[#00E5FF]">{comrade.distFormatted}</td>
                    <td className="text-emerald-400 font-bold">~{comrade.estWalkMinutes} dakika</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Sign-off Footer */}
          <div className="pt-4 border-t border-slate-800 flex items-center justify-between text-[10px] font-mono text-slate-400 print:border-slate-300 print:text-slate-700">
            <div>
              KOMUTA MERKEZİ ONAYI: <strong className="text-white print:text-black">ROTA+ NEXUS C2 OPERATÖRÜ</strong>
            </div>
            <div>
              MÜHÜR / İMZA: _______________________
            </div>
          </div>

        </div>

      </div>

    </div>
  );
}
