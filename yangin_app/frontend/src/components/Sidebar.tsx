import React from 'react';
import type { FireEvent } from '../App';

interface SidebarProps {
  fires: FireEvent[];
  onSelectFire: (fire: FireEvent) => void;
}

const Sidebar: React.FC<SidebarProps> = ({ fires, onSelectFire }) => {
  return (
    <div className="w-80 h-full bg-gray-800 p-4 overflow-y-auto border-r border-gray-700 flex flex-col">
      <div className="mb-6">
        <h1 className="text-xl font-bold mb-2">ORMAN YANGINI İZLEME</h1>
        <div className="bg-gray-700 p-3 rounded-lg">
          <p className="text-sm">AKTİF YANGIN: <span className="font-bold text-orange-400">{fires.length}</span></p>
          <p className="text-sm">KRİTİK: <span className="font-bold text-red-600">{fires.filter(f => f.confidence >= 85).length}</span></p>
          <p className="text-sm">YÜKSEK: <span className="font-bold text-red-400">{fires.filter(f => f.confidence >= 70 && f.confidence < 85).length}</span></p>
        </div>
      </div>
      
      <div className="flex-1 overflow-y-auto space-y-2">
        {fires.map(fire => (
          <div 
            key={fire.id || fire.external_id} 
            className="p-3 bg-gray-700 rounded-lg cursor-pointer hover:bg-gray-600 transition"
            onClick={() => onSelectFire(fire)}
          >
            <div className="flex justify-between items-start">
              <span className={`px-2 py-1 text-xs rounded font-bold ${
                fire.confidence >= 85 ? 'bg-red-900 text-red-200' :
                fire.confidence >= 70 ? 'bg-red-600 text-white' : 'bg-orange-500 text-white'
              }`}>
                {fire.confidence >= 85 ? 'KRİTİK' : fire.confidence >= 70 ? 'YÜKSEK' : 'ORTA'}
              </span>
              <span className="text-xs text-gray-400">{fire.fire_metric.toFixed(1)} MW</span>
            </div>
            <div className="mt-2 text-sm font-semibold">
              {fire.province ? `${fire.province} / ${fire.district}` : 'Konum Tespiti Bekleniyor'}
            </div>
            <div className="text-xs text-gray-400 mt-1">
              Sensör: {fire.sensor}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default Sidebar;
