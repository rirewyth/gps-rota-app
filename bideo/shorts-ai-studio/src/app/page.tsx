"use client";

import React, { useState } from 'react';
import { 
  PlaySquare, LayoutDashboard, PlusCircle, FolderOpen, 
  Layers, Lightbulb, Settings, Zap, Play, FileVideo, Video, Loader2, X, Download, Clock, CheckCircle2
} from 'lucide-react';

export default function Dashboard() {
  const [isGenerating, setIsGenerating] = useState(false);
  const [genStep, setGenStep] = useState(0);
  const [videoUrl, setVideoUrl] = useState<string | null>(null);
  const [promptInput, setPromptInput] = useState("Bankamatik Nasıl Çalışır?");
  const [videoTitle, setVideoTitle] = useState("Bankamatik Nasıl Çalışır?");

  const steps = [
    "Fikirler ve Senaryo Analiz Ediliyor...",
    "Kurgu ve Görsel Yönetmenlik Tasarlanıyor...",
    "AI Seslendirme (Ahmet Neural) Üretiliyor...",
    "Sinematik Görseller & Altyazılar İşleniyor...",
    "Video Kurgulanıyor (1080x1920 MP4)..."
  ];

  const handleGenerate = async (customTopic?: string) => {
    const topicToUse = customTopic || promptInput || "Bankamatik Nasıl Çalışır?";
    setPromptInput(topicToUse);
    setVideoTitle(topicToUse);
    setIsGenerating(true);
    setGenStep(0);
    setVideoUrl(null);
    
    let currentStep = 0;
    const interval = setInterval(() => {
      if (currentStep < 3) {
        currentStep += 1;
        setGenStep(currentStep);
      }
    }, 1200);

    try {
      const res = await fetch('/api/generate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt: topicToUse })
      });
      
      clearInterval(interval);
      setGenStep(4);
      
      const data = await res.json();
      
      if (data.success) {
        setTimeout(() => {
          setIsGenerating(false);
          setVideoUrl(data.videoUrl);
          if (data.title) setVideoTitle(data.title);
        }, 1000);
      } else {
        alert("Hata oluştu: " + data.error);
        setIsGenerating(false);
      }
    } catch (err) {
      clearInterval(interval);
      setIsGenerating(false);
      alert("Sunucu hatası.");
    }
  };

  return (
    <div className="flex h-screen bg-gray-950 text-gray-100 overflow-hidden font-sans">
      {/* SIDEBAR */}
      <aside className="w-64 border-r border-gray-800 bg-gray-900 flex flex-col hidden md:flex">
        <div className="p-6 flex items-center gap-3">
          <div className="bg-indigo-600 p-2 rounded-lg shadow-lg shadow-indigo-500/20">
            <Video className="w-6 h-6 text-white" />
          </div>
          <div>
            <h1 className="text-xl font-bold tracking-tight text-white">SHORTS AI</h1>
            <p className="text-xs text-indigo-400 font-medium">Studio v1.0</p>
          </div>
        </div>
        
        <nav className="flex-1 px-4 space-y-2 mt-2">
          <NavItem icon={<LayoutDashboard size={20} />} label="Dashboard" active />
          <NavItem icon={<PlusCircle size={20} />} label="Yeni Video" />
          <NavItem icon={<FolderOpen size={20} />} label="Projeler" />
          <NavItem icon={<Layers size={20} />} label="Şablonlar" />
          <NavItem icon={<Lightbulb size={20} />} label="AI Fikirler" />
        </nav>
        
        <div className="p-4 border-t border-gray-800">
          <NavItem icon={<Settings size={20} />} label="Ayarlar" />
        </div>
      </aside>

      {/* MAIN CONTENT */}
      <main className="flex-1 flex flex-col overflow-y-auto relative">
        <header className="border-b border-gray-800 bg-gray-900/60 p-6 flex justify-between items-center sticky top-0 backdrop-blur-md z-10">
          <div>
            <h2 className="text-2xl font-bold text-white tracking-tight">Shorts AI Studio</h2>
            <p className="text-sm text-gray-400">Yapay zekâ ile YouTube Shorts ve dikey video üretim merkezi</p>
          </div>
          <button 
            onClick={() => handleGenerate()}
            disabled={isGenerating}
            className="bg-indigo-600 hover:bg-indigo-500 disabled:bg-indigo-800 text-white px-5 py-2.5 rounded-xl flex items-center gap-2 font-medium shadow-lg shadow-indigo-600/30 transition-all hover:scale-[1.02] active:scale-[0.98]"
          >
            {isGenerating ? <Loader2 size={18} className="animate-spin" /> : <PlusCircle size={18} />}
            {isGenerating ? 'Üretiliyor...' : 'Yeni Shorts Üret'}
          </button>
        </header>

        {/* LOADING OVERLAY */}
        {isGenerating && (
          <div className="absolute inset-0 bg-gray-950/90 backdrop-blur-md z-30 flex flex-col items-center justify-center p-6 text-center">
            <div className="relative mb-6">
              <div className="w-20 h-20 rounded-full border-4 border-indigo-500/20 border-t-indigo-500 animate-spin"></div>
              <Video className="w-8 h-8 text-indigo-400 absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2" />
            </div>
            <h3 className="text-2xl font-bold text-white mb-2">{steps[genStep]}</h3>
            <p className="text-gray-400 mb-6 text-sm max-w-sm">
              FFmpeg, Edge-TTS Türkçe dublaj ve sinematik görsel pipeline çalışıyor...
            </p>
            <div className="w-72 bg-gray-800 rounded-full h-2 mb-2 overflow-hidden shadow-inner">
              <div 
                className="bg-gradient-to-r from-indigo-500 to-purple-500 h-2 transition-all duration-500" 
                style={{ width: `${(genStep / (steps.length - 1)) * 100}%` }}
              ></div>
            </div>
          </div>
        )}

        {/* RESULT MODAL */}
        {videoUrl && (
          <div className="fixed inset-0 bg-gray-950/90 backdrop-blur-md z-40 flex flex-col items-center justify-center p-4">
            <div className="bg-gray-900 border border-gray-800 p-6 rounded-2xl max-w-md w-full relative shadow-2xl animate-in fade-in zoom-in-95 duration-200">
              <button 
                onClick={() => setVideoUrl(null)} 
                className="absolute top-4 right-4 text-gray-400 hover:text-white p-2 rounded-lg hover:bg-gray-800 transition-colors"
              >
                <X size={20} />
              </button>
              
              <div className="flex items-center gap-2 mb-4">
                <span className="p-1.5 bg-yellow-400/10 text-yellow-400 rounded-lg">
                  <Zap size={18} />
                </span>
                <div>
                  <h3 className="text-lg font-bold text-white leading-tight">{videoTitle}</h3>
                  <span className="text-xs text-green-400 flex items-center gap-1 font-medium mt-0.5">
                    <CheckCircle2 size={12} /> 1080x1920 (9:16) • Türkçe Dublaj Hazır
                  </span>
                </div>
              </div>

              <div className="aspect-[9/16] bg-black rounded-xl overflow-hidden mb-5 border border-gray-800 shadow-2xl relative max-h-[520px] mx-auto">
                <video 
                  src={videoUrl} 
                  controls 
                  autoPlay 
                  className="w-full h-full object-cover"
                />
              </div>

              <div className="flex gap-3">
                <a 
                  href={videoUrl} 
                  download 
                  className="flex-1 bg-indigo-600 hover:bg-indigo-500 text-center py-3 rounded-xl text-white font-medium flex items-center justify-center gap-2 transition-all shadow-lg shadow-indigo-600/30"
                >
                  <Download size={18} />
                  MP4 İndir
                </a>
                <button
                  onClick={() => setVideoUrl(null)}
                  className="px-5 py-3 rounded-xl bg-gray-800 hover:bg-gray-700 text-gray-200 font-medium transition-colors"
                >
                  Kapat
                </button>
              </div>
            </div>
          </div>
        )}

        <div className="p-8 max-w-6xl mx-auto w-full space-y-10">
          
          {/* PROMPT BOX */}
          <section className="bg-gradient-to-r from-gray-900 via-indigo-950/20 to-gray-900 border border-gray-800 p-6 rounded-2xl relative overflow-hidden">
            <div className="max-w-2xl">
              <h3 className="text-xl font-bold text-white mb-2">Video Fikrini Yaz, AI Videolaştırsın</h3>
              <p className="text-sm text-gray-400 mb-4">
                Konuyu yazın; AI senaryoyu bölsün, görselleri tasarlasın, Türkçe seslendirip altyazılarıyla montajlasın.
              </p>
              
              <div className="flex flex-col sm:flex-row gap-3">
                <input 
                  type="text" 
                  value={promptInput}
                  onChange={(e) => setPromptInput(e.target.value)}
                  placeholder="Örn: Bankamatik Nasıl Çalışır?"
                  className="flex-1 bg-gray-950 border border-gray-700 rounded-xl px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 text-sm"
                />
                <button
                  onClick={() => handleGenerate()}
                  className="bg-indigo-600 hover:bg-indigo-500 text-white font-semibold px-6 py-3 rounded-xl flex items-center justify-center gap-2 transition-all shadow-lg shadow-indigo-600/25 shrink-0"
                >
                  <Zap size={18} />
                  Videoyu Üret
                </button>
              </div>

              {/* QUICK PILLS */}
              <div className="flex flex-wrap gap-2 mt-4 items-center">
                <span className="text-xs text-gray-500 font-medium">Örnek Konular:</span>
                <button 
                  onClick={() => handleGenerate("Bankamatik Nasıl Çalışır?")}
                  className="text-xs bg-indigo-600/20 hover:bg-indigo-600/30 text-indigo-300 border border-indigo-500/30 px-3 py-1.5 rounded-lg transition-colors flex items-center gap-1.5"
                >
                  💳 Bankamatik Nasıl Çalışır?
                </button>
                <button 
                  onClick={() => handleGenerate("Karadelikler ve Uzay")}
                  className="text-xs bg-gray-800 hover:bg-gray-700 text-gray-300 px-3 py-1.5 rounded-lg transition-colors"
                >
                  🌌 Karadelikler
                </button>
                <button 
                  onClick={() => handleGenerate("Yapay Zekanın Geleceği")}
                  className="text-xs bg-gray-800 hover:bg-gray-700 text-gray-300 px-3 py-1.5 rounded-lg transition-colors"
                >
                  🤖 Yapay Zeka
                </button>
                <button 
                  onClick={() => handleGenerate("Antik Mısır Piramitleri")}
                  className="text-xs bg-gray-800 hover:bg-gray-700 text-gray-300 px-3 py-1.5 rounded-lg transition-colors"
                >
                  🏛️ Antik Mısır
                </button>
              </div>
            </div>
          </section>

          {/* FEATURED COMPLETED VIDEO */}
          <section>
            <div className="flex items-center justify-between mb-4">
              <div>
                <h3 className="text-xl font-bold text-white">Hazır Shorts Projeleri</h3>
                <p className="text-sm text-gray-400">Üretilmiş ve yayınlanmaya hazır YouTube Shorts videolarınız</p>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              
              {/* BANKAMATİK PROJESİ */}
              <div className="bg-gray-900 border border-gray-800 rounded-2xl overflow-hidden hover:border-indigo-500/50 transition-all group shadow-xl">
                <div className="relative aspect-[9/16] max-h-72 w-full bg-gray-950 overflow-hidden cursor-pointer" onClick={() => { setVideoUrl('/output/bankamatik-nasil-calisir.mp4'); setVideoTitle('Bankamatik Nasıl Çalışır?'); }}>
                  <img 
                    src="/output/atm/scene_1.jpg" 
                    alt="Bankamatik Nasıl Çalışır" 
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                  />
                  <div className="absolute inset-0 bg-gradient-to-t from-gray-950 via-transparent to-black/40"></div>
                  
                  {/* PLAY OVERLAY */}
                  <div className="absolute inset-0 flex items-center justify-center">
                    <div className="w-14 h-14 rounded-full bg-indigo-600/90 text-white flex items-center justify-center shadow-lg group-hover:scale-110 group-hover:bg-indigo-500 transition-all">
                      <Play size={24} className="ml-1" />
                    </div>
                  </div>

                  {/* BADGES */}
                  <div className="absolute top-3 left-3 bg-black/60 backdrop-blur-md px-2.5 py-1 rounded-md text-xs font-semibold text-yellow-400 flex items-center gap-1 border border-white/10">
                    <Zap size={12} /> SHORTS 9:16
                  </div>
                  <div className="absolute top-3 right-3 bg-black/60 backdrop-blur-md px-2.5 py-1 rounded-md text-xs font-semibold text-white flex items-center gap-1 border border-white/10">
                    <Clock size={12} /> 56 sn
                  </div>

                  <div className="absolute bottom-3 left-3 right-3">
                    <span className="text-[11px] font-semibold uppercase tracking-wider text-indigo-400 bg-indigo-950/80 px-2 py-0.5 rounded border border-indigo-800/60 inline-block mb-1">
                      Full Dublaj + Altyazı
                    </span>
                    <h4 className="text-base font-bold text-white leading-snug">Bankamatik Nasıl Çalışır? (ATM Mekanizması)</h4>
                  </div>
                </div>

                <div className="p-5 space-y-3">
                  <p className="text-xs text-gray-400 leading-relaxed">
                    Kart okuma, HSM kriptografik PIN güvenliği, ana sunucu onayı, zırhlı kasa para kasetleri, optik sahte para denetimi ve 30 saniye kuralı.
                  </p>
                  
                  <div className="flex items-center justify-between pt-2 border-t border-gray-800">
                    <button 
                      onClick={() => { setVideoUrl('/output/bankamatik-nasil-calisir.mp4'); setVideoTitle('Bankamatik Nasıl Çalışır?'); }}
                      className="text-xs font-semibold text-indigo-400 hover:text-indigo-300 flex items-center gap-1"
                    >
                      <Play size={14} /> Videoyu İzle
                    </button>
                    <a 
                      href="/output/bankamatik-nasil-calisir.mp4" 
                      download 
                      className="text-xs bg-gray-800 hover:bg-gray-700 text-white px-3 py-1.5 rounded-lg flex items-center gap-1 transition-colors"
                    >
                      <Download size={12} /> İndir (MP4)
                    </a>
                  </div>
                </div>
              </div>

            </div>
          </section>

          {/* STATS */}
          <section>
            <h3 className="text-lg font-medium text-gray-400 mb-4">Üretim Özeti</h3>
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
              <StatCard title="Hazır Shorts" value="1" icon={<PlaySquare className="text-green-400" />} />
              <StatCard title="Render Edilen Süre" value="56s" icon={<Clock className="text-indigo-400" />} />
              <StatCard title="Çözünürlük" value="1080p" icon={<FileVideo className="text-yellow-400" />} />
              <StatCard title="Ses Motoru" value="Ahmet AI" icon={<Zap className="text-purple-400" />} />
            </div>
          </section>

        </div>
      </main>
    </div>
  );
}

function NavItem({ icon, label, active = false }: { icon: React.ReactNode, label: string, active?: boolean }) {
  return (
    <a href="#" className={`flex items-center gap-3 px-3 py-2.5 rounded-lg transition-colors ${active ? 'bg-gray-800 text-white shadow-sm' : 'text-gray-400 hover:text-gray-200 hover:bg-gray-800/50'}`}>
      {icon}
      <span className="font-medium text-sm">{label}</span>
    </a>
  );
}

function StatCard({ title, value, icon }: { title: string, value: string, icon: React.ReactNode }) {
  return (
    <div className="bg-gray-900 border border-gray-800 p-5 rounded-xl flex items-center justify-between">
      <div>
        <p className="text-gray-400 text-xs font-medium mb-1">{title}</p>
        <p className="text-2xl font-bold text-white">{value}</p>
      </div>
      <div className="p-3 bg-gray-800/50 rounded-lg">
        {icon}
      </div>
    </div>
  );
}
