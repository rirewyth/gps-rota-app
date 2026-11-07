export const foodDatabase = [
  { id: 1, name: "Yumurta (Haşlanmış)", calories: 155, protein: 13, carbs: 1.1, fat: 11 },
  { id: 2, name: "Tavuk Göğsü (Izgara)", calories: 165, protein: 31, carbs: 0, fat: 3.6 },
  { id: 3, name: "Muz", calories: 89, protein: 1.1, carbs: 22.8, fat: 0.3 },
  { id: 4, name: "Elma", calories: 52, protein: 0.3, carbs: 14, fat: 0.2 },
  { id: 5, name: "Pirinç Pilavı", calories: 130, protein: 2.7, carbs: 28, fat: 0.3 },
  { id: 6, name: "Makarna (Sade Pişmiş)", calories: 131, protein: 5, carbs: 25, fat: 1.1 },
  { id: 7, name: "Tam Buğday Ekmek (1 Dilim ~30g)", calories: 247, protein: 13, carbs: 41, fat: 3.4 }, // 100g
  { id: 8, name: "Beyaz Peynir (Tam Yağlı)", calories: 264, protein: 14, carbs: 2.5, fat: 22 },
  { id: 9, name: "Zeytin (Siyah)", calories: 115, protein: 0.8, carbs: 6, fat: 11 },
  { id: 10, name: "Yulaf Ezmesi", calories: 389, protein: 17, carbs: 66, fat: 7 },
  { id: 11, name: "Süt (Yarım Yağlı)", calories: 47, protein: 3.3, carbs: 4.8, fat: 1.5 },
  { id: 12, name: "Yoğurt (Tam Yağlı)", calories: 61, protein: 3.5, carbs: 4.7, fat: 3.3 },
  { id: 13, name: "Ayran", calories: 38, protein: 2, carbs: 2.5, fat: 2 },
  { id: 14, name: "Filtre Kahve", calories: 2, protein: 0.3, carbs: 0, fat: 0 },
  { id: 15, name: "Çay (Şekersiz)", calories: 1, protein: 0, carbs: 0, fat: 0 },
  { id: 16, name: "Badem (Kavrulmamış)", calories: 579, protein: 21, carbs: 22, fat: 50 },
  { id: 17, name: "Ceviz", calories: 654, protein: 15, carbs: 14, fat: 65 },
  { id: 18, name: "Mercimek Çorbası", calories: 56, protein: 2.7, carbs: 8.4, fat: 1.5 },
  { id: 19, name: "Izgara Köfte", calories: 250, protein: 18, carbs: 5, fat: 17 },
  { id: 20, name: "Ton Balığı (Süzülmüş)", calories: 116, protein: 26, carbs: 0, fat: 1 },
  { id: 21, name: "Domates", calories: 18, protein: 0.9, carbs: 3.9, fat: 0.2 },
  { id: 22, name: "Salatalık", calories: 15, protein: 0.6, carbs: 3.6, fat: 0.1 },
  { id: 23, name: "Çikolata (Sütlü)", calories: 535, protein: 7.6, carbs: 59, fat: 30 },
  { id: 24, name: "Yarım Yağlı Süt", calories: 47, protein: 3.3, carbs: 4.8, fat: 1.5 },
  { id: 25, name: "Hamburger", calories: 295, protein: 17, carbs: 24, fat: 14 },
  { id: 26, name: "Pizza (Karışık)", calories: 266, protein: 11, carbs: 33, fat: 10 },
  { id: 27, name: "Bulgur Pilavı", calories: 83, protein: 3.1, carbs: 18.6, fat: 0.2 },
  { id: 28, name: "Salata (Zeytinyağlı)", calories: 75, protein: 1, carbs: 5, fat: 6 },
  { id: 29, name: "Fıstık Ezmesi", calories: 588, protein: 25, carbs: 20, fat: 50 },
  { id: 30, name: "Zeytinyağı", calories: 884, protein: 0, carbs: 0, fat: 100 },
];

export const getFoodSuggestions = (query) => {
  if (!query) return [];
  const q = query.toLowerCase();
  return foodDatabase.filter(food => food.name.toLowerCase().includes(q));
};
