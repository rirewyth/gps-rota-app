import { HashRouter, Routes, Route, Navigate, useLocation, Link } from 'react-router-dom';
import { Home, Utensils, Droplet, TrendingUp, Calendar, Heart, User } from 'lucide-react';
import { useStore } from './store/useStore';
import { useUIStore } from './store/useUIStore';
import { AnimatePresence } from 'framer-motion';

import Onboarding from './pages/Onboarding';
import Dashboard from './pages/Dashboard';
import Meals from './pages/Meals';
import Biz from './pages/Biz';
import Progress from './pages/Progress';

import GlobalAddMenu from './components/GlobalAddMenu';
import AddMealModal from './components/AddMealModal';
import AddWeightModal from './components/AddWeightModal';

const BottomNav = () => {
  const location = useLocation();
  const isActive = (path) => location.pathname === path;
  const { setAddMenuOpen } = useUIStore();

  return (
    <div className="fixed bottom-0 left-0 right-0 bg-white border-t border-rose-100 px-6 py-3 flex justify-between items-center z-50 rounded-t-3xl shadow-[0_-4px_24px_rgba(0,0,0,0.02)]">
      <Link to="/dashboard" className={`flex flex-col items-center gap-1 ${isActive('/dashboard') ? 'text-primary' : 'text-muted'}`}>
        <Home size={24} strokeWidth={isActive('/dashboard') ? 2.5 : 2} />
        <span className="text-[10px] font-medium">Bugün</span>
      </Link>
      
      <Link to="/meals" className={`flex flex-col items-center gap-1 ${isActive('/meals') ? 'text-primary' : 'text-muted'}`}>
        <Utensils size={24} strokeWidth={isActive('/meals') ? 2.5 : 2} />
        <span className="text-[10px] font-medium">Beslenme</span>
      </Link>

      {/* Center + Button for Add Meal/Water/Weight */}
      <div className="relative -top-6">
        <button onClick={() => setAddMenuOpen(true)} className="bg-primary text-white w-14 h-14 rounded-full flex items-center justify-center shadow-lg hover:scale-105 active:scale-95 transition-all">
          <span className="text-3xl leading-none mb-1">+</span>
        </button>
      </div>

      <Link to="/progress" className={`flex flex-col items-center gap-1 ${isActive('/progress') ? 'text-primary' : 'text-muted'}`}>
        <TrendingUp size={24} strokeWidth={isActive('/progress') ? 2.5 : 2} />
        <span className="text-[10px] font-medium">İlerleme</span>
      </Link>

      <Link to="/biz" className={`flex flex-col items-center gap-1 ${isActive('/biz') ? 'text-primary' : 'text-muted'}`}>
        <Heart size={24} strokeWidth={isActive('/biz') ? 2.5 : 2} />
        <span className="text-[10px] font-medium">Biz</span>
      </Link>
    </div>
  );
};

const ProtectedRoute = ({ children }) => {
  const hasOnboarded = useStore(state => state.hasOnboarded);
  const { isAddMealOpen, isAddWeightOpen } = useUIStore();

  if (!hasOnboarded) {
    return <Navigate to="/onboarding" />;
  }
  return (
    <div className="pb-24 pt-6 px-4 max-w-md mx-auto min-h-screen relative">
      {children}
      <BottomNav />
      <GlobalAddMenu />
      
      <AnimatePresence>
        {isAddMealOpen && <AddMealModal />}
        {isAddWeightOpen && <AddWeightModal />}
      </AnimatePresence>
    </div>
  );
};

function App() {
  const hasOnboarded = useStore(state => state.hasOnboarded);

  return (
    <HashRouter>
      <div className="bg-background min-h-screen">
        <Routes>
          <Route path="/onboarding" element={!hasOnboarded ? <Onboarding /> : <Navigate to="/dashboard" />} />
          
          <Route path="/dashboard" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
          <Route path="/meals" element={<ProtectedRoute><Meals /></ProtectedRoute>} />
          <Route path="/biz" element={<ProtectedRoute><Biz /></ProtectedRoute>} />
          <Route path="/progress" element={<ProtectedRoute><Progress /></ProtectedRoute>} />
          
          <Route path="*" element={<Navigate to={hasOnboarded ? "/dashboard" : "/onboarding"} />} />
        </Routes>
      </div>
    </HashRouter>
  );
}

export default App;
