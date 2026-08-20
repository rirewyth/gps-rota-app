import React from 'react';

export default function LoadingScreen() {
  return (
    <div className="loading-screen">
      <h2 style={{ fontSize: '2rem', letterSpacing: '0.1em' }}>AKGÜL TAŞIMACILIK</h2>
      <p style={{ marginTop: '1rem', opacity: 0.5, letterSpacing: '0.2em', fontSize: '0.8rem' }}>LOADING VEHICLE EXPERIENCE</p>
      <div style={{ marginTop: '2rem', width: '200px', height: '2px', background: '#333', overflow: 'hidden' }}>
        <div style={{ width: '100%', height: '100%', background: 'var(--color-accent)', animation: 'loading 2.5s ease-out forwards' }}></div>
      </div>
      <style>{`
        @keyframes loading {
          0% { transform: translateX(-100%); }
          100% { transform: translateX(0); }
        }
      `}</style>
    </div>
  );
}
