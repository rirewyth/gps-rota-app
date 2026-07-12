import React, { useEffect, useState } from 'react';
import { CloudLightning, Wind, Thermometer, CloudRain, Brain, Mountain, Flame, Activity } from 'lucide-react';
import axios from 'axios';

function RightSidebar() {
  const [weather, setWeather] = useState(null);

  useEffect(() => {
    // Open-Meteo API for real weather data in Ankara (Lat: 39.92, Lng: 32.85)
    const fetchWeather = async () => {
      try {
        const res = await axios.get('https://api.open-meteo.com/v1/forecast?latitude=39.92&longitude=32.85&current_weather=true&hourly=relative_humidity_2m,surface_pressure');
        if (res.data && res.data.current_weather) {
          setWeather({
            temp: res.data.current_weather.temperature,
            windSpeed: res.data.current_weather.windspeed,
            pressure: res.data.hourly.surface_pressure[0] || 1012,
            isDay: res.data.current_weather.is_day
          });
        }
      } catch (e) {
        console.error("Hava durumu çekilemedi", e);
      }
    };

    fetchWeather();
    const interval = setInterval(fetchWeather, 15 * 60 * 1000); // 15 mins
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="right-sidebar">
      {/* Weather Intelligence */}
      <div className="glass-panel">
        <h2>Canlı Hava İstihbaratı</h2>
        
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <CloudLightning size={32} className="text-yellow" />
            <div>
              <div style={{ fontSize: '1.2rem', fontWeight: 'bold' }}>Ankara Merkez</div>
              <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>Gerçek Zamanlı Veri</div>
            </div>
          </div>
          <div style={{ fontSize: '2rem', fontWeight: 'bold', color: 'var(--color-orange)' }}>
            {weather ? `${weather.temp}°` : '...'}
          </div>
        </div>

        <div className="item-row">
          <Wind size={18} className="text-blue" />
          <span style={{ flex: 1 }}>Rüzgar Hızı</span>
          <span style={{ fontWeight: 'bold' }}>{weather ? `${weather.windSpeed} km/s` : '...'}</span>
        </div>
        <div className="item-row">
          <CloudRain size={18} className="text-blue" />
          <span style={{ flex: 1 }}>Yağış Radarı</span>
          <span className="badge blue">Aktif</span>
        </div>
        <div className="item-row">
          <Thermometer size={18} className="text-red" />
          <span style={{ flex: 1 }}>Basınç</span>
          <span style={{ fontWeight: 'bold' }}>{weather ? `${weather.pressure} hPa` : '...'}</span>
        </div>
      </div>

      {/* Risk Indices */}
      <div className="glass-panel">
        <h2>Risk İndeksleri</h2>
        <div className="item-row">
          <Mountain size={18} className="text-orange" />
          <span style={{ flex: 1 }}>Çığ Riski</span>
          <div style={{ width: '60px', height: '6px', background: 'rgba(255,255,255,0.1)', borderRadius: '3px', overflow: 'hidden' }}>
            <div style={{ width: '30%', height: '100%', background: 'var(--color-yellow)' }}></div>
          </div>
        </div>
        <div className="item-row">
          <Flame size={18} className="text-red" />
          <span style={{ flex: 1 }}>Orman Yangını İndeksi</span>
          <div style={{ width: '60px', height: '6px', background: 'rgba(255,255,255,0.1)', borderRadius: '3px', overflow: 'hidden' }}>
            <div style={{ width: '85%', height: '100%', background: 'var(--color-red)' }}></div>
          </div>
        </div>
        <div className="item-row">
          <Activity size={18} className="text-blue" />
          <span style={{ flex: 1 }}>Hava Kalitesi</span>
          <span className="badge green">İyi</span>
        </div>
      </div>

      {/* AI Predictions */}
      <div className="glass-panel" style={{ flex: 1, borderColor: 'var(--color-blue)', background: 'linear-gradient(180deg, rgba(20,20,20,0.7) 0%, rgba(51,153,255,0.1) 100%)' }}>
        <h2 style={{ color: 'var(--color-blue)' }}>
          <Brain size={20} /> YZ Modülü
        </h2>
        <div style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', lineHeight: '1.5' }}>
          <p style={{ marginBottom: '8px' }}><strong style={{color: '#fff'}}>Tahmin:</strong> Kandilli ve Meteoroloji verileri analiz edildiğinde riskli bölge hareketliliği olağan sınırlar içindedir.</p>
          <p><strong style={{color: '#fff'}}>Öneri:</strong> Güncel rota paylaşım verilerine göre güvenli alanlarda yığılma yok.</p>
        </div>
      </div>
    </div>
  );
}

export default RightSidebar;
