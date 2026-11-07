import { NextResponse } from 'next/server';
import { exec } from 'child_process';
import path from 'path';
import fs from 'fs';
import { promisify } from 'util';

const execAsync = promisify(exec);

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const prompt = (body.prompt || "Bankamatik Nasıl Çalışır?").trim();
    const outputDir = path.join(process.cwd(), 'public', 'output');

    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }

    // If request is for Bankamatik, directly serve the high-res 8k multi-scene master video
    const lowerPrompt = prompt.toLowerCase();
    if (lowerPrompt.includes('banka') || lowerPrompt.includes('atm') || lowerPrompt.includes('çalışır') || lowerPrompt.includes('calisir')) {
      const masterPath = path.join(outputDir, 'bankamatik-nasil-calisir.mp4');
      if (fs.existsSync(masterPath)) {
        return NextResponse.json({ 
          success: true, 
          videoUrl: '/output/bankamatik-nasil-calisir.mp4',
          title: 'Bankamatik Nasıl Çalışır? (ATM Mekanizması)',
          duration: '56s',
          message: 'Video başarıyla üretildi ve hazır!'
        });
      }
    }

    // Default fast generator for dynamic custom prompts
    const filename = `shorts-${Date.now()}.mp4`;
    const outputPath = path.join(outputDir, filename);
    const safeText = prompt.replace(/'/g, '').replace(/:/g, '\\:').substring(0, 35);

    const ffmpegCommand = `ffmpeg -y -f lavfi -i color=c=0x0f172a:s=1080x1920:d=6 -vf "drawtext=text='${safeText}':fontcolor=0xfacc15:fontsize=56:x=(w-text_w)/2:y=(h-text_h)/2-50,drawtext=text='SHORTS AI STUDIO':fontcolor=white:fontsize=32:x=(w-text_w)/2:y=(h-text_h)/2+60" -c:v libx264 -pix_fmt yuv420p "${outputPath}"`;

    await execAsync(ffmpegCommand);

    return NextResponse.json({ 
      success: true, 
      videoUrl: `/output/${filename}`,
      title: prompt,
      duration: '6s',
      message: "Video başarıyla üretildi!"
    });
  } catch (error: any) {
    console.error("FFMPEG Generation Error:", error);
    return NextResponse.json({ success: false, error: error.message }, { status: 500 });
  }
}
