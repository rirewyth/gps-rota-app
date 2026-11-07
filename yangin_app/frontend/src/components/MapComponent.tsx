import React, { useEffect, useRef } from 'react';
import { Map as MapLibreMap, Marker } from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';
import type { FireEvent } from '../App';

interface MapComponentProps {
  fires: FireEvent[];
  selectedFire: FireEvent | null;
  onSelectFire: (fire: FireEvent) => void;
}

const MapComponent: React.FC<MapComponentProps> = ({ fires, selectedFire, onSelectFire }) => {
  const mapContainer = useRef<HTMLDivElement>(null);
  const map = useRef<MapLibreMap | null>(null);
  const markers = useRef<Marker[]>([]);

  useEffect(() => {
    if (map.current) return; // initialize map only once
    if (mapContainer.current) {
      map.current = new MapLibreMap({
        container: mapContainer.current,
        style: {
          version: 8,
          sources: {
            osm: {
              type: 'raster',
              tiles: [
                'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
                'https://b.tile.openstreetmap.org/{z}/{x}/{y}.png',
                'https://c.tile.openstreetmap.org/{z}/{x}/{y}.png'
              ],
              tileSize: 256,
              attribution: '&copy; OpenStreetMap Contributors'
            }
          },
          layers: [
            {
              id: 'osm',
              type: 'raster',
              source: 'osm'
            }
          ]
        },
        center: [35.2433, 38.9637], // Center of Turkey
        zoom: 5
      });
    }
  }, []);

  useEffect(() => {
    if (!map.current) return;

    // Clear existing markers
    markers.current.forEach(marker => marker.remove());
    markers.current = [];

    // Add new markers
    fires.forEach(fire => {
      let color = '#FFA500'; // ACTIVE
      if (fire.confidence >= 85) color = '#8B0000'; // Critical
      else if (fire.confidence >= 70) color = '#FF0000'; // High

      const marker = new Marker({ color })
        .setLngLat([fire.longitude, fire.latitude])
        .addTo(map.current!);

      marker.getElement().addEventListener('click', () => {
        onSelectFire(fire);
      });

      markers.current.push(marker);
    });
  }, [fires]);

  useEffect(() => {
    if (selectedFire && map.current) {
      map.current.flyTo({
        center: [selectedFire.longitude, selectedFire.latitude],
        zoom: 12,
        duration: 2000
      });
    }
  }, [selectedFire]);

  return <div ref={mapContainer} className="absolute inset-0" style={{ width: '100%', height: '100%' }} />;
};

export default MapComponent;
