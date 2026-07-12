import React, { useEffect, useState } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Circle } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';
import axios from 'axios';
import MarkerProfile from './MarkerProfile';
import { collection, onSnapshot, query, limit } from 'firebase/firestore';
import { db } from '../firebase';

// Custom icons
const createIcon = (color) => {
  return L.divIcon({
    className: 'custom-icon',
    html: `<div style="background-color: ${color}; width: 16px; height: 16px; border-radius: 50%; border: 2px solid #fff; box-shadow: 0 0 10px ${color}"></div>`,
    iconSize: [16, 16],
    iconAnchor: [8, 8],
  });
};

const icons = {
  safe: createIcon('var(--color-green)'),
  sos: createIcon('var(--color-red)'),
  tracking: createIcon('var(--color-orange)'),
  offline: createIcon('#808080'),
  earthquake: createIcon('var(--color-red)'), // using red for earthquake epicenter
};

// Fallback mock data in case firebase is not connected
const fallbackMockUsers = [
  { id: 'mock1', name: 'Ahmet Yılmaz', status: 'safe', lat: 39.92077, lng: 32.85411, battery: 85, lastSeen: '1 dk önce', bloodType: 'A+' },
  { id: 'mock2', name: 'Elif Demir', status: 'sos', lat: 39.9334, lng: 32.8597, battery: 15, lastSeen: 'Şimdi', bloodType: '0-', rescueNotes: 'Acil Yardım!' },
];

function MapArea() {
  const center = [39.0, 35.0]; // Center of Turkey
  const [baseUsers, setBaseUsers] = useState(fallbackMockUsers);
  const [sosUsers, setSosUsers] = useState([]);
  const [earthquakes, setEarthquakes] = useState([]);

  useEffect(() => {
    // 1. Fetch Real Earthquake Data
    const fetchEarthquakes = async () => {
      try {
        const response = await axios.get('https://api.orhanaydogdu.com.tr/deprem/kandilli/live');
        if (response.data && response.data.result) {
          const significantEqs = response.data.result
            .filter(eq => eq.mag >= 3.0)
            .slice(0, 5);
          setEarthquakes(significantEqs);
        }
      } catch (error) {
        console.error("Deprem verisi çekilemedi:", error);
      }
    };

    fetchEarthquakes();
    const eqInterval = setInterval(fetchEarthquakes, 5 * 60 * 1000);

    // 2. Real-time Firebase Users
    let unsubs = [];
    if (db) {
      try {
        const qUsers = query(collection(db, "users"), limit(50));
        const unsubUsers = onSnapshot(qUsers, (snapshot) => {
          const liveUsers = snapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data()
          }));
          if (liveUsers.length > 0) setBaseUsers(liveUsers);
        }, (error) => console.log("Users hatası", error));
        unsubs.push(unsubUsers);

        const qSos = query(collection(db, "sos_alerts"), limit(50));
        const unsubSos = onSnapshot(qSos, (snapshot) => {
          const sosList = snapshot.docs.map(doc => {
            const data = doc.data();
            return {
              id: doc.id,
              name: data.name || data.user_name || 'Acil SOS!',
              lat: data.latitude || 0,
              lng: data.longitude || 0,
              status: 'sos',
              rescueNotes: 'KULLANICI ACİL DURUM BİLDİRDİ!'
            };
          });
          setSosUsers(sosList);
        }, (error) => console.log("SOS hatası", error));
        unsubs.push(unsubSos);

      } catch (e) {
        console.log("Firebase yapılandırması eksik, mock veri devrede.");
      }
    }

    return () => {
      clearInterval(eqInterval);
      unsubs.forEach(fn => fn());
    };
  }, []);

  // Merge users for display (SOS overrides base user)
  const displayUsers = [...baseUsers];
  sosUsers.forEach(sosUser => {
    const idx = displayUsers.findIndex(u => u.id === sosUser.id || u.uid === sosUser.id);
    if (idx > -1) {
      displayUsers[idx] = { ...displayUsers[idx], ...sosUser };
    } else {
      displayUsers.push(sosUser);
    }
  });

  return (
    <div className="map-container">
      <MapContainer center={center} zoom={6} style={{ height: '100%', width: '100%' }} zoomControl={false}>
        {/* Free Dark Map Tile Layer */}
        <TileLayer
          url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        />

        {/* Real Earthquakes Layer */}
        {earthquakes.map((eq, idx) => (
          <React.Fragment key={`eq-${idx}`}>
            <Circle 
              center={[eq.geojson.coordinates[1], eq.geojson.coordinates[0]]} 
              radius={eq.mag * 5000} // Radius based on magnitude
              pathOptions={{ color: 'rgba(255,51,51,0.5)', fillColor: 'red', fillOpacity: 0.2 }} 
            />
            <Marker position={[eq.geojson.coordinates[1], eq.geojson.coordinates[0]]} icon={icons.earthquake}>
              <Popup className="custom-popup">
                <div style={{ color: '#fff' }}>
                  <h4 style={{ color: 'var(--color-red)', margin: '0 0 4px 0' }}>DEPREM</h4>
                  <p style={{ margin: 0 }}><strong>Büyüklük:</strong> {eq.mag}</p>
                  <p style={{ margin: 0, fontSize: '0.8rem' }}><strong>Yer:</strong> {eq.title}</p>
                  <p style={{ margin: 0, fontSize: '0.8rem', color: 'var(--text-secondary)' }}>{eq.date}</p>
                </div>
              </Popup>
            </Marker>
          </React.Fragment>
        ))}

        {/* User Markers (Firebase or Mock) */}
        {displayUsers.map(user => (
          <Marker key={user.id} position={[user.lat || 39, user.lng || 35]} icon={icons[user.status || 'safe']}>
            <Popup className="custom-popup">
              <MarkerProfile user={user} />
            </Popup>
          </Marker>
        ))}
      </MapContainer>
    </div>
  );
}

export default MapArea;
