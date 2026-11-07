import React, { useState, useEffect, useRef } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Circle, Polyline, useMap } from 'react-leaflet';
import L from 'leaflet';
import { 
  ActivitySquare, Terminal, ShieldCheck, AlertTriangle, 
  Wifi, ChevronRight, Zap, X, MapPin, Users
} from 'lucide-react';

// --- CUSTOM ICONS ---
const createPulseIcon = (color, text) => L.divIcon({
  className: 'custom-icon',
  html: `
    <div style="position: relative; width: 28px; height: 28px; cursor: pointer;">
      <div style="position: absolute; width: 100%; height: 100%; background: ${color}; border-radius: 50%; opacity: 0.5; animation: ping 2s cubic-bezier(0, 0, 0.2, 1) infinite;"></div>
      <div style="position: absolute; top: 2px; left: 2px; width: 24px; height: 24px; background: #0A0C0F; border: 2px solid ${color}; border-radius: 50%; display: flex; align-items: center; justify-content: center; color: ${color}; font-size: 12px; font-weight: bold;">
        ${text}
      </div>
    </div>`,
  iconSize: [28, 28],
  iconAnchor: [14, 14]
});

const icons = {
  FIRE: createPulseIcon('#FF3B1C', '🔥'),
  EARTHQUAKE: createPulseIcon('#FF8C00', '⚠️'),
  SOS: createPulseIcon('#ef4444', 'SOS'),
  TEAM: createPulseIcon('#00E5FF', 'T'),
  DRONE: createPulseIcon('#a855f7', 'D')
};

// --- MOCK DATA FOR REAL-TIME SIMULATION ---
const MOCK_INCIDENTS = [
  { id: 'TR-2026-10482', type: 'ORMAN YANGINI', loc: 'Antalya / Serik', priority: 'CRITICAL', coords: [36.93, 31.08], radius: 3000, risk: 'HIGH SPREAD', wind: 'NW 18 km/h' },
  { id: 'TR-2026-10485', type: 'DEPREM', loc: 'İzmir / Seferihisar', priority: 'NATIONAL', coords: [38.19, 26.83], radius: 15000, risk: 'AFTERSHOCKS', wind: 'NE 12 km/h' },
  { id: 'TR-2026-10488', type: 'KAYIP KİŞİ', loc: 'Bursa / Uludağ', priority: 'HIGH', coords: [40.06, 29.21], radius: 5000, risk: 'HYPOTHERMIA', wind: 'N 25 km/h' }
];

const initialTeams = [
  { id: 'TEAM-ALPHA', role: 'SEARCH & RESCUE', status: 'ACTIVE', coords: [36.91, 31.05], target: [36.93, 31.08], battery: 84 },
  { id: 'TEAM-BRAVO', role: 'MEDICAL', status: 'EN ROUTE', coords: [38.15, 26.80], target: [38.19, 26.83], battery: 92 },
  { id: 'TEAM-CHARLIE', role: 'EVAC', status: 'WAITING', coords: [40.02, 29.20], target: [40.06, 29.21], battery: 100 },
  { id: 'DRONE-01', role: 'AERIAL RECON', status: 'PATROL', coords: [39.9, 32.8], target: [39.95, 32.85], battery: 45 }
];

// Helper component to recenter map
function MapController({ center }) {
  const map = useMap();
  useEffect(() => {
    map.flyTo(center, map.getZoom(), { animate: true, duration: 1.5 });
  }, [center, map]);
  return null;
}

function App() {
  const [time, setTime] = useState(new Date());
  const [teams, setTeams] = useState(initialTeams);
  const [logs, setLogs] = useState(["SYSTEM INITIALIZED", "CONNECTING TO ROTA+ FIREBASE...", "LIVE TELEMETRY ESTABLISHED"]);
  const [sosActive, setSosActive] = useState(true);
  const [activeIncident, setActiveIncident] = useState(MOCK_INCIDENTS[0]);
  const [activeTab, setActiveTab] = useState('COMMAND');
  const [modalOpen, setModalOpen] = useState(false);

  const logsEndRef = useRef(null);

  // Real-time loop
  useEffect(() => {
    const timer = setInterval(() => {
      setTime(new Date());
      
      setTeams(prevTeams => prevTeams.map(team => {
        const speed = team.id.includes('DRONE') ? 0.005 : 0.0005;
        const dx = team.target[0] - team.coords[0];
        const dy = team.target[1] - team.coords[1];
        const dist = Math.sqrt(dx*dx + dy*dy);
        
        if (dist < 0.001) {
          return { ...team, target: [team.coords[0] + (Math.random()-0.5)*0.1, team.coords[1] + (Math.random()-0.5)*0.1] };
        }
        
        return {
          ...team,
          coords: [team.coords[0] + (dx/dist)*speed, team.coords[1] + (dy/dist)*speed],
          battery: Math.max(0, team.battery - 0.01)
        };
      }));

    }, 1000);
    return () => clearInterval(timer);
  }, []);

  const addLog = (msg) => {
    setLogs(prev => {
      const newLogs = [...prev, `[${new Date().toLocaleTimeString()}] ${msg}`];
      return newLogs.slice(-20);
    });
  };

  useEffect(() => {
    if (logsEndRef.current) {
      logsEndRef.current.scrollIntoView({ behavior: 'smooth' });
    }
  }, [logs]);

  const handleIncidentClick = (inc) => {
    setActiveIncident(inc);
    addLog(`VIEW SWITCHED TO INCIDENT: ${inc.id}`);
  };

  const handleSosResolve = () => {
    setSosActive(false);
    addLog("CRITICAL SOS RESOLVED. MED-EVAC DISPATCHED.");
  };

  return (
    <div className="flex flex-col h-screen bg-[#020617] text-slate-300 font-mono text-sm overflow-hidden">
      
      {/* TOP NAV */}
      <header className="flex justify-between items-center px-6 py-3 bg-[#0f172a]/90 backdrop-blur-md border-b border-slate-800 z-[1000]">
        <div className="flex items-center space-x-6">
          <div className="flex items-center space-x-2 cursor-pointer" onClick={() => addLog("SYSTEM REBOOT INITIATED...")}>
            <div className="w-2 h-2 rounded-full bg-cyan-400 animate-pulse"></div>
            <span className="text-white font-bold tracking-[0.2em]">ROTA<span className="text-orange-500">+</span> NEXUS</span>
          </div>
          <div className="h-4 w-px bg-slate-700"></div>
          <nav className="flex space-x-6 text-xs font-bold tracking-widest text-slate-400">
            {['COMMAND', 'INTEL', 'RESOURCES', 'LOGISTICS'].map(tab => (
              <button 
                key={tab}
                onClick={() => { setActiveTab(tab); addLog(`ACCESSED ${tab} MODULE`); }}
                className={`transition-colors ${activeTab === tab ? 'text-cyan-400 border-b-2 border-cyan-400 pb-1' : 'hover:text-white'}`}
              >
                {tab}
              </button>
            ))}
          </nav>
        </div>
        <div className="flex items-center space-x-6">
          <button onClick={() => addLog("CONNECTION TEST PING...")} className="flex items-center space-x-2 text-emerald-400 text-xs hover:text-emerald-300 cursor-pointer">
            <ShieldCheck className="w-4 h-4" />
            <span>LIVE DATA LINK ACTIVE</span>
          </button>
          <div className="text-cyan-400 font-bold tracking-widest bg-slate-900 px-3 py-1 rounded border border-slate-800">{time.toLocaleTimeString('en-US', {hour12: false})}</div>
        </div>
      </header>

      {/* MAIN WORKSPACE */}
      <div className="flex-1 relative">
        <div className="absolute inset-0 z-0">
          <MapContainer center={activeIncident.coords} zoom={7} className="w-full h-full" zoomControl={false}>
            <MapController center={activeIncident.coords} />
            <TileLayer url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png" />
            
            {/* Render Incidents */}
            {MOCK_INCIDENTS.map(inc => (
              <React.Fragment key={inc.id}>
                <Circle center={inc.coords} radius={inc.radius} pathOptions={{ color: inc.id === activeIncident.id ? '#FF3B1C' : '#FF8C00', weight: 1, fillColor: inc.id === activeIncident.id ? '#FF3B1C' : '#FF8C00', fillOpacity: 0.1 }} />
                <Marker 
                  position={inc.coords} 
                  icon={inc.type === 'ORMAN YANGINI' ? icons.FIRE : icons.EARTHQUAKE}
                  eventHandlers={{ click: () => handleIncidentClick(inc) }}
                />
              </React.Fragment>
            ))}

            {/* Render Teams */}
            {teams.map(team => (
              <React.Fragment key={team.id}>
                <Marker position={team.coords} icon={team.id.includes('DRONE') ? icons.DRONE : icons.TEAM}>
                  <Popup className="bg-[#0f172a] border border-cyan-500 text-cyan-400 p-0 rounded-none shadow-lg shadow-cyan-500/20">
                    <div className="font-bold border-b border-cyan-900 pb-1 mb-1">{team.id}</div>
                    <div className="text-xs">ROLE: {team.role}</div>
                    <div className="text-xs">STATUS: {team.status}</div>
                    <div className="text-xs">BATT: {team.battery.toFixed(1)}%</div>
                  </Popup>
                </Marker>
                <Polyline positions={[team.coords, team.target]} pathOptions={{ color: '#00E5FF', weight: 1, dashArray: '4' }} />
              </React.Fragment>
            ))}

            {/* SOS Signal */}
            {sosActive && (
              <>
                <Circle center={[38.21, 26.85]} radius={5000} pathOptions={{ color: '#ef4444', weight: 1, className: 'animate-ping' }} />
                <Marker position={[38.21, 26.85]} icon={icons.SOS} eventHandlers={{ click: () => addLog("INSPECTING SOS SIGNAL AT 38.21, 26.85") }}/>
              </>
            )}
          </MapContainer>
        </div>

        {/* LEFT PANEL */}
        <div className="absolute left-6 top-6 bottom-6 w-80 flex flex-col gap-4 z-[500] pointer-events-none">
          <div className="bg-[#020617]/90 backdrop-blur-md border border-slate-800 rounded-lg p-4 pointer-events-auto shadow-2xl transition-transform hover:scale-[1.02]">
            <h2 className="text-xs font-bold text-slate-400 mb-3 flex items-center tracking-widest"><ActivitySquare className="w-4 h-4 mr-2 text-cyan-400"/> GLOBAL TELEMETRY</h2>
            <div className="space-y-3 cursor-default">
              <div className="flex justify-between items-center border-b border-slate-800 pb-2 hover:bg-slate-800/50 p-1 rounded transition-colors">
                <span className="text-slate-500 text-xs">ACTIVE INCIDENTS</span>
                <span className="text-orange-500 font-bold">{MOCK_INCIDENTS.length}</span>
              </div>
              <div className="flex justify-between items-center border-b border-slate-800 pb-2 hover:bg-slate-800/50 p-1 rounded transition-colors">
                <span className="text-slate-500 text-xs">TEAMS IN FIELD</span>
                <span className="text-cyan-400 font-bold">{teams.length}</span>
              </div>
              <div className="flex justify-between items-center pb-1 hover:bg-slate-800/50 p-1 rounded transition-colors" onClick={() => addLog("PINGING FIREBASE API...")}>
                <span className="text-slate-500 text-xs">LIVE API STATUS</span>
                <span className="text-emerald-400 font-bold flex items-center cursor-pointer hover:text-emerald-300"><Wifi className="w-3 h-3 mr-1"/> CONNECTED</span>
              </div>
            </div>
          </div>

          <div className="flex-1 bg-[#020617]/90 backdrop-blur-md border border-slate-800 rounded-lg p-4 flex flex-col pointer-events-auto shadow-2xl">
            <h2 className="text-xs font-bold text-slate-400 mb-3 flex items-center tracking-widest"><Terminal className="w-4 h-4 mr-2 text-cyan-400"/> OPERATION LOG</h2>
            <div className="flex-1 overflow-y-auto space-y-1 text-[10px] leading-tight text-slate-400 custom-scrollbar pr-2">
              {logs.map((log, i) => (
                <div key={i} className={`font-mono ${log.includes('CRITICAL') ? 'text-red-400' : 'text-emerald-500/80'}`}>
                  <span className="opacity-50 mr-2">&gt;</span>{log}
                </div>
              ))}
              <div ref={logsEndRef} />
            </div>
          </div>
        </div>

        {/* RIGHT PANEL */}
        <div className="absolute right-6 top-6 w-[400px] z-[500] pointer-events-auto flex flex-col gap-4">
          
          {sosActive && (
            <div className="bg-red-950/90 backdrop-blur-md border border-red-500 rounded-lg p-4 shadow-[0_0_30px_rgba(239,68,68,0.3)] animate-pulse cursor-default">
              <div className="flex items-center justify-between mb-2">
                <h3 className="text-red-400 font-bold flex items-center"><AlertTriangle className="w-5 h-5 mr-2"/> CRITICAL SOS ALERT</h3>
                <span className="text-xs bg-red-500 text-white px-2 py-0.5 rounded font-bold">LIVE</span>
              </div>
              <div className="text-xs text-red-200 mb-4">
                Emergency signal detected. User unresponsive. AI Recommends immediate dispatch of TEAM-BRAVO.
              </div>
              <button 
                onClick={handleSosResolve}
                className="w-full bg-red-600 hover:bg-red-500 text-white text-xs font-bold py-3 rounded transition-colors shadow-lg shadow-red-600/50 cursor-pointer"
              >
                DISPATCH MED-EVAC & RESOLVE
              </button>
            </div>
          )}

          <div className="bg-[#020617]/95 backdrop-blur-xl border border-slate-700 rounded-lg shadow-2xl overflow-hidden">
            <div className="bg-gradient-to-r from-slate-800 to-slate-900 p-4 border-b border-slate-700">
              <div className="text-[10px] text-cyan-400 font-bold tracking-widest mb-1">FOCUSED INCIDENT</div>
              <div className="text-2xl text-white font-bold tracking-tight">{activeIncident.id}</div>
              <div className="text-sm text-slate-400 flex items-center mt-1"><MapPin className="w-3 h-3 mr-1"/> {activeIncident.type} - {activeIncident.loc}</div>
            </div>
            
            <div className="p-4 space-y-4">
              <div className="grid grid-cols-2 gap-3">
                <div className="bg-slate-900 rounded p-3 border border-slate-800">
                  <div className="text-[10px] text-slate-500 mb-1">PRIORITY</div>
                  <div className="text-orange-500 font-bold">{activeIncident.priority}</div>
                </div>
                <div className="bg-slate-900 rounded p-3 border border-slate-800">
                  <div className="text-[10px] text-slate-500 mb-1">THREAT LEVEL</div>
                  <div className="text-red-400 font-bold">{activeIncident.risk}</div>
                </div>
              </div>

              <div className="border border-indigo-500/30 bg-indigo-950/30 rounded p-3 relative overflow-hidden cursor-pointer hover:bg-indigo-900/40 transition-colors" onClick={() => addLog("AI RECALCULATING THREAT VECTORS...")}>
                <div className="absolute top-0 left-0 w-1 h-full bg-indigo-500"></div>
                <div className="text-[10px] text-indigo-400 font-bold mb-2 flex items-center">
                  <Zap className="w-3 h-3 mr-1"/> NEXUS AI INSIGHT
                </div>
                <p className="text-xs text-indigo-200/80 leading-relaxed">
                  Perimeter expanding NW. Recommend deploying aerial drops before 23:00 to protect Sector 4.
                </p>
              </div>

              <button 
                onClick={() => { setModalOpen(true); addLog(`OPENING OPERATION MODULE FOR ${activeIncident.id}`); }}
                className="w-full flex items-center justify-center bg-cyan-600/20 hover:bg-cyan-600/40 text-cyan-400 border border-cyan-500/50 rounded py-3 text-xs font-bold transition-all shadow-[0_0_15px_rgba(0,229,255,0.1)] cursor-pointer"
              >
                MANAGE OPERATIONS <ChevronRight className="w-4 h-4 ml-1"/>
              </button>
            </div>
          </div>
        </div>

        {/* MODAL */}
        {modalOpen && (
          <div className="absolute inset-0 z-[2000] bg-black/60 backdrop-blur-sm flex items-center justify-center pointer-events-auto">
            <div className="bg-slate-900 border-2 border-cyan-500/50 w-[600px] rounded-xl shadow-[0_0_50px_rgba(0,229,255,0.2)] flex flex-col">
              <div className="flex justify-between items-center p-4 border-b border-slate-800 bg-slate-950 rounded-t-xl">
                <h2 className="text-cyan-400 font-bold tracking-widest">OPERATION MODULE: {activeIncident.id}</h2>
                <button onClick={() => setModalOpen(false)} className="text-slate-500 hover:text-white transition-colors cursor-pointer"><X className="w-5 h-5"/></button>
              </div>
              <div className="p-6 space-y-6">
                <div className="bg-slate-950 border border-slate-800 p-4 rounded text-xs text-slate-400 space-y-2">
                  <p><strong className="text-white">TYPE:</strong> {activeIncident.type}</p>
                  <p><strong className="text-white">COORDINATES:</strong> {activeIncident.coords.join(', ')}</p>
                  <p><strong className="text-white">AFFECTED RADIUS:</strong> {activeIncident.radius} meters</p>
                </div>
                
                <div>
                  <h3 className="text-slate-400 text-xs font-bold mb-3">AVAILABLE TEAMS FOR DISPATCH</h3>
                  <div className="grid grid-cols-2 gap-3">
                    {teams.map(team => (
                      <div key={team.id} className="border border-slate-700 bg-slate-800/50 p-3 rounded flex justify-between items-center hover:bg-slate-800 cursor-pointer transition-colors" onClick={() => { addLog(`DISPATCHED ${team.id} TO ${activeIncident.id}`); setModalOpen(false); }}>
                        <div>
                          <div className="font-bold text-cyan-400 text-xs">{team.id}</div>
                          <div className="text-[10px] text-slate-500">{team.role}</div>
                        </div>
                        <div className="text-xs font-bold text-emerald-400 bg-emerald-400/10 px-2 py-1 rounded">DISPATCH</div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

      </div>
    </div>
  );
}

export default App;
