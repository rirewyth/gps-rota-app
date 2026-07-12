import React, { useEffect, useState } from 'react';
import { Users, AlertTriangle, RadioReceiver, BookOpen, Truck, LifeBuoy } from 'lucide-react';
import { collection, onSnapshot, query, where } from 'firebase/firestore';
import { db } from '../firebase';

function LeftSidebar() {
  const [stats, setStats] = useState({
    liveUsers: 0,
    activeTracking: 0,
    sos: 0,
    medicalProfiles: 0
  });

  useEffect(() => {
    let unsubs = [];
    if (db) {
      try {
        const qUsers = query(collection(db, "users"));
        const unsubUsers = onSnapshot(qUsers, (snap) => setStats(s => ({...s, liveUsers: snap.size, activeTracking: snap.size, medicalProfiles: snap.size})));
        unsubs.push(unsubUsers);

        // DOĞRU KOLEKSİYON: sos_alerts
        const qSos = query(collection(db, "sos_alerts"));
        const unsubSos = onSnapshot(qSos, (snap) => setStats(s => ({...s, sos: snap.size})));
        unsubs.push(unsubSos);
      } catch (e) {
        console.log("Firebase stat dinleyicileri başlatılamadı.", e);
      }
    }
    return () => unsubs.forEach(fn => fn());
  }, []);

  return (
    <div className="left-sidebar">
      {/* Brand */}
      <div className="glass-panel" style={{ padding: '24px 16px', textAlign: 'center', borderColor: 'var(--color-orange)' }}>
        <h1 style={{ color: 'var(--text-primary)', margin: 0, fontSize: '1.5rem', letterSpacing: '2px', textTransform: 'uppercase' }}>
          ROTA<span className="text-orange">+</span>
        </h1>
        <p style={{ color: 'var(--text-secondary)', fontSize: '0.75rem', marginTop: '4px', textTransform: 'uppercase', letterSpacing: '1px' }}>
          Acil Durum Komuta Merkezi
        </p>
      </div>

      {/* Navigation / Actions */}
      <div className="glass-panel">
        <h2>Kontrol Paneli</h2>
        <div className="item-row">
          <Users size={18} className="text-blue" />
          <span style={{ flex: 1 }}>Canlı Kullanıcılar</span>
          <span className="badge blue">{stats.liveUsers}</span>
        </div>
        <div className="item-row">
          <RadioReceiver size={18} className="text-orange" />
          <span style={{ flex: 1 }}>Aktif Takip</span>
          <span className="badge orange">{stats.activeTracking}</span>
        </div>
        <div className="item-row" style={{ backgroundColor: 'rgba(255,51,51,0.1)', margin: '0 -16px', padding: '8px 16px', borderLeft: '3px solid var(--color-red)' }}>
          <AlertTriangle size={18} className="text-red" />
          <span style={{ flex: 1, color: 'var(--color-red)', fontWeight: 'bold' }}>Aktif SOS</span>
          <span className="badge red" style={{ animation: 'pulse 2s infinite' }}>{stats.sos}</span>
        </div>
        <div className="item-row">
          <BookOpen size={18} className="text-green" />
          <span style={{ flex: 1 }}>Tıbbi Profiller</span>
          <span className="badge" style={{ background: 'rgba(255,255,255,0.1)' }}>{stats.medicalProfiles}</span>
        </div>
      </div>

      {/* Operasyonlar */}
      <div className="glass-panel" style={{ flex: 1 }}>
        <h2>Operasyonlar</h2>
        <div className="item-row">
          <Truck size={18} className="text-orange" />
          <span style={{ flex: 1 }}>Arama Kurtarma Timleri</span>
        </div>
        <div className="item-row">
          <LifeBuoy size={18} className="text-blue" />
          <span style={{ flex: 1 }}>Kurtarma Talepleri</span>
        </div>
        <div className="item-row">
          <AlertTriangle size={18} className="text-yellow" />
          <span style={{ flex: 1 }}>Afet Raporları</span>
        </div>
      </div>

      <style>{`
        @keyframes pulse {
          0% { box-shadow: 0 0 0 0 rgba(255,51,51,0.7); }
          70% { box-shadow: 0 0 0 10px rgba(255,51,51,0); }
          100% { box-shadow: 0 0 0 0 rgba(255,51,51,0); }
        }
      `}</style>
    </div>
  );
}

export default LeftSidebar;
