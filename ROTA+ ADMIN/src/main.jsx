import { Component, StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.jsx'

class RootErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }
  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }
  render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen bg-[#02040A] text-white p-8 font-mono">
          <div className="max-w-xl mx-auto border border-red-500 bg-slate-900 p-6 rounded-xl">
            <h2 className="text-red-400 font-bold mb-2">ROTA+ ADMIN Hata Yakalandı</h2>
            <pre className="text-xs text-red-200 whitespace-pre-wrap">
              {this.state.error?.message || String(this.state.error)}
            </pre>
            <button
              onClick={() => window.location.reload()}
              className="mt-4 px-4 py-2 bg-orange-600 text-white rounded-lg text-xs font-bold cursor-pointer"
            >
              Yenile
            </button>
          </div>
        </div>
      );
    }
    return this.props.children;
  }
}

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <RootErrorBoundary>
      <App />
    </RootErrorBoundary>
  </StrictMode>
);
