# Hyperframes Composition Brief: Rota+

## Objective
Create a short launch-style brag video for Rota+.

## Output
- Composition directory: `brag-output-2026-10-04-213000/composition/`
- Rendered video: `brag-output-2026-10-04-213000/brag.mp4`
- Format: landscape — 1920x1080
- Duration: 20 seconds

## Source Material
- Project root: `C:\Users\rirew\Downloads\gps-rota-app-repo`
- Primary files read: `index.html`
- Product name: Rota+
- Tagline / strongest claim: "Trekking & Doğa Navigasyon Platformu" / "You built it. Now survive with it."
- Key UI or visual moment to recreate: The Team Alarm button turning into a green "SENT" badge, the tactical GPS coordinates, and the SOS pulse.
- Copy that must appear verbatim:
  - "ROTA+"
  - "TEAM ALARM"
  - "SENT"
  - "Trekking & Doğa Navigasyon Platformu"

## Creative Direction
- Tone preset: cinematic
- Creative direction: tactical expedition gear
- Interpretation: Deliberate, dramatic pacing. High contrast dark visuals with red/orange/green accents and monospace typography.
- Angle: A "high-stakes tactical mission" theme leaning into the serious, life-saving aspects of the app.
- Hook: A dark topographic grid with a scanning line. A red SOS pulse blinks in the center, and the bold headline "ROTA+" slams into view.
- Outro / punchline: The screen goes dark, leaving only the glowing Rota+ logo and the tagline: "Trekking & Doğa Navigasyon Platformu"
- Avoid:
  - Generic SaaS language
  - Abstract filler visuals
  - Unrelated visual redesign

## Visual Identity
- Background: #0A0C0F
- Text: #E8EDF2
- Accent: #FF3B1C (red), #FF8C00 (orange), #22FF7A (green)
- Display font: Barlow Condensed
- Body font: Barlow / Share Tech Mono (for coordinates and UI)
- Visual references from the project: The blinking red SOS pulse ring (`.sos-pulse`), the tactical monospace coordinates (`.tac-gps-wrap`), the Team Alarm button (`.team-alarm-btn`).

## Storyboard
Scene summary:
1. The Hook — 4s — Topographic grid, scanning line, red SOS pulse. "ROTA+" slams in.
2. Tactical GPS — 5s — Monospace coordinates and altitude metrics update. Cursor clicks "TEAM ALARM" button, green "SENT" badge pops up.
3. The SOS Pulse — 6s — Large SOS icon with red rings pulsing. Morse code dots/dashes light up sequentially.
4. Outro — 5s — Screen darkens, Rota+ logo fades in, tagline fades in.

## Audio
- Audio role: cinematic support
- Audio arc: Tension building through precise UI sounds, peaking at the SOS pulse, and fading to a dramatic silence.
- Music: `ende-happy-beats.mp3` (or any available cinematic/moody bed from the skill assets)
- Music treatment: Swells during the SOS pulse, fades out on the logo.
- Music cue guidance: To be detected at composition time via hyperframes beats.
- Audio-reactive treatment: Subtle; use music bass to make the SOS red glow breathe.
- Audio-coupled moments:
  - Tactical GPS — simulated interaction (click on TEAM ALARM)
  - SOS Pulse — Morse code sequence (telemetry hits)
- SFX selection guidance: Precise mechanical clicks for UI, tension hits for reveals.
- Exact SFX choice: Hyperframes should choose filenames, timestamps, density, and volume based on the implemented animation.

## Hyperframes Instructions
- Show real UI/visual elements (tactical coordinates, SOS pulse).
- Keep all text readable.
- Treat `/brag` audio notes as guidance.
- Honor planned music treatment.
- Run `hyperframes check` before render.
- Keep creation and rendering local.
