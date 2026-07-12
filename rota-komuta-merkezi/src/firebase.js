import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";

const firebaseConfig = {
  apiKey: "AIzaSyAMq-QJatDK3_Arwwxoi76Laa38AFvlB2E",
  authDomain: "rotaplus-cd84d.firebaseapp.com",
  projectId: "rotaplus-cd84d",
  storageBucket: "rotaplus-cd84d.firebasestorage.app",
  messagingSenderId: "537544685736",
  appId: "1:537544685736:web:5f1004ef8222c83e8b2a9d",
  measurementId: "G-62RWQY2Z11"
};

// Config bilgileri boş/hatalı olduğunda uygulamanın çökmemesi için basit bir kontrol
let app;
let db;

try {
  app = initializeApp(firebaseConfig);
  db = getFirestore(app);
  console.log("Firebase başarıyla başlatıldı!");
} catch (error) {
  console.error("Firebase başlatılamadı. Lütfen firebaseConfig bilgilerinizi kontrol edin.", error);
}

export { db };
