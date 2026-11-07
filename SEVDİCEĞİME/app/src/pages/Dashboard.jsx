import React from 'react';
import { useStore } from '../store/useStore';
import { CircularProgressbar, buildStyles } from 'react-circular-progressbar';
import 'react-circular-progressbar/dist/styles.css';
import { Droplet, Heart } from 'lucide-react';

const Dashboard = () => {
  const { profile, water, meals, addWater } = useStore();
  
  const today = new Date().toISOString().split('T')[0];
  const todayWater = water.find(w => w.date === today)?.amount || 0;
  
  const todayMeals = meals.filter(m => m.date === today);
  const totalCalories = todayMeals.reduce((sum, m) => sum + m.calories, 0);
  const totalProtein = todayMeals.reduce((sum, m) => sum + m.protein, 0);
  const totalCarbs = todayMeals.reduce((sum, m) => sum + m.carbs, 0);
  const totalFat = todayMeals.reduce((sum, m) => sum + m.fat, 0);

  const calRemaining = profile.calorieTarget - totalCalories;
  
  const formattedDate = new Date().toLocaleDateString('tr-TR', { day: 'numeric', month: 'long', year: 'numeric', weekday: 'long' });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-3xl font-serif text-primary">Günaydın sevdiceğim ❤️</h1>
        <p className="text-muted text-sm mt-1 font-medium">{formattedDate}</p>
        <p className="text-text mt-3 italic text-sm">
          “Bugün de kendine iyi bakıyoruz. Ben buradayım. ❤️”
        </p>
      </div>

      {/* Main Calorie Card */}
      <div className="card text-center flex flex-col items-center justify-center py-8">
        <h2 className="font-serif text-xl mb-6 text-text">Bugünkü Kalorin</h2>
        <div className="w-48 h-48">
          <CircularProgressbar
            value={totalCalories}
            maxValue={profile.calorieTarget}
            text={`${totalCalories} kcal`}
            styles={buildStyles({
              textColor: '#3A252B',
              pathColor: '#A63D57',
              trailColor: '#FDF2F5',
              textSize: '12px'
            })}
          />
        </div>
        <p className="text-muted mt-4 font-medium">/ {profile.calorieTarget} kcal</p>
        <p className="text-primary font-bold mt-2">{calRemaining > 0 ? `${calRemaining} kcal kaldı` : 'Bugünlük hedefimizi aştık ❤️'}</p>
        {calRemaining < 0 && (
          <p className="text-xs text-muted mt-2 px-4">
            “Bugün hedefini biraz geçtik sevdiceğim. Hiç sorun değil, yarın yeniden dengeleriz. ❤️”
          </p>
        )}
      </div>

      {/* Macros */}
      <div className="grid grid-cols-3 gap-4">
        <MacroCard title="🥩 Protein" current={totalProtein} target={profile.proteinTarget} unit="g" color="bg-rose-200" />
        <MacroCard title="🍚 Karb." current={totalCarbs} target={profile.carbTarget} unit="g" color="bg-amber-200" />
        <MacroCard title="🥑 Yağ" current={totalFat} target={profile.fatTarget} unit="g" color="bg-emerald-200" />
      </div>

      {/* Water Tracker */}
      <div className="card">
        <h2 className="font-serif text-xl mb-4 flex items-center gap-2">
          <Droplet className="text-blue-400" /> Bugün Ne Kadar Su İçtin?
        </h2>
        <p className="text-center font-bold text-lg mb-4 text-text">{todayWater.toFixed(1)} L / {profile.waterTarget} L</p>
        
        {/* Simple water visual */}
        <div className="h-6 w-full bg-blue-50 rounded-full overflow-hidden mb-6">
          <div 
            className="h-full bg-blue-400 transition-all duration-500 ease-out" 
            style={{ width: `${Math.min((todayWater / profile.waterTarget) * 100, 100)}%` }}
          />
        </div>

        <div className="flex gap-4 justify-center">
          <button onClick={() => addWater(0.25)} className="btn-secondary flex-1 text-sm">
            +250 ml
          </button>
          <button onClick={() => addWater(0.5)} className="btn-secondary flex-1 text-sm">
            +500 ml
          </button>
        </div>
      </div>
      
      {/* Smart Suggestions */}
      <div className="card bg-primary/5 border-primary/20">
        <h2 className="font-serif text-xl mb-3 text-primary">🤍 Bugün Sana Ne Öneriyorum?</h2>
        <p className="text-text text-sm leading-relaxed">
          {totalProtein < profile.proteinTarget * 0.5 ? 
            "Bugün protein hedefinin biraz gerisindesin sevdiceğim. Akşam öğününe yoğurt, yumurta veya uygun bir protein kaynağı ekleyebilirsin. ❤️" : 
            todayWater < 1 ?
            "Bugün su biraz geride kalmış. Hadi bir bardak su içelim sevdiceğim. 💧" :
            "Bugün harika gidiyorsun, seninle gurur duyuyorum. ❤️"}
        </p>
      </div>

      {/* Spacer for bottom nav */}
      <div className="h-8"></div>
    </div>
  );
};

const MacroCard = ({ title, current, target, unit, color }) => {
  const percent = Math.min((current / target) * 100, 100);
  return (
    <div className="card p-4 flex flex-col items-center">
      <h3 className="text-xs font-semibold text-muted mb-2">{title}</h3>
      <p className="text-sm font-bold text-text mb-2">{Math.round(current)} / {target}{unit}</p>
      <div className="w-full h-2 bg-gray-100 rounded-full overflow-hidden">
        <div className={`h-full ${color}`} style={{ width: `${percent}%` }}></div>
      </div>
    </div>
  );
}

export default Dashboard;
