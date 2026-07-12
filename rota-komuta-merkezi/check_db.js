import { initializeApp } from "firebase/app";
import { getFirestore, collection, getDocs, limit, query } from "firebase/firestore";

const firebaseConfig = {
  apiKey: "AIzaSyAMq-QJatDK3_Arwwxoi76Laa38AFvlB2E",
  authDomain: "rotaplus-cd84d.firebaseapp.com",
  projectId: "rotaplus-cd84d",
  storageBucket: "rotaplus-cd84d.firebasestorage.app",
  messagingSenderId: "537544685736",
  appId: "1:537544685736:web:5f1004ef8222c83e8b2a9d",
  measurementId: "G-62RWQY2Z11"
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function checkData() {
  try {
    const q = query(collection(db, "users"), limit(5));
    const querySnapshot = await getDocs(q);
    console.log("USERS COLLECTION FOUND. Doc count:", querySnapshot.size);
    querySnapshot.forEach((doc) => {
      console.log(doc.id, " => ", doc.data());
    });
  } catch (e) {
    console.error("Error fetching users:", e);
  }
}

checkData();
