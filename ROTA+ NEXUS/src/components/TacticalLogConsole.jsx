import React, { useRef, useEffect } from 'react';
import { Terminal, Shield, Radio, Activity } from 'lucide-react';

export default function TacticalLogConsole({ logs = [] }) {
  const scrollRef = useRef(null);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [logs]);

  return (
    <div className="h-28 bg-[#02050D]/95 backdrop-blur-md border-t border-[#00E5FF]/30 flex flex-col font-tactical select-none z-30">
      
      {/* Console Header (Image 2 exact style) */}
      <div className="h-6 px-3 bg-[#030917] border-b border-cyan-500/20 flex items-center justify-between text-[10px]">
        <div className="flex items-center gap-2 text-cyan-400 font-bold tracking-widest">
          <Terminal className="w-3 h-3 text-[#00E5FF]" />
          <span>SİSTEM LOGLARI & TELEMETRİ RAPORLARI</span>
        </div>
        <div className="flex items-center gap-3 text-slate-500 font-mono text-[9px]">
          <span className="flex items-center gap-1">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
            CANLI AKIŞ
          </span>
          <span>BUFFER: {logs.length} SATIR</span>
        </div>
      </div>

      {/* Log Feed */}
      <div 
        ref={scrollRef}
        className="flex-1 overflow-y-auto px-3 py-1.5 space-y-1 font-mono text-[10px] leading-tight custom-scrollbar"
      >
        {logs.map((log, idx) => {
          const isSos = log.includes('SOS') || log.includes('ACİL');
          const isSync = log.includes('FİREBASE') || log.includes('CANLI');
          const isLock = log.includes('HEDEF') || log.includes('KOKPİT');

          return (
            <div 
              key={idx}
              className={`flex items-start gap-2 ${
                isSos 
                  ? 'text-red-400 font-bold bg-red-950/20 px-1 border-l-2 border-red-500' 
                  : isLock
                  ? 'text-[#00E5FF] font-semibold'
                  : isSync
                  ? 'text-emerald-400'
                  : 'text-slate-400'
              }`}
            >
              <span className="text-cyan-500/50 select-none">&gt;&gt;</span>
              <span>{log}</span>
            </div>
          );
        })}
      </div>

    </div>
  );
}
