const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

async function render() {
  const fps = 30;
  const duration = 35; // 35 seconds
  const frames = fps * duration;
  const workDir = path.join(__dirname, 'work');
  const framesDir = path.join(workDir, 'frames');
  
  // Try to use edge if chrome is not downloaded
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
  
  console.log('Rendering extended TR frames...');
  for (let i = 0; i < frames; i++) {
    const t = i / fps;
    await page.evaluate(`window.renderFrame(${t})`);
    
    // pad frame number
    const frameNum = i.toString().padStart(4, '0');
    await page.screenshot({ path: path.join(framesDir, `frame_${frameNum}.jpg`), quality: 90 });
    
    if (i % 50 === 0) console.log(`Rendered ${i}/${frames} frames...`);
  }
  
  await browser.close();
  console.log('Frames generated. Ready for ffmpeg!');
}

render().catch(err => {
  console.error(err);
  process.exit(1);
});
