import React, { useState, useEffect } from 'react';
import { 
  Play, 
  Pause, 
  RotateCcw, 
  FastForward, 
  Clock, 
  Radio, 
  History,
  ChevronUp,
  ChevronDown
} from 'lucide-react';
import { soundFx } from '../audio';

export default function TimelineReplayBar({
  progress = 1.0,
  onChangeProgress = () => {},
  isPlaying = false,
  onTogglePlay = () => {},
  speed = 1,
  onChangeSpeed = () => {},
  onResetLive = () => {}
}) {
  const [isExpanded, setIsExpanded] = useState(true);

  // Compute military time string between 08:00 and 20:00
  const totalSeconds = Math.round(progress * 12 * 3600); // 12 hours window (08:00 -> 20:00)
  const hour = Math.floor(totalSeconds / 3600) + 8;
  const minute = Math.floor((totalSeconds % 3600) / 60);
  const second = totalSeconds % 60;

  const timeFormatted = `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}:${String(second).padStart(2, '0')}`;
  const isLive = progress >= 0.99;

  return (
    <div className="w-full bg-[#02050D] border-t border-cyan-500/25 px-4 py-1.5 flex flex-col gap-1 font-tactical select-none z-30">
      
      {/* Top Bar / Controls */}
      <div className="flex items-center justify-between">
        
        {/* Left: Playback Controls */}
        <div className="flex items-center gap-2">
          
          {/* Play/Pause */}
          <button
            onClick={() => {
              onTogglePlay();
              soundFx.playSelect();
            }}
            className={`px-2.5 py-1 text-xs flex items-center gap-1.5 font-bold cursor-pointer transition-all border ${
              isPlaying
                ? 'bg-amber-600 text-white border-amber-400'
                : 'tactical-btn'
            }`}
          >
            {isPlaying ? <Pause className="w-3.5 h-3.5 fill-current" /> : <Play className="w-3.5 h-3.5 fill-current" />}
            <span>{isPlaying ? 'DURAKLAT' : 'OYNAT'}</span>
          </button>

          {/* Speed Multiplier */}
          <div className="flex items-center border border-cyan-500/30 bg-[#030917] text-[10px] font-mono">
            {[1, 2, 5, 10].map((s) => (
              <button
                key={s}
                onClick={() => {
                  onChangeSpeed(s);
                  soundFx.playSelect();
                }}
                className={`px-2 py-0.5 cursor-pointer transition-colors ${
                  speed === s ? 'bg-[#00E5FF] text-black font-bold' : 'text-slate-400 hover:text-white'
                }`}
              >
                {s}x
              </button>
            ))}
          </div>

          {/* Time Display */}
          <div className="flex items-center gap-1.5 px-2 py-0.5 bg-[#030917] border border-cyan-500/30 text-xs font-mono">
            <Clock className="w-3.5 h-3.5 text-[#00E5FF]" />
            <span className="text-white font-bold">{timeFormatted}</span>
            <span className="text-slate-500 text-[10px]">TSİ</span>
          </div>

        </div>

        {/* Right: Live Status / Live Reset */}
        <div className="flex items-center gap-2">
          {isLive ? (
            <div className="flex items-center gap-1 text-[10px] text-emerald-400 font-mono font-bold bg-emerald-950/40 border border-emerald-500/50 px-2 py-0.5">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
              <span>CANLI YAYIN (GERÇEK ZAMANLI)</span>
            </div>
          ) : (
            <button
              onClick={() => {
                onResetLive();
                soundFx.playSelect();
              }}
              className="tactical-btn-orange px-2 py-0.5 text-[10px] flex items-center gap-1 cursor-pointer font-bold animate-pulse"
            >
              <Radio className="w-3 h-3" /> CANLIYA DÖN (LIVE)
            </button>
          )}

          <div className="text-[9px] text-slate-500 font-mono hidden md:block">
            24S ZAMAN TÜNELİ OYNATICI
          </div>
        </div>

      </div>

      {/* Scrubber Slider */}
      <div className="relative w-full flex items-center gap-2 pt-0.5">
        <span className="text-[9px] font-mono text-slate-500">08:00</span>
        
        <input
          type="range"
          min="0"
          max="1"
          step="0.005"
          value={progress}
          onChange={(e) => {
            onChangeProgress(parseFloat(e.target.value));
          }}
          className="flex-1 h-1.5 bg-slate-800 rounded-none appearance-none cursor-pointer accent-[#FF4D26]"
        />

        <span className="text-[9px] font-mono text-slate-500">20:00</span>
      </div>

    </div>
  );
}
