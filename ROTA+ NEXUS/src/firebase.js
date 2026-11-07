import { initializeApp, getApps, getApp } from 'firebase/app';
import { getAuth, signInAnonymously } from 'firebase/auth';
import { 
  getFirestore, 
  collection, 
  onSnapshot 
} from 'firebase/firestore';

const firebaseConfig = {
  apiKey: "AIzaSyCovIDS0P5nNlkqLHXgSvmmxqpr1TEQnjs",
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
