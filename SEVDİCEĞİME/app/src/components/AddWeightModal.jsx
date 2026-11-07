import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { X, Scale } from 'lucide-react';
import { useStore } from '../store/useStore';
import { useUIStore } from '../store/useUIStore';

const AddWeightModal = () => {
  const { addWeight, weightHistory, profile } = useStore();
  const { setAddWeightOpen } = useUIStore();
  
  const initialWeight = weightHistory.length > 0 
    ? weightHistory[weightHistory.length - 1].weight 
    : profile.weight;

  const [weight, setWeight] = useState(initialWeight || '');

  const handleSubmit = (e) => {
    e.preventDefault();
    if(weight) {
      addWeight(Number(weight), new Date().toISOString().split('T')[0]);
      setAddWeightOpen(false);
    }
  };

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/40 px-4 backdrop-blur-sm">
      <motion.div 
        initial={{ opacity: 0, y: 50, scale: 0.9 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        exit={{ opacity: 0, y: 50, scale: 0.9 }}
        className="bg-background rounded-3xl p-6 w-full max-w-sm shadow-2xl"
      >
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-2xl font-serif text-primary flex items-center gap-2">
            <Scale className="text-primary" /> Tartı Zamanı
          </h2>
          <button onClick={() => setAddWeightOpen(false)} className="p-2 bg-rose-50 rounded-full text-primary hover:bg-rose-100 transition"><X size={20} /></button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6 text-center">
          <p className="text-muted text-sm px-2">
            Bugün kaç kilosun sevdiceğim? Değişimler normaldir, sayılara çok takılmıyoruz. ❤️
          </p>
          
          <div>
            <div className="flex items-end justify-center gap-2">
              <input required type="number" step="0.1" className="input-field text-4xl font-bold text-center w-32 h-20 bg-white" 
                value={weight} onChange={e => setWeight(e.target.value)} autoFocus />
              <span className="text-xl font-medium text-muted mb-4">kg</span>
            </div>
          </div>

          <button type="submit" className="btn-primary w-full mt-4">
            Kendimi Kaydet ❤️
          </button>
        </form>
      </motion.div>
    </div>
  );
};

export default AddWeightModal;
