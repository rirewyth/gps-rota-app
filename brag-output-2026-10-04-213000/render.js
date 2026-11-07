const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

async function render() {
  const fps = 30;
  const duration = 60; // 60 seconds
  const frames = fps * duration;
  const workDir = path.join(__dirname, 'work');
  const framesDir = path.join(workDir, 'frames');
  
  if (!fs.existsSync(framesDir)) fs.mkdirSync(framesDir);
  
  const browserPaths = [
    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe'
  ];
  let executablePath = null;
  for (let p of browserPaths) {
    if (fs.existsSync(p)) { executablePath = p; break; }
  }

  const browser = await puppeteer.launch({ 
    headless: "new", 
    executablePath: executablePath || undefined,
    defaultViewport: { width: 1920, height: 1080 } 
  });
  const page = await browser.newPage();
  await page.goto(`file:///${workDir}/index.html`);
  
  console.log('Rendering 60s Tactical 3D frames...');
  for (let i = 0; i < frames; i++) {
    const t = i / fps;
    await page.evaluate(`window.renderFrame(${t})`);
    const frameNum = i.toString().padStart(4, '0');
    await page.screenshot({ path: path.join(framesDir, `frame_${frameNum}.jpg`), quality: 85 });
    if (i % 100 === 0) console.log(`Rendered ${i}/${frames} frames...`);
  }
  
  await browser.close();
  console.log('Frames generated. Running FFmpeg with complex audio mix...');

  const ffmpegExe = `"C:\\Users\\rirew\\AppData\\Local\\Microsoft\\WinGet\\Packages\\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\\ffmpeg-9.0.2-full_build\\bin\\ffmpeg.exe"`;
  const musicFile = `C:\\Users\\rirew\\Downloads\\brag\\skills\\brag\\assets\\music\\happy-beats-business-moves-vol-12-by-ende-dot-app.mp3`;
  const sfxBase = `C:\\Users\\rirew\\Downloads\\brag\\skills\\brag\\assets\\sfx`;
  
  // Tactical SFX
  const sfx = [
    { file: 'interface/glitch_004.ogg', timeMs: 500 },
    { file: 'interface/glitch_002.ogg', timeMs: 2000 },
    { file: 'impact/impactWood_heavy_000.ogg', timeMs: 2000 },
    
    { file: 'interface/switch_001.ogg', timeMs: 10500 },
    { file: 'interface/switch_002.ogg', timeMs: 20500 },
    
    { file: 'interface/error_005.ogg', timeMs: 30000 }, // SOS
    { file: 'impact/impactWood_heavy_001.ogg', timeMs: 31000 }, // SOS Text
    
    { file: 'impact/impactWood_heavy_002.ogg', timeMs: 40500 }, // 1000+
    
    { file: 'interface/glitch_004.ogg', timeMs: 50500 }, // Logo
    { file: 'interface/click_002.ogg', timeMs: 51500 }, // Badges
    { file: 'interface/drop_001.ogg', timeMs: 52500 }, // CTA
  ];

  let inputs = `-i "work/frames/frame_%04d.jpg" -i "${musicFile}" `;
  // Pitch down music and speed up to make it sound like a dark cyberpunk track
  let filter = `[1:a]asetrate=48000*0.75,atempo=1.33,volume=0.8[a1]; `; 
  let mixStr = `[a1]`;

  sfx.forEach((s, idx) => {
    let inputIdx = idx + 2;
    inputs += `-i "${path.join(sfxBase, s.file)}" `;
    filter += `[${inputIdx}:a]adelay=${s.timeMs}|${s.timeMs}[a${inputIdx}]; `;
    mixStr += `[a${inputIdx}]`;
  });

  filter += `${mixStr}amix=inputs=${sfx.length + 1}:duration=first:dropout_transition=2:normalize=0[aout]`;

  let ffmpegCmd = `${ffmpegExe} -y -framerate 30 ${inputs} -filter_complex "${filter}" -map 0:v -map "[aout]" -c:v libx264 -pix_fmt yuv420p -c:a aac -b:a 192k -t 60 "brag-tactical-60s.mp4"`;
  
  try {
    execSync(ffmpegCmd, { stdio: 'inherit' });
    console.log('Done rendering brag-tactical-60s.mp4');
  } catch (err) {
    console.error('FFmpeg failed', err);
  }
}

render().catch(err => {
  console.error(err);
  process.exit(1);
});
