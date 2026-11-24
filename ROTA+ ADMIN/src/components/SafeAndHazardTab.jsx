import React, { useEffect, useState } from 'react';
import { ShieldCheck, AlertOctagon, Trash2, Plus } from 'lucide-react';
import { createSafeZone, createHazardZone, deleteDocByPath, logAdminAction } from '../firebase';

export default function SafeAndHazardTab({
  safeZones = [],
  hazardZones = [],
  prefillSafeCoords = null,
  prefillHazardCoords = null,
}) {
  // Safe zone form
  const [szName, setSzName] = useState('');
  const [szCat, setSzCat] = useState('Toplanma Alanı');
  const [szLat, setSzLat] = useState('');
  const [szLng, setSzLng] = useState('');
  const [szCap, setSzCap] = useState('');
  const [szNote, setSzNote] = useState('');

  // Hazard zone form
  const [hzName, setHzName] = useState('');
  const [hzType, setHzType] = useState('Heyelan Riski');
  const [hzLat, setHzLat] = useState('');
  const [hzLng, setHzLng] = useState('');
  const [hzRadius, setHzRadius] = useState('500');
  const [hzNote, setHzNote] = useState('');

  useEffect(() => {
    if (Array.isArray(prefillSafeCoords) && prefillSafeCoords.length === 2) {
      setSzLat(prefillSafeCoords[0].toFixed(5));
      setSzLng(prefillSafeCoords[1].toFixed(5));
    }
  }, [prefillSafeCoords]);

  useEffect(() => {
    if (Array.isArray(prefillHazardCoords) && prefillHazardCoords.length === 2) {
      setHzLat(prefillHazardCoords[0].toFixed(5));
      setHzLng(prefillHazardCoords[1].toFixed(5));
    }
  }, [prefillHazardCoords]);

  return (
    <div className="grid gap-5 lg:grid-cols-2">
      {/* SAFE ZONES */}
      <div className="space-y-3">
        <form
          onSubmit={async (e) => {
            e.preventDefault();
            if (!szName.trim() || !szLat || !szLng) return;
            await createSafeZone({ name: szName, category: szCat, lat: szLat, lng: szLng, capacity: szCap, note: szNote });
            setSzName(''); setSzLat(''); setSzLng(''); setSzCap(''); setSzNote('');
          }}
          className="bg-[#040814] border border-emerald-500/40 p-4 space-y-2.5"
        >
          <div className="flex items-center gap-2 text-xs font-bold text-emerald-400 uppercase">
            <ShieldCheck className="w-4 h-4" /> TOPLANMA / YARDIM NOKTASI EKLE
          </div>
          <input value={szName} onChange={(e) => setSzName(e.target.value)} placeholder="ALAN ADI (ÖR: ATATÜRK PARKI TOPLANMA)" className="w-full bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white" />
          <div className="grid grid-cols-2 gap-2">
            <select value={szCat} onChange={(e) => setSzCat(e.target.value)} className="bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white">
              <option>Toplanma Alanı</option>
              <option>Su / Gıda Noktası</option>
              <option>Çadır Kent</option>
              <option>İlk Yardım İstasyonu</option>
            </select>
            <input value={szCap} onChange={(e) => setSzCap(e.target.value)} placeholder="KAPASİTE (ÖR: 500 KİŞİ)" className="bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white" />
          </div>
          <div className="grid grid-cols-2 gap-2">
            <input value={szLat} onChange={(e) => setSzLat(e.target.value)} placeholder="ENLEM (LAT)" className="bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white" />
            <input value={szLng} onChange={(e) => setSzLng(e.target.value)} placeholder="BOYLAM (LNG)" className="bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white" />
          </div>
          <input value={szNote} onChange={(e) => setSzNote(e.target.value)} placeholder="EK NOT..." className="w-full bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white" />
          <button type="submit" className="w-full py-2 bg-emerald-600 hover:bg-emerald-500 text-black font-black text-xs flex items-center justify-center gap-1 cursor-pointer">
            <Plus className="w-4 h-4" /> GÜVENLİ NOKTA EKLE
          </button>
        </form>

        <div className="space-y-2">
          {safeZones.map((z) => (
            <div key={z.id} className="bg-[#040814] border border-slate-800 p-3 flex justify-between gap-2 text-xs">
              <div>
                <div className="font-bold text-emerald-300">🟢 {z.name} <span className="text-[10px] text-slate-400">[{z.category}]</span></div>
                <div className="text-[11px] text-[#00E5FF]">{z.lat}, {z.lng} {z.capacity ? `• Kapasite: ${z.capacity}` : ''}</div>
                {z.note && <div className="text-slate-400 mt-0.5">{z.note}</div>}
              </div>
              <button
                onClick={async () => {
                  await deleteDocByPath('safe_zones', z.id);
                  await logAdminAction('TOPLANMA_ALANI_SILINDI', z.name || z.id, '');
                }}
                className="text-red-400 hover:text-red-300 p-1 h-fit cursor-pointer"
              >
                <Trash2 className="w-4 h-4" />
              </button>
            </div>
          ))}
        </div>
      </div>

      {/* HAZARD ZONES */}
      <div className="space-y-3">
        <form
          onSubmit={async (e) => {
            e.preventDefault();
            if (!hzName.trim() || !hzLat || !hzLng) return;
            await createHazardZone({ name: hzName, hazardType: hzType, lat: hzLat, lng: hzLng, radiusMeters: hzRadius, note: hzNote });
            setHzName(''); setHzLat(''); setHzLng(''); setHzRadius('500'); setHzNote('');
          }}
          className="bg-[#040814] border border-red-500/40 p-4 space-y-2.5"
        >
          <div className="flex items-center gap-2 text-xs font-bold text-red-400 uppercase">
            <AlertOctagon className="w-4 h-4" /> TEHLİKELİ BÖLGE (RED ZONE) EKLE
          </div>
          <input value={hzName} onChange={(e) => setHzName(e.target.value)} placeholder="BÖLGE ADI (ÖR: KUZEY YAMACI HEYELAN)" className="w-full bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white" />
          <div className="grid grid-cols-2 gap-2">
            <select value={hzType} onChange={(e) => setHzType(e.target.value)} className="bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white">
              <option>Heyelan Riski</option>
              <option>Çığ Tehlikesi</option>
              <option>Yangın Sınırı</option>
              <option>Enkaz / Yıkım Alanı</option>
              <option>Taşkın / Sel</option>
            </select>
            <input value={hzRadius} onChange={(e) => setHzRadius(e.target.value)} placeholder="YARIÇAP (METRE)" className="bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white" />
          </div>
          <div className="grid grid-cols-2 gap-2">
            <input value={hzLat} onChange={(e) => setHzLat(e.target.value)} placeholder="ENLEM (LAT)" className="bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white" />
            <input value={hzLng} onChange={(e) => setHzLng(e.target.value)} placeholder="BOYLAM (LNG)" className="bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white" />
          </div>
          <input value={hzNote} onChange={(e) => setHzNote(e.target.value)} placeholder="UYARI NOTU..." className="w-full bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white" />
          <button type="submit" className="w-full py-2 bg-red-600 hover:bg-red-500 text-white font-black text-xs flex items-center justify-center gap-1 cursor-pointer">
            <Plus className="w-4 h-4" /> RİSKLİ BÖLGE EKLE
          </button>
        </form>

        <div className="space-y-2">
          {hazardZones.map((z) => (
            <div key={z.id} className="bg-[#040814] border border-slate-800 p-3 flex justify-between gap-2 text-xs">
              <div>
                <div className="font-bold text-red-400">⛔ {z.name} <span className="text-[10px] text-amber-300">[{z.hazardType} • {z.radiusMeters || 500}m]</span></div>
                <div className="text-[11px] text-[#00E5FF]">{z.lat}, {z.lng}</div>
                {z.note && <div className="text-slate-400 mt-0.5">{z.note}</div>}
              </div>
              <button
                onClick={async () => {
                  await deleteDocByPath('hazard_zones', z.id);
                  await logAdminAction('RISKLI_BOLGE_SILINDI', z.name || z.id, '');
                }}
                className="text-red-400 hover:text-red-300 p-1 h-fit cursor-pointer"
              >
                <Trash2 className="w-4 h-4" />
              </button>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
