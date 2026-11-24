import { Component, StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.jsx'

class RootErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null, info: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, info) {
    this.setState({ error, info });
  }

  async handleClearAndReload() {
    try {
      localStorage.clear();
      sessionStorage.clear();
      if (window.indexedDB && typeof window.indexedDB.databases === 'function') {
        const dbs = await window.indexedDB.databases();
        await Promise.all(
          dbs.map((db) => db.name && new Promise((res) => {
            const req = window.indexedDB.deleteDatabase(db.name);
            req.onsuccess = req.onerror = req.onblocked = () => res();
          }))
        );
      }
    } catch (_) {}
    window.location.reload();
  }

  render() {
    if (this.state.hasError) {
      return (
        <div style={{
          minHeight: '100vh',
          backgroundColor: '#02040A',
          color: '#F8FAFC',
          padding: '32px',
          fontFamily: 'monospace',
          overflowY: 'auto'
        }}>
          <div style={{
            maxWidth: '760px',
            margin: '0 auto',
            backgroundColor: '#111827',
            border: '1px solid #ef4444',
            borderRadius: '12px',
            padding: '24px'
          }}>
            <h2 style={{ color: '#f87171', margin: '0 0 12px 0', fontSize: '18px' }}>
              ROTA+ NEXUS — Arayüz Hatası Yakalandı
            </h2>
            <pre style={{
              whiteSpace: 'pre-wrap',
              wordBreak: 'break-word',
              color: '#fecaca',
              fontSize: '13px',
              backgroundColor: '#090d16',
              padding: '12px',
              borderRadius: '8px'
            }}>
              {this.state.error?.stack || this.state.error?.message || String(this.state.error)}
            </pre>
            {this.state.info?.componentStack && (
              <pre style={{
                whiteSpace: 'pre-wrap',
                color: '#94a3b8',
                fontSize: '11px',
                marginTop: '12px',
                maxHeight: '220px',
                overflowY: 'auto'
              }}>
                {this.state.info.componentStack}
              </pre>
            )}
            <div style={{ display: 'flex', gap: '12px', marginTop: '16px' }}>
              <button
                onClick={() => this.handleClearAndReload()}
                style={{
                  backgroundColor: '#dc2626',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '8px',
                  padding: '10px 16px',
                  cursor: 'pointer',
                  fontWeight: 'bold'
                }}
              >
                Site Verisini Temizle & Yenile
              </button>
              <button
                onClick={() => window.location.reload()}
                style={{
                  backgroundColor: '#1e293b',
                  color: '#e2e8f0',
                  border: '1px solid #334155',
                  borderRadius: '8px',
                  padding: '10px 16px',
                  cursor: 'pointer'
                }}
              >
                Yenile
              </button>
            </div>
          </div>
        </div>
      );
    }
    return this.props.children;
  }
}

const rootElement = document.getElementById('root');

if (!window.__ROTA_NEXUS_ROOT__) {
  window.__ROTA_NEXUS_ROOT__ = createRoot(rootElement);
}

window.__ROTA_NEXUS_ROOT__.render(
  <StrictMode>
    <RootErrorBoundary>
      <App />
    </RootErrorBoundary>
  </StrictMode>
);
