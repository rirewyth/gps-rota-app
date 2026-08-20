import React from 'react';
import { config } from '../../data/config';

export default function QuoteForm() {
  const handleSubmit = (e) => {
    e.preventDefault();
    window.open(`${config.waLink}?text=${encodeURIComponent('Merhaba, teklif almak istiyorum.')}`, '_blank');
  };

  return (
    <section style={{ padding: '10rem 2rem' }}>
      <div className="container" style={{ maxWidth: '800px', margin: '0 auto' }}>
        <div className="glass-panel">
          <h2 style={{ fontSize: '3rem', marginBottom: '3rem', textAlign: 'center' }}>AKILLI TEKLİF</h2>
          <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
            <div style={{ display: 'flex', gap: '2rem', flexWrap: 'wrap' }}>
              <input type="text" placeholder="Nereden? (İl/İlçe)" className="minimal-input" style={{ flex: '1 1 200px' }} required />
              <input type="text" placeholder="Nereye? (İl/İlçe)" className="minimal-input" style={{ flex: '1 1 200px' }} required />
            </div>
            <div style={{ display: 'flex', gap: '2rem', flexWrap: 'wrap' }}>
              <select className="minimal-input" style={{ flex: '1 1 200px' }}>
                <option value="">Ev Tipi Seçin</option>
                <option>1+1</option>
                <option>2+1</option>
                <option>3+1</option>
                <option>4+1</option>
                <option>Diğer</option>
              </select>
              <input type="number" placeholder="Kat" className="minimal-input" style={{ flex: '1 1 200px' }} />
            </div>
            <select className="minimal-input">
              <option value="">Asansör Durumu</option>
              <option>Var</option>
              <option>Yok</option>
              <option>Bilmiyorum</option>
            </select>
            <input type="text" placeholder="Taşınma Tarihi (Opsiyonel)" onFocus={(e) => e.target.type = 'date'} onBlur={(e) => e.target.type = 'text'} className="minimal-input" />
            
            <div style={{ display: 'flex', gap: '2rem', flexWrap: 'wrap', marginTop: '1rem' }}>
              <input type="text" placeholder="Ad Soyad" className="minimal-input" style={{ flex: '1 1 200px' }} required />
              <input type="tel" placeholder="Telefon" className="minimal-input" style={{ flex: '1 1 200px' }} required />
            </div>
            
            <button type="submit" className="btn-primary" style={{ marginTop: '3rem', padding: '1.5rem', fontSize: '1rem', width: '100%' }}>
              WHATSAPP'TAN TEKLİF İSTE
            </button>
          </form>
        </div>
      </div>
    </section>
  );
}
