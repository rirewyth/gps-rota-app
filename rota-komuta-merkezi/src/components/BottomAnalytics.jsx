import React, { useEffect, useState } from 'react';
import { Activity, ShieldCheck, Bluetooth, MapPin, AlertCircle, CheckCircle2 } from 'lucide-react';
import { collection, onSnapshot, query, where } from 'firebase/firestore';
import { db } from '../firebase';

function BottomAnalytics() {
  const [stats, setStats] = useState({
    registeredUsers: 0,
    safeCheckins: 0,
    sharedRoutes: 0,
    openIncidents: 0,
    rescueTeams: 0,
    bleSignals: 0
  });

  useEffect(() => {
    let unsubs = [];
    if (db) {
      try {
        // Users collection
        const qUsers = query(collection(db, "users"));
        const unsubUsers = onSnapshot(qUsers, (snap) => setStats(s => ({...s, registeredUsers: snap.size})));
        unsubs.push(unsubUsers);

        // Safe status
        const qSafe = query(collection(db, "users"), where("status", "==", "safe"));
        const unsubSafe = onSnapshot(qSafe, (snap) => setStats(s => ({...s, safeCheckins: snap.size})));
        unsubs.push(unsubSafe);

        // SOS/Incidents (from sos_alerts)
        const qSos = query(collection(db, "sos_alerts"));
        const unsubSos = onSnapshot(qSos, (snap) => setStats(s => ({...s, openIncidents: snap.size})));
        unsubs.push(unsubSos);

        // Tracking routes
        const qTrack = query(collection(db, "users"), where("status", "==", "tracking"));
        const unsubTrack = onSnapshot(qTrack, (snap) => setStats(s => ({...s, sharedRoutes: snap.size})));
        unsubs.push(unsubTrack);
        
        // Note: rescueTeams and bleSignals might need their own collections. 
        // Just mocking them based on something else or leaving static for now, or using users data if it has roles.
      } catch (e) {
        console.log("Firebase analitik dinleyicileri başlatılamadı.");
      }
    }
    return () => unsubs.forEach(fn => fn());
  }, []);

  const statBoxStyle = {
    background: 'rgba(255,255,255,0.03)',
    border: '1px solid rgba(255,255,255,0.05)',
    borderRadius: '8px',
    padding: '12px',
    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
    flex: 1
  };

  const valStyle = {
    fontSize: '1.5rem',
    fontWeight: 'bold',
    color: '#fff'
  };

  return (
    <div className="bottom-analytics glass-panel">
      <h2>Sistem Analitiği & Raporlar</h2>
      
      <div style={{ display: 'flex', gap: '16px', flexWrap: 'wrap' }}>
        <div style={statBoxStyle}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
            <Activity size={16} className="text-green" /> Kayıtlı Kullanıcı
          </div>
          <div style={valStyle}>{stats.registeredUsers || '0'}</div>
        </div>

        <div style={statBoxStyle}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
            <CheckCircle2 size={16} className="text-green" /> Güvenli Bildirimi
          </div>
          <div style={valStyle}>{stats.safeCheckins || '0'}</div>
        </div>

        <div style={{...statBoxStyle, borderColor: 'rgba(255,106,0,0.3)', background: 'rgba(255,106,0,0.05)'}}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--color-orange)', fontSize: '0.85rem' }}>
            <MapPin size={16} /> Paylaşılan Rota
          </div>
          <div style={{...valStyle, color: 'var(--color-orange)'}}>{stats.sharedRoutes || '0'}</div>
        </div>

        <div style={{...statBoxStyle, borderColor: 'rgba(255,51,51,0.3)', background: 'rgba(255,51,51,0.05)'}}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--color-red)', fontSize: '0.85rem', fontWeight: 'bold' }}>
            <AlertCircle size={16} /> Açık Olaylar (SOS)
          </div>
          <div style={{...valStyle, color: 'var(--color-red)'}}>{stats.openIncidents || '0'}</div>
        </div>

        <div style={statBoxStyle}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
            <ShieldCheck size={16} className="text-blue" /> Kurtarma Ekibi
          </div>
          <div style={valStyle}>{stats.rescueTeams || '0'}</div>
        </div>

        <div style={statBoxStyle}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
            <Bluetooth size={16} className="text-blue" /> BLE Sinyali
          </div>
          <div style={valStyle}>{stats.bleSignals || '0'}</div>
        </div>
      </div>
    </div>
  );
}

export default BottomAnalytics;
