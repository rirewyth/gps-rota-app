import React, { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Search } from 'lucide-react';
import { useStore } from '../store/useStore';
import { useUIStore } from '../store/useUIStore';
import { getFoodSuggestions, foodDatabase } from '../data/foodDatabase';

const AddMealModal = () => {
  const { addMeal } = useStore();
  const { setAddMealOpen } = useUIStore();
  
  const [mealType, setMealType] = useState('Kahvaltı');
  const [foodName, setFoodName] = useState('');
  const [amount, setAmount] = useState(100);
  
  const [macros, setMacros] = useState({ calories: '', protein: '', carbs: '', fat: '' });
  
  const [suggestions, setSuggestions] = useState([]);
  const [showSuggestions, setShowSuggestions] = useState(false);
  const [selectedDbFood, setSelectedDbFood] = useState(null);

  const wrapperRef = useRef(null);

  // Close suggestions when clicking outside
  useEffect(() => {
    function handleClickOutside(event) {
      if (wrapperRef.current && !wrapperRef.current.contains(event.target)) {
        setShowSuggestions(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, [wrapperRef]);

  // Handle Search Input
  const handleFoodNameChange = (e) => {
    const val = e.target.value;
    setFoodName(val);
    setSelectedDbFood(null); // Clear selected food if they type manually
    
    if (val.length > 1) {
      setSuggestions(getFoodSuggestions(val));
      setShowSuggestions(true);
    } else {
      setSuggestions([]);
      setShowSuggestions(false);
    }
  };

  const selectFood = (food) => {
    setFoodName(food.name);
    setSelectedDbFood(food);
    setShowSuggestions(false);
  };

  // Auto-calculate macros when amount or selected food changes
  useEffect(() => {
    if (selectedDbFood) {
      const factor = (amount || 0) / 100;
      setMacros({
        calories: Math.round(selectedDbFood.calories * factor),
        protein: Number((selectedDbFood.protein * factor).toFixed(1)),
        carbs: Number((selectedDbFood.carbs * factor).toFixed(1)),
        fat: Number((selectedDbFood.fat * factor).toFixed(1)),
      });
    }
  }, [amount, selectedDbFood]);

  const handleSubmit = (e) => {
    e.preventDefault();
    addMeal({
      date: new Date().toISOString().split('T')[0],
      mealType: mealType,
      foodName: foodName,
      amount: Number(amount),
      calories: Number(macros.calories),
      protein: Number(macros.protein) || 0,
      carbs: Number(macros.carbs) || 0,
      fat: Number(macros.fat) || 0,
    });
    setAddMealOpen(false);
  };

  // Quick amounts
  const quickAmounts = [50, 100, 150, 200, 250];

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/40 px-4 backdrop-blur-sm">
      <motion.div 
        initial={{ opacity: 0, y: 50, scale: 0.9 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        exit={{ opacity: 0, y: 50, scale: 0.9 }}
        className="bg-background rounded-3xl p-6 w-full max-w-md shadow-2xl overflow-y-auto max-h-[90vh]"
      >
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-2xl font-serif text-primary">Ne yedin sevdiceğim? ❤️</h2>
          <button onClick={() => setAddMealOpen(false)} className="p-2 bg-rose-50 rounded-full text-primary hover:bg-rose-100 transition"><X size={20} /></button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-5">
          <div>
            <label className="text-xs text-muted font-medium mb-1 block">Öğün</label>
            <select className="input-field py-2" value={mealType} onChange={e => setMealType(e.target.value)}>
              <option>Kahvaltı</option>
              <option>Öğle</option>
              <option>Ara Öğün</option>
              <option>Akşam</option>
              <option>Gece</option>
            </select>
          </div>
          
          <div className="relative" ref={wrapperRef}>
            <label className="text-xs text-muted font-medium mb-1 block">Yiyecek / İçecek</label>
            <div className="relative">
              <input required type="text" placeholder="Örn: Tavuk Göğsü, Muz..." className="input-field py-2 pl-9" 
                value={foodName} onChange={handleFoodNameChange} onFocus={() => foodName.length > 1 && setShowSuggestions(true)} autoComplete="off" />
              <Search size={16} className="absolute left-3 top-3 text-rose-300" />
            </div>

            {/* Dropdown Suggestions */}
            <AnimatePresence>
              {showSuggestions && suggestions.length > 0 && (
                <motion.div 
                  initial={{ opacity: 0, y: -10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -10 }}
                  className="absolute z-10 w-full mt-1 bg-white border border-rose-100 rounded-xl shadow-lg max-h-48 overflow-y-auto"
                >
                  {suggestions.map(food => (
                    <div 
                      key={food.id} 
                      onClick={() => selectFood(food)}
                      className="px-4 py-3 hover:bg-primary/5 cursor-pointer border-b border-rose-50 last:border-0 transition-colors"
                    >
                      <div className="font-medium text-text text-sm">{food.name}</div>
                      <div className="text-xs text-muted">100g: {food.calories} kcal | P: {food.protein}g | C: {food.carbs}g</div>
                    </div>
                  ))}
                </motion.div>
              )}
            </AnimatePresence>
          </div>

          <div>
            <label className="text-xs text-muted font-medium mb-1 block">Miktar (g/ml)</label>
            <input required type="number" min="0" className="input-field py-2 font-bold text-lg" 
              value={amount} onChange={e => setAmount(e.target.value)} />
            
            <div className="flex gap-2 mt-2 overflow-x-auto pb-1 no-scrollbar">
              {quickAmounts.map(q => (
                <button 
                  key={q} type="button" 
                  onClick={() => setAmount(q)}
                  className={`flex-shrink-0 px-3 py-1 text-xs rounded-full border transition ${Number(amount) === q ? 'bg-primary text-white border-primary' : 'bg-white text-muted border-rose-100 hover:border-primary/40'}`}
                >
                  {q}g
                </button>
              ))}
            </div>
          </div>

          <div className="bg-white p-4 rounded-2xl border border-rose-50">
            <p className="text-xs font-semibold text-primary mb-3">Hesaplanan Besin Değerleri</p>
            <div className="grid grid-cols-2 gap-3 mb-3">
              <div>
                <label className="text-[10px] text-muted font-medium block">Kalori (kcal)</label>
                <input required type="number" min="0" className="input-field py-2 text-sm bg-gray-50/50" 
                  value={macros.calories} onChange={e => setMacros({...macros, calories: e.target.value})} />
              </div>
              <div>
                <label className="text-[10px] text-muted font-medium block">Protein (g)</label>
                <input type="number" step="0.1" min="0" className="input-field py-2 text-sm bg-gray-50/50" 
                  value={macros.protein} onChange={e => setMacros({...macros, protein: e.target.value})} />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-[10px] text-muted font-medium block">Karb. (g)</label>
                <input type="number" step="0.1" min="0" className="input-field py-2 text-sm bg-gray-50/50" 
                  value={macros.carbs} onChange={e => setMacros({...macros, carbs: e.target.value})} />
              </div>
              <div>
                <label className="text-[10px] text-muted font-medium block">Yağ (g)</label>
                <input type="number" step="0.1" min="0" className="input-field py-2 text-sm bg-gray-50/50" 
                  value={macros.fat} onChange={e => setMacros({...macros, fat: e.target.value})} />
              </div>
            </div>
          </div>

          <button type="submit" className="btn-primary w-full mt-2" disabled={!foodName || !amount || !macros.calories}>
            Öğünüme Ekle ❤️
          </button>
        </form>
      </motion.div>
    </div>
  );
};

export default AddMealModal;
