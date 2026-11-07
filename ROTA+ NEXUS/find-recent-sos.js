import { initializeApp } from 'firebase/app';
import { getFirestore, collection, getDocs } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: "AIzaSyCovIDS0P5nNlkqLHXgSvmmxqpr1TEQnjs",
  projectId: "rotaplus-cd84d",
  storageBucket: "rotaplus-cd84d.firebasestorage.app",
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function findAnyRecentSos() {
  const snap = await getDocs(collection(db, 'users'));
  const nowSec = 1794030000; // current time approx
  console.log(`Checking ${snap.size} users...`);
  
  snap.forEach(d => {
    const data = d.data();
    const sosVal = data.is_sos || data.sos || data.emergency;
    const sosTs = data.sos_timestamp?.seconds || 0;
    const locTs = data.location_timestamp?.seconds || 0;
    const lastActive = data.last_active?.seconds || 0;

    // Check if updated in the last 24 hours (since 1793900000)
    if (sosTs > 1793900000 || locTs > 1793900000 || lastActive > 1793900000) {
      console.log(`[RECENT USER] ${data.name || data.username} (${d.id})`);
      console.log(`  is_sos: ${data.is_sos}, sos: ${data.sos}`);
      console.log(`  sos_timestamp:`, data.sos_timestamp);
      console.log(`  location_timestamp:`, data.location_timestamp);
      console.log(`  last_active:`, data.last_active);
    }
  });

  process.exit(0);
}

findAnyRecentSos();
