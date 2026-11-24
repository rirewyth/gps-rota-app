import React, { useState, useMemo } from 'react';
import {
  X,
  AlertTriangle,
  Phone,
  Clock,
  MapPin,
  User,
  CheckCircle2,
  Send,
  Users,
  Search
} from 'lucide-react';
import {
  updateDisasterReportStatus,
  dispatchUsersToReport,
  isNexusAuthenticated,
  signInNexusWithGoogle
} from '../firebase';
import { calculateDistanceMeters } from '../utils/terrainMath';
import { soundFx } from '../audio';

export default function ReportsModal({
  isOpen = false,
  onClose = () => {},
  reports = [],
  users = [],
  onCenterReport = () => {}
}) {
  const [authNeeded, setAuthNeeded] = useState(!isNexusAuthenticated());
  const [errMsg, setErrMsg] = useState('');
  const [successMsg, setSuccessMsg] = useState('');
  const [dispatchingReportId, setDispatchingReportId] = useState(null);
  const [selectedUserIds, setSelectedUserIds] = useState(new Set());
  const [userSearch, setUserSearch] = useState('');
  const [dispatchNote, setDispatchNote] = useState('');
  const [isSendingDispatch, setIsSendingDispatch] = useState(false);

  const activeDispatchReport = useMemo(
    () => reports.find((r) => r.id === dispatchingReportId) || null,
    [reports, dispatchingReportId]
  );

  const sortedCandidates = useMemo(() => {
    const q = userSearch.trim().toLowerCase();
    const list = users
      .filter((u) => !q || (u.name || '').toLowerCase().includes(q) || (u.teamId || '').toLowerCase().includes(q))
      .map((u) => {
        let distKm = null;
        if (
          activeDispatchReport?.lat != null &&
          activeDispatchReport?.lng != null &&
          u.hasCoords &&
          Array.isArray(u.coords) &&
          u.coords.length === 2
        ) {
          const m = calculateDistanceMeters(
            activeDispatchReport.lat,
            activeDispatchReport.lng,
            u.coords[0],
            u.coords[1]
          );
          distKm = m / 1000;
        }
        return { ...u, distKm };
      });
    list.sort((a, b) => {
      if (a.distKm != null && b.distKm != null) return a.distKm - b.distKm;
      if (a.distKm != null) return -1;
      if (b.distKm != null) return 1;
      return (a.name || '').localeCompare(b.name || '', 'tr');
    });
    return list;
  }, [users, userSearch, activeDispatchReport]);

  if (!isOpen) return null;

  const toggleUser = (uid) => {
    setSelectedUserIds((prev) => {
      const next = new Set(prev);
      if (next.has(uid)) next.delete(uid);
      else next.add(uid);
      return next;
    });
  };

  const handleOpenDispatch = (repId) => {
    setErrMsg('');
    setSuccessMsg('');
    if (dispatchingReportId === repId) {
      setDispatchingReportId(null);
      return;
    }
    setDispatchingReportId(repId);
    setSelectedUserIds(new Set());
    setUserSearch('');
    setDispatchNote('');
  };

  const handleSendDispatch = async (rep) => {
    const chosen = users.filter((u) => selectedUserIds.has(u.id));
    if (chosen.length === 0) {
      setErrMsg('Yönlendirmek için veritabanından en az 1 kişi seçin.');
      return;
    }
    setErrMsg('');
    setSuccessMsg('');
    setIsSendingDispatch(true);
    try {
      const count = await dispatchUsersToReport({
        report: rep,
        selectedUsers: chosen,
        note: dispatchNote,
      });
      soundFx.playSuccess();
      setSuccessMsg(`✓ ${count} gerçek operatöre görev yönlendirmesi ve telefon bildirimi gönderildi.`);
      setDispatchingReportId(null);
      setSelectedUserIds(new Set());
      setDispatchNote('');
    } catch (e) {
      setErrMsg(`Yönlendirme hatası: ${e.message}`);
    } finally {
      setIsSendingDispatch(false);
    }
  };

  const handleStatus = async (id, st) => {
    setErrMsg('');
    try {
      await updateDisasterReportStatus(id, st);
      soundFx.playSelect();
    } catch (e) {
      setErrMsg(`Durum güncellenemedi (Admin girişi gerekebilir): ${e.message}`);
      setAuthNeeded(true);
    }
  };

  const handleGoogleAuth = async () => {
    setErrMsg('');
    try {
      await signInNexusWithGoogle();
      setAuthNeeded(false);
      soundFx.playSuccess();
    } catch (e) {
      setErrMsg(`Giriş hatası: ${e.message}`);
    }
  };

  return (
    <div className="fixed inset-0 z-[1000] bg-black/80 backdrop-blur-sm flex items-center justify-center p-4 font-tactical select-none">
      <div className="w-full max-w-4xl bg-[#040814] border border-amber-500/50 shadow-[0_0_40px_rgba(245,158,11,0.2)] flex flex-col max-h-[90vh]">
        <div className="px-5 py-3.5 border-b border-amber-500/30 bg-[#02050D] flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <AlertTriangle className="w-5 h-5 text-amber-400 animate-pulse" />
            <div>
              <h2 className="text-sm font-black tracking-widest text-white uppercase">
                GELEN AFET &amp; OLAY İHBARLARI ({reports.length})
              </h2>
              <p className="text-[10px] font-mono text-slate-400">
                Rota+ Emniyetteyim üzerinden gönderilen deprem, sel, yangın ihbarları (Telefon, Tarih, Özet &amp; Fotoğraf)
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 text-slate-400 hover:text-white border border-slate-800 hover:border-slate-600 cursor-pointer"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        <div className="p-5 overflow-y-auto space-y-3 flex-1">
          {authNeeded && (
            <div className="p-3 bg-amber-950/40 border border-amber-500/50 flex items-center justify-between gap-3">
              <span className="text-[11px] font-mono text-amber-200">
                İhbarları görüntülemek ve durum güncellemek için Admin hesabınızla oturum açın:
              </span>
              <button
                onClick={handleGoogleAuth}
                className="bg-white hover:bg-slate-200 text-black font-bold text-[11px] font-mono px-3 py-1.5 shrink-0 cursor-pointer"
              >
                GOOGLE İLE GİRİŞ YAP
              </button>
            </div>
          )}

          {errMsg && (
            <div className="p-2.5 bg-red-950/60 border border-red-500 text-red-300 text-xs font-mono">
              {errMsg}
            </div>
          )}

          {successMsg && (
            <div className="p-2.5 bg-emerald-950/60 border border-emerald-500 text-emerald-300 text-xs font-mono">
              {successMsg}
            </div>
          )}

          {reports.length === 0 ? (
            <div className="py-12 text-center text-xs font-mono text-slate-500">
              Henüz gelen afet/olay ihbarı bulunmuyor (veya Admin oturumu bekleniyor).
            </div>
          ) : (
            reports.map((rep) => (
              <div
                key={rep.id}
                className="bg-[#02050D] border border-slate-800 hover:border-amber-500/40 p-4 space-y-2.5"
              >
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <span className="px-2 py-0.5 bg-red-950 border border-red-500/60 text-red-300 font-mono text-[10px] font-bold uppercase">
                      {rep.disasterType}
                    </span>
                    <span className="px-2 py-0.5 bg-amber-950/60 border border-amber-500/40 text-amber-300 font-mono text-[10px] font-bold">
                      {rep.status}
                    </span>
                  </div>
                  <div className="flex items-center gap-1.5 text-[10px] font-mono text-slate-400">
                    <Clock className="w-3 h-3 text-cyan-400" />
                    <span>{rep.dateTimeStr || 'Tarih yok'}</span>
                  </div>
                </div>

                <div className="flex flex-wrap items-center gap-4 text-xs font-mono text-slate-200">
                  <span className="flex items-center gap-1.5 font-bold">
                    <User className="w-3.5 h-3.5 text-cyan-400" />
                    {rep.reporterName}
                  </span>
                  <span className="flex items-center gap-1.5 text-emerald-300 font-bold">
                    <Phone className="w-3.5 h-3.5" />
                    {rep.reporterPhone}
                  </span>
                  <span className="px-2 py-0.5 bg-slate-900 border border-slate-700 text-slate-300 text-[10px]">
                    🌐 IP: {rep.reporterIp || 'Alınamadı'}
                  </span>
                  {rep.lat != null && rep.lng != null && (
                    <button
                      onClick={() => {
                        onCenterReport([rep.lat, rep.lng]);
                        onClose();
                      }}
                      className="flex items-center gap-1 text-cyan-300 hover:underline cursor-pointer"
                    >
                      <MapPin className="w-3.5 h-3.5" />
                      {rep.lat.toFixed(4)}, {rep.lng.toFixed(4)} (Haritada Gör)
                    </button>
                  )}
                </div>

                <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 bg-[#050B1A] border border-slate-800/80 p-2.5 text-[11px] font-mono">
                  <div>
                    <span className="text-slate-500 block text-[9px]">İL</span>
                    <span className="text-slate-100 font-bold">{rep.province || 'Belirtilmedi'}</span>
                  </div>
                  <div>
                    <span className="text-slate-500 block text-[9px]">İLÇE</span>
                    <span className="text-slate-100 font-bold">{rep.district || 'Belirtilmedi'}</span>
                  </div>
                  <div>
                    <span className="text-slate-500 block text-[9px]">MAHALLE</span>
                    <span className="text-slate-100 font-bold">{rep.neighborhood || 'Belirtilmedi'}</span>
                  </div>
                  <div>
                    <span className="text-slate-500 block text-[9px]">SOKAK / CADDE / NO</span>
                    <span className="text-slate-100 font-bold">{rep.street || 'Belirtilmedi'}</span>
                  </div>
                </div>

                {rep.fullAddress && (
                  <div className="text-[11px] font-mono text-amber-200 bg-amber-950/30 border border-amber-500/30 px-2.5 py-1.5">
                    🏠 TAM ADRES: {rep.fullAddress}
                  </div>
                )}

                <div>
                  <span className="text-[9px] font-mono text-slate-500 uppercase tracking-wider block mb-1">
                    OLAY RAPORU &amp; ÖZET
                  </span>
                  <p className="text-xs font-mono text-slate-200 bg-[#070E1F] p-2.5 border border-slate-800/80 leading-relaxed">
                    {rep.summary}
                  </p>
                </div>

                {Array.isArray(rep.dispatchedTo) && rep.dispatchedTo.length > 0 && (
                  <div className="bg-cyan-950/25 border border-cyan-500/30 p-2.5 space-y-1">
                    <span className="text-[9px] font-mono text-cyan-300 font-bold uppercase block">
                      SEVK EDİLEN OPERATÖRLER ({rep.dispatchedTo.length})
                    </span>
                    <div className="flex flex-wrap gap-1.5">
                      {rep.dispatchedTo.map((d, idx) => (
                        <span
                          key={`${d.uid || idx}-${idx}`}
                          className="px-2 py-0.5 bg-cyan-950/70 border border-cyan-500/40 text-cyan-200 text-[10px] font-mono"
                        >
                          👤 {d.name} {d.dispatchedAt ? `(${d.dispatchedAt})` : ''}
                        </span>
                      ))}
                    </div>
                  </div>
                )}

                {rep.imageBase64 && (
                  <img
                    src={`data:image/jpeg;base64,${rep.imageBase64}`}
                    alt="İhbar Fotoğrafı"
                    className="w-full max-h-60 object-cover border border-slate-800"
                  />
                )}

                <div className="flex flex-wrap items-center justify-between gap-2 pt-1">
                  <div className="flex flex-wrap items-center gap-2">
                    {['İNCELENİYOR', 'SEVK EDİLDİ', 'ÇÖZÜLDÜ'].map((st) => (
                      <button
                        key={st}
                        onClick={() => handleStatus(rep.id, st)}
                        className={`px-2.5 py-1 text-[10px] font-mono font-bold border cursor-pointer flex items-center gap-1 ${
                          rep.status === st
                            ? 'bg-emerald-950 border-emerald-400 text-emerald-300'
                            : 'bg-[#071022] border-slate-700 text-slate-300 hover:border-cyan-400'
                        }`}
                      >
                        <CheckCircle2 className="w-3 h-3" />
                        {st}
                      </button>
                    ))}
                  </div>

                  <button
                    onClick={() => handleOpenDispatch(rep.id)}
                    className={`px-3 py-1.5 text-[10px] font-mono font-bold border cursor-pointer flex items-center gap-1.5 ${
                      dispatchingReportId === rep.id
                        ? 'bg-amber-600 border-amber-400 text-black'
                        : 'bg-cyan-950/70 border-cyan-400/60 text-cyan-200 hover:bg-cyan-900/60'
                    }`}
                  >
                    <Users className="w-3.5 h-3.5" />
                    İNSAN YÖNLENDİR ({users.length})
                  </button>
                </div>

                {dispatchingReportId === rep.id && (
                  <div className="mt-2 p-3 bg-[#060D20] border border-cyan-500/40 space-y-2.5">
                    <div className="flex items-center justify-between gap-2">
                      <span className="text-[11px] font-mono font-bold text-cyan-300">
                        VERİTABANINDAN OPERATÖR SEÇ &amp; OLAYA YÖNLENDİR
                      </span>
                      <span className="text-[10px] font-mono text-slate-400">
                        Seçili: {selectedUserIds.size} kişi
                      </span>
                    </div>

                    <div className="relative">
                      <Search className="w-3.5 h-3.5 text-slate-400 absolute left-2.5 top-2.5" />
                      <input
                        type="text"
                        value={userSearch}
                        onChange={(e) => setUserSearch(e.target.value)}
                        placeholder="Operatör adı veya ekip ara..."
                        className="w-full bg-[#02050D] border border-slate-700 pl-8 pr-3 py-1.5 text-xs font-mono text-white focus:outline-none focus:border-cyan-400"
                      />
                    </div>

                    <div className="max-h-44 overflow-y-auto space-y-1 border border-slate-800/80 bg-[#02050D] p-1.5">
                      {sortedCandidates.length === 0 ? (
                        <div className="text-[11px] font-mono text-slate-500 p-3 text-center">
                          Eşleşen kullanıcı bulunamadı.
                        </div>
                      ) : (
                        sortedCandidates.map((u) => {
                          const checked = selectedUserIds.has(u.id);
                          return (
                            <label
                              key={u.id}
                              className={`flex items-center justify-between gap-2 px-2.5 py-1.5 cursor-pointer text-xs font-mono border ${
                                checked
                                  ? 'bg-cyan-950/60 border-cyan-500/60 text-white'
                                  : 'border-transparent hover:bg-slate-900/60 text-slate-300'
                              }`}
                            >
                              <div className="flex items-center gap-2 min-w-0">
                                <input
                                  type="checkbox"
                                  checked={checked}
                                  onChange={() => toggleUser(u.id)}
                                  className="accent-cyan-400"
                                />
                                <span className="truncate font-bold">{u.name}</span>
                                {u.teamId && (
                                  <span className="text-[10px] text-amber-300 shrink-0">[{u.teamId}]</span>
                                )}
                              </div>
                              <span className="text-[10px] text-cyan-300 shrink-0">
                                {u.distKm != null ? `${u.distKm.toFixed(1)} km` : 'GPS yok'}
                              </span>
                            </label>
                          );
                        })
                      )}
                    </div>

                    <input
                      type="text"
                      value={dispatchNote}
                      onChange={(e) => setDispatchNote(e.target.value)}
                      placeholder="Yönlendirme / görev talimatı (opsiyonel)..."
                      className="w-full bg-[#02050D] border border-slate-700 px-3 py-1.5 text-xs font-mono text-white focus:outline-none focus:border-cyan-400"
                    />

                    <div className="flex justify-end gap-2">
                      <button
                        onClick={() => setDispatchingReportId(null)}
                        className="px-3 py-1.5 text-[10px] font-mono border border-slate-700 text-slate-300 cursor-pointer"
                      >
                        İPTAL
                      </button>
                      <button
                        disabled={isSendingDispatch || selectedUserIds.size === 0}
                        onClick={() => handleSendDispatch(rep)}
                        className="px-3 py-1.5 text-[10px] font-mono font-bold bg-cyan-500 hover:bg-cyan-400 disabled:opacity-40 text-black flex items-center gap-1.5 cursor-pointer"
                      >
                        <Send className="w-3 h-3" />
                        {isSendingDispatch
                          ? 'GÖNDERİLİYOR...'
                          : `SEÇİLİ KİŞİLERİ YÖNLENDİR (${selectedUserIds.size})`}
                      </button>
                    </div>
                  </div>
                )}
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
