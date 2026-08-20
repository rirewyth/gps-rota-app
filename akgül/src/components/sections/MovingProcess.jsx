import React from 'react';

export default function MovingProcess() {
  const steps = [
    { num: '01', title: 'Planlama', desc: 'Eşyalarınızın durumunu analiz edip size en uygun nakliye planını ve aracını belirliyoruz.' },
    { num: '02', title: 'Paketleme', desc: 'Tüm eşyalarınızı özel koruyucu malzemelerle çizilme ve darbelere karşı güvenle paketliyoruz.' },
    { num: '03', title: 'Asansörlü Taşıma', desc: 'Yüksek katlı binalarda modüler asansör sistemimizle eşyalarınızı sarsmadan indiriyoruz.' },
    { num: '04', title: 'Yeni Yuvanız', desc: 'Eşyalarınızı yeni adresinize ulaştırıp, istediğiniz odalara kurulumunu gerçekleştiriyoruz.' }
  ];

  return (
    <section id="nasil-calisir" className="scroll-section" style={{ padding: '8rem 2rem', position: 'relative' }}>
      <div className="container" style={{ maxWidth: '1000px' }}>
        <h2 className="card-animation" style={{ fontSize: 'clamp(2.5rem, 6vw, 4rem)', marginBottom: '5rem', textAlign: 'center' }}>
          SIFIR RİSK.<br />
          <span className="text-accent">MAKSİMUM GÜVEN.</span>
        </h2>
        
        <div style={{ position: 'relative' }}>
          {/* Timeline line */}
          <div style={{ position: 'absolute', left: '2rem', top: 0, bottom: 0, width: '1px', background: 'rgba(255,255,255,0.1)' }}></div>
          
          <div style={{ display: 'flex', flexDirection: 'column', gap: '4rem' }}>
            {steps.map((step, idx) => (
              <div key={idx} className="glass-panel card-animation" style={{ position: 'relative', marginLeft: '4rem', padding: '3rem' }}>
                {/* Timeline dot */}
                <div style={{ position: 'absolute', left: '-2rem', top: '50%', transform: 'translate(-50%, -50%)', width: '12px', height: '12px', borderRadius: '50%', background: 'var(--color-accent)', boxShadow: '0 0 20px var(--color-accent)' }}></div>
                
                <h3 className="text-accent" style={{ fontSize: '1.2rem', letterSpacing: '0.1em', marginBottom: '1rem' }}>{step.num}</h3>
                <h4 style={{ fontSize: '2rem', marginBottom: '1rem', fontWeight: '400' }}>{step.title}</h4>
                <p style={{ fontSize: '1.1rem', opacity: 0.7, lineHeight: '1.6' }}>{step.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
