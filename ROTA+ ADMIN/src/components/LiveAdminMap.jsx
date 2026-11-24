import React, { useEffect, useState } from 'react';
import { MapContainer, TileLayer, CircleMarker, Circle, Popup, useMap, useMapEvents } from 'react-leaflet';
import { Copy, Flame, ShieldCheck, AlertOctagon } from 'lucide-react';

function MapController({ focusCoords, onPickPoint }) {
  const map = useMap();
  useEffect(() => {
    if (Array.isArray(focusCoords) && focusCoords.length === 2) {
      map.flyTo(focusCoords, 15, { duration: 0.8 });
    }
  }, [focusCoords, map]);

  useMapEvents({
    click(e) {
      onPickPoint([e.latlng.lat, e.latlng.lng]);
    },
  });
  return null;
}

export default function LiveAdminMap({
  users = [],
  fires = [],
  disasterReports = [],
  safeZones = [],
  hazardZones = [],
  focusCoords = null,
  onUseForFire = () => {},
  onUseForSafeZone = () => {},
  onUseForHazardZone = () => {}
}) {
  const [showOperators, setShowOperators] = useState(true);
  const [onlySos, setOnlySos] = useState(false);
  const [showFires, setShowFires] = useState(true);
  const [showReports, setShowReports] = useState(true);
  const [showZones, setShowZones] = useState(true);
  const [mapStyle, setMapStyle] = useState('DARK');
  const [pickedPoint, setPickedPoint] = useState(null);
  const [copied, setCopied] = useState(false);

  const tileUrl =
    mapStyle === 'TOPO'
      ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}'
      : mapStyle === 'SAT'
        ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
        : 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}';

  const userMarkers = users
    .map((u) => {
      const lat = parseFloat(u.lat ?? u.last_lat);
      const lng = parseFloat(u.lng ?? u.last_lng);
      if (isNaN(lat) || isNaN(lng) || (lat === 0 && lng === 0)) return null;
      const isSos = Boolean(u.is_sos || u.sos);
      if (onlySos && !isSos) return null;
      return {
        id: u.id,
        name: u.name || u.ad || u.email || 'Operatör',
        lat,
        lng,
        isSos,
        isOnline: Boolean(u.is_online),
      };
    })
    .filter(Boolean);

  const fireMarkers = fires
    .map((f) => {
      const lat = parseFloat(f.lat);
      const lng = parseFloat(f.lng);
      if (isNaN(lat) || isNaN(lng)) return null;
      return { ...f, lat, lng };
    })
    .filter(Boolean);

  const reportMarkers = disasterReports
    .map((r) => {
      const lat = parseFloat(r.lat);
      const lng = parseFloat(r.lng);
      if (isNaN(lat) || isNaN(lng)) return null;
      return { ...r, lat, lng };
    })
    .filter(Boolean);

  const handleCopy = () => {
    if (!pickedPoint) return;
    navigator.clipboard?.writeText(`${pickedPoint[0].toFixed(5)}, ${pickedPoint[1].toFixed(5)}`);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="space-y-2.5">
      {/* Layer Filters + Picked Coordinate Bar */}
      <div className="flex flex-wrap items-center justify-between gap-2 bg-[#040814] border border-[#00E5FF]/25 p-2.5">
        <div className="flex flex-wrap gap-1.5">
          <FilterBtn active={showOperators} label="OPERATÖRLER" onClick={() => setShowOperators(!showOperators)} />
          <FilterBtn active={onlySos} label="SADECE SOS" danger onClick={() => setOnlySos(!onlySos)} />
          <FilterBtn active={showFires} label="YANGINLAR" onClick={() => setShowFires(!showFires)} />
          <FilterBtn active={showReports} label="İHBARLAR" onClick={() => setShowReports(!showReports)} />
          <FilterBtn active={showZones} label="BÖLGELER" onClick={() => setShowZones(!showZones)} />
          <span className="border-l border-slate-700 mx-1" />
          <FilterBtn active={mapStyle === 'DARK'} label="KOYU" onClick={() => setMapStyle('DARK')} />
          <FilterBtn active={mapStyle === 'TOPO'} label="TOPO" onClick={() => setMapStyle('TOPO')} />
          <FilterBtn active={mapStyle === 'SAT'} label="UYDU" onClick={() => setMapStyle('SAT')} />
        </div>

        {pickedPoint ? (
          <div className="flex flex-wrap items-center gap-2 text-xs">
            <span className="text-[#00E5FF]">
              SEÇİLEN: {pickedPoint[0].toFixed(5)}, {pickedPoint[1].toFixed(5)}
            </span>
            <button
              onClick={handleCopy}
              className="px-2 py-1 border border-slate-700 text-slate-200 text-[10px] flex items-center gap-1 cursor-pointer"
            >
              <Copy className="w-3 h-3" /> {copied ? 'KOPYALANDI' : 'KOPYALA'}
            </button>
            <button
              onClick={() => onUseForFire(pickedPoint)}
              className="px-2 py-1 border border-[#FF4D26]/60 bg-[#FF4D26]/20 text-[#FF4D26] text-[10px] font-bold flex items-center gap-1 cursor-pointer"
            >
              <Flame className="w-3 h-3" /> YANGIN EKLE
            </button>
            <button
              onClick={() => onUseForSafeZone(pickedPoint)}
              className="px-2 py-1 border border-emerald-500/60 bg-emerald-950/60 text-emerald-300 text-[10px] font-bold flex items-center gap-1 cursor-pointer"
            >
              <ShieldCheck className="w-3 h-3" /> TOPLANMA
            </button>
            <button
              onClick={() => onUseForHazardZone(pickedPoint)}
              className="px-2 py-1 border border-red-500/60 bg-red-950/60 text-red-300 text-[10px] font-bold flex items-center gap-1 cursor-pointer"
            >
              <AlertOctagon className="w-3 h-3" /> RİSKLİ BÖLGE
            </button>
          </div>
        ) : (
          <span className="text-[10px] text-slate-500">Koordinat almak için haritaya tıklayın</span>
        )}
      </div>

      <div className="h-[64vh] w-full overflow-hidden border border-[#00E5FF]/30 bg-[#02050D] shadow-[0_0_25px_rgba(0,229,255,0.08)]">
        <MapContainer
          center={[39.0, 35.0]}
          zoom={6}
          style={{ height: '100%', width: '100%', background: '#050A14' }}
        >
          <TileLayer
            key={mapStyle}
            url={tileUrl}
            attribution="&copy; Esri"
          />
          <MapController focusCoords={focusCoords} onPickPoint={setPickedPoint} />

          {showOperators &&
            userMarkers.map((u) => (
              <CircleMarker
                key={`u-${u.id}`}
                center={[u.lat, u.lng]}
                radius={u.isSos ? 10 : 6}
                pathOptions={{
                  color: u.isSos ? '#ef4444' : u.isOnline ? '#22c55e' : '#38bdf8',
                  fillColor: u.isSos ? '#ef4444' : u.isOnline ? '#22c55e' : '#38bdf8',
                  fillOpacity: 0.8,
                }}
              >
                <Popup>
                  <div className="text-xs font-mono text-slate-900">
                    <strong>{u.name}</strong>
                    <div>{u.isSos ? '🚨 SOS AKTİF' : u.isOnline ? '🟢 Çevrimiçi' : '🔵 Son Konum'}</div>
                    <div>{u.lat.toFixed(5)}, {u.lng.toFixed(5)}</div>
                  </div>
                </Popup>
              </CircleMarker>
            ))}

          {showFires &&
            fireMarkers.map((f) => (
              <CircleMarker
                key={`f-${f.id}`}
                center={[f.lat, f.lng]}
                radius={9}
                pathOptions={{
                  color: '#f97316',
                  fillColor: '#ea580c',
                  fillOpacity: 0.85,
                }}
              >
                <Popup>
                  <div className="text-xs font-mono text-slate-900">
                    <strong>🔥 {f.name || 'Yangın'}</strong>
                    <div>Durum: {f.status || 'Aktif'}</div>
                    {f.team && <div>Ekip: {f.team}</div>}
                    {f.description && <div>{f.description}</div>}
                  </div>
                </Popup>
              </CircleMarker>
            ))}

          {showReports &&
            reportMarkers.map((r) => (
              <CircleMarker
                key={`r-${r.id}`}
                center={[r.lat, r.lng]}
                radius={8}
                pathOptions={{
                  color: '#facc15',
                  fillColor: '#eab308',
                  fillOpacity: 0.85,
                }}
              >
                <Popup>
                  <div className="text-xs font-mono text-slate-900">
                    <strong>⚠️ {r.disasterType || 'İhbar'} ({r.status || 'YENİ'})</strong>
                    <div>{r.reporterName} • {r.reporterPhone}</div>
                    {r.fullAddress && <div>{r.fullAddress}</div>}
                    <div>{r.summary}</div>
                  </div>
                </Popup>
              </CircleMarker>
            ))}

          {showZones &&
            safeZones
              .filter((z) => !isNaN(parseFloat(z.lat)) && !isNaN(parseFloat(z.lng)))
              .map((z) => (
                <CircleMarker
                  key={`sz-${z.id}`}
                  center={[Number(z.lat), Number(z.lng)]}
                  radius={9}
                  pathOptions={{ color: '#10b981', fillColor: '#10b981', fillOpacity: 0.75 }}
                >
                  <Popup>
                    <div className="text-xs font-mono text-slate-900">
                      <strong>🟢 {z.name}</strong>
                      <div>{z.category}</div>
                      {z.capacity && <div>Kapasite: {z.capacity}</div>}
                    </div>
                  </Popup>
                </CircleMarker>
              ))}

          {showZones &&
            hazardZones
              .filter((z) => !isNaN(parseFloat(z.lat)) && !isNaN(parseFloat(z.lng)))
              .map((z) => (
                <Circle
                  key={`hz-${z.id}`}
                  center={[Number(z.lat), Number(z.lng)]}
                  radius={Number(z.radiusMeters) || 500}
                  pathOptions={{ color: '#ef4444', fillColor: '#ef4444', fillOpacity: 0.25 }}
                >
                  <Popup>
                    <div className="text-xs font-mono text-slate-900">
                      <strong>⛔ {z.name}</strong>
                      <div>{z.hazardType} ({z.radiusMeters || 500}m)</div>
                      {z.note && <div>{z.note}</div>}
                    </div>
                  </Popup>
                </Circle>
              ))}
        </MapContainer>
      </div>
    </div>
  );
}

function FilterBtn({ active, label, danger, onClick }) {
  return (
    <button
      onClick={onClick}
      className={`px-2.5 py-1 text-[10px] font-bold border cursor-pointer ${
        active
          ? danger
            ? 'bg-red-950 border-red-500 text-red-300'
            : 'bg-[#00E5FF]/15 border-[#00E5FF] text-[#00E5FF]'
          : 'bg-[#02050D] border-slate-700 text-slate-500'
      }`}
    >
      {label}
    </button>
  );
}
