import { initializeApp } from 'firebase/app';
import { getFirestore, collection, getDocs, limit, query, orderBy } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: "AIzaSyCovIDS0P5nNlkqLHXgSvmmxqpr1TEQnjs",
  projectId: "rotaplus-cd84d",
  storageBucket: "rotaplus-cd84d.firebasestorage.app",
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

// Check collections
const possibleCollections = [
  'sos', 'sos_alerts', 'emergencies', 'emergency_calls', 'incidents', 
  'messages', 'notifications', 'reports', 'alerts', 'teams'
];

async function checkCollections() {
  for (const c of possibleCollections) {
    try {
      const snap = await getDocs(query(collection(db, c), limit(3)));
      if (snap.size > 0) {
        console.log(`Collection '${c}' exists with at least ${snap.size} docs.`);
        snap.forEach(d => console.log(` [${c}] ID: ${d.id}`, d.data()));
      }
    } catch (e) {
      // not exists or forbidden
    }
  }

  // Check Sercan's subcollections or recent changes
  try {
    const subCol = collection(db, 'users', 'KsFraxgl94NwOCnYvw9i7H2Fr2F2', 'location_history');
    const locSnap = await getDocs(query(subCol, orderBy('timestamp', 'desc'), limit(3)));
    console.log(`Sercan location_history docs: ${locSnap.size}`);
    locSnap.forEach(d => console.log('  loc doc:', d.data()));
  } catch (e) {
    console.log('Error checking subcollection:', e.message);
  }

  process.exit(0);
}

checkCollections();
