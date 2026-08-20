import React from 'react';

export default function ScrollStory() {
  const scenes = [
    { id: 1, title: 'HER TAŞINMA İYİ BİR PLANLA BAŞLAR.' },
    { id: 2, title: 'YOLA ÇIKIYORUZ.' },
    { id: 3, title: 'YÜKSEK KATLAR İŞİ ZORLAŞTIRMASIN.' },
    { id: 4, title: 'YÜKSEK KATLAR ARTIK ENGEL DEĞİL.' },
    { id: 5, title: 'HER ŞEYİN YERİ BELLİ.' },
    { id: 6, title: 'YENİ ADRESE DOĞRU.' },
    { id: 7, title: 'TAŞINMA TAMAMLANDI.' }
  ];

  return (
    <div className="story-container">
      {scenes.map((scene, i) => (
        <section key={scene.id} className="scroll-section" style={{ padding: '0 2rem' }}>
          <div className="container" style={{ marginTop: 'auto', marginBottom: '10vh' }}>
            <div className="glass-panel card-animation" style={{ maxWidth: '800px' }}>
              <h2 style={{ fontSize: 'clamp(2rem, 5vw, 3.5rem)', textTransform: 'uppercase', marginBottom: '1rem' }}>
                {scene.title}
              </h2>
              {scene.id === 4 && (
                <div style={{ marginTop: '2rem' }}>
                  <p style={{ opacity: 0.8, marginBottom: '1.5rem', fontSize: '1.2rem' }}>Asansörlü taşımacılık yüksek katlarda sıfır risk sağlar.</p>
                  <button className="btn-secondary">BİLGİ AL</button>
                </div>
              )}
            </div>
          </div>
        </section>
      ))}
    </div>
  );
}
