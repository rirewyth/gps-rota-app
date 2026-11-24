import React, { useEffect, useState } from 'react';
import { X, Send, Shield, Crown, BadgeCheck, Ban, Phone, Heart, MapPin, Route, Trash2 } from 'lucide-react';
import { sendDirectUserNotification, updateUserFlags, formatImgSrc, fetchUserRoutes, deleteUserRoute } from '../firebase';

export default function UserDetailModal({ user, onClose }) {
  const [notifTitle, setNotifTitle] = useState('ROTA+ ADMIN YÖNETİM');
  const [notifMsg, setNotifMsg] = useState('');
  const [sending, setSending] = useState(false);
  const [feedback, setFeedback] = useState('');
  const [routes, setRoutes] = useState([]);

  useEffect(() => {
    if (!user?.id) {
      setRoutes([]);
      return;
    }
    fetchUserRoutes(user.id).then(setRoutes).catch(() => setRoutes([]));
  }, [user?.id]);

  if (!user) return null;

  const avatar = formatImgSrc(user.profile_pic_url || user.avatar || user.photoURL);
  const name = user.name || user.ad || user.username || 'Operatör';
  const lat = parseFloat(user.lat ?? user.last_lat);
  const lng = parseFloat(user.lng ?? user.last_lng);
  const hasCoords = !isNaN(lat) && !isNaN(lng) && !(lat === 0 && lng === 0);

  const handleSend = async (e) => {
    e.preventDefault();
    if (!notifMsg.trim()) return;
    setSending(true);
    setFeedback('');
    try {
      await sendDirectUserNotification({ uid: user.id, title: notifTitle, message: notifMsg });
      setFeedback('✓ Bildirim kullanıcının telefonuna gönderildi.');
      setNotifMsg('');
    } catch (err) {
      setFeedback(`Hata: ${err.message}`);
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4 font-tactical">
      <div className="w-full max-w-xl bg-[#040814] border border-[#00E5FF]/50 shadow-[0_0_40px_rgba(0,229,255,0.15)] flex flex-col max-h-[90vh]">
        <div className="px-4 py-3 bg-[#02050D] border-b border-[#00E5FF]/30 flex items-center justify-between">
          <div className="flex items-center gap-3">
            {avatar ? (
              <img src={avatar} alt={name} className="w-9 h-9 object-cover border border-[#00E5FF]/50" />
            ) : (
              <div className="w-9 h-9 bg-[#070E1F] border border-slate-700 flex items-center justify-center text-xs font-bold text-[#00E5FF]">
                {name.slice(0, 2).toUpperCase()}
              </div>
            )}
            <div>
              <div className="text-sm font-black text-white">{name}</div>
              <div className="text-[10px] text-slate-400">{user.email || user.id}</div>
            </div>
          </div>
          <button onClick={onClose} className="p-1 text-slate-400 hover:text-white cursor-pointer">
            <X className="w-4 h-4" />
          </button>
        </div>

        <div className="p-4 overflow-y-auto space-y-4">
          {/* Telemetry & Profile Details */}
          <div className="grid grid-cols-2 gap-2 bg-[#02050D] border border-slate-800 p-3 text-xs">
            <div><span className="text-slate-500 block text-[9px]">TELEFON</span><span className="text-emerald-300 flex items-center gap-1"><Phone className="w-3 h-3" /> {user.phone || user.telefon || '-'}</span></div>
            <div><span className="text-slate-500 block text-[9px]">KAN GRUBU</span><span className="text-red-300 flex items-center gap-1"><Heart className="w-3 h-3" /> {user.kan_grubu || user.bloodType || '-'}</span></div>
            <div><span className="text-slate-500 block text-[9px]">ACİL DURUM KİŞİSİ</span><span className="text-white">{user.acil_kisi_ad || '-'} ({user.acil_kisi_tel || '-'})</span></div>
            <div><span className="text-slate-500 block text-[9px]">BOY / KİLO / YAŞ</span><span className="text-white">{user.boy_cm || '-'} cm / {user.kilo_kg || '-'} kg / {user.yas || '-'}</span></div>
            <div className="col-span-2">
              <span className="text-slate-500 block text-[9px]">SON KONUM</span>
              <span className="text-[#00E5FF] flex items-center gap-1">
                <MapPin className="w-3 h-3" /> {hasCoords ? `${lat.toFixed(5)}, ${lng.toFixed(5)}` : 'Konum yok'}
              </span>
            </div>
          </div>

          {/* Role & Flag Toggles */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
            <button
              onClick={() => updateUserFlags(user.id, { is_admin: !user.is_admin })}
              className={`py-2 px-2 border text-[10px] font-bold flex items-center justify-center gap-1 cursor-pointer ${
                user.is_admin ? 'bg-purple-950 border-purple-400 text-purple-200' : 'bg-[#070E1F] border-slate-700 text-slate-300'
              }`}
            >
              <Shield className="w-3.5 h-3.5" /> {user.is_admin ? 'ADMIN: AÇIK' : 'ADMIN YAP'}
            </button>
            <button
              onClick={() => updateUserFlags(user.id, { is_premium: !user.is_premium })}
              className={`py-2 px-2 border text-[10px] font-bold flex items-center justify-center gap-1 cursor-pointer ${
                user.is_premium ? 'bg-amber-950 border-amber-400 text-amber-200' : 'bg-[#070E1F] border-slate-700 text-slate-300'
              }`}
            >
              <Crown className="w-3.5 h-3.5" /> {user.is_premium ? 'PREMIUM: AÇIK' : 'PREMIUM YAP'}
            </button>
            <button
              onClick={() => updateUserFlags(user.id, { is_verified: !user.is_verified })}
              className={`py-2 px-2 border text-[10px] font-bold flex items-center justify-center gap-1 cursor-pointer ${
                user.is_verified ? 'bg-cyan-950 border-[#00E5FF] text-[#00E5FF]' : 'bg-[#070E1F] border-slate-700 text-slate-300'
              }`}
            >
              <BadgeCheck className="w-3.5 h-3.5" /> {user.is_verified ? 'ONAYLI' : 'ONAYLA'}
            </button>
            <button
              onClick={() => updateUserFlags(user.id, { is_banned: !user.is_banned })}
              className={`py-2 px-2 border text-[10px] font-bold flex items-center justify-center gap-1 cursor-pointer ${
                user.is_banned ? 'bg-red-950 border-red-400 text-red-200' : 'bg-[#070E1F] border-slate-700 text-red-300'
              }`}
            >
              <Ban className="w-3.5 h-3.5" /> {user.is_banned ? 'YASAKLI' : 'YASAKLA'}
            </button>
          </div>

          {/* Saved Routes */}
          <div className="bg-[#02050D] border border-slate-800 p-3 space-y-2">
            <div className="text-[10px] text-amber-300 font-bold flex items-center gap-1">
              <Route className="w-3.5 h-3.5" /> KAYITLI ROTALAR ({routes.length})
            </div>
            {routes.length === 0 ? (
              <div className="text-[11px] text-slate-500">Kayıtlı rota yok.</div>
            ) : (
              <div className="max-h-36 overflow-y-auto space-y-1.5">
                {routes.map((r) => (
                  <div key={r.id} className="flex items-center justify-between bg-[#040814] border border-slate-800 px-2.5 py-1.5 text-xs">
                    <div className="truncate">
                      <span className="text-white font-bold">{r.name || r.title || r.id}</span>
                      {r.distanceKm && <span className="text-slate-400 ml-2">({Number(r.distanceKm).toFixed(1)} km)</span>}
                    </div>
                    <button
                      onClick={async () => {
                        await deleteUserRoute(user.id, r.id);
                        setRoutes((prev) => prev.filter((item) => item.id !== r.id));
                      }}
                      className="text-red-400 hover:text-red-300 p-0.5 cursor-pointer"
                      title="Rotayı Sil"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Direct Notification Form */}
          <form onSubmit={handleSend} className="bg-[#02050D] border border-[#00E5FF]/30 p-3 space-y-2.5">
            <div className="text-[10px] text-[#00E5FF] font-bold uppercase">KULLANICIYA DOĞRUDAN BİLDİRİM GÖNDER</div>
            {feedback && <div className="text-xs text-emerald-300">{feedback}</div>}
            <input
              value={notifTitle}
              onChange={(e) => setNotifTitle(e.target.value)}
              placeholder="Başlık"
              className="w-full bg-[#040814] border border-slate-700 px-3 py-1.5 text-xs text-white focus:border-[#00E5FF] focus:outline-none"
            />
            <textarea
              rows={3}
              value={notifMsg}
              onChange={(e) => setNotifMsg(e.target.value)}
              placeholder="Özel uyarı veya bilgi mesajı yazın..."
              className="w-full bg-[#040814] border border-slate-700 px-3 py-1.5 text-xs text-white focus:border-[#00E5FF] focus:outline-none"
            />
            <button
              disabled={sending || !notifMsg.trim()}
              type="submit"
              className="w-full py-2 bg-[#00E5FF] hover:bg-cyan-300 disabled:opacity-40 text-black font-black text-xs flex items-center justify-center gap-1.5 cursor-pointer"
            >
              <Send className="w-3.5 h-3.5" /> {sending ? 'GÖNDERİLİYOR...' : 'BİLDİRİM GÖNDER'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
