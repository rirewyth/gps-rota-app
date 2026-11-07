import React from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Utensils, Droplet, Scale, X } from 'lucide-react';
import { useUIStore } from '../store/useUIStore';
import { useStore } from '../store/useStore';

const GlobalAddMenu = () => {
  const { isAddMenuOpen, setAddMenuOpen, setAddMealOpen, setAddWeightOpen } = useUIStore();
  const { addWater } = useStore();

  const handleAction = (action) => {
    setAddMenuOpen(false);
    setTimeout(() => {
      if (action === 'meal') setAddMealOpen(true);
      if (action === 'weight') setAddWeightOpen(true);
      if (action === 'water') {
        // Hızlı su ekleme
        addWater(0.25);
      }
    }, 200);
  };

  return (
    <AnimatePresence>
      {isAddMenuOpen && (
        <>
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={() => setAddMenuOpen(false)}
            className="fixed inset-0 bg-black/40 backdrop-blur-[2px] z-[80]"
          />
          <motion.div
            initial={{ opacity: 0, y: 100, scale: 0.9 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 100, scale: 0.9 }}
            className="fixed bottom-28 left-0 right-0 mx-auto w-64 bg-white rounded-3xl p-4 shadow-2xl z-[90] border border-rose-100 flex flex-col gap-3"
          >
            <button onClick={() => handleAction('meal')} className="flex items-center gap-3 p-3 rounded-xl hover:bg-rose-50 transition text-text font-medium">
              <div className="bg-primary/10 p-2 rounded-full text-primary"><Utensils size={20} /></div>
              Yemek Ekle
            </button>
            <button onClick={() => handleAction('water')} className="flex items-center gap-3 p-3 rounded-xl hover:bg-blue-50 transition text-text font-medium">
              <div className="bg-blue-100 p-2 rounded-full text-blue-500"><Droplet size={20} /></div>
              +250ml Su İçtim
            </button>
            <button onClick={() => handleAction('weight')} className="flex items-center gap-3 p-3 rounded-xl hover:bg-amber-50 transition text-text font-medium">
              <div className="bg-amber-100 p-2 rounded-full text-amber-600"><Scale size={20} /></div>
              Kilo Kaydet
            </button>
            
            <div className="absolute -bottom-3 left-1/2 -translate-x-1/2 w-6 h-6 bg-white rotate-45 border-r border-b border-rose-100"></div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
};

export default GlobalAddMenu;
