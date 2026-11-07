import { create } from 'zustand';
import { persist } from 'zustand/middleware';

const initialProfile = {
  name: "",
  age: 0,
  gender: "",
  height: 0,
  weight: 0,
  targetWeight: 0,
  activityLevel: "",
  goal: "",
  calorieTarget: 1850,
  proteinTarget: 110,
  carbTarget: 210,
  fatTarget: 60,
  waterTarget: 2.2,
};

export const useStore = create(
  persist(
    (set, get) => ({
      profile: initialProfile,
      hasOnboarded: false,
      meals: [], // { id, date, mealType, foodName, amount, calories, protein, carbs, fat }
      water: [], // { date, amount }
      weightHistory: [], // { date, weight }
      moodHistory: [], // { date, mood, note }
      
      setProfile: (newProfile) => set({ profile: { ...get().profile, ...newProfile } }),
      completeOnboarding: () => set({ hasOnboarded: true }),
      
      addMeal: (meal) => set((state) => ({ 
        meals: [...state.meals, { ...meal, id: Date.now().toString() }] 
      })),
      
      addWater: (amount, date) => set((state) => {
        const today = date || new Date().toISOString().split('T')[0];
        const existing = state.water.find(w => w.date === today);
        if (existing) {
          return {
            water: state.water.map(w => w.date === today ? { ...w, amount: w.amount + amount } : w)
          };
        }
        return { water: [...state.water, { date: today, amount }] };
      }),
      
      addWeight: (weight, date) => set((state) => ({
        weightHistory: [...state.weightHistory, { date: date || new Date().toISOString().split('T')[0], weight }]
      })),
      
      addMood: (mood, note, date) => set((state) => ({
        moodHistory: [...state.moodHistory, { date: date || new Date().toISOString().split('T')[0], mood, note }]
      })),

      resetAll: () => set({
        profile: initialProfile,
        hasOnboarded: false,
        meals: [],
        water: [],
        weightHistory: [],
        moodHistory: []
      })
    }),
    {
      name: 'sevdicegim-storage', // unique name
    }
  )
);
