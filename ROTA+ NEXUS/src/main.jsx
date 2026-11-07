import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.jsx'

const rootElement = document.getElementById('root');

if (!window.__ROTA_NEXUS_ROOT__) {
  window.__ROTA_NEXUS_ROOT__ = createRoot(rootElement);
}

window.__ROTA_NEXUS_ROOT__.render(
  <StrictMode>
    <App />
  </StrictMode>
);
