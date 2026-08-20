import React from 'react';

export default function ServiceStory() {
  return (
    <section id="hizmetler" style={{ padding: '8rem 2rem', background: 'var(--color-bg-dark)' }}>
      <div className="container">
        <h2 style={{ fontSize: '3rem', marginBottom: '4rem' }}>HİZMETLERİMİZ</h2>
        <div style={{ display: 'grid', gap: '2rem', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))' }}>
          <div className="glass-panel card-animation" style={{ padding: '3rem' }}>
            <h3 className="text-accent" style={{ fontSize: '1rem', letterSpacing: '0.1em' }}>01 EVDEN EVE</h3>
            <h4 style={{ fontSize: '1.8rem', marginTop: '1rem' }}>EVİNİZDEN YENİ YUVANIZA.</h4>
          </div>
          <div className="glass-panel card-animation" style={{ padding: '3rem' }}>
            <h3 className="text-accent" style={{ fontSize: '1rem', letterSpacing: '0.1em' }}>02 ASANSÖRLÜ TAŞIMACILIK</h3>
            <h4 style={{ fontSize: '1.8rem', marginTop: '1rem' }}>YÜKSEK KATLAR İÇİN AKILLI ÇÖZÜM.</h4>
          </div>
          <div className="glass-panel card-animation" style={{ padding: '3rem' }}>
            <h3 className="text-accent" style={{ fontSize: '1rem', letterSpacing: '0.1em' }}>03 ŞEHİR İÇİ TAŞIMACILIK</h3>
            <h4 style={{ fontSize: '1.8rem', marginTop: '1rem' }}>GÜVENLİ VE HIZLI NAKLİYE.</h4>
          </div>
        </div>
      </div>
    </section>
  );
}
