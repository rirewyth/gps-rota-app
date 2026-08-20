import React from 'react';

export default function Header() {
  return (
    <header>
      <div className="logo">AKGÜL TAŞIMACILIK</div>
      <nav>
        <a href="#hizmetler">Hizmetler</a>
        <a href="#asansorlu-tasima">Asansörlü Taşıma</a>
        <a href="#nasil-calisir">Nasıl Çalışır?</a>
        <a href="#iletisim">İletişim</a>
        <button className="btn-primary" style={{ padding: '0.5rem 1rem', fontSize: '0.8rem' }}>WhatsApp'tan Teklif Al</button>
      </nav>
    </header>
  );
}
