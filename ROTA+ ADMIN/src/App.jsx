import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  Shield,
  Users,
  FileText,
  Map as MapIcon,
  BadgeCheck,
  BarChart3,
  Megaphone,
  Flag,
  Flame,
  AlertTriangle,
  LogOut,
  Search,
  Trash2,
  CheckCircle2,
  XCircle,
  Crown,
  Ban,
  Plus,
  Phone,
  MapPin,
  Clock,
  Radio,
  Volume2,
  VolumeX,
  Download,
  Printer,
  Send,
  ShieldAlert,
  AlertOctagon,
  History,
  ShieldCheck,
  LifeBuoy
} from 'lucide-react';
import {
  subscribeAuth,
  verifyAdminUser,
  loginWithGoogle,
  loginWithEmail,
  logoutAdmin,
  subscribeCollection,
  updateUserFlags,
  deleteDocByPath,
  updateDocByPath,
  createAnnouncement,
  createFireMarker,
  banIpAddress,
  unbanIpAddress,
  dispatchUsersToReport,
  sendTargetedBulkNotification,
  logAdminAction,
  toMillis,
  formatImgSrc
} from './firebase';
import LiveAdminMap from './components/LiveAdminMap';
import UserDetailModal from './components/UserDetailModal';
import TeamsTab from './components/TeamsTab';
import SosCenterTab from './components/SosCenterTab';
import SafeAndHazardTab from './components/SafeAndHazardTab';
import StatsAndAnalyticsTab from './components/StatsAndAnalyticsTab';
import SupportTicketsTab from './components/SupportTicketsTab';
import { playTacticalAlert, requestDesktopNotifications, showDesktopNotification } from './utils/soundAlert';
import { downloadCsv, haversineKm, printIncidentReport } from './utils/exportUtils';

const TABS = [
  { id: 'incidents', label: 'İHBARLAR', icon: AlertTriangle },
  { id: 'sos', label: 'SOS MERKEZİ', icon: AlertOctagon },
  { id: 'map', label: 'CANLI HARİTA', icon: MapIcon },
  { id: 'zones', label: 'SAHA NOKTALARI', icon: ShieldCheck },
  { id: 'users', label: 'KULLANICILAR', icon: Users },
  { id: 'teams', label: 'EKİPLER', icon: Shield },
  { id: 'posts', label: 'GÖNDERİLER', icon: FileText },
  { id: 'apps', label: 'BAŞVURULAR', icon: BadgeCheck },
  { id: 'announcements', label: 'DUYURULAR', icon: Megaphone },
  { id: 'fires', label: 'YANGINLAR', icon: Flame },
  { id: 'support', label: 'DESTEK', icon: LifeBuoy },
  { id: 'reports', label: 'ŞİKAYETLER', icon: Flag },
  { id: 'stats', label: 'İSTATİSTİK', icon: BarChart3 },
  { id: 'logs', label: 'İŞLEM KAYDI', icon: History },
];

export default function App() {
  const [authUser, setAuthUser] = useState(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [checkingAuth, setCheckingAuth] = useState(true);
  const [loginEmail, setLoginEmail] = useState('');
  const [loginPass, setLoginPass] = useState('');
  const [authError, setAuthError] = useState('');
  const [now, setNow] = useState(new Date());

  const [activeTab, setActiveTab] = useState('incidents');
  const [userSearch, setUserSearch] = useState('');
  const [alertsEnabled, setAlertsEnabled] = useState(true);
  const [selectedUserForModal, setSelectedUserForModal] = useState(null);

  const [users, setUsers] = useState([]);
  const [posts, setPosts] = useState([]);
  const [teams, setTeams] = useState([]);
  const [apps, setApps] = useState([]);
  const [announcements, setAnnouncements] = useState([]);
  const [reports, setReports] = useState([]);
  const [fires, setFires] = useState([]);
  const [incidents, setIncidents] = useState([]);
  const [bannedIps, setBannedIps] = useState([]);
  const [adminLogs, setAdminLogs] = useState([]);
  const [safeZones, setSafeZones] = useState([]);
  const [hazardZones, setHazardZones] = useState([]);
  const [supportTickets, setSupportTickets] = useState([]);
  const [mapFocusCoords, setMapFocusCoords] = useState(null);
  const [prefillSafeCoords, setPrefillSafeCoords] = useState(null);
  const [prefillHazardCoords, setPrefillHazardCoords] = useState(null);

  // Province crisis alert
  const [crisisProvince, setCrisisProvince] = useState('İstanbul');
  const [crisisMsg, setCrisisMsg] = useState('');

  // Targeted bulk notification
  const [bulkTarget, setBulkTarget] = useState('all');
  const [bulkTitle, setBulkTitle] = useState('ROTA+ KOMUTA BİLDİRİMİ');
  const [bulkMsg, setBulkMsg] = useState('');
  const [bulkSending, setBulkSending] = useState(false);

  // Dispatch state for incidents
  const [dispatchReportId, setDispatchReportId] = useState(null);
  const [dispatchSearch, setDispatchSearch] = useState('');
  const [dispatchSelectedIds, setDispatchSelectedIds] = useState(new Set());
  const [dispatchNote, setDispatchNote] = useState('');
  const [dispatchSending, setDispatchSending] = useState(false);
  const [toastMsg, setToastMsg] = useState('');

  // Announcement form
  const [annTitle, setAnnTitle] = useState('');
  const [annContent, setAnnContent] = useState('');
  const [annLevel, setAnnLevel] = useState('normal');

  // Fire form
  const [fireName, setFireName] = useState('');
  const [fireLat, setFireLat] = useState('');
  const [fireLng, setFireLng] = useState('');
  const [fireTeam, setFireTeam] = useState('');
  const [fireDesc, setFireDesc] = useState('');
  const [fireStatus, setFireStatus] = useState('Aktif');

  const knownIncidentIdsRef = useRef(null);
  const alertsEnabledRef = useRef(alertsEnabled);
  alertsEnabledRef.current = alertsEnabled;

  useEffect(() => {
    const t = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(t);
  }, []);

  useEffect(() => {
    return subscribeAuth(async (u) => {
      setAuthUser(u);
      if (u) {
        const ok = await verifyAdminUser(u);
        setIsAdmin(ok);
        if (!ok) {
          setAuthError(`ERİŞİM REDDEDİLDİ: ${u.email || u.uid} admin yetkisine sahip değil.`);
        } else {
          setAuthError('');
        }
      } else {
        setIsAdmin(false);
      }
      setCheckingAuth(false);
    });
  }, []);

  useEffect(() => {
    if (!isAdmin) return;
    const unsubs = [
      subscribeCollection('users', (rows) => setUsers(rows)),
      subscribeCollection('posts', (rows) =>
        setPosts([...rows].sort((a, b) => toMillis(b.timestamp) - toMillis(a.timestamp)))
      ),
      subscribeCollection('teams', (rows) => setTeams(rows)),
      subscribeCollection('guide_applications', (rows) =>
        setApps([...rows].sort((a, b) => toMillis(b.timestamp) - toMillis(a.timestamp)))
      ),
      subscribeCollection('announcements', (rows) =>
        setAnnouncements([...rows].sort((a, b) => toMillis(b.timestamp) - toMillis(a.timestamp)))
      ),
      subscribeCollection('reports', (rows) =>
        setReports([...rows].sort((a, b) => toMillis(b.timestamp) - toMillis(a.timestamp)))
      ),
      subscribeCollection('fires', (rows) =>
        setFires([...rows].sort((a, b) => toMillis(b.timestamp) - toMillis(a.timestamp)))
      ),
      subscribeCollection('banned_ips', (rows) => setBannedIps(rows)),
      subscribeCollection('admin_logs', (rows) =>
        setAdminLogs([...rows].sort((a, b) => toMillis(b.timestamp) - toMillis(a.timestamp)))
      ),
      subscribeCollection('safe_zones', (rows) =>
        setSafeZones([...rows].sort((a, b) => toMillis(b.timestamp) - toMillis(a.timestamp)))
      ),
      subscribeCollection('hazard_zones', (rows) =>
        setHazardZones([...rows].sort((a, b) => toMillis(b.timestamp) - toMillis(a.timestamp)))
      ),
      subscribeCollection('support_tickets', (rows) =>
        setSupportTickets([...rows].sort((a, b) => toMillis(b.timestamp) - toMillis(a.timestamp)))
      ),
      subscribeCollection('disaster_reports', (rows) => {
        const sorted = [...rows].sort((a, b) => toMillis(b.timestamp) - toMillis(a.timestamp));
        if (knownIncidentIdsRef.current === null) {
          knownIncidentIdsRef.current = new Set(sorted.map((r) => r.id));
        } else {
          const fresh = sorted.filter((r) => !knownIncidentIdsRef.current.has(r.id));
          sorted.forEach((r) => knownIncidentIdsRef.current.add(r.id));
          if (fresh.length > 0 && alertsEnabledRef.current) {
            playTacticalAlert();
            const first = fresh[0];
            showDesktopNotification(
              `🚨 YENİ İHBAR: ${first.disasterType || 'Afet'}`,
              `${first.reporterName || 'Operatör'} (${first.province || ''} ${first.district || ''}) — ${first.summary || ''}`
            );
          }
        }
        setIncidents(sorted);
      }),
    ];
    return () => unsubs.forEach((u) => u && u());
  }, [isAdmin]);

  const bannedIpSet = useMemo(() => new Set(bannedIps.map((b) => b.ip)), [bannedIps]);

  const filteredUsers = useMemo(() => {
    const q = userSearch.trim().toLowerCase();
    if (!q) return users;
    return users.filter(
      (u) =>
        (u.name || '').toLowerCase().includes(q) ||
        (u.ad || '').toLowerCase().includes(q) ||
        (u.email || '').toLowerCase().includes(q) ||
        u.id.toLowerCase().includes(q)
    );
  }, [users, userSearch]);

  const activeDispatchReport = useMemo(
    () => incidents.find((r) => r.id === dispatchReportId) || null,
    [incidents, dispatchReportId]
  );

  const dispatchCandidates = useMemo(() => {
    const q = dispatchSearch.trim().toLowerCase();
    const list = users
      .filter((u) => {
        const nm = (u.name || u.ad || u.username || '').toLowerCase();
        return !q || nm.includes(q) || (u.email || '').toLowerCase().includes(q);
      })
      .map((u) => {
        const uLat = parseFloat(u.lat ?? u.last_lat);
        const uLng = parseFloat(u.lng ?? u.last_lng);
        let distKm = null;
        if (
          activeDispatchReport?.lat != null &&
          activeDispatchReport?.lng != null &&
          !isNaN(uLat) &&
          !isNaN(uLng) &&
          !(uLat === 0 && uLng === 0)
        ) {
          distKm = haversineKm(
            Number(activeDispatchReport.lat),
            Number(activeDispatchReport.lng),
            uLat,
            uLng
          );
        }
        return { ...u, distKm };
      });
    list.sort((a, b) => {
      if (a.distKm != null && b.distKm != null) return a.distKm - b.distKm;
      if (a.distKm != null) return -1;
      if (b.distKm != null) return 1;
      return (a.name || a.ad || '').localeCompare(b.name || b.ad || '', 'tr');
    });
    return list;
  }, [users, dispatchSearch, activeDispatchReport]);

  const stats = useMemo(() => {
    const premiumCount = users.filter((u) => u.is_premium === true).length;
    const onlineCount = users.filter((u) => u.is_online === true).length;
    const sosCount = users.filter((u) => u.is_sos === true || u.sos === true).length;
    const activeFires = fires.filter((f) => f.status === 'Aktif').length;
    const newIncidents = incidents.filter((r) => (r.status || 'YENİ') === 'YENİ').length;
    return { premiumCount, onlineCount, sosCount, activeFires, newIncidents };
  }, [users, fires, incidents]);

  const showToast = (msg) => {
    setToastMsg(msg);
    setTimeout(() => setToastMsg(''), 4000);
  };

  const handleToggleAlerts = async () => {
    const next = !alertsEnabled;
    setAlertsEnabled(next);
    if (next) {
      await requestDesktopNotifications();
      playTacticalAlert();
    }
  };

  const handleExportUsersCsv = () => {
    downloadCsv(
      `rota_kullanicilar_${new Date().toISOString().slice(0, 10)}.csv`,
      ['UID', 'Ad Soyad', 'E-posta', 'Telefon', 'Kan Grubu', 'Premium', 'Admin', 'Onaylı', 'Yasaklı'],
      users.map((u) => [
        u.id,
        u.name || u.ad || '',
        u.email || '',
        u.phone || u.telefon || '',
        u.kan_grubu || '',
        u.is_premium ? 'EVET' : 'HAYIR',
        u.is_admin ? 'EVET' : 'HAYIR',
        u.is_verified ? 'EVET' : 'HAYIR',
        u.is_banned ? 'EVET' : 'HAYIR',
      ])
    );
  };

  const handleExportIncidentsCsv = () => {
    downloadCsv(
      `rota_ihbarlar_${new Date().toISOString().slice(0, 10)}.csv`,
      ['Tür', 'Durum', 'Tarih', 'İhbarcı', 'Telefon', 'IP Adresi', 'İl', 'İlçe', 'Mahalle', 'Sokak', 'Lat', 'Lng', 'Özet'],
      incidents.map((r) => [
        r.disasterType || '',
        r.status || 'YENİ',
        r.dateTimeStr || '',
        r.reporterName || '',
        r.reporterPhone || '',
        r.reporterIp || '',
        r.province || '',
        r.district || '',
        r.neighborhood || '',
        r.street || '',
        r.lat ?? '',
        r.lng ?? '',
        r.summary || '',
      ])
    );
  };

  const handleExportFiresCsv = () => {
    downloadCsv(
      `rota_yanginlar_${new Date().toISOString().slice(0, 10)}.csv`,
      ['Yangın Adı', 'Durum', 'Enlem', 'Boylam', 'Ekip', 'Açıklama'],
      fires.map((f) => [f.name || '', f.status || '', f.lat ?? '', f.lng ?? '', f.team || '', f.description || ''])
    );
  };

  const handleSendDispatch = async (rep) => {
    const chosen = users.filter((u) => dispatchSelectedIds.has(u.id));
    if (chosen.length === 0) return;
    setDispatchSending(true);
    try {
      const cnt = await dispatchUsersToReport({ report: rep, selectedUsers: chosen, note: dispatchNote });
      showToast(`✓ ${cnt} operatöre görev bildirimi gönderildi.`);
      setDispatchReportId(null);
      setDispatchSelectedIds(new Set());
      setDispatchNote('');
    } catch (e) {
      showToast(`Hata: ${e.message}`);
    } finally {
      setDispatchSending(false);
    }
  };

  const handleGoogleLogin = async () => {
    setAuthError('');
    try {
      await loginWithGoogle();
    } catch (e) {
      setAuthError(e.message);
    }
  };

  const handleEmailLogin = async (e) => {
    e.preventDefault();
    setAuthError('');
    try {
      await loginWithEmail(loginEmail, loginPass);
    } catch (err) {
      setAuthError(err.message);
    }
  };

  const dateStr = now.toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric' });
  const timeStr = now.toLocaleTimeString('tr-TR', { hour12: false });

  if (checkingAuth) {
    return (
      <div className="min-h-screen bg-[#02040A] flex items-center justify-center text-[#00E5FF] font-tactical text-xs tracking-widest uppercase">
        YETKİ DOĞRULANIYOR...
      </div>
    );
  }

  if (!authUser || !isAdmin) {
    return (
      <div className="min-h-screen bg-[#02040A] flex items-center justify-center p-4 font-tactical">
        <div className="w-full max-w-md bg-[#040814] border border-[#00E5FF]/40 shadow-[0_0_40px_rgba(0,229,255,0.12)] p-6 space-y-5">
          <div className="flex items-center gap-3 border-b border-[#00E5FF]/20 pb-4">
            <div className="p-2.5 bg-[#00E5FF]/10 border border-[#00E5FF]/50 text-[#00E5FF]">
              <Shield className="w-6 h-6" />
            </div>
            <div>
              <h1 className="text-base font-black tracking-widest text-white uppercase">
                ROTA+ <span className="text-[#00E5FF]">ADMIN</span>
              </h1>
              <p className="text-[10px] text-slate-400 uppercase tracking-wider">
                YETKİLİ KOMUTA &amp; YÖNETİM TERMİNALİ
              </p>
            </div>
          </div>

          {authError && (
            <div className="p-3 bg-red-950/60 border border-red-500 text-red-200 text-xs">
              {authError}
            </div>
          )}

          <button
            onClick={handleGoogleLogin}
            className="w-full py-2.5 px-4 bg-[#00E5FF] hover:bg-cyan-300 text-black font-black text-xs tracking-widest uppercase cursor-pointer transition"
          >
            GOOGLE ADMIN HESABI İLE GİRİŞ YAP
          </button>

          <form onSubmit={handleEmailLogin} className="space-y-3 pt-3 border-t border-slate-800">
            <input
              type="email"
              value={loginEmail}
              onChange={(e) => setLoginEmail(e.target.value)}
              placeholder="ADMIN E-POSTA"
              className="w-full bg-[#02050D] border border-slate-700 px-3.5 py-2.5 text-xs text-white focus:outline-none focus:border-[#00E5FF]"
            />
            <input
              type="password"
              value={loginPass}
              onChange={(e) => setLoginPass(e.target.value)}
              placeholder="ŞİFRE"
              className="w-full bg-[#02050D] border border-slate-700 px-3.5 py-2.5 text-xs text-white focus:outline-none focus:border-[#00E5FF]"
            />
            <button
              type="submit"
              className="w-full py-2.5 bg-[#FF4D26] hover:bg-orange-500 text-white font-black text-xs tracking-widest uppercase cursor-pointer transition"
            >
              E-POSTA İLE GİRİŞ YAP
            </button>
          </form>

          {authUser && !isAdmin && (
            <button
              onClick={logoutAdmin}
              className="w-full py-2 text-[11px] text-slate-400 hover:text-white border border-slate-800 cursor-pointer uppercase"
            >
              ÇIKIŞ YAP ({authUser.email})
            </button>
          )}
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#02040A] text-slate-100 flex flex-col font-tactical">
      {/* NEXUS-STYLE TACTICAL HEADER */}
      <header className="h-12 bg-[#02050D] border-b border-[#00E5FF]/30 px-4 flex items-center justify-between gap-3 select-none">
        <div className="flex items-center gap-3">
          <div className="w-7 h-7 bg-[#00E5FF]/10 border border-[#00E5FF]/50 flex items-center justify-center text-[#00E5FF]">
            <Radio className="w-4 h-4 animate-pulse" />
          </div>
          <div className="flex items-center gap-2.5">
            <span className="text-sm font-black tracking-widest text-white uppercase">
              ROTA+ <span className="text-[#00E5FF]">ADMIN</span>
            </span>
            <span className="hidden sm:inline-block px-2 py-0.5 bg-emerald-950/70 border border-emerald-500/40 text-emerald-300 text-[10px]">
              ● FIRESTORE CANLI
            </span>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={handleToggleAlerts}
            className={`flex items-center gap-1 px-2.5 py-1 border text-[10px] cursor-pointer ${
              alertsEnabled
                ? 'border-[#00E5FF]/50 bg-[#00E5FF]/10 text-[#00E5FF]'
                : 'border-slate-700 bg-[#040814] text-slate-400'
            }`}
            title="Sesli & Masaüstü Bildirimleri"
          >
            {alertsEnabled ? <Volume2 className="w-3.5 h-3.5" /> : <VolumeX className="w-3.5 h-3.5" />}
            <span className="hidden sm:inline">{alertsEnabled ? 'ALARM AÇIK' : 'ALARM KAPALI'}</span>
          </button>

          <div className="hidden md:flex items-center gap-1.5 text-[11px] text-[#00E5FF] bg-[#040814] border border-[#00E5FF]/25 px-2.5 py-1">
            <Clock className="w-3.5 h-3.5" />
            <span>{dateStr} {timeStr}</span>
          </div>
          <span className="hidden lg:inline-block text-[10px] text-slate-400 border border-slate-800 bg-[#040814] px-2.5 py-1">
            {authUser.email}
          </span>
          <button
            onClick={logoutAdmin}
            className="flex items-center gap-1.5 px-2.5 py-1 border border-red-500/40 bg-red-950/30 hover:bg-red-900/50 text-[10px] text-red-300 cursor-pointer uppercase"
          >
            <LogOut className="w-3.5 h-3.5" />
            ÇIKIŞ
          </button>
        </div>
      </header>

      {toastMsg && (
        <div className="mx-4 mt-2 p-2.5 bg-emerald-950/80 border border-emerald-500 text-emerald-200 text-xs">
          {toastMsg}
        </div>
      )}

      {/* TELEMETRY STAT STRIP */}
      <div className="px-4 pt-3 grid grid-cols-2 sm:grid-cols-5 gap-2.5">
        <StatCard label="TOPLAM OPERATÖR" value={users.length} color="text-[#00E5FF]" border="border-[#00E5FF]/30" />
        <StatCard label="PREMIUM ÜYE" value={stats.premiumCount} color="text-amber-400" border="border-amber-500/30" />
        <StatCard label="CANLI / SOS" value={`${stats.onlineCount} / ${stats.sosCount}`} color="text-emerald-400" border="border-emerald-500/30" />
        <StatCard label="AKTİF YANGIN" value={stats.activeFires} color="text-[#FF4D26]" border="border-[#FF4D26]/40" />
        <StatCard label="YENİ İHBAR" value={stats.newIncidents} color="text-red-400" border="border-red-500/40" />
      </div>

      {/* TACTICAL NAVIGATION TABS */}
      <nav className="px-4 pt-3 flex gap-1.5 overflow-x-auto border-b border-[#00E5FF]/20 pb-2.5">
        {TABS.map((t) => {
          const Icon = t.icon;
          const active = activeTab === t.id;
          return (
            <button
              key={t.id}
              onClick={() => setActiveTab(t.id)}
              className={`flex items-center gap-1.5 px-3 py-1.5 text-[11px] font-bold tracking-wider shrink-0 cursor-pointer border transition ${
                active
                  ? 'bg-[#00E5FF]/15 border-[#00E5FF] text-[#00E5FF] shadow-[0_0_12px_rgba(0,229,255,0.2)]'
                  : 'bg-[#040814] border-slate-800 text-slate-400 hover:text-white hover:border-slate-600'
              }`}
            >
              <Icon className="w-3.5 h-3.5" />
              {t.label}
              {t.id === 'incidents' && incidents.length > 0 && (
                <span className="ml-1 px-1.5 bg-red-600 text-white text-[9px]">{incidents.length}</span>
              )}
              {t.id === 'sos' && stats.sosCount > 0 && (
                <span className="ml-1 px-1.5 bg-red-600 text-white text-[9px] animate-pulse">{stats.sosCount}</span>
              )}
              {t.id === 'teams' && teams.length > 0 && (
                <span className="ml-1 px-1.5 bg-slate-700 text-white text-[9px]">{teams.length}</span>
              )}
            </button>
          );
        })}
      </nav>

      {/* MAIN COMMAND PANEL */}
      <main className="p-4 flex-1 max-w-[1440px] w-full mx-auto">
        {activeTab === 'users' && (
          <div className="space-y-3">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div className="relative flex-1 min-w-[240px] max-w-md">
                <Search className="w-4 h-4 text-[#00E5FF] absolute left-3 top-2.5" />
                <input
                  value={userSearch}
                  onChange={(e) => setUserSearch(e.target.value)}
                  placeholder="OPERATÖR ADI, E-POSTA VEYA UID ARA..."
                  className="w-full bg-[#040814] border border-[#00E5FF]/30 pl-9 pr-4 py-2 text-xs text-white focus:outline-none focus:border-[#00E5FF]"
                />
              </div>
              <button
                onClick={handleExportUsersCsv}
                className="px-3 py-2 bg-[#040814] border border-emerald-500/50 text-emerald-300 hover:bg-emerald-950/40 text-xs font-bold flex items-center gap-1.5 cursor-pointer"
              >
                <Download className="w-3.5 h-3.5" /> CSV / EXCEL İNDİR
              </button>
            </div>

            <div className="grid gap-2.5 md:grid-cols-2">
              {filteredUsers.map((u) => {
                const avatar = formatImgSrc(u.profile_pic_url || u.avatar || u.photoURL);
                const name = u.name || u.ad || u.username || 'İsimsiz';
                return (
                  <div
                    key={u.id}
                    className="bg-[#040814] border border-slate-800 hover:border-[#00E5FF]/40 p-3.5 flex items-start justify-between gap-3"
                  >
                    <div className="flex items-center gap-3 min-w-0">
                      {avatar ? (
                        <img src={avatar} alt={name} className="w-11 h-11 object-cover border border-[#00E5FF]/40" />
                      ) : (
                        <div className="w-11 h-11 bg-[#070E1F] border border-slate-700 flex items-center justify-center text-xs font-bold text-[#00E5FF]">
                          {name.slice(0, 2).toUpperCase()}
                        </div>
                      )}
                      <div className="min-w-0">
                        <div className="font-bold text-xs text-white truncate">{name}</div>
                        <div className="text-[11px] text-slate-400 truncate">{u.email || u.id}</div>
                        <div className="flex flex-wrap gap-1.5 mt-1.5">
                          {u.is_admin && <Badge text="ADMIN" color="bg-purple-950 text-purple-300 border-purple-500/50" />}
                          {u.is_premium && <Badge text="PREMIUM" color="bg-amber-950 text-amber-300 border-amber-500/50" />}
                          {u.is_verified && <Badge text="ONAYLI" color="bg-cyan-950 text-[#00E5FF] border-[#00E5FF]/50" />}
                          {u.is_banned && <Badge text="YASAKLI" color="bg-red-950 text-red-300 border-red-500/50" />}
                        </div>
                      </div>
                    </div>

                    <div className="flex flex-col gap-1 shrink-0">
                      <ActionBtn
                        label="DETAY & BİLDİRİM"
                        icon={Send}
                        onClick={() => setSelectedUserForModal(u)}
                      />
                      <ActionBtn
                        label={u.is_premium ? 'PREMİUM KALDIR' : 'PREMİUM YAP'}
                        icon={Crown}
                        active={u.is_premium}
                        onClick={() => updateUserFlags(u.id, { is_premium: !u.is_premium })}
                      />
                      <ActionBtn
                        label={u.is_banned ? 'YASAĞI KALDIR' : 'YASAKLA'}
                        icon={Ban}
                        danger={!u.is_banned}
                        onClick={() => updateUserFlags(u.id, { is_banned: !u.is_banned })}
                      />
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {activeTab === 'posts' && (
          <div className="grid gap-3 md:grid-cols-2">
            {posts.map((p) => {
              const img = formatImgSrc(p.imageBase64 || p.imageUrl);
              return (
                <div key={p.id} className="bg-[#040814] border border-slate-800 hover:border-[#00E5FF]/30 p-3.5 space-y-2.5">
                  <div className="flex items-center justify-between border-b border-slate-800/80 pb-2">
                    <span className="font-bold text-xs text-[#00E5FF]">{p.userName || p.authorName || 'Operatör'}</span>
                    <button
                      onClick={() => deleteDocByPath('posts', p.id)}
                      className="text-red-400 hover:text-red-300 p-1 cursor-pointer"
                      title="Gönderiyi Sil"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                  <p className="text-xs text-slate-300 whitespace-pre-wrap">{p.text || p.content || p.caption || ''}</p>
                  {img && <img src={img} alt="Gönderi" className="w-full max-h-56 object-cover border border-slate-800" />}
                </div>
              );
            })}
          </div>
        )}

        {activeTab === 'map' && (
          <LiveAdminMap
            users={users}
            fires={fires}
            disasterReports={incidents}
            safeZones={safeZones}
            hazardZones={hazardZones}
            focusCoords={mapFocusCoords}
            onUseForFire={([lat, lng]) => {
              setFireLat(lat.toFixed(5));
              setFireLng(lng.toFixed(5));
              setActiveTab('fires');
            }}
            onUseForSafeZone={(coords) => {
              setPrefillSafeCoords(coords);
              setActiveTab('zones');
            }}
            onUseForHazardZone={(coords) => {
              setPrefillHazardCoords(coords);
              setActiveTab('zones');
            }}
          />
        )}

        {activeTab === 'zones' && (
          <SafeAndHazardTab
            safeZones={safeZones}
            hazardZones={hazardZones}
            prefillSafeCoords={prefillSafeCoords}
            prefillHazardCoords={prefillHazardCoords}
          />
        )}

        {activeTab === 'support' && <SupportTicketsTab tickets={supportTickets} />}

        {activeTab === 'sos' && (
          <SosCenterTab
            users={users}
            onLocate={(coords) => {
              setMapFocusCoords(coords);
              setActiveTab('map');
            }}
          />
        )}

        {activeTab === 'logs' && (
          <div className="space-y-2">
            {adminLogs.length === 0 && <EmptyState text="HENÜZ ADMIN İŞLEM KAYDI YOK." />}
            {adminLogs.map((l) => (
              <div key={l.id} className="bg-[#040814] border border-slate-800 px-4 py-2.5 flex flex-wrap items-center justify-between gap-2 text-xs">
                <div className="flex items-center gap-2.5">
                  <span className="px-2 py-0.5 bg-[#00E5FF]/15 border border-[#00E5FF]/40 text-[#00E5FF] text-[10px] font-bold">
                    {l.action}
                  </span>
                  <span className="text-white font-bold">{l.target}</span>
                  {l.details && <span className="text-slate-400">— {l.details}</span>}
                </div>
                <div className="text-[10px] text-slate-500">
                  {l.adminEmail} • {toMillis(l.timestamp) ? new Date(toMillis(l.timestamp)).toLocaleString('tr-TR') : ''}
                </div>
              </div>
            ))}
          </div>
        )}

        {activeTab === 'teams' && <TeamsTab teams={teams} />}

        {activeTab === 'apps' && (
          <div className="space-y-2.5">
            {apps.length === 0 && <EmptyState text="BEKLEYEN REHBER BAŞVURUSU YOK." />}
            {apps.map((a) => (
              <div key={a.id} className="bg-[#040814] border border-slate-800 p-4 flex flex-wrap items-center justify-between gap-3">
                <div className="space-y-1">
                  <div className="font-bold text-xs text-white">
                    {a.name || a.fullName || a.id} <span className="text-amber-400">[{a.status || 'beklemede'}]</span>
                  </div>
                  <div className="text-[11px] text-slate-400">{a.experience || a.notes || a.reason || ''}</div>
                </div>
                <div className="flex gap-2">
                  <button
                    onClick={async () => {
                      await updateDocByPath('guide_applications', a.id, { status: 'approved' });
                      await updateUserFlags(a.id, { is_verified: true, role: 'guide' }).catch(() => {});
                    }}
                    className="px-3 py-1.5 bg-emerald-900/70 border border-emerald-500/60 hover:bg-emerald-800 text-emerald-200 text-[10px] font-bold flex items-center gap-1 cursor-pointer"
                  >
                    <CheckCircle2 className="w-3.5 h-3.5" /> ONAYLA
                  </button>
                  <button
                    onClick={() => updateDocByPath('guide_applications', a.id, { status: 'rejected' })}
                    className="px-3 py-1.5 bg-red-950/70 border border-red-500/60 hover:bg-red-900 text-red-200 text-[10px] font-bold flex items-center gap-1 cursor-pointer"
                  >
                    <XCircle className="w-3.5 h-3.5" /> REDDET
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}

        {activeTab === 'stats' && (
          <StatsAndAnalyticsTab
            users={users}
            posts={posts}
            incidents={incidents}
            fires={fires}
            safeZones={safeZones}
            hazardZones={hazardZones}
            bannedIpsCount={bannedIps.length}
          />
        )}

        {activeTab === 'announcements' && (
          <div className="grid gap-4 md:grid-cols-3">
            <div className="space-y-4 h-fit">
              <form
                onSubmit={async (e) => {
                  e.preventDefault();
                  if (!annTitle.trim() || !annContent.trim()) return;
                  await createAnnouncement({ title: annTitle, content: annContent, level: annLevel });
                  await logAdminAction('DUYURU_YAYINLANDI', annTitle, annLevel);
                  setAnnTitle('');
                  setAnnContent('');
                  showToast('✓ Duyuru yayınlandı.');
                }}
                className="bg-[#040814] border border-[#00E5FF]/30 p-4 space-y-3"
              >
                <h3 className="font-bold text-xs text-[#00E5FF] tracking-wider uppercase">YENİ DUYURU YAYINLA</h3>
                <input
                  value={annTitle}
                  onChange={(e) => setAnnTitle(e.target.value)}
                  placeholder="DUYURU BAŞLIĞI"
                  className="w-full bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white focus:border-[#00E5FF] focus:outline-none"
                />
                <select
                  value={annLevel}
                  onChange={(e) => setAnnLevel(e.target.value)}
                  className="w-full bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white focus:border-[#00E5FF] focus:outline-none"
                >
                  <option value="normal">NORMAL</option>
                  <option value="warning">UYARI</option>
                  <option value="critical">KRİTİK ACİL</option>
                </select>
                <textarea
                  rows={3}
                  value={annContent}
                  onChange={(e) => setAnnContent(e.target.value)}
                  placeholder="DUYURU İÇERİĞİ..."
                  className="w-full bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white focus:border-[#00E5FF] focus:outline-none"
                />
                <button
                  type="submit"
                  className="w-full py-2 bg-[#FF4D26] hover:bg-orange-500 text-white text-xs font-black tracking-wider flex items-center justify-center gap-1.5 cursor-pointer"
                >
                  <Plus className="w-4 h-4" /> DUYURU GÖNDER
                </button>
              </form>

              <form
                onSubmit={async (e) => {
                  e.preventDefault();
                  if (!bulkMsg.trim()) return;
                  const targetList = users.filter((u) => {
                    if (bulkTarget === 'online') return u.is_online === true;
                    if (bulkTarget === 'premium') return u.is_premium === true;
                    if (bulkTarget === 'guides') return u.role === 'guide' || u.is_verified === true;
                    if (bulkTarget === 'sos') return u.is_sos === true || u.sos === true;
                    return true;
                  });
                  if (targetList.length === 0) {
                    showToast('Seçili hedef kitlede kullanıcı yok.');
                    return;
                  }
                  setBulkSending(true);
                  try {
                    const cnt = await sendTargetedBulkNotification({
                      targetUsers: targetList,
                      title: bulkTitle,
                      message: bulkMsg,
                    });
                    setBulkMsg('');
                    showToast(`✓ ${cnt} kullanıcıya hedefli bildirim gönderildi.`);
                  } finally {
                    setBulkSending(false);
                  }
                }}
                className="bg-[#040814] border border-amber-500/40 p-4 space-y-3"
              >
                <h3 className="font-bold text-xs text-amber-400 tracking-wider uppercase">HEDEF KİTLE BİLDİRİMİ</h3>
                <select
                  value={bulkTarget}
                  onChange={(e) => setBulkTarget(e.target.value)}
                  className="w-full bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white focus:border-[#00E5FF] focus:outline-none"
                >
                  <option value="all">TÜM KULLANICILAR ({users.length})</option>
                  <option value="online">SADECE ÇEVRİMİÇİ ({stats.onlineCount})</option>
                  <option value="premium">SADECE PREMİUM ({stats.premiumCount})</option>
                  <option value="guides">SADECE REHBER / ONAYLI</option>
                  <option value="sos">SADECE SOS ({stats.sosCount})</option>
                </select>
                <input
                  value={bulkTitle}
                  onChange={(e) => setBulkTitle(e.target.value)}
                  placeholder="BİLDİRİM BAŞLIĞI"
                  className="w-full bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white focus:border-[#00E5FF] focus:outline-none"
                />
                <textarea
                  rows={3}
                  value={bulkMsg}
                  onChange={(e) => setBulkMsg(e.target.value)}
                  placeholder="Hedef kitleye gönderilecek bildirim metni..."
                  className="w-full bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white focus:border-[#00E5FF] focus:outline-none"
                />
                <button
                  disabled={bulkSending || !bulkMsg.trim()}
                  type="submit"
                  className="w-full py-2 bg-[#00E5FF] hover:bg-cyan-300 disabled:opacity-40 text-black text-xs font-black tracking-wider flex items-center justify-center gap-1.5 cursor-pointer"
                >
                  <Send className="w-3.5 h-3.5" /> {bulkSending ? 'GÖNDERİLİYOR...' : 'TOPLU BİLDİRİM AT'}
                </button>
              </form>

              <form
                onSubmit={async (e) => {
                  e.preventDefault();
                  if (!crisisProvince.trim() || !crisisMsg.trim()) return;
                  await createAnnouncement({
                    title: `🚨 ${crisisProvince.toUpperCase()} İLİ ACİL KRİZ ALARMI`,
                    content: crisisMsg,
                    level: 'critical',
                  });
                  await sendTargetedBulkNotification({
                    targetUsers: users,
                    title: `🚨 ${crisisProvince.toUpperCase()} ACİL KRİZ MODU`,
                    message: crisisMsg,
                  });
                  await logAdminAction('KRIZ_ALARMI', crisisProvince, crisisMsg.slice(0, 60));
                  setCrisisMsg('');
                  showToast(`✓ ${crisisProvince} için Acil Kriz Alarmı yayınlandı.`);
                }}
                className="bg-[#040814] border border-red-500/50 p-4 space-y-2.5"
              >
                <h3 className="font-bold text-xs text-red-400 tracking-wider uppercase">İL BAZLI ACİL KRİZ ALARMI</h3>
                <input
                  value={crisisProvince}
                  onChange={(e) => setCrisisProvince(e.target.value)}
                  placeholder="İL ADI (ÖR: İSTANBUL, İZMİR, HATAY)"
                  className="w-full bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white focus:border-red-500 focus:outline-none"
                />
                <textarea
                  rows={2}
                  value={crisisMsg}
                  onChange={(e) => setCrisisMsg(e.target.value)}
                  placeholder="Kriz alarmı talimatı..."
                  className="w-full bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white focus:border-red-500 focus:outline-none"
                />
                <button
                  type="submit"
                  className="w-full py-2 bg-red-600 hover:bg-red-500 text-white text-xs font-black tracking-wider cursor-pointer"
                >
                  🚨 KRİZ ALARMI BAŞLAT
                </button>
              </form>
            </div>

            <div className="md:col-span-2 space-y-2.5">
              {announcements.map((a) => (
                <div key={a.id} className="bg-[#040814] border border-slate-800 p-4 flex justify-between gap-3">
                  <div>
                    <div className="font-bold text-xs text-white">
                      {a.title} <span className="text-[10px] uppercase text-[#FF4D26] ml-2">[{a.level || 'normal'}]</span>
                    </div>
                    <p className="text-xs text-slate-300 mt-1">{a.content}</p>
                  </div>
                  <button
                    onClick={() => deleteDocByPath('announcements', a.id)}
                    className="text-red-400 hover:text-red-300 p-1 h-fit cursor-pointer"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              ))}
            </div>
          </div>
        )}

        {activeTab === 'reports' && (
          <div className="space-y-2.5">
            {reports.length === 0 && <EmptyState text="ŞİKAYET KAYDI YOK." />}
            {reports.map((r) => (
              <div key={r.id} className="bg-[#040814] border border-slate-800 p-4 flex justify-between gap-3">
                <div>
                  <div className="text-xs font-bold text-amber-300">{r.reason || r.type || 'ŞİKAYET'}</div>
                  <div className="text-xs text-slate-400 mt-1">{r.details || r.summary || r.postId || ''}</div>
                </div>
                <button
                  onClick={() => deleteDocByPath('reports', r.id)}
                  className="text-red-400 hover:text-red-300 p-1 h-fit cursor-pointer"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            ))}
          </div>
        )}

        {activeTab === 'fires' && (
          <div className="space-y-3">
            <div className="flex justify-end">
              <button
                onClick={handleExportFiresCsv}
                className="px-3 py-1.5 bg-[#040814] border border-emerald-500/50 text-emerald-300 hover:bg-emerald-950/40 text-xs font-bold flex items-center gap-1.5 cursor-pointer"
              >
                <Download className="w-3.5 h-3.5" /> YANGINLAR CSV İNDİR
              </button>
            </div>
            <div className="grid gap-4 md:grid-cols-3">
              <form
                onSubmit={async (e) => {
                  e.preventDefault();
                  if (!fireName.trim() || !fireLat || !fireLng) return;
                  await createFireMarker({
                    name: fireName,
                    lat: fireLat,
                    lng: fireLng,
                    team: fireTeam,
                    description: fireDesc,
                    status: fireStatus,
                  });
                  setFireName('');
                  setFireLat('');
                  setFireLng('');
                  setFireTeam('');
                  setFireDesc('');
                }}
                className="bg-[#040814] border border-[#FF4D26]/40 p-4 space-y-2.5 h-fit"
              >
                <h3 className="font-bold text-xs text-[#FF4D26] uppercase tracking-wider">YANGIN NOKTASI EKLE</h3>
                <input value={fireName} onChange={(e) => setFireName(e.target.value)} placeholder="BÖLGE / YANGIN ADI" className="w-full bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white" />
                <div className="grid grid-cols-2 gap-2">
                  <input value={fireLat} onChange={(e) => setFireLat(e.target.value)} placeholder="ENLEM (LAT)" className="w-full bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white" />
                  <input value={fireLng} onChange={(e) => setFireLng(e.target.value)} placeholder="BOYLAM (LNG)" className="w-full bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white" />
                </div>
                <input value={fireTeam} onChange={(e) => setFireTeam(e.target.value)} placeholder="MÜDAHALE EKİBİ" className="w-full bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white" />
                <select value={fireStatus} onChange={(e) => setFireStatus(e.target.value)} className="w-full bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white">
                  <option value="Aktif">AKTİF</option>
                  <option value="Kontrol Altında">KONTROL ALTINDA</option>
                  <option value="Söndürüldü">SÖNDÜRÜLDÜ</option>
                </select>
                <textarea rows={3} value={fireDesc} onChange={(e) => setFireDesc(e.target.value)} placeholder="AÇIKLAMA..." className="w-full bg-[#02050D] border border-slate-700 px-3 py-2 text-xs text-white" />
                <button type="submit" className="w-full py-2 bg-[#FF4D26] hover:bg-orange-500 text-white text-xs font-black cursor-pointer">
                  YANGIN KAYDI EKLE
                </button>
              </form>

              <div className="md:col-span-2 space-y-2.5">
                {fires.map((f) => (
                  <div key={f.id} className="bg-[#040814] border border-slate-800 p-4 flex justify-between gap-3">
                    <div className="space-y-1">
                      <div className="font-bold text-xs text-white">🔥 {f.name} <span className="text-[#FF4D26]">[{f.status}]</span></div>
                      <div className="text-[11px] text-[#00E5FF]">{f.lat}, {f.lng} {f.team ? `• EKİP: ${f.team}` : ''}</div>
                      {f.description && <p className="text-xs text-slate-300">{f.description}</p>}
                    </div>
                    <div className="flex items-center gap-1.5 h-fit">
                      <button onClick={() => updateDocByPath('fires', f.id, { status: 'Kontrol Altında' })} className="px-2 py-1 text-[10px] border border-slate-700 text-slate-300 cursor-pointer">KONTROL</button>
                      <button onClick={() => updateDocByPath('fires', f.id, { status: 'Söndürüldü' })} className="px-2 py-1 text-[10px] border border-emerald-500/40 text-emerald-300 cursor-pointer">SÖNDÜ</button>
                      <button onClick={() => deleteDocByPath('fires', f.id)} className="text-red-400 hover:text-red-300 p-1 cursor-pointer"><Trash2 className="w-4 h-4" /></button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}

        {activeTab === 'incidents' && (
          <div className="space-y-3">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <span className="text-[11px] text-slate-400">
                ENGELLİ IP SAYISI: <strong className="text-red-400">{bannedIps.length}</strong>
              </span>
              <button
                onClick={handleExportIncidentsCsv}
                className="px-3 py-1.5 bg-[#040814] border border-emerald-500/50 text-emerald-300 hover:bg-emerald-950/40 text-xs font-bold flex items-center gap-1.5 cursor-pointer"
              >
                <Download className="w-3.5 h-3.5" /> İHBARLAR CSV / EXCEL İNDİR
              </button>
            </div>

            {incidents.length === 0 && <EmptyState text="HENÜZ AFET/OLAY İHBARI YOK." />}
            {incidents.map((rep) => {
              const img = formatImgSrc(rep.imageBase64);
              const isIpBanned = rep.reporterIp && bannedIpSet.has(rep.reporterIp);
              const isDispatchOpen = dispatchReportId === rep.id;
              return (
                <div key={rep.id} className="bg-[#040814] border border-slate-800 hover:border-amber-500/40 p-4 space-y-3">
                  <div className="flex flex-wrap items-center justify-between gap-2 border-b border-slate-800/80 pb-2">
                    <div className="flex items-center gap-2">
                      <span className="px-2 py-0.5 bg-red-950 border border-red-500/60 text-red-300 text-[10px] font-bold uppercase">
                        {rep.disasterType || 'İHBAR'}
                      </span>
                      <span className="px-2 py-0.5 bg-amber-950/60 border border-amber-500/40 text-amber-300 text-[10px] font-bold">
                        {rep.status || 'YENİ'}
                      </span>
                      {isIpBanned && (
                        <span className="px-2 py-0.5 bg-red-900 border border-red-400 text-white text-[10px] font-bold">
                          IP ENGELLİ
                        </span>
                      )}
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="text-[11px] text-[#00E5FF]">{rep.dateTimeStr || ''}</span>
                      <button
                        onClick={() => printIncidentReport(rep)}
                        className="px-2 py-0.5 border border-slate-700 hover:border-[#00E5FF] text-slate-300 text-[10px] flex items-center gap-1 cursor-pointer"
                      >
                        <Printer className="w-3 h-3" /> YAZDIR (A4)
                      </button>
                    </div>
                  </div>

                  <div className="flex flex-wrap items-center gap-4 text-xs">
                    <span className="text-white font-bold">👤 {rep.reporterName || 'Operatör'}</span>
                    <span className="text-emerald-300 font-bold flex items-center gap-1">
                      <Phone className="w-3.5 h-3.5" /> {rep.reporterPhone || '-'}
                    </span>
                    <span className="px-2 py-0.5 bg-[#02050D] border border-slate-700 text-slate-300 text-[10px]">
                      🌐 IP: {rep.reporterIp || 'Alınamadı'}
                    </span>
                    {rep.lat != null && rep.lng != null && (
                      <button
                        onClick={() => {
                          setMapFocusCoords([Number(rep.lat), Number(rep.lng)]);
                          setActiveTab('map');
                        }}
                        className="text-[#00E5FF] hover:underline flex items-center gap-1 cursor-pointer"
                      >
                        <MapPin className="w-3.5 h-3.5" /> {Number(rep.lat).toFixed(5)}, {Number(rep.lng).toFixed(5)} (Haritada Gör)
                      </button>
                    )}
                  </div>

                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 bg-[#02050D] border border-slate-800 p-2.5 text-[11px]">
                    <div><span className="text-slate-500 block text-[9px]">İL</span>{rep.province || '-'}</div>
                    <div><span className="text-slate-500 block text-[9px]">İLÇE</span>{rep.district || '-'}</div>
                    <div><span className="text-slate-500 block text-[9px]">MAHALLE</span>{rep.neighborhood || '-'}</div>
                    <div><span className="text-slate-500 block text-[9px]">SOKAK / NO</span>{rep.street || '-'}</div>
                  </div>

                  <p className="text-xs text-slate-200 bg-[#070E1F] border border-slate-800 p-3">
                    {rep.summary}
                  </p>

                  {Array.isArray(rep.dispatchedTo) && rep.dispatchedTo.length > 0 && (
                    <div className="bg-cyan-950/25 border border-[#00E5FF]/30 p-2.5 space-y-1">
                      <span className="text-[9px] text-[#00E5FF] font-bold uppercase block">
                        SEVK EDİLEN OPERATÖRLER ({rep.dispatchedTo.length})
                      </span>
                      <div className="flex flex-wrap gap-1.5">
                        {rep.dispatchedTo.map((d, idx) => (
                          <span key={idx} className="px-2 py-0.5 bg-cyan-950/70 border border-[#00E5FF]/40 text-cyan-200 text-[10px]">
                            👤 {d.name} ({d.dispatchedAt})
                          </span>
                        ))}
                      </div>
                    </div>
                  )}

                  {img && <img src={img} alt="İhbar Fotoğrafı" className="w-full max-h-64 object-cover border border-slate-800" />}

                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <div className="flex flex-wrap gap-1.5">
                      {['İNCELENİYOR', 'SEVK EDİLDİ', 'ÇÖZÜLDÜ'].map((st) => (
                        <button
                          key={st}
                          onClick={() => updateDocByPath('disaster_reports', rep.id, { status: st })}
                          className={`px-2.5 py-1 text-[10px] font-bold border cursor-pointer ${
                            rep.status === st
                              ? 'bg-emerald-950 border-emerald-400 text-emerald-300'
                              : 'bg-[#071022] border-slate-700 text-slate-300 hover:border-[#00E5FF]'
                          }`}
                        >
                          {st}
                        </button>
                      ))}
                      <button
                        onClick={() => {
                          setDispatchReportId(isDispatchOpen ? null : rep.id);
                          setDispatchSelectedIds(new Set());
                          setDispatchSearch('');
                          setDispatchNote('');
                        }}
                        className={`px-2.5 py-1 text-[10px] font-bold border flex items-center gap-1 cursor-pointer ${
                          isDispatchOpen
                            ? 'bg-amber-500 border-amber-400 text-black'
                            : 'bg-cyan-950/60 border-[#00E5FF]/50 text-[#00E5FF]'
                        }`}
                      >
                        <Users className="w-3 h-3" /> İNSAN YÖNLENDİR
                      </button>
                      {rep.reporterIp && (
                        <button
                          onClick={async () => {
                            if (isIpBanned) {
                              await unbanIpAddress(rep.reporterIp);
                              await logAdminAction('IP_ENGEL_KALDIRILDI', rep.reporterIp, rep.id);
                            } else {
                              await banIpAddress(rep.reporterIp);
                              await logAdminAction('IP_ENGELLENDI', rep.reporterIp, rep.disasterType || '');
                            }
                          }}
                          className="px-2.5 py-1 text-[10px] font-bold border border-red-500/50 bg-red-950/40 text-red-300 flex items-center gap-1 cursor-pointer"
                        >
                          <ShieldAlert className="w-3 h-3" /> {isIpBanned ? 'IP ENGELİ KALDIR' : 'IP ENGELLE'}
                        </button>
                      )}
                      {rep.reporterUid && (
                        <button
                          onClick={async () => {
                            await updateUserFlags(rep.reporterUid, { is_banned: true });
                            await logAdminAction('HESAP_YASAKLANDI', rep.reporterName || rep.reporterUid, rep.id);
                            showToast('✓ Hesap yasaklandı.');
                          }}
                          className="px-2.5 py-1 text-[10px] font-bold border border-red-500/50 bg-red-950/40 text-red-300 flex items-center gap-1 cursor-pointer"
                        >
                          <Ban className="w-3 h-3" /> HESABI YASAKLA
                        </button>
                      )}
                    </div>
                    <button
                      onClick={() => deleteDocByPath('disaster_reports', rep.id)}
                      className="text-red-400 hover:text-red-300 p-1 cursor-pointer"
                      title="İhbarı Sil"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>

                  {isDispatchOpen && (
                    <div className="p-3 bg-[#02050D] border border-[#00E5FF]/40 space-y-2.5">
                      <div className="flex items-center justify-between text-[11px]">
                        <span className="text-[#00E5FF] font-bold">VERİTABANINDAN OPERATÖR SEÇ &amp; YÖNLENDİR</span>
                        <span className="text-slate-400">Seçili: {dispatchSelectedIds.size}</span>
                      </div>
                      <input
                        value={dispatchSearch}
                        onChange={(e) => setDispatchSearch(e.target.value)}
                        placeholder="Operatör adı ara..."
                        className="w-full bg-[#040814] border border-slate-700 px-3 py-1.5 text-xs text-white focus:border-[#00E5FF] focus:outline-none"
                      />
                      <div className="max-h-40 overflow-y-auto space-y-1 border border-slate-800 p-1.5">
                        {dispatchCandidates.map((u) => {
                          const checked = dispatchSelectedIds.has(u.id);
                          const nm = u.name || u.ad || u.username || 'Operatör';
                          return (
                            <label
                              key={u.id}
                              className={`flex items-center justify-between px-2 py-1 text-xs cursor-pointer ${
                                checked ? 'bg-cyan-950/60 text-white' : 'text-slate-300 hover:bg-slate-900/50'
                              }`}
                            >
                              <span className="flex items-center gap-2">
                                <input
                                  type="checkbox"
                                  checked={checked}
                                  onChange={() => {
                                    setDispatchSelectedIds((prev) => {
                                      const next = new Set(prev);
                                      if (next.has(u.id)) next.delete(u.id);
                                      else next.add(u.id);
                                      return next;
                                    });
                                  }}
                                />
                                {nm}
                              </span>
                              <span className="text-[10px] text-[#00E5FF]">
                                {u.distKm != null ? `${u.distKm.toFixed(1)} km` : 'GPS yok'}
                              </span>
                            </label>
                          );
                        })}
                      </div>
                      <input
                        value={dispatchNote}
                        onChange={(e) => setDispatchNote(e.target.value)}
                        placeholder="Komuta notu (opsiyonel)..."
                        className="w-full bg-[#040814] border border-slate-700 px-3 py-1.5 text-xs text-white focus:border-[#00E5FF] focus:outline-none"
                      />
                      <div className="flex justify-end gap-2">
                        <button
                          onClick={() => setDispatchReportId(null)}
                          className="px-3 py-1 border border-slate-700 text-slate-300 text-[10px] cursor-pointer"
                        >
                          İPTAL
                        </button>
                        <button
                          disabled={dispatchSending || dispatchSelectedIds.size === 0}
                          onClick={() => handleSendDispatch(rep)}
                          className="px-3 py-1 bg-[#00E5FF] text-black font-bold text-[10px] disabled:opacity-40 cursor-pointer"
                        >
                          {dispatchSending ? 'GÖNDERİLİYOR...' : `SEÇİLİ KİŞİLERİ YÖNLENDİR (${dispatchSelectedIds.size})`}
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </main>

      <UserDetailModal
        user={selectedUserForModal ? users.find((u) => u.id === selectedUserForModal.id) || selectedUserForModal : null}
        onClose={() => setSelectedUserForModal(null)}
      />
    </div>
  );
}

function StatCard({ label, value, color, border }) {
  return (
    <div className={`bg-[#040814] border ${border} p-2.5`}>
      <div className="text-[9px] text-slate-400 tracking-wider">{label}</div>
      <div className={`text-lg font-black mt-0.5 ${color}`}>{value}</div>
    </div>
  );
}

function BigStat({ title, value, sub }) {
  return (
    <div className="bg-[#040814] border border-[#00E5FF]/30 p-5">
      <div className="text-[11px] text-slate-400">{title}</div>
      <div className="text-3xl font-black text-white mt-1">{value}</div>
      <div className="text-xs text-[#00E5FF] mt-1">{sub}</div>
    </div>
  );
}

function Badge({ text, color }) {
  return <span className={`px-1.5 py-0.5 border text-[9px] font-bold ${color}`}>{text}</span>;
}

function ActionBtn({ label, icon: Icon, active, danger, onClick }) {
  return (
    <button
      onClick={onClick}
      className={`px-2 py-1 text-[10px] font-bold border flex items-center gap-1 cursor-pointer ${
        danger
          ? 'bg-red-950/50 border-red-500/50 text-red-300 hover:bg-red-900/50'
          : active
            ? 'bg-amber-950/60 border-amber-400/60 text-amber-300'
            : 'bg-[#070E1F] border-slate-700 text-slate-300 hover:border-[#00E5FF]'
      }`}
    >
      <Icon className="w-3 h-3" />
      {label}
    </button>
  );
}

function EmptyState({ text }) {
  return <div className="py-12 text-center text-xs text-slate-500">{text}</div>;
}
