import { initializeApp } from 'firebase/app';
import { getFirestore, collection, getDocs } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: "AIzaSyCovIDS0P5nNlkqLHXgSvmmxqpr1TEQnjs",
  projectId: "rotaplus-cd84d",
  storageBucket: "rotaplus-cd84d.firebasestorage.app",
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function checkRecentUsers() {
  const col = collection(db, 'users');
  const snap = await getDocs(col);
  const users = [];

  snap.forEach(d => {
    const data = d.data();
    users.push({
      id: d.id,
      name: data.name || data.username,
      is_sos: data.is_sos,
      sos: data.sos,
      sos_timestamp: data.sos_timestamp,
      location_timestamp: data.location_timestamp,
      last_active: data.last_active,
      last_seen: data.last_seen
    });
  });

  // Sort by latest timestamp
  const getTs = (u) => {
    const t = u.sos_timestamp || u.location_timestamp || u.last_seen || u.last_active;
    if (!t) return 0;
    if (t.seconds) return t.seconds;
    if (typeof t.toDate === 'function') return t.toDate().getTime() / 1000;
    if (typeof t === 'number') return t;
    if (typeof t === 'string') return new Date(t).getTime() / 1000;
    return 0;
  };

  users.sort((a, b) => getTs(b) - getTs(a));

  console.log('Top 10 most recently active users in DB:');
  users.slice(0, 10).forEach(u => {
    console.log(`- ${u.name} (ID: ${u.id})`);
    console.log(`  is_sos: ${u.is_sos}, sos: ${u.sos}`);
    console.log(`  sos_timestamp:`, u.sos_timestamp);
    console.log(`  location_ts:`, u.location_timestamp);
  });

  process.exit(0);
}

checkRecentUsers();
