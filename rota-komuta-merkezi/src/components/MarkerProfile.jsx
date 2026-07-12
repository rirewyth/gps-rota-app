import React from 'react';
import { Activity, Battery, Compass, Droplet, Navigation, Phone, ShieldAlert, User } from 'lucide-react';

function MarkerProfile({ user }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: '12px', borderBottom: '1px solid rgba(255,255,255,0.1)', paddingBottom: '8px' }}>
        <div style={{
          width: '40px', height: '40px', borderRadius: '50%', backgroundColor: 'rgba(255,255,255,0.1)',
          display: 'flex', justifyContent: 'center', alignItems: 'center'
        }}>
          <User size={24} />
        </div>
        <div>
          <h3 style={{ margin: 0, color: '#fff', fontSize: '1rem', textTransform: 'none' }}>{user.name || 'Bilinmeyen Kullanıcı'}</h3>
          <span className={`badge ${(user.status === 'sos') ? 'red' : (user.status === 'safe') ? 'green' : (user.status === 'tracking') ? 'orange' : ''}`} style={{ display: 'inline-block', marginTop: '4px' }}>
            {(user.status || 'safe').toUpperCase()}
          </span>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px', fontSize: '0.85rem' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
          <Battery size={14} className={(user.battery && user.battery < 20) ? 'text-red' : 'text-green'} /> %{user.battery || '?'}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
          <Activity size={14} className="text-blue" /> {user.lastSeen || 'Bilinmiyor'}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
          <Droplet size={14} className="text-red" /> Kan: {user.bloodType || '?'}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
          <Navigation size={14} className="text-orange" /> Hız: 0km/h
        </div>
      </div>

      {user.rescueNotes && (
        <div style={{ marginTop: '8px', padding: '8px', backgroundColor: 'rgba(255,51,51,0.1)', border: '1px solid rgba(255,51,51,0.3)', borderRadius: '4px', fontSize: '0.8rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '4px', color: 'var(--color-red)', fontWeight: 'bold', marginBottom: '4px' }}>
            <ShieldAlert size={14} /> Kurtarma Notu
          </div>
          {user.rescueNotes}
        </div>
      )}

      <div style={{ display: 'flex', gap: '8px', marginTop: '8px' }}>
        <button style={{ flex: 1, padding: '6px', background: 'var(--color-orange)', border: 'none', borderRadius: '4px', color: '#fff', fontWeight: 'bold', cursor: 'pointer' }}>
          Profile Git
        </button>
        <button style={{ padding: '6px', background: 'rgba(255,255,255,0.1)', border: 'none', borderRadius: '4px', color: '#fff', cursor: 'pointer' }}>
          <Phone size={16} />
        </button>
      </div>
    </div>
  );
}

export default MarkerProfile;
