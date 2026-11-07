import React from 'react';
import { useStore } from '../store/useStore';
import { useUIStore } from '../store/useUIStore';
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';

const Progress = () => {
  const { profile, weightHistory, meals } = useStore();
  const { setAddWeightOpen } = useUIStore();
  
  const initialWeight = Number(profile.weight);
  const targetWeight = Number(profile.targetWeight);
  
  const currentWeight = weightHistory.length > 0 
    ? Number(weightHistory[weightHistory.length - 1].weight) 
    : initialWeight;
    
  // Calculate progress percentage
  let progressPercent = 0;
  if (initialWeight !== targetWeight) {
    const totalDiff = Math.abs(initialWeight - targetWeight);
    const currentDiff = Math.abs(initialWeight - currentWeight);
    progressPercent = Math.min((currentDiff / totalDiff) * 100, 100);
  } else {
    progressPercent = 100;
  }

  // Group meals by date for calorie history
  const calHistoryMap = meals.reduce((acc, meal) => {
    acc[meal.date] = (acc[meal.date] || 0) + meal.calories;
    return acc;
  }, {});
  
  const calData = Object.keys(calHistoryMap).sort().slice(-7).map(date => ({
    date: date.substring(5), // MM-DD
    calories: calHistoryMap[date]
  }));
  
  const weightData = weightHistory.slice(-7).map(w => ({
    date: w.date.substring(5),
    weight: w.weight
  }));

  return (
    <div className="space-y-6">
      <div className="mb-6 flex justify-between items-center">
        <h1 className="text-3xl font-serif text-primary">📈 Değişimini Görelim</h1>
      </div>

      <div className="card text-center p-6 bg-gradient-to-br from-primary/10 to-secondary/10 border-primary/20">
        <div className="flex justify-between text-sm font-medium text-muted mb-4 px-4">
          <div className="text-left">
            Başlangıç<br/>
            <span className="text-text font-bold text-base">{initialWeight} kg</span>
          </div>
          <div className="text-center">
            Şu an<br/>
            <span className="text-primary font-bold text-lg">{currentWeight} kg</span>
          </div>
          <div className="text-right">
            Hedef<br/>
            <span className="text-text font-bold text-base">{targetWeight} kg</span>
          </div>
        </div>
        
        <div className="w-full h-4 bg-white rounded-full overflow-hidden shadow-inner mb-3">
          <div 
            className="h-full bg-primary transition-all duration-1000 ease-out" 
            style={{ width: `${progressPercent}%` }}
          />
        </div>
        <p className="font-bold text-primary mb-2">%{Math.round(progressPercent)} tamamlandı ❤️</p>
        <p className="text-xs text-muted">
          “Hedefine doğru güzel gidiyorsun sevdiceğim. Acelemiz yok, önemli olan sağlıklı ilerlemek. ❤️”
        </p>
        
        <button onClick={() => setAddWeightOpen(true)} className="btn-primary mt-6 w-full text-sm">
          + Bugünün Kilosunu Kaydet
        </button>
      </div>

      {weightData.length > 0 && (
        <div className="card p-4">
          <h2 className="font-serif text-lg mb-4 text-text flex items-center gap-2">⚖️ Kilo Geçmişin</h2>
          <div className="h-48 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={weightData}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f0f0f0" />
                <XAxis dataKey="date" axisLine={false} tickLine={false} tick={{ fontSize: 12, fill: '#8D777D' }} dy={10} />
                <YAxis domain={['dataMin - 1', 'dataMax + 1']} axisLine={false} tickLine={false} tick={{ fontSize: 12, fill: '#8D777D' }} dx={-10} />
                <Tooltip 
                  contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 4px 12px rgba(0,0,0,0.1)' }}
                  labelStyle={{ color: '#8D777D', marginBottom: '4px' }}
                />
                <Line type="monotone" dataKey="weight" stroke="#A63D57" strokeWidth={3} dot={{ r: 4, fill: '#A63D57' }} activeDot={{ r: 6 }} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}

      {calData.length > 0 && (
        <div className="card p-4">
          <h2 className="font-serif text-lg mb-4 text-text flex items-center gap-2">🔥 Kalori Geçmişin</h2>
          <div className="h-48 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={calData}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f0f0f0" />
                <XAxis dataKey="date" axisLine={false} tickLine={false} tick={{ fontSize: 12, fill: '#8D777D' }} dy={10} />
                <YAxis axisLine={false} tickLine={false} tick={{ fontSize: 12, fill: '#8D777D' }} dx={-10} />
                <Tooltip 
                  contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 4px 12px rgba(0,0,0,0.1)' }}
                />
                <Line type="monotone" dataKey="calories" stroke="#E8B86D" strokeWidth={3} dot={{ r: 4, fill: '#E8B86D' }} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}

      <div className="h-8"></div>
    </div>
  );
};

export default Progress;
