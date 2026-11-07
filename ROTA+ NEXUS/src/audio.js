// Tactical Web Audio API Generator for ROTA+ NEXUS
class TacticalAudio {
  constructor() {
    this.ctx = null;
    this.sosInterval = null;
    this.isMuted = true; // Start muted by default to prevent sudden noise
  }

  init() {
    try {
      if (!this.ctx) {
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        if (AudioContext) {
          this.ctx = new AudioContext();
        }
      }
      if (this.ctx && this.ctx.state === 'suspended') {
        this.ctx.resume();
      }
    } catch (e) {
      // Audio autoplay policy catch
    }
  }

  setMuted(muted) {
    this.isMuted = Boolean(muted);
    if (this.isMuted) {
      this.stopSosAlarm();
    }
  }

  playTone(freq = 880, type = 'sine', duration = 0.15, volume = 0.08) {
    if (this.isMuted) return;
    try {
      this.init();
      if (!this.ctx) return;

      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();

      osc.type = type;
      osc.frequency.setValueAtTime(freq, this.ctx.currentTime);

      gain.gain.setValueAtTime(volume, this.ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.0001, this.ctx.currentTime + duration);

      osc.connect(gain);
      gain.connect(this.ctx.destination);

      osc.start();
      osc.stop(this.ctx.currentTime + duration);
    } catch (e) {
      // Audio policy catch
    }
  }

  playRadarPing() {
    this.playTone(1200, 'sine', 0.2, 0.03);
  }

  playSelect() {
    this.playTone(720, 'triangle', 0.06, 0.05);
  }

  playTargetLock() {
    if (this.isMuted) return;
    this.playTone(840, 'sine', 0.06, 0.05);
    setTimeout(() => {
      this.playTone(1260, 'sine', 0.1, 0.07);
    }, 70);
  }

  playSosBeep() {
    if (this.isMuted) return;
    this.playTone(950, 'sawtooth', 0.18, 0.09);
  }

  playDispatch() {
    if (this.isMuted) return;
    this.playTone(440, 'sawtooth', 0.1, 0.07);
    setTimeout(() => this.playTone(880, 'sawtooth', 0.18, 0.07), 90);
  }

  playDroneLaunch() {
    if (this.isMuted) return;
    this.playTone(520, 'sine', 0.12, 0.06);
    setTimeout(() => this.playTone(780, 'sine', 0.15, 0.08), 120);
    setTimeout(() => this.playTone(1040, 'sine', 0.25, 0.08), 260);
  }

  playHazardAlert() {
    if (this.isMuted) return;
    this.playTone(820, 'square', 0.15, 0.1);
    setTimeout(() => this.playTone(620, 'square', 0.2, 0.1), 160);
  }

  playPrint() {
    if (this.isMuted) return;
    this.playTone(1400, 'triangle', 0.05, 0.04);
    setTimeout(() => this.playTone(1600, 'triangle', 0.06, 0.04), 80);
  }

  startSosAlarm() {
    if (this.isMuted || this.sosInterval) return;
    this.init();
    
    let high = true;
    const tick = () => {
      if (this.isMuted) {
        this.stopSosAlarm();
        return;
      }
      this.playTone(high ? 950 : 700, 'sawtooth', 0.35, 0.1);
      high = !high;
    };

    tick();
    this.sosInterval = setInterval(tick, 700);
  }

  stopSosAlarm() {
    if (this.sosInterval) {
      clearInterval(this.sosInterval);
      this.sosInterval = null;
    }
  }
}

// Proxy wrapper to prevent any "soundFx.XYZ is not a function" from ever crashing the app
const baseAudio = new TacticalAudio();
export const soundFx = new Proxy(baseAudio, {
  get(target, prop) {
    if (prop in target) {
      const val = target[prop];
      return typeof val === 'function' ? val.bind(target) : val;
    }
    // Safe fallback no-op function for any missing method
    return () => {};
  }
});
