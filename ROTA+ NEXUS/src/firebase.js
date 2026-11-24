import { initializeApp, getApps, getApp } from 'firebase/app';
import { getAuth, signInAnonymously, signInWithEmailAndPassword, GoogleAuthProvider, signInWithPopup } from 'firebase/auth';
import { 
  getFirestore, 
  collection, 
  doc,
  writeBatch,
  updateDoc,
  arrayUnion,
  serverTimestamp,
  onSnapshot 
} from 'firebase/firestore';

const firebaseConfig = {
  apiKey: "AIzaSyCovIDS0P5nNlkqLHXgSvmmxqpr1TEQnjs",
  authDomain: "rotaplus-cd84d.firebaseapp.com",
  projectId: "rotaplus-cd84d",
  storageBucket: "rotaplus-cd84d.firebasestorage.app",
};

// Initialize Firebase App singleton
export const app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApp();
export const auth = getAuth(app);
export const db = getFirestore(app);

/**
 * Format profile photo from Firestore.
 * Handles 'base64:...' strings, raw base64, or direct URLs.
 */
export function formatProfilePhoto(rawPic) {
  if (!rawPic || typeof rawPic !== 'string') return null;
  const trimmed = rawPic.trim();
  if (trimmed.startsWith('base64:')) {
    return `data:image/jpeg;base64,${trimmed.substring(7)}`;
  }
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://') || trimmed.startsWith('data:image/')) {
    return trimmed;
  }
  if (trimmed.length > 50 && !trimmed.includes(' ')) {
    return `data:image/jpeg;base64,${trimmed}`;
  }
  return null;
}

/**
 * Generate 2-letter uppercase initials for avatar fallback
 */
export function getInitials(name) {
  if (!name) return 'RP';
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 1) return parts[0].substring(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

/**
 * Extract timestamp in seconds
 */
export function getTimestampSeconds(val) {
  if (!val) return 0;
  if (val.seconds) return val.seconds;
  if (typeof val === 'number') return val;
  if (typeof val.toDate === 'function') return Math.floor(val.toDate().getTime() / 1000);
  if (typeof val === 'string') {
    const parsed = new Date(val).getTime();
    return isNaN(parsed) ? 0 : Math.floor(parsed / 1000);
  }
  return 0;
}

/**
 * Connect to Firebase Firestore and listen to REAL `users` collection.
 * No random simulations - 100% real database records.
 * Tracks live incoming SOS transitions and isolates stale historical records.
 */
export function subscribeToFirebaseUsers(onUsersUpdate, onStatusChange, onIncomingSos) {
  let isSubscribed = true;
  let isFirstRun = true;
  const previousSosState = new Map();

  const connect = async () => {
    try {
      onStatusChange({ status: 'CONNECTING', message: 'Firebase rotaplus-cd84d bağlanılıyor...' });
      
      try {
        await signInAnonymously(auth);
      } catch (authErr) {
        console.warn('Anonymous auth note:', authErr.message);
      }

      const usersCol = collection(db, 'users');
      const unsubscribe = onSnapshot(usersCol, (snapshot) => {
        if (!isSubscribed) return;

        const realUsers = [];
        const nowSec = Math.floor(Date.now() / 1000);
        let newlyTriggeredSosUser = null;

        snapshot.forEach((docSnap) => {
          const data = docSnap.data();
          const lat = parseFloat(data.lat || data.last_lat);
          const lng = parseFloat(data.lng || data.last_lng);
          const hasCoords = !isNaN(lat) && !isNaN(lng) && !(lat === 0 && lng === 0);

          const name = data.name || data.username || data.ad || `Kullanıcı (${docSnap.id.substring(0, 4)})`;
          const avatar = formatProfilePhoto(data.profile_pic_url || data.avatar || data.photoURL || data.image);
          const initials = getInitials(name);

          // Raw SOS flag from database
          const rawSos = Boolean(data.is_sos || data.sos || data.safety_status === 'sos');

          // Timestamps
          const sosSec = getTimestampSeconds(data.sos_timestamp);
          const locSec = getTimestampSeconds(data.location_timestamp);
          const lastActiveSec = getTimestampSeconds(data.last_active || data.last_seen);

          // Check if user transitioned from false to true live in this session
          const prevSos = previousSosState.get(docSnap.id);
          const transitionedToSos = !isFirstRun && prevSos === false && rawSos === true;
          previousSosState.set(docSnap.id, rawSos);

          // Determine if this is a FRESH LIVE SOS:
          // 1. Transitioned during current live session, OR
          // 2. Triggered within the last 24 hours (86400 sec), OR
          // 3. User was active in the last 24h and is_sos is true
          const isFreshSos = rawSos && (
            transitionedToSos ||
            (sosSec > 0 && (nowSec - sosSec) < 86400) ||
            (lastActiveSec > 0 && (nowSec - lastActiveSec) < 86400 && rawSos)
          );

          // If rawSos is true but it's an old test from months ago, it is an archive record
          const isArchiveSos = rawSos && !isFreshSos;

          // Real telemetry fields
          const altitude = Number(data.last_elevation || data.elevation || data.altitude || 0);
          const battery = data.battery_level !== undefined ? Number(data.battery_level) : (data.battery !== undefined ? Number(data.battery) : 100);
          const team = data.team_name || data.affiliationName || data.affiliationType || 'Bireysel';
          const teamId = (data.team_id || data.teamCode || '').toString().trim();
          const role = data.role || (data.is_admin ? 'KOMUTAN' : (rawSos ? 'ACİL DURUM' : (data.roles?.[0] || 'SAHA ÜYESİ')));
          const phone = data.acil_tel || data.acil_kisi_tel || data.phone || '';
          const kanGrubu = data.kan_grubu || '';
          const bio = data.bio || '';
          const liveTrail = Array.isArray(data.live_trail) ? data.live_trail : [];

          const userObj = {
            id: docSnap.id,
            name,
            username: data.username || '',
            avatar,
            initials,
            hasCoords,
            coords: hasCoords ? [lat, lng] : null,
            lat: hasCoords ? lat : null,
            lng: hasCoords ? lng : null,
            altitude,
            battery,
            speed: data.speed ? Number(data.speed) : 0,
            isSos: rawSos,
            isFreshSos: isFreshSos,
            isArchiveSos: isArchiveSos,
            sosSec,
            locSec,
            lastActiveSec,
            team,
            teamId,
            fcmTokens: Array.isArray(data.fcmTokens) ? data.fcmTokens : [],
            role,
            phone,
            kanGrubu,
            bio,
            signalStrength: data.signal_strength || 'GÜÇLÜ',
            lastSeen: data.last_seen || data.last_active || null,
            trail: hasCoords ? (liveTrail.length > 0 ? liveTrail : [[lat, lng]]) : []
          };

          if (transitionedToSos && !newlyTriggeredSosUser) {
            newlyTriggeredSosUser = userObj;
          }

          realUsers.push(userObj);
        });

        isFirstRun = false;

        const withCoordsCount = realUsers.filter(u => u.hasCoords).length;
        const freshSosCount = realUsers.filter(u => u.isFreshSos).length;
        const archiveSosCount = realUsers.filter(u => u.isArchiveSos).length;

        onStatusChange({ 
          status: 'LIVE', 
          message: `Firebase: ${realUsers.length} kullanıcı (${withCoordsCount} konumlu | ${freshSosCount} canlı SOS | ${archiveSosCount} arşiv)` 
        });

        onUsersUpdate(realUsers);

        if (newlyTriggeredSosUser && typeof onIncomingSos === 'function') {
          onIncomingSos(newlyTriggeredSosUser);
        }
      }, (err) => {
        console.error('Firestore snapshot error:', err);
        onStatusChange({ 
          status: 'ERROR', 
          message: `Veritabanı hatası: ${err.message}` 
        });
      });

      return unsubscribe;
    } catch (error) {
      console.error('Firebase connection error:', error);
      onStatusChange({ 
        status: 'ERROR', 
        message: 'Ağ bağlantısı kurulamadı.' 
      });
      return () => {};
    }
  };

  const unsubPromise = connect();

  return () => {
    isSubscribed = false;
    unsubPromise.then(unsub => {
      if (typeof unsub === 'function') unsub();
    });
  };
}

export function isNexusAuthenticated() {
  return Boolean(auth.currentUser);
}

export async function signInNexusCommander(email, password) {
  const cred = await signInWithEmailAndPassword(auth, email.trim(), password);
  return cred.user;
}

export async function signInNexusWithGoogle() {
  const provider = new GoogleAuthProvider();
  const cred = await signInWithPopup(auth, provider);
  return cred.user;
}

/**
 * Send a command message from ROTA+ NEXUS to selected Rota+ Emniyetteyim users.
 * Writes into `notifications/{uid}/items` (phone notification) AND `teams/{teamId}/messages` (ekip chat).
 */
export async function sendNexusTeamMessage({
  recipientIds = [],
  teamIds = [],
  fcmTokens = [],
  message = '',
  senderName = 'ROTA+ NEXUS KOMUTA',
  extraData = {}
}) {
  const cleanMsg = message.trim();
  if (!cleanMsg || !recipientIds.length) {
    throw new Error('Alıcı veya mesaj boş olamaz.');
  }

  if (!auth.currentUser) {
    try {
      await signInAnonymously(auth);
    } catch (_) {}
  }

  if (!auth.currentUser) {
    const err = new Error('AUTH_REQUIRED');
    err.code = 'AUTH_REQUIRED';
    throw err;
  }

  const uniqueIds = [...new Set(recipientIds.filter(Boolean))];
  const uniqueTeamIds = [...new Set(teamIds.map((t) => (t || '').trim()).filter(Boolean))];

  const chunkSize = 400;
  for (let i = 0; i < uniqueIds.length; i += chunkSize) {
    const chunk = uniqueIds.slice(i, i + chunkSize);
    const batch = writeBatch(db);
    for (const uid of chunk) {
      const notifRef = doc(collection(db, 'notifications', uid, 'items'));
      batch.set(notifRef, {
        ...extraData,
        type: 'nexus_dispatch',
        fromUserId: 'nexus_command',
        fromUserName: senderName,
        fromUserPic: '',
        text: cleanMsg,
        isRead: false,
        timestamp: serverTimestamp(),
      });
    }
    await batch.commit();
  }

  if (uniqueTeamIds.length > 0) {
    const teamBatch = writeBatch(db);
    for (const tid of uniqueTeamIds) {
      const msgRef = doc(collection(db, 'teams', tid, 'messages'));
      teamBatch.set(msgRef, {
        senderId: 'nexus_command',
        senderName: `📡 ${senderName}`,
        senderPic: '',
        text: cleanMsg,
        type: 'text',
        isNexusCommand: true,
        timestamp: serverTimestamp(),
      });
    }
    await teamBatch.commit();
  }

  // Blaze plan olmadan yerel FCM HTTP v1 Push Relay uzerinden kapali telefonlara gonder
  let pushSent = 0;
  let pushNote = '';
  const uniqueTokens = [...new Set((fcmTokens || []).filter(Boolean))];
  if (uniqueTokens.length > 0) {
    try {
      const pushRes = await fetch('http://127.0.0.1:5175/send-push', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          tokens: uniqueTokens,
          title: `📡 ${senderName}`,
          body: cleanMsg,
        }),
      });
      const pushJson = await pushRes.json();
      if (pushJson.ok) {
        pushSent = pushJson.sent || 0;
      } else {
        pushNote = pushJson.error || '';
      }
    } catch (_) {
      pushNote = 'Yerel push-server (5175) calismiyor.';
    }
  }

  return { count: uniqueIds.length, pushSent, pushNote };
}

/**
 * Listen to real-time disaster reports (`reports` collection where reportCategory == 'disaster_report').
 */
export function subscribeToFirebaseReports(onReportsUpdate) {
  let isSubscribed = true;
  const colRef = collection(db, 'disaster_reports');
  const unsub = onSnapshot(
    colRef,
    (snapshot) => {
      if (!isSubscribed) return;
      const list = [];
      snapshot.forEach((docSnap) => {
        const d = docSnap.data();
        list.push({
          id: docSnap.id,
          disasterType: d.disasterType || 'İhbar',
          reporterName: d.reporterName || 'Operatör',
          reporterPhone: d.reporterPhone || '-',
          reporterIp: d.reporterIp || '',
          summary: d.summary || '',
          dateTimeStr: d.dateTimeStr || '',
          fullAddress: d.fullAddress || '',
          province: d.province || '',
          district: d.district || '',
          neighborhood: d.neighborhood || '',
          street: d.street || '',
          lat: typeof d.lat === 'number' ? d.lat : null,
          lng: typeof d.lng === 'number' ? d.lng : null,
          imageBase64: d.imageBase64 || '',
          status: d.status || 'YENİ',
          dispatchedTo: Array.isArray(d.dispatchedTo) ? d.dispatchedTo : [],
          tsSec: getTimestampSeconds(d.timestamp),
        });
      });
      list.sort((a, b) => b.tsSec - a.tsSec);
      onReportsUpdate(list);
    },
    (err) => {
      console.warn('Reports listener note:', err.message);
    }
  );
  return () => {
    isSubscribed = false;
    unsub();
  };
}

export async function updateDisasterReportStatus(reportId, status) {
  if (!auth.currentUser) {
    try { await signInAnonymously(auth); } catch (_) {}
  }
  await updateDoc(doc(db, 'disaster_reports', reportId), { status });
}

export async function dispatchUsersToReport({ report, selectedUsers = [], note = '' }) {
  if (!report?.id || !selectedUsers.length) {
    throw new Error('Yönlendirilecek en az 1 operatör seçin.');
  }
  if (!auth.currentUser) {
    try { await signInAnonymously(auth); } catch (_) {}
  }

  const addrText = report.fullAddress || [report.street, report.neighborhood, report.district, report.province].filter(Boolean).join(', ');
  const coordText = report.lat != null && report.lng != null ? `${report.lat.toFixed(5)}, ${report.lng.toFixed(5)}` : 'GPS yok';
  const cleanNote = note.trim();

  const dispatchMsg = [
    `🚨 GÖREV YÖNLENDİRME: ${report.disasterType}`,
    report.province || report.district
      ? `🏙️ İl/İlçe: ${[report.province, report.district].filter(Boolean).join(' / ')}`
      : null,
    report.neighborhood ? `🏘️ Mahalle: ${report.neighborhood}` : null,
    report.street ? `🛣️ Sokak/Cadde: ${report.street}` : null,
    addrText ? `🏠 Tam Adres: ${addrText}` : null,
    `📍 Koordinat: ${coordText}`,
    `📞 İhbarcı: ${report.reporterName} (${report.reporterPhone})`,
    `📝 Özet: ${report.summary}`,
    cleanNote ? `📌 Komuta Notu: ${cleanNote}` : null,
  ].filter(Boolean).join('\n');

  const recipientIds = selectedUsers.map((u) => u.id).filter(Boolean);
  const teamIds = selectedUsers.map((u) => u.teamId).filter(Boolean);
  const fcmTokens = selectedUsers.map((u) => u.fcmToken).filter(Boolean);

  await sendNexusTeamMessage({
    recipientIds,
    teamIds,
    fcmTokens,
    message: dispatchMsg,
    senderName: 'ROTA+ NEXUS SEVK KOMUTA',
    extraData: {
      reportId: report.id,
      disasterType: report.disasterType || '',
      reporterName: report.reporterName || '',
      reporterPhone: report.reporterPhone || '',
      summary: report.summary || '',
      province: report.province || '',
      district: report.district || '',
      neighborhood: report.neighborhood || '',
      street: report.street || '',
      fullAddress: addrText || '',
      lat: report.lat ?? null,
      lng: report.lng ?? null,
      dateTimeStr: report.dateTimeStr || '',
      note: cleanNote,
    },
  });

  const nowStr = new Date().toLocaleString('tr-TR');
  const entries = selectedUsers.map((u) => ({
    uid: u.id,
    name: u.name || 'Operatör',
    dispatchedAt: nowStr,
    note: cleanNote,
  }));

  await updateDoc(doc(db, 'disaster_reports', report.id), {
    status: 'SEVK EDİLDİ',
    dispatchedTo: arrayUnion(...entries),
  });

  return entries.length;
}
