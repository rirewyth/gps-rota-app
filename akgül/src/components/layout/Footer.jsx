import React from 'react';
import { config } from '../../data/config';

export default function Footer() {
  return (
    <footer style={{ padding: '4rem 2rem', background: 'var(--color-bg-dark)', borderTop: '1px solid #333' }}>
      <div className="container" style={{ display: 'flex', flexDirection: 'column', gap: '1rem', alignItems: 'center', textAlign: 'center' }}>
        <h3>AKGÜL TAŞIMACILIK</h3>
        <p style={{ opacity: 0.7 }}>Taşınma sürecinizi daha kolay hale getirmek için buradayız.</p>
        <div style={{ display: 'flex', gap: '1rem', marginTop: '1rem' }}>
          <a href="#hizmetler">Hizmetler</a>
          <a href="#iletisim">İletişim</a>
          <a href={config.waLink}>WhatsApp</a>
        </div>
        <p style={{ fontWeight: 'bold', fontSize: '1.2rem', marginTop: '1rem' }}>{config.phone}</p>
        <p style={{ opacity: 0.5, fontSize: '0.8rem', marginTop: '2rem' }}>KVKK / Gizlilik / Çerezler.</p>
      </div>
    </footer>
  );
}
