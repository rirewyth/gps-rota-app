import React, { useEffect, useState } from 'react';
import MapComponent from './components/MapComponent';
import Sidebar from './components/Sidebar';
import axios from 'axios';

export interface FireEvent {
  id: number;
  external_id: string;
  satellite: string;
  sensor: string;
  latitude: number;
  longitude: number;
  fire_metric: number;
  confidence: number;
  status: string;
  province: string;
  district: string;
  village: string;
  locality: string;
  detected_at: string;
}

function App() {
  const [fires, setFires] = useState<FireEvent[]>([]);
  const [selectedFire, setSelectedFire] = useState<FireEvent | null>(null);

  useEffect(() => {
    // Fetch initial data
    axios.get('http://localhost:8000/api/fires/active')
      .then(response => {
        setFires(response.data);
      })
      .catch(error => console.error("Error fetching fires", error));

    // WebSocket connection
    const ws = new WebSocket('ws://localhost:8000/ws/fires');
    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      if (data.event === "NEW_FIRE") {
        alert("YENİ YANGIN TESPİT EDİLDİ: " + data.province + " / " + data.district);
        // We can re-fetch or append
        axios.get('http://localhost:8000/api/fires/active').then(res => setFires(res.data));
      }
    };

    return () => ws.close();
  }, []);

  return (
    <div className="flex h-screen bg-gray-900 text-white font-sans">
      <Sidebar fires={fires} onSelectFire={setSelectedFire} />
      <div className="flex-1 relative">
        <MapComponent fires={fires} selectedFire={selectedFire} onSelectFire={setSelectedFire} />
      </div>
    </div>
  );
}

export default App;
