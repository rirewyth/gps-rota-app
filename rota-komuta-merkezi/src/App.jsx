import React, { useState, useEffect } from 'react';
import './App.css';
import MapArea from './components/MapArea';
import LeftSidebar from './components/LeftSidebar';
import RightSidebar from './components/RightSidebar';
import BottomAnalytics from './components/BottomAnalytics';
import { collection, onSnapshot, query, limit } from 'firebase/firestore';
import { db } from './firebase';

function App() {
  const [errorMsg, setErrorMsg] = useState(null);

  useEffect(() => {
    if (db) {
      const qSos = query(collection(db, "sos_alerts"), limit(1));
      const unsub = onSnapshot(qSos, () => {}, (err) => {
        setErrorMsg(err.message);
      });
      return () => unsub();
    }
  }, []);

  return (
    <div className="app-container">
      {errorMsg && (
        <div style={{ position: 'absolute', top: 0, left: 0, right: 0, background: 'red', color: 'white', padding: '16px', zIndex: 9999, textAlign: 'center', fontWeight: 'bold' }}>
          FIREBASE HATASI: {errorMsg}. (Kurallarınız güncel olmayabilir, 'firebase deploy --only firestore:rules' yapın)
        </div>
      )}
      <MapArea />
      <LeftSidebar />
      <RightSidebar />
      <BottomAnalytics />
    </div>
  );
}

export default App;
