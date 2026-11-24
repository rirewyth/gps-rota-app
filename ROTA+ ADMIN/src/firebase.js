import { initializeApp, getApps, getApp } from 'firebase/app';
import {
  getAuth,
  GoogleAuthProvider,
  signInWithPopup,
  signInWithEmailAndPassword,
  signOut,
  onAuthStateChanged
} from 'firebase/auth';
import {
  getFirestore,
  collection,
  doc,
  getDoc,
  getDocs,
  setDoc,
  addDoc,
  updateDoc,
  deleteDoc,
  writeBatch,
  arrayUnion,
  onSnapshot,
  serverTimestamp
} from 'firebase/firestore';

const firebaseConfig = {
  apiKey: "AIzaSyCovIDS0P5nNlkqLHXgSvmmxqpr1TEQnjs",
  authDomain: "rotaplus-cd84d.firebaseapp.com",
  projectId: "rotaplus-cd84d",
  storageBucket: "rotaplus-cd84d.firebasestorage.app",
};

export const app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApp();
export const auth = getAuth(app);
export const db = getFirestore(app);

const ADMIN_EMAILS = ['sercanoral65@gmail.com', 'demo@gmail.com', 'admin@rota.plus'];

export async function verifyAdminUser(user) {
  if (!user) return false;
  if (user.email && ADMIN_EMAILS.includes(user.email.toLowerCase())) {
    return true;
  }
  try {
    const snap = await getDoc(doc(db, 'users', user.uid));
    return snap.exists() && snap.data()?.is_admin === true;
  } catch (_) {
    return false;
  }
}

export async function loginWithGoogle() {
  const provider = new GoogleAuthProvider();
  const cred = await signInWithPopup(auth, provider);
  return cred.user;
}

export async function loginWithEmail(email, password) {
  const cred = await signInWithEmailAndPassword(auth, email.trim(), password);
  return cred.user;
}

export async function logoutAdmin() {
  await signOut(auth);
}

export function subscribeAuth(cb) {
  return onAuthStateChanged(auth, cb);
}

export function toMillis(ts) {
  if (!ts) return 0;
  if (typeof ts === 'number') return ts;
  if (ts.seconds) return ts.seconds * 1000;
  if (typeof ts.toDate === 'function') return ts.toDate().getTime();
  return 0;
}

export function formatImgSrc(raw) {
  if (!raw || typeof raw !== 'string') return null;
  const s = raw.trim();
  if (!s) return null;
  if (s.startsWith('base64:')) return `data:image/jpeg;base64,${s.slice(7)}`;
  if (s.startsWith('http://') || s.startsWith('https://') || s.startsWith('data:image/')) return s;
  if (s.length > 60 && !s.includes(' ')) return `data:image/jpeg;base64,${s}`;
  return null;
}

export function subscribeCollection(name, onData, onError) {
  return onSnapshot(
    collection(db, name),
    (snap) => {
      const rows = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      onData(rows);
    },
    (err) => {
      if (onError) onError(err);
    }
  );
}

export async function updateUserFlags(uid, patch) {
  await updateDoc(doc(db, 'users', uid), patch);
}

export async function deleteDocByPath(colName, id) {
  await deleteDoc(doc(db, colName, id));
}

export async function updateDocByPath(colName, id, patch) {
  await updateDoc(doc(db, colName, id), patch);
}

export async function createAnnouncement({ title, content, level = 'normal' }) {
  await addDoc(collection(db, 'announcements'), {
    title: title.trim(),
    content: content.trim(),
    level,
    authorEmail: auth.currentUser?.email || 'admin@rota.plus',
    timestamp: serverTimestamp(),
  });
}

export async function createFireMarker({ name, lat, lng, description, team, status = 'Aktif' }) {
  await addDoc(collection(db, 'fires'), {
    name: name.trim(),
    lat: Number(lat),
    lng: Number(lng),
    description: description.trim(),
    team: team.trim(),
    status,
    timestamp: serverTimestamp(),
  });
}

export async function banIpAddress(ip, reason = 'Sahte/Asılsız İhbar') {
  if (!ip) return;
  const id = ip.replace(/:/g, '_');
  await setDoc(doc(db, 'banned_ips', id), {
    ip,
    reason,
    bannedBy: auth.currentUser?.email || 'admin',
    timestamp: serverTimestamp(),
  });
}

export async function unbanIpAddress(ip) {
  if (!ip) return;
  const id = ip.replace(/:/g, '_');
  await deleteDoc(doc(db, 'banned_ips', id));
}

export async function sendDirectUserNotification({ uid, title, message }) {
  const cleanMsg = message.trim();
  if (!uid || !cleanMsg) throw new Error('Mesaj boş olamaz.');
  await addDoc(collection(db, 'notifications', uid, 'items'), {
    type: 'admin',
    fromUserId: auth.currentUser?.uid || 'admin',
    fromUserName: title?.trim() || 'ROTA+ ADMIN YÖNETİM',
    fromUserPic: '',
    text: cleanMsg,
    isRead: false,
    timestamp: serverTimestamp(),
  });
}

export async function dispatchUsersToReport({ report, selectedUsers = [], note = '' }) {
  if (!report?.id || !selectedUsers.length) {
    throw new Error('En az 1 operatör seçin.');
  }
  const addrText =
    report.fullAddress ||
    [report.street, report.neighborhood, report.district, report.province].filter(Boolean).join(', ');
  const coordText =
    report.lat != null && report.lng != null
      ? `${Number(report.lat).toFixed(5)}, ${Number(report.lng).toFixed(5)}`
      : 'GPS yok';
  const cleanNote = note.trim();

  const dispatchMsg = [
    `🚨 GÖREV YÖNLENDİRME: ${report.disasterType || 'İhbar'}`,
    report.province || report.district
      ? `🏙️ İl/İlçe: ${[report.province, report.district].filter(Boolean).join(' / ')}`
      : null,
    report.neighborhood ? `🏘️ Mahalle: ${report.neighborhood}` : null,
    report.street ? `🛣️ Sokak/Cadde: ${report.street}` : null,
    addrText ? `🏠 Tam Adres: ${addrText}` : null,
    `📍 Koordinat: ${coordText}`,
    `📞 İhbarcı: ${report.reporterName || '-'} (${report.reporterPhone || '-'})`,
    `📝 Özet: ${report.summary || ''}`,
    cleanNote ? `📌 Komuta Notu: ${cleanNote}` : null,
  ].filter(Boolean).join('\n');

  const batch = writeBatch(db);
  for (const u of selectedUsers) {
    const notifRef = doc(collection(db, 'notifications', u.id, 'items'));
    batch.set(notifRef, {
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
      type: 'nexus_dispatch',
      fromUserId: 'nexus_command',
      fromUserName: 'ROTA+ ADMIN SEVK KOMUTA',
      fromUserPic: '',
      text: dispatchMsg,
      isRead: false,
      timestamp: serverTimestamp(),
    });
  }
  await batch.commit();

  const nowStr = new Date().toLocaleString('tr-TR');
  const entries = selectedUsers.map((u) => ({
    uid: u.id,
    name: u.name || u.ad || 'Operatör',
    dispatchedAt: nowStr,
    note: cleanNote,
  }));

  await updateDoc(doc(db, 'disaster_reports', report.id), {
    status: 'SEVK EDİLDİ',
    dispatchedTo: arrayUnion(...entries),
  });

  return entries.length;
}

export function subscribeTeamMessages(teamId, onData) {
  return onSnapshot(collection(db, 'teams', teamId, 'messages'), (snap) => {
    const msgs = snap.docs
      .map((d) => ({ id: d.id, ...d.data() }))
      .sort((a, b) => toMillis(a.timestamp) - toMillis(b.timestamp));
    onData(msgs);
  });
}

export async function logAdminAction(action, target = '', details = '') {
  try {
    await addDoc(collection(db, 'admin_logs'), {
      adminEmail: auth.currentUser?.email || 'admin',
      action,
      target: String(target),
      details: String(details),
      timestamp: serverTimestamp(),
    });
  } catch (_) {}
}

export async function sendTargetedBulkNotification({ targetUsers = [], title = '', message = '' }) {
  const cleanMsg = message.trim();
  if (!cleanMsg || targetUsers.length === 0) {
    throw new Error('Hedef kullanıcı veya mesaj boş.');
  }
  const chunkSize = 400;
  for (let i = 0; i < targetUsers.length; i += chunkSize) {
    const chunk = targetUsers.slice(i, i + chunkSize);
    const batch = writeBatch(db);
    for (const u of chunk) {
      const ref = doc(collection(db, 'notifications', u.id, 'items'));
      batch.set(ref, {
        type: 'admin',
        fromUserId: auth.currentUser?.uid || 'admin',
        fromUserName: title.trim() || 'ROTA+ ADMIN DUYURU',
        fromUserPic: '',
        text: cleanMsg,
        isRead: false,
        timestamp: serverTimestamp(),
      });
    }
    await batch.commit();
  }
  await logAdminAction('TOPLU_BILDIRIM', `${targetUsers.length} kişi`, `${title}: ${cleanMsg.slice(0, 80)}`);
  return targetUsers.length;
}

export async function fetchUserRoutes(uid) {
  const snap = await getDocs(collection(db, 'users', uid, 'routes'));
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

export async function deleteUserRoute(uid, routeId) {
  await deleteDoc(doc(db, 'users', uid, 'routes', routeId));
  await logAdminAction('ROTA_SILINDI', `${uid}/${routeId}`, '');
}

export async function createSafeZone({ name, category, lat, lng, capacity = '', note = '' }) {
  await addDoc(collection(db, 'safe_zones'), {
    name: name.trim(),
    category,
    lat: Number(lat),
    lng: Number(lng),
    capacity: capacity.trim(),
    note: note.trim(),
    timestamp: serverTimestamp(),
  });
  await logAdminAction('TOPLANMA_ALANI_EKLENDI', name.trim(), `${category} (${lat}, ${lng})`);
}

export async function createHazardZone({ name, hazardType, lat, lng, radiusMeters = 500, note = '' }) {
  await addDoc(collection(db, 'hazard_zones'), {
    name: name.trim(),
    hazardType,
    lat: Number(lat),
    lng: Number(lng),
    radiusMeters: Number(radiusMeters) || 500,
    note: note.trim(),
    timestamp: serverTimestamp(),
  });
  await logAdminAction('RISKLI_BOLGE_EKLENDI', name.trim(), `${hazardType} ${radiusMeters}m (${lat}, ${lng})`);
}

export async function replySupportTicket({ ticket, replyText }) {
  const clean = replyText.trim();
  if (!ticket?.id || !clean) return;
  await updateDoc(doc(db, 'support_tickets', ticket.id), {
    status: 'YANITLANDI',
    adminReply: clean,
    repliedBy: auth.currentUser?.email || 'admin',
    repliedAt: serverTimestamp(),
  });
  if (ticket.userId) {
    await addDoc(collection(db, 'notifications', ticket.userId, 'items'), {
      type: 'admin',
      fromUserId: auth.currentUser?.uid || 'admin',
      fromUserName: 'ROTA+ DESTEK YANITI',
      fromUserPic: '',
      text: clean,
      isRead: false,
      timestamp: serverTimestamp(),
    });
  }
  await logAdminAction('DESTEK_YANITLANDI', ticket.userName || ticket.id, clean.slice(0, 60));
}
