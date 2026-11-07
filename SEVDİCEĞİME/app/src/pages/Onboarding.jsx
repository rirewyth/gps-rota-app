import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Heart } from 'lucide-react';
import { useStore } from '../store/useStore';

const Onboarding = () => {
  const [step, setStep] = useState(0);
  const { setProfile, completeOnboarding } = useStore();
  const [formData, setFormData] = useState({
    name: '',
    age: '',
    gender: '',
    height: '',
    weight: '',
    targetWeight: '',
    goal: '',
    activityLevel: ''
  });

  const nextStep = () => {
    if (step < 4) setStep(step + 1);
    else {
      setProfile(formData);
      completeOnboarding();
    }
  };

  const screens = [
    {
      id: 'welcome',
      content: (
        <div className="flex flex-col items-center justify-center text-center h-full space-y-6">
          <Heart className="text-primary w-20 h-20 fill-primary animate-pulse" />
          <h1 className="text-4xl font-serif text-primary mt-4">Hoş geldin sevdiceğim ❤️</h1>
          <p className="text-muted text-lg px-4 leading-relaxed">
            “Bu küçük site senin için hazırlandı. Çünkü kendine iyi bakmanı çok istiyorum.”
          </p>
          <button onClick={nextStep} className="btn-primary w-full max-w-[250px] mt-8">
            Başlayalım ❤️
          </button>
        </div>
      )
    },
    {
      id: 'info',
      content: (
        <div className="flex flex-col h-full justify-center space-y-6">
          <h1 className="text-3xl font-serif text-primary text-center mb-6">Seni biraz tanıyalım.</h1>
          
          <div className="space-y-4">
            <input type="text" placeholder="İsim (Bana nasıl hitap edilmesini istersin?)" className="input-field" 
              value={formData.name} onChange={e => setFormData({...formData, name: e.target.value})} />
            
            <div className="grid grid-cols-2 gap-4">
              <input type="number" placeholder="Yaş" className="input-field" 
                value={formData.age} onChange={e => setFormData({...formData, age: e.target.value})} />
              
              <select className="input-field text-text" value={formData.gender} onChange={e => setFormData({...formData, gender: e.target.value})}>
                <option value="" disabled>Cinsiyet</option>
                <option value="kadin">Kadın</option>
                <option value="erkek">Erkek</option>
              </select>
            </div>

            <div className="grid grid-cols-3 gap-4">
              <input type="number" placeholder="Boy (cm)" className="input-field" 
                value={formData.height} onChange={e => setFormData({...formData, height: e.target.value})} />
              <input type="number" placeholder="Kilo (kg)" className="input-field" 
                value={formData.weight} onChange={e => setFormData({...formData, weight: e.target.value})} />
              <input type="number" placeholder="Hedef (kg)" className="input-field" 
                value={formData.targetWeight} onChange={e => setFormData({...formData, targetWeight: e.target.value})} />
            </div>
          </div>
          
          <button onClick={nextStep} className="btn-primary w-full mt-8" disabled={!formData.name || !formData.weight}>
            Devam Et ❤️
          </button>
        </div>
      )
    },
    {
      id: 'goal',
      content: (
        <div className="flex flex-col h-full justify-center space-y-6">
          <h1 className="text-3xl font-serif text-primary text-center mb-6">Bugünkü hedefin ne?</h1>
          <div className="space-y-3">
            {[
              { id: 'lose', icon: '⚖️', label: 'Kilo vermek' },
              { id: 'gain', icon: '💪', label: 'Kilo almak' },
              { id: 'maintain', icon: '❤️', label: 'Kilo korumak' },
              { id: 'muscle', icon: '🏋️', label: 'Kas kütlesi artırmak' }
            ].map(g => (
              <button key={g.id} 
                onClick={() => setFormData({...formData, goal: g.id})}
                className={`w-full p-4 rounded-xl border text-left flex items-center gap-3 transition-all ${
                  formData.goal === g.id ? 'border-primary bg-primary/5 shadow-md' : 'border-rose-100 bg-white hover:border-primary/30'
                }`}>
                <span className="text-2xl">{g.icon}</span>
                <span className="font-medium text-lg">{g.label}</span>
              </button>
            ))}
          </div>
          <button onClick={nextStep} className="btn-primary w-full mt-8" disabled={!formData.goal}>
            Devam Et
          </button>
        </div>
      )
    },
    {
      id: 'activity',
      content: (
        <div className="flex flex-col h-full justify-center space-y-6">
          <h1 className="text-3xl font-serif text-primary text-center mb-6">Günlük hareketin nasıl?</h1>
          <div className="space-y-3">
            {[
              { id: 'sedentary', label: 'Hareketsiz' },
              { id: 'light', label: 'Az hareketli' },
              { id: 'moderate', label: 'Orta aktif' },
              { id: 'active', label: 'Aktif' },
              { id: 'very_active', label: 'Çok aktif' }
            ].map(a => (
              <button key={a.id} 
                onClick={() => setFormData({...formData, activityLevel: a.id})}
                className={`w-full p-4 rounded-xl border text-center transition-all ${
                  formData.activityLevel === a.id ? 'border-primary bg-primary/5 shadow-md text-primary font-medium' : 'border-rose-100 bg-white'
                }`}>
                {a.label}
              </button>
            ))}
          </div>
          <button onClick={nextStep} className="btn-primary w-full mt-8" disabled={!formData.activityLevel}>
            Devam Et
          </button>
        </div>
      )
    },
    {
      id: 'finish',
      content: (
        <div className="flex flex-col items-center justify-center text-center h-full space-y-6">
          <motion.div 
            initial={{ scale: 0 }}
            animate={{ scale: 1 }}
            transition={{ type: "spring", stiffness: 260, damping: 20 }}
          >
            <Heart className="text-primary w-32 h-32 fill-primary" />
          </motion.div>
          <p className="text-2xl font-serif text-primary mt-6 leading-relaxed">
            “Tamamdır sevdiceğim. Bundan sonra sana biraz daha iyi bakacağız. ❤️”
          </p>
          <button onClick={nextStep} className="btn-primary w-full max-w-[250px] mt-8">
            Beni Günlüğüme Götür
          </button>
        </div>
      )
    }
  ];

  return (
    <div className="min-h-screen flex flex-col justify-center px-6 py-12 max-w-md mx-auto relative overflow-hidden bg-background">
      <AnimatePresence mode="wait">
        <motion.div
          key={step}
          initial={{ opacity: 0, x: 20 }}
          animate={{ opacity: 1, x: 0 }}
          exit={{ opacity: 0, x: -20 }}
          transition={{ duration: 0.3 }}
          className="h-full flex-1"
        >
          {screens[step].content}
        </motion.div>
      </AnimatePresence>
    </div>
  );
};

export default Onboarding;
