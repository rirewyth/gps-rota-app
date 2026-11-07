import { initializeApp } from 'firebase/app';
import { getFirestore, doc, getDoc } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: "AIzaSyCovIDS0P5nNlkqLHXgSvmmxqpr1TEQnjs",
  projectId: "rotaplus-cd84d",
  storageBucket: "rotaplus-cd84d.firebasestorage.app",
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

const testSosIds = [
  'Hsow77sjIlVwGxpRxROgsowcRuk2', // vaha
  'Itrg9ty080c1Jfc3XHVjZQVSwts2', // TB3ELE
  'OIGBFt9BR4UhAGdHkzxS3r9bg9y1', // peri
  'UVrB6xAPo8OQJnrFxJYzOdxNpah2', // Emrah
  'dCG4dA8zEAcYg0B7zEadndRoAuu2', // Görkem
  'wBfhQTCVBWcgDIF1Ddbw4Uvj8Cy1', // Team Guardian
  'KsFraxgl94NwOCnYvw9i7H2Fr2F2', // Sercan
  '4Bnv4ZTBMna8LGH3Q05CRqNOtFg1'  // Bekir
];

async function checkDetails() {
  for (const id of testSosIds) {
    const snap = await getDoc(doc(db, 'users', id));
    if (snap.exists()) {
      const d = snap.data();
      console.log(`=== USER: ${d.name || d.username} (${id}) ===`);
      console.log('is_sos:', d.is_sos, 'sos:', d.sos);
      console.log('sos_timestamp:', d.sos_timestamp);
      console.log('location_timestamp:', d.location_timestamp);
      console.log('last_seen:', d.last_seen);
      console.log('last_active:', d.last_active);
    }
  }
  process.exit(0);
}

checkDetails();
