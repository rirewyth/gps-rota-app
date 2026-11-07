import React from 'react';
import { useStore } from '../store/useStore';
import { useUIStore } from '../store/useUIStore';
import { Plus } from 'lucide-react';

const Meals = () => {
  const { meals } = useStore();
  const { setAddMealOpen } = useUIStore();
  
  const today = new Date().toISOString().split('T')[0];
  const todayMeals = meals.filter(m => m.date === today);

  const mealTypes = ['Kahvaltı', 'Öğle', 'Ara Öğün', 'Akşam', 'Gece'];

  const getMealsByType = (type) => todayMeals.filter(m => m.mealType === type);

  return (
    <div className="space-y-6">
      <div className="mb-6">
        <h1 className="text-3xl font-serif text-primary">🍽️ Bugün Ne Yedin?</h1>
      </div>

      {mealTypes.map(type => {
        const typeMeals = getMealsByType(type);
        const totalCals = typeMeals.reduce((s, m) => s + m.calories, 0);

        return (
          <div key={type} className="card p-5">
            <div className="flex justify-between items-center mb-4 border-b border-rose-50 pb-2">
              <h2 className="font-serif text-lg text-primary">{type}</h2>
              <span className="font-bold text-sm">{totalCals} kcal</span>
            </div>
            
            {typeMeals.length === 0 ? (
              <p className="text-sm text-muted italic mb-3">Henüz eklenmedi.</p>
            ) : (
              <ul className="space-y-2 mb-4">
                {typeMeals.map(m => (
                  <li key={m.id} className="flex justify-between text-sm">
                    <span>{m.foodName} <span className="text-xs text-muted">({m.amount}g)</span></span>
                    <span className="font-medium">{m.calories} kcal</span>
                  </li>
                ))}
              </ul>
            )}

            <button 
              onClick={() => setAddMealOpen(true)}
              className="text-primary text-sm font-medium flex items-center gap-1 hover:underline"
            >
              <Plus size={16} /> Ekle
            </button>
          </div>
        )
      })}

      <div className="h-8"></div>
    </div>
  );
};

export default Meals;
