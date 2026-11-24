import React, { useState, useMemo } from 'react';
import {
  X,
  Send,
  Users,
  Search,
  Hash,
  CheckSquare,
  Square,
  Radio,
  CheckCircle2,
  AlertTriangle
} from 'lucide-react';
import { sendNexusTeamMessage, isNexusAuthenticated, signInNexusCommander, signInNexusWithGoogle } from '../firebase';
import { soundFx } from '../audio';

const QUICK_TEMPLATES = [
  'Toplanma noktasına intikal edin.',
  'Acil durum durum raporu geçin.',
  'Hava koşulları nedeniyle güvenli bölgede bekleyin.',
  'Komuta merkezi sizi izliyor, rotada kalın.'
];

export default function TeamMessageModal({
  isOpen = false,
  onClose = () => {},
  users = [],
  onSentSuccess = () => {}
}) {
  const [searchQuery, setSearchQuery] = useState('');
  const [teamCodeInput, setTeamCodeInput] = useState('');
  const [selectedIds, setSelectedIds] = useState(new Set());
  const [messageText, setMessageText] = useState('');
  const [sending, setSending] = useState(false);
  const [statusMsg, setStatusMsg] = useState(null);
  const [needsAuth, setNeedsAuth] = useState(!isNexusAuthenticated());
  const [cmdEmail, setCmdEmail] = useState('');
  const [cmdPass, setCmdPass] = useState('');
  const [authLoading, setAuthLoading] = useState(false);

  const uniqueTeamCodes = useMemo(() => {
    const map = new Map();
    users.forEach((u) => {
      const code = (u.teamId || '').trim();
      if (!code) return;
      if (!map.has(code)) {
        map.set(code, { code, teamName: u.team || code, count: 0 });
      }
      map.get(code).count += 1;
    });
    return Array.from(map.values());
  }, [users]);

  const filteredUsers = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    const codeFilter = teamCodeInput.trim().toLowerCase();
    return users.filter((u) => {
      const matchesCode = !codeFilter || (u.teamId || '').toLowerCase().includes(codeFilter) || (u.team || '').toLowerCase().includes(codeFilter);
      const matchesName =
        !q ||
        (u.name || '').toLowerCase().includes(q) ||
        (u.username || '').toLowerCase().includes(q) ||
        (u.teamId || '').toLowerCase().includes(q) ||
        (u.team || '').toLowerCase().includes(q);
      return matchesCode && matchesName;
    });
  }, [users, searchQuery, teamCodeInput]);

  if (!isOpen) return null;

  const toggleUser = (id) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const selectByTeamCode = (code) => {
    const clean = code.trim().toLowerCase();
    if (!clean) return;
    const matches = users.filter(
      (u) => (u.teamId || '').toLowerCase() === clean || (u.team || '').toLowerCase() === clean
    );
    setSelectedIds((prev) => {
      const next = new Set(prev);
      matches.forEach((u) => next.add(u.id));
      return next;
    });
    setTeamCodeInput(code);
    soundFx.playSelect();
  };

  const selectAllFiltered = () => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      filteredUsers.forEach((u) => next.add(u.id));
      return next;
    });
    soundFx.playSelect();
  };

  const clearSelection = () => {
    setSelectedIds(new Set());
    setTeamCodeInput('');
  };

  const handleSend = async () => {
    const cleanMsg = messageText.trim();
    if (selectedIds.size === 0) {
      setStatusMsg({ type: 'error', text: 'Lütfen en az bir ekip kodu veya kullanıcı seçin.' });
      return;
    }
    if (!cleanMsg) {
      setStatusMsg({ type: 'error', text: 'Lütfen gönderilecek mesajı yazın.' });
      return;
    }

    setSending(true);
    setStatusMsg(null);
    try {
      const ids = Array.from(selectedIds);
      const selectedUsers = users.filter((u) => selectedIds.has(u.id));
      const teamIds = selectedUsers
        .map((u) => u.teamId)
        .filter((t) => typeof t === 'string' && t.trim().length > 0);
      if (teamCodeInput.trim()) {
        const matchedTeam = uniqueTeamCodes.find(
          (t) => t.code.toLowerCase() === teamCodeInput.trim().toLowerCase()
        );
        if (matchedTeam) teamIds.push(matchedTeam.code);
      }

      const fcmTokens = selectedUsers.flatMap((u) => Array.isArray(u.fcmTokens) ? u.fcmTokens : []);

      const result = await sendNexusTeamMessage({
        recipientIds: ids,
        teamIds,
        fcmTokens,
        message: cleanMsg,
        senderName: 'ROTA+ NEXUS KOMUTA'
      });
      soundFx.playSuccess();
      const pushInfo = result.pushSent > 0
        ? ` (${result.pushSent} cihaza kapalı ekran Push gönderildi)`
        : (result.pushNote ? ` (Not: ${result.pushNote})` : '');
      setStatusMsg({
        type: 'success',
        text: `✓ Mesaj ${result.count} kullanıcıya & ekip chatine iletildi!${pushInfo}`
      });
      onSentSuccess(result.count, cleanMsg);
      setMessageText('');
    } catch (err) {
      if (err.code === 'AUTH_REQUIRED' || (err.message || '').toLowerCase().includes('permission')) {
        setNeedsAuth(true);
        setStatusMsg({
          type: 'error',
          text: 'Firebase yazma yetkisi için aşağıdaki alandan Komuta Hesabı (E-posta & Şifre) ile bir kez oturum açın.'
        });
      } else {
        setStatusMsg({ type: 'error', text: `Gönderim hatası: ${err.message}` });
      }
    } finally {
      setSending(false);
    }
  };

  const handleCommanderLogin = async () => {
    if (!cmdEmail.trim() || !cmdPass) return;
    setAuthLoading(true);
    setStatusMsg(null);
    try {
      await signInNexusCommander(cmdEmail, cmdPass);
      setNeedsAuth(false);
      soundFx.playSuccess();
      setStatusMsg({ type: 'success', text: '✓ Komuta oturumu açıldı! Şimdi GÖNDER butonuna basabilirsiniz.' });
    } catch (err) {
      setStatusMsg({ type: 'error', text: `Giriş hatası: ${err.message}` });
    } finally {
      setAuthLoading(false);
    }
  };

  const handleGoogleLogin = async () => {
    setAuthLoading(true);
    setStatusMsg(null);
    try {
      await signInNexusWithGoogle();
      setNeedsAuth(false);
      soundFx.playSuccess();
      setStatusMsg({ type: 'success', text: '✓ Google ile oturum açıldı! Şimdi GÖNDER butonuna basabilirsiniz.' });
    } catch (err) {
      setStatusMsg({ type: 'error', text: `Google giriş hatası: ${err.message}` });
    } finally {
      setAuthLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-[1000] bg-black/80 backdrop-blur-sm flex items-center justify-center p-4 font-tactical select-none">
      <div className="w-full max-w-3xl bg-[#040814] border border-cyan-500/50 shadow-[0_0_40px_rgba(0,229,255,0.2)] flex flex-col max-h-[90vh]">
        {/* Header */}
        <div className="px-5 py-3.5 border-b border-cyan-500/30 bg-[#02050D] flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <Radio className="w-5 h-5 text-cyan-400 animate-pulse" />
            <div>
              <h2 className="text-sm font-black tracking-widest text-white uppercase">
                EKİBE MESAJ GEÇ // ROTA+ EMNİYETTEYİM BİLDİRİMİ
              </h2>
              <p className="text-[10px] font-mono text-slate-400">
                Ekip kodu veya kullanıcı ismi seçerek seçilen kişilerin telefonuna anlık bildirim gönderin.
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

        {/* Body */}
        <div className="p-5 overflow-y-auto space-y-4 flex-1">
          {/* Ekip Kodu ile Hızlı Seçim */}
          <div>
            <label className="text-[10px] font-mono font-bold text-cyan-400 tracking-wider uppercase block mb-1.5">
              1. EKİP KODU İLE SEÇ (VEYA FİLTRELE)
            </label>
            <div className="flex flex-wrap items-center gap-2">
              <div className="relative flex-1 min-w-[200px]">
                <Hash className="w-3.5 h-3.5 text-cyan-400 absolute left-2.5 top-1/2 -translate-y-1/2" />
                <input
                  type="text"
                  value={teamCodeInput}
                  onChange={(e) => setTeamCodeInput(e.target.value)}
                  placeholder="Ekip kodu yazın (ör. AFAD01)..."
                  className="w-full bg-[#02050D] border border-slate-700 focus:border-cyan-400 text-white text-xs font-mono pl-8 pr-3 py-2 outline-none"
                />
              </div>
              {teamCodeInput.trim() && (
                <button
                  onClick={() => selectByTeamCode(teamCodeInput)}
                  className="px-3 py-2 bg-cyan-950 hover:bg-cyan-900 border border-cyan-400 text-cyan-200 text-[11px] font-mono font-bold cursor-pointer"
                >
                  KODDAKİ TÜM EKİBİ SEÇ
                </button>
              )}
            </div>

            {uniqueTeamCodes.length > 0 && (
              <div className="flex flex-wrap gap-1.5 mt-2">
                {uniqueTeamCodes.map((t) => (
                  <button
                    key={t.code}
                    onClick={() => selectByTeamCode(t.code)}
                    className="px-2 py-1 bg-[#071022] hover:bg-cyan-950 border border-cyan-500/30 text-[10px] font-mono text-cyan-300 cursor-pointer flex items-center gap-1"
                  >
                    <Hash className="w-2.5 h-2.5" />
                    <span className="font-bold">{t.code}</span>
                    <span className="text-slate-400">({t.count})</span>
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* İsim Bazlı Kullanıcı Seçimi */}
          <div>
            <div className="flex items-center justify-between mb-1.5">
              <label className="text-[10px] font-mono font-bold text-cyan-400 tracking-wider uppercase flex items-center gap-1.5">
                <Users className="w-3.5 h-3.5" />
                2. ROTA+ EMNİYETTEYİM KULLANICILARI ({selectedIds.size} SEÇİLİ)
              </label>
              <div className="flex items-center gap-2 text-[10px] font-mono">
                <button
                  onClick={selectAllFiltered}
                  className="text-emerald-400 hover:underline cursor-pointer"
                >
                  Görünenleri Seç ({filteredUsers.length})
                </button>
                <span className="text-slate-700">|</span>
                <button
                  onClick={clearSelection}
                  className="text-red-400 hover:underline cursor-pointer"
                >
                  Seçimi Temizle
                </button>
              </div>
            </div>

            <div className="relative mb-2">
              <Search className="w-3.5 h-3.5 text-slate-400 absolute left-2.5 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="İsim, @kullanıcı adı veya ekip ara..."
                className="w-full bg-[#02050D] border border-slate-800 focus:border-cyan-400 text-white text-xs font-mono pl-8 pr-3 py-2 outline-none"
              />
            </div>

            <div className="max-h-44 overflow-y-auto border border-slate-800 bg-[#02050D] divide-y divide-slate-800/70">
              {filteredUsers.length === 0 ? (
                <div className="p-4 text-center text-xs font-mono text-slate-500">
                  Eşleşen kullanıcı bulunamadı.
                </div>
              ) : (
                filteredUsers.map((u) => {
                  const isChecked = selectedIds.has(u.id);
                  return (
                    <div
                      key={u.id}
                      onClick={() => toggleUser(u.id)}
                      className={`px-3 py-2 flex items-center justify-between cursor-pointer transition-colors ${
                        isChecked ? 'bg-cyan-950/40' : 'hover:bg-slate-900/50'
                      }`}
                    >
                      <div className="flex items-center gap-2.5 min-w-0">
                        {isChecked ? (
                          <CheckSquare className="w-4 h-4 text-cyan-400 shrink-0" />
                        ) : (
                          <Square className="w-4 h-4 text-slate-600 shrink-0" />
                        )}
                        <div className="min-w-0">
                          <div className="text-xs font-bold text-white truncate flex items-center gap-1.5">
                            <span>{u.name}</span>
                            {u.isFreshSos && (
                              <span className="text-[9px] bg-red-950 text-red-300 border border-red-500/60 px-1 font-mono">
                                SOS
                              </span>
                            )}
                          </div>
                          <div className="text-[10px] font-mono text-slate-400 truncate">
                            {u.username ? `@${u.username} • ` : ''}
                            Ekip: {u.team || 'Bireysel'}
                            {u.teamId ? ` [Kod: ${u.teamId}]` : ''}
                          </div>
                        </div>
                      </div>
                      <span className="text-[10px] font-mono text-slate-500 shrink-0 ml-2">
                        %{u.battery ?? 100}
                      </span>
                    </div>
                  );
                })
              )}
            </div>
          </div>

          {/* Mesaj Yazma Alanı */}
          <div>
            <label className="text-[10px] font-mono font-bold text-cyan-400 tracking-wider uppercase block mb-1.5">
              3. GÖNDERİLECEK KOMUTA MESAJI
            </label>
            <div className="flex flex-wrap gap-1.5 mb-2">
              {QUICK_TEMPLATES.map((tpl, idx) => (
                <button
                  key={idx}
                  onClick={() => setMessageText(tpl)}
                  className="text-[10px] font-mono px-2 py-1 bg-[#071022] hover:bg-slate-800 border border-slate-700 text-slate-300 cursor-pointer"
                >
                  + {tpl}
                </button>
              ))}
            </div>
            <textarea
              rows={3}
              value={messageText}
              onChange={(e) => setMessageText(e.target.value)}
              placeholder="Seçilen kişilerin telefonuna bildirim olarak gidecek mesajı yazın..."
              className="w-full bg-[#02050D] border border-slate-700 focus:border-cyan-400 text-white text-xs font-mono p-3 outline-none resize-none"
            />
          </div>

          {needsAuth && (
            <div className="p-3 bg-amber-950/40 border border-amber-500/60 space-y-2">
              <div className="text-[11px] font-mono font-bold text-amber-300">
                🔐 KOMUTA YETKİLENDİRMESİ (FİREBASE OTURUMU)
              </div>
              <p className="text-[10px] font-mono text-slate-300">
                Firestore kuralları mesaj yazmak için oturum gerektirir. Uygulamadaki yetkili e-posta ve şifrenizle bir kez giriş yapın:
              </p>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
                <input
                  type="email"
                  value={cmdEmail}
                  onChange={(e) => setCmdEmail(e.target.value)}
                  placeholder="E-posta (ör. sercanoral65@gmail.com)"
                  className="bg-[#02050D] border border-slate-700 focus:border-amber-400 text-white text-xs font-mono px-2.5 py-1.5 outline-none"
                />
                <input
                  type="password"
                  value={cmdPass}
                  onChange={(e) => setCmdPass(e.target.value)}
                  placeholder="Şifre"
                  className="bg-[#02050D] border border-slate-700 focus:border-amber-400 text-white text-xs font-mono px-2.5 py-1.5 outline-none"
                />
                <button
                  onClick={handleCommanderLogin}
                  disabled={authLoading}
                  className="bg-amber-400 hover:bg-amber-300 text-black font-bold text-xs font-mono py-1.5 px-3 cursor-pointer"
                >
                  {authLoading ? 'GİRİLİYOR...' : 'OTURUM AÇ'}
                </button>
              </div>
              <div className="flex items-center justify-between pt-1">
                <span className="text-[10px] font-mono text-slate-400">
                  Uygulamaya Google ile giriyorsanız:
                </span>
                <button
                  onClick={handleGoogleLogin}
                  disabled={authLoading}
                  className="bg-white hover:bg-slate-200 text-black font-bold text-[11px] font-mono py-1 px-3 cursor-pointer"
                >
                  GOOGLE İLE GİRİŞ YAP
                </button>
              </div>
            </div>
          )}

          {statusMsg && (
            <div
              className={`p-2.5 border text-xs font-mono flex items-center gap-2 ${
                statusMsg.type === 'success'
                  ? 'bg-emerald-950/60 border-emerald-500 text-emerald-300'
                  : 'bg-red-950/60 border-red-500 text-red-300'
              }`}
            >
              {statusMsg.type === 'success' ? (
                <CheckCircle2 className="w-4 h-4 shrink-0" />
              ) : (
                <AlertTriangle className="w-4 h-4 shrink-0" />
              )}
              <span>{statusMsg.text}</span>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="px-5 py-3 border-t border-slate-800 bg-[#02050D] flex items-center justify-end gap-2">
          <button
            onClick={onClose}
            className="px-4 py-2 text-xs font-mono text-slate-400 hover:text-white border border-slate-800 cursor-pointer"
          >
            KAPAT
          </button>
          <button
            onClick={handleSend}
            disabled={sending}
            className="px-5 py-2 bg-[#00E5FF] hover:bg-cyan-300 disabled:opacity-50 text-[#02040A] font-black text-xs font-mono flex items-center gap-1.5 cursor-pointer shadow-[0_0_15px_rgba(0,229,255,0.4)]"
          >
            <Send className="w-3.5 h-3.5" />
            <span>{sending ? 'GÖNDERİLİYOR...' : `GÖNDER (${selectedIds.size})`}</span>
          </button>
        </div>
      </div>
    </div>
  );
}
