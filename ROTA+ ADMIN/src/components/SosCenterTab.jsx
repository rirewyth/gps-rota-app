import React from 'react';
import { AlertOctagon, MapPin, Phone, CheckCircle2, Heart } from 'lucide-react';
import { updateUserFlags, logAdminAction } from '../firebase';

export default function SosCenterTab({ users = [], onLocate }) {
  const sosUsers = users.filter((u) => u.is_sos === true || u.sos === true);

  const handleClearSos = async (u) => {
    await updateUserFlags(u.id, { is_sos: false, sos: false, safety_status: 'safe' });
    await logAdminAction('SOS_KAPATILDI', u.name || u.ad || u.id, 'Admin tarafından SOS sonlandırıldı');
  };

  if (sosUsers.length === 0) {
    return (
      <div className="py-14 text-center border border-emerald-500/20 bg-[#040814]">
        <div className="text-emerald-400 text-sm font-bold">✓ AKTİF SOS SİNYALİ YOK</div>
        <div className="text-xs text-slate-500 mt-1">Tüm operatörler güvenli durumda.</div>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {sosUsers.map((u) => {
        const name = u.name || u.ad || u.username || u.id;
        const lat = parseFloat(u.lat ?? u.last_lat);
        const lng = parseFloat(u.lng ?? u.last_lng);
        const hasCoords = !isNaN(lat) && !isNaN(lng) && !(lat === 0 && lng === 0);
        return (
          <div
            key={u.id}
            className="bg-[#040814] border border-red-500/70 shadow-[0_0_20px_rgba(239,68,68,0.18)] p-4 flex flex-wrap items-center justify-between gap-4"
          >
            <div className="space-y-1.5">
              <div className="flex items-center gap-2">
                <AlertOctagon className="w-5 h-5 text-red-500 animate-pulse" />
                <span className="text-sm font-black text-white">{name}</span>
                <span className="px-2 py-0.5 bg-red-600 text-white text-[10px] font-bold">CANLI SOS</span>
              </div>
              <div className="flex flex-wrap gap-4 text-xs text-slate-300">
                <span className="flex items-center gap-1 text-emerald-300">
                  <Phone className="w-3.5 h-3.5" /> Tel: {u.phone || u.telefon || '-'}
                </span>
                <span>
                  Acil Kişi: <strong className="text-amber-300">{u.acil_kisi_ad || '-'} ({u.acil_kisi_tel || '-'})</strong>
                </span>
                <span className="flex items-center gap-1 text-red-300">
                  <Heart className="w-3.5 h-3.5" /> {u.kan_grubu || '-'}
                </span>
              </div>
              {hasCoords && (
                <div className="text-xs text-[#00E5FF]">
                  📍 {lat.toFixed(5)}, {lng.toFixed(5)}
                </div>
              )}
            </div>

            <div className="flex items-center gap-2">
              {hasCoords && (
                <button
                  onClick={() => onLocate([lat, lng])}
                  className="px-3 py-1.5 border border-[#00E5FF]/60 bg-[#00E5FF]/10 text-[#00E5FF] text-xs font-bold flex items-center gap-1 cursor-pointer"
                >
                  <MapPin className="w-3.5 h-3.5" /> HARİTADA GÖR
                </button>
              )}
              <button
                onClick={() => handleClearSos(u)}
                className="px-3 py-1.5 border border-emerald-500/60 bg-emerald-950/70 text-emerald-200 text-xs font-bold flex items-center gap-1 cursor-pointer"
              >
                <CheckCircle2 className="w-3.5 h-3.5" /> SOS KAPAT
              </button>
            </div>
          </div>
        );
      })}
    </div>
  );
}
