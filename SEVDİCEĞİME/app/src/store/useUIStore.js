import { create } from 'zustand';

export const useUIStore = create((set) => ({
  isAddMenuOpen: false,
  isAddMealOpen: false,
  isAddWeightOpen: false,
  
  setAddMenuOpen: (val) => set({ isAddMenuOpen: val }),
  setAddMealOpen: (val) => set({ isAddMealOpen: val }),
  setAddWeightOpen: (val) => set({ isAddWeightOpen: val }),
}));
