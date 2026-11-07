import { initializeApp } from 'firebase/app';
import { getFirestore, collection, getDocs } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: "AIzaSyCovIDS0P5nNlkqLHXgSvmmxqpr1TEQnjs",
  projectId: "rotaplus-cd84d",
  storageBucket: "rotaplus-cd84d.firebasestorage.app",
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function checkSosAlerts() {
  try {
    const col = collection(db, 'sos_alerts');
    const snap = await getDocs(col);
    console.log(`sos_alerts collection has ${snap.size} documents:`);
    snap.forEach(d => {
      console.log(`- Doc ID: ${d.id}`, d.data());
    });
  } catch (err) {
    console.error('Error reading sos_alerts:', err.message);
  }
  process.exit(0);
}

checkSosAlerts();
