import React from 'react';

export default function Hero() {
  const scrollToContact = () => {
    document.getElementById('iletisim').scrollIntoView({ behavior: 'smooth' });
  };

  return (
    <section className="scroll-section" style={{ minHeight: '100vh', display: 'flex', alignItems: 'center' }}>
      <div className="container">
        <div className="hero-content card-animation" style={{ maxWidth: '1000px' }}>
          <h1 className="hero-title" style={{ fontSize: 'clamp(4rem, 10vw, 8rem)', fontWeight: '300', letterSpacing: '-0.04em', lineHeight: '0.9' }}>
            SİZ <span className="text-accent" style={{ fontStyle: 'italic' }}>YERLEŞİN.</span><br />
            GERİSİNİ<br />
            <strong style={{ fontWeight: '700' }}>BİZE BIRAKIN.</strong>
          </h1>
          <p className="hero-subtitle" style={{ fontSize: '1.5rem', opacity: 0.6, maxWidth: '600px', marginTop: '2rem' }}>
            Akgül Taşımacılık ile modern, güvenilir ve stressiz nakliye deneyimi. Evden eve asansörlü profesyonel çözümler.
          </p>
          <div className="cta-group" style={{ marginTop: '3rem' }}>
            <button className="btn-primary" onClick={scrollToContact} style={{ padding: '1.2rem 3rem', fontSize: '1rem' }}>
              HEMEN TEKLİF AL
            </button>
            <a href="#hizmetler" className="btn-secondary" style={{ padding: '1.2rem 3rem', fontSize: '1rem' }}>
              HİZMETLERİ İNCELE
            </a>
          </div>
        </div>
      </div>
      
      {/* Scroll indicator */}
      <div style={{ position: 'absolute', bottom: '2rem', left: '2rem', opacity: 0.5, fontSize: '0.8rem', letterSpacing: '0.2em' }} className="card-animation">
        AŞAĞI KAYDIR ↓
      </div>
    </section>
  );
}
