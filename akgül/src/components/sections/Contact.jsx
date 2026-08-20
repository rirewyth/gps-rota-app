import React from 'react';
import { Phone, MapPin, Mail, ArrowUpRight } from 'lucide-react';
import { config } from '../../data/config';

export default function Contact() {
  return (
    <section id="iletisim" className="scroll-section" style={{ padding: '8rem 2rem', borderTop: '1px solid rgba(255,255,255,0.05)' }}>
      <div className="container">
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '4rem' }}>
          
          <div className="card-animation">
            <h2 style={{ fontSize: 'clamp(2rem, 5vw, 4rem)', marginBottom: '2rem' }}>BİZE ULAŞIN</h2>
            <p style={{ opacity: 0.7, fontSize: '1.2rem', marginBottom: '3rem', maxWidth: '400px' }}>
              Sorunsuz ve güvenilir taşımacılık hizmeti için bizimle hemen iletişime geçin.
            </p>
            
            <a href={`tel:${config.phone.replace(/\s+/g, '')}`} className="btn-primary" style={{ display: 'inline-flex', alignItems: 'center', gap: '1rem', padding: '1.5rem 3rem', fontSize: '1.2rem' }}>
              <Phone size={24} />
              {config.phone}
            </a>
          </div>

          <div className="card-animation" style={{ display: 'flex', flexDirection: 'column', gap: '2rem', justifyContent: 'center' }}>
            <div className="glass-panel" style={{ padding: '2rem', display: 'flex', alignItems: 'flex-start', gap: '1.5rem' }}>
              <MapPin className="text-accent" size={32} />
              <div>
                <h4 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>Merkez Ofis</h4>
                <p style={{ opacity: 0.7 }}>Akgül Taşımacılık, Merkez / Türkiye</p>
              </div>
            </div>
            
            <a href={config.waLink} target="_blank" rel="noreferrer" className="glass-panel" style={{ padding: '2rem', display: 'flex', alignItems: 'flex-start', gap: '1.5rem', transition: 'all 0.3s' }}>
              <Mail className="text-accent" size={32} />
              <div style={{ flex: 1 }}>
                <h4 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>WhatsApp Destek</h4>
                <p style={{ opacity: 0.7 }}>Anında fiyat teklifi alın</p>
              </div>
              <ArrowUpRight size={24} style={{ opacity: 0.5 }} />
            </a>
          </div>
          
        </div>
      </div>
    </section>
  );
}
