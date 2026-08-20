# ROTA+ EMMİYETTEYİM

# IMMERSIVE PRODUCT WEBSITE --- MASTER SPECIFICATION

## Antigravity Build Document / v3.0

> **Reference inspiration:** Fişştech-style product storytelling, where
> individual product capabilities are demonstrated through interactive
> UI scenes rather than a gallery of screenshots. The reference site
> uses sequential "how it works" storytelling and animated product
> states; Rota+ should apply the same principle to a much richer
> outdoor-safety product. citeturn0view0
>
> **Important:** Do NOT copy the visual identity, layout, wording,
> assets, or code of the reference site. Use only the
> product-storytelling principle as inspiration.

------------------------------------------------------------------------

# 00. THE BRIEF

Build a **premium, cinematic, interactive product website** for **ROTA+
Emniyetteyim**.

This must NOT feel like:

-   a normal startup landing page
-   a WordPress template
-   a generic AI-generated website
-   a simple app-promotion page
-   a page containing 30 feature cards
-   a page where every feature is represented by a screenshot

It must feel like:

> **A digital product demonstration that the visitor can explore.**

The website should progressively reveal the Rota+ ecosystem.

Every important feature gets its own:

-   visual scene
-   interaction
-   animation
-   state change
-   miniature product interface
-   data visualization
-   micro-story

**Screenshots are references, not the primary storytelling method.**

The website should be able to explain the product even if the visitor
never sees a single static screenshot.

------------------------------------------------------------------------

# 01. CORE EXPERIENCE

The visitor journey should feel like this:

``` text
ARRIVE
  ↓
WHAT IS ROTA+?
  ↓
ENTER THE OUTDOOR WORLD
  ↓
PLAN A ROUTE
  ↓
NAVIGATE
  ↓
SEE LIVE LOCATION
  ↓
FOLLOW THE TEAM
  ↓
CHECK WEATHER / TERRAIN
  ↓
DISCOVER FIRE RISK
  ↓
LOSE NETWORK
  ↓
COMMUNICATE / OFFLINE
  ↓
EMERGENCY
  ↓
SOS
  ↓
CRITICAL ALERT
  ↓
RESCUE / SURVIVAL
  ↓
SOCIAL / COMMUNITY
  ↓
AI ADVISOR
  ↓
AR / RADAR / NIGHT MODE
  ↓
THE WHOLE ECOSYSTEM
  ↓
DOWNLOAD ROTA+
```

The website should progressively answer:

> **"Why would I want this application with me in nature?"**

------------------------------------------------------------------------

# 02. THE MOST IMPORTANT RULE

## ONE FEATURE = ONE VISUAL STORY

Do NOT create:

``` text
[Icon] Offline Maps
[Icon] Live Tracking
[Icon] Weather
[Icon] SOS
[Icon] AI
```

That is too generic.

Instead:

``` text
OFFLINE MAPS
→ map downloads
→ network disappears
→ UI changes to OFFLINE
→ route remains visible
→ user continues moving

LIVE TRACKING
→ map opens
→ team markers appear
→ route draws
→ distance updates
→ one member changes status

SOS
→ phone UI enters emergency mode
→ countdown / confirmation state
→ location locks
→ signal expands
→ emergency status propagates to team

FIRE MONITORING
→ Turkey map appears
→ fire markers emerge
→ one marker selected
→ risk/status information expands
```

The visitor should **see the feature happen**.

------------------------------------------------------------------------

# 03. BRAND POSITIONING

## Brand

**ROTA+**

## Product name

**ROTA+ EMMİYETTEYİM**

## Category

Outdoor navigation + live tracking + communication + emergency safety
platform.

## Core message

# DOĞADA YALNIZ DEĞİLSİN.

Supporting message:

> Rota, takip, iletişim ve acil durum araçlarını tek bir outdoor
> deneyimde birleştir.

Secondary:

> **ROTANI BELİRLE. EKİBİNİ TAKİP ET. GÜVENDE KAL.**

------------------------------------------------------------------------

# 04. VISUAL DIRECTION

The visual system must combine:

``` text
BLACK
+
ORANGE
+
TOPOGRAPHIC MAPS
+
GPS
+
HUD
+
LIVE DATA
+
OUTDOOR TERRAIN
+
EMERGENCY SIGNALS
+
PREMIUM TYPOGRAPHY
```

Reference application screens establish the product's existing visual
language:

-   black background
-   white typography
-   orange primary accent
-   red emergency state
-   green activity state
-   cyan / purple / yellow data accents

Preserve that DNA.

------------------------------------------------------------------------

# 05. COLOR SYSTEM

``` css
--bg-0: #030303;
--bg-1: #080808;
--bg-2: #0D0D0D;
--surface: #121212;
--surface-2: #181818;

--orange: #FF6A00;
--orange-bright: #FF7A18;
--orange-soft: rgba(255,106,0,.15);

--white: #F5F5F5;
--muted: #999999;
--dim: #5F5F5F;

--red: #FF4040;
--red-soft: rgba(255,64,64,.15);

--green: #54FF45;
--cyan: #20E8FF;
--yellow: #E8FF24;
--purple: #D052FF;
--amber: #FFB52E;

--border: rgba(255,255,255,.10);
```

Never turn the site into a rainbow.

Orange remains the brand anchor.

Other colors communicate **states and data**.

------------------------------------------------------------------------

# 06. TYPOGRAPHY

Primary:

**Inter**

Display alternative:

**Space Grotesk**

Technical:

**JetBrains Mono**

Use monospace for:

-   GPS coordinates
-   elevation
-   telemetry
-   system labels
-   network states
-   timestamps
-   technical HUD

Example:

``` text
41.8081° N
27.7828° E
ALT 712 M
GPS LOCKED
LIVE
```

------------------------------------------------------------------------

# 07. MOTION PHILOSOPHY

The site must have a **motion language**, not random animations.

Motion should communicate:

### Direction

Routes move.

### Connection

Signals travel.

### Status

Indicators pulse.

### Risk

Emergency states intensify.

### Data

Numbers update.

### Terrain

Maps shift.

### Progress

Scroll reveals product capability.

### Discovery

New features enter the viewport with purpose.

------------------------------------------------------------------------

# 08. MOTION TECHNOLOGY

Preferred:

``` text
GSAP
GSAP ScrollTrigger
Framer Motion
SVG
Canvas
Three.js
WebGL where justified
CSS transforms
```

For lightweight interactive motion, SVG/CSS/Canvas is preferred.

Do not use WebGL just because it looks impressive.

Performance is a requirement.

------------------------------------------------------------------------

# 09. GLOBAL SCROLL EXPERIENCE

The page should feel like one continuous expedition.

Avoid:

``` text
section
gap
section
gap
section
gap
```

Instead use transitions:

``` text
MOUNTAIN
   ↓
MAP
   ↓
ROUTE
   ↓
DEVICE
   ↓
LIVE TRACKING
   ↓
EMERGENCY
```

Sections should visually transform into one another.

------------------------------------------------------------------------

# 10. HERO --- "ENTER THE OUTDOOR SYSTEM"

## Scene

Full viewport.

Dark mountain terrain.

Very subtle atmospheric fog.

Topographic contour lines slowly move.

A glowing orange route line travels across the terrain.

Small GPS nodes appear.

A tiny coordinate HUD updates.

## Text

Eyebrow:

``` text
ROTA+ EMMİYETTEYİM
```

Main:

# DOĞADA

# YALNIZ DEĞİLSİN.

Body:

> Rotalarını planla, ekibini takip et, çevrendeki riskleri gör ve acil
> durumlarda hazırlıklı ol.

CTA:

**ROTA+'I KEŞFET**

Secondary:

**NASIL ÇALIŞIR? ↓**

## Animation

On load:

1.  Black screen.
2.  Tiny orange point appears.
3.  Point expands into GPS pulse.
4.  Terrain contour lines reveal.
5.  Route draws.
6.  Coordinates appear.
7.  Main headline fades in.
8.  Product UI appears from darkness.

No instant appearance.

------------------------------------------------------------------------

# 11. HERO INTERACTION

Mouse movement:

-   terrain has slight parallax
-   GPS point subtly follows cursor
-   HUD reacts
-   route glow shifts

Do not overdo parallax.

Mobile:

-   disable cursor-based effects
-   use slow ambient movement

------------------------------------------------------------------------

# 12. HERO HUD

Floating HUD elements:

``` text
GPS
LOCKED
```

``` text
ALT
712 M
```

``` text
ROUTE
7.49 KM
```

``` text
LIVE
● CONNECTED
```

These can be demonstration values.

If demo values are not real, label the entire scene as a product
visualization where appropriate.

------------------------------------------------------------------------

# 13. "ONE APP / MANY SYSTEMS"

Hero transitions into a giant statement:

# BİR UYGULAMA.

# BİRDEN FAZLA HAYATİ İHTİYAÇ.

Then system nodes orbit around a central ROTA+ symbol:

``` text
          WEATHER
             |
AR ---- ROTA+ ---- SOS
             |
         TRACKING
       /     |      \
   ROUTE   TEAM    FIRE
```

Each node is interactive.

Hovering a node:

-   node lights up
-   corresponding miniature UI appears
-   connecting line animates
-   short explanation appears

Clicking a node scrolls to its feature story.

------------------------------------------------------------------------

# 14. FEATURE INDEX

Create a persistent small side index on desktop:

``` text
01 ROUTE
02 NAVIGATION
03 LIVE TRACKING
04 TEAM
05 OFFLINE
06 COMMUNICATION
07 FIRE
08 WEATHER
09 RADAR
10 NIGHT OPS
11 SOS
12 CRITICAL ALERT
13 SURVIVAL
14 EARTHQUAKE
15 SOCIAL
16 PROFILE
17 AI
18 AR
19 BAROMETER
20 RESCUE
```

The active feature is highlighted in orange.

On mobile:

Use a compact horizontal progress indicator instead.

------------------------------------------------------------------------

# 15. FEATURE 01 --- SMART ROUTE PLANNING

## Headline

# ROTANI ÇIKMADAN ÖNCE TANı.

## Visual

Large interactive topographic map.

User can:

-   select start
-   select destination
-   drag route points

Demo mode can automatically create a route.

## Animation

1.  Start point appears.
2.  Destination appears.
3.  Route line draws.
4.  Elevation graph grows.
5.  Distance updates.
6.  Estimated duration appears.

UI:

``` text
AŞIK VEYSEL YÜRÜYÜŞ PİSTİ

7.49 KM
+712 M
83 DK
9.999 ADIM
```

## Scroll interaction

Scrolling down causes the route to extend across the map.

------------------------------------------------------------------------

# 16. FEATURE 02 --- ROUTE FLYOVER

## Headline

# ROTAYI YOLA ÇIKMADAN GÖR.

The route transforms into a 3D terrain.

Camera flies:

``` text
START
→ CLIMB
→ RIDGE
→ SUMMIT
→ FINISH
```

Overlay:

``` text
ALTITUDE
712 M
```

At each waypoint:

-   marker appears
-   elevation changes
-   camera moves

Use Three.js/Mapbox only if performance remains acceptable.

------------------------------------------------------------------------

# 17. FEATURE 03 --- LIVE TRACKING

## Headline

# EKİBİNİ

# HER ADIMDA GÖR.

Map becomes the full screen.

One marker = user.

Other markers = team.

Animation:

``` text
TEAM MEMBER 01
● ONLINE

TEAM MEMBER 02
● MOVING

TEAM MEMBER 03
● PAUSED
```

Route draws live.

Distance counter updates.

One team member moves visibly.

------------------------------------------------------------------------

# 18. FEATURE 04 --- TEAM MANAGEMENT

Transition from map to team panel.

Animated team members:

``` text
SERCAN
● ONLINE

AHMET
● ONLINE

MEHMET
● MOVING

CAN
● PAUSED
```

Click member:

-   map focuses on them
-   profile card expands
-   distance appears

Team network lines connect members.

------------------------------------------------------------------------

# 19. FEATURE 05 --- OFFLINE MAPS

## Headline

# ŞEBEKE YOKSA

# ROTA BİTMEZ.

Animation:

1.  Map is online.
2.  Network indicator shows 4G.
3.  Map download begins.
4.  Progress: `72% → 100%`
5.  Network disappears.
6.  UI switches to: `OFFLINE`
7.  Route remains.
8.  GPS marker continues.

This should be one of the strongest animations on the site.

------------------------------------------------------------------------

# 20. FEATURE 06 --- COMMUNICATION / MESH

## Headline

# BAĞLANTI KOPTUĞUNDA

# EKİBİN KOPMASIN.

Create animated node network.

``` text
DEVICE A
   ╲
    ╲
    DEVICE B
    ╱
   ╱
DEVICE C
```

Signal packet travels between nodes.

UI:

``` text
NETWORK
LOCAL LINK

3 DEVICES
CONNECTED
```

If Mesh is still a planned/experimental feature, clearly mark it as:

``` text
PLANLANIYOR
```

Do not imply unsupported real-world range.

------------------------------------------------------------------------

# 21. FEATURE 07 --- FIRE MONITORING

## Headline

# ÇEVRENDEKİ

# RİSKLERİ GÖR.

Turkey silhouette / map.

Fire markers appear sequentially.

One marker pulses red.

Click:

``` text
KIRKLAR DEMİRKÖY

● AKTİF

41.8081
27.7828
```

Another:

``` text
HATAY GÜVEÇÇİ

▲ KONTROL ALTINDA
```

Map zooms into selected point.

The animation must feel like an operational monitoring system, not a
decorative map.

------------------------------------------------------------------------

# 22. FEATURE 08 --- WEATHER

## Headline

# YOLA ÇIKMADAN

# HAVAYI KONTROL ET.

Create animated weather visualization.

Example:

``` text
14°C
22 KM/H
1008 HPA
%40 YAĞIŞ
```

Wind particles move across map.

Rain begins if demo scenario calls for it.

Weather data changes visually.

------------------------------------------------------------------------

# 23. FEATURE 09 --- BAROMETER

## Headline

# HAVADAKİ DEĞİŞİMİ

# HİSSET.

Animated pressure graph.

``` text
1018
1015
1012
1008
1005
```

Pressure line drops.

A warning state appears:

``` text
PRESSURE DROP
MONITOR CONDITIONS
```

Important:

Do not claim that a phone barometer can reliably predict a storm unless
the actual product supports that interpretation.

------------------------------------------------------------------------

# 24. FEATURE 10 --- RADAR

## Headline

# EKİBİNİN

# YÖNÜNÜ BUL.

Full circular tactical-style radar.

Center:

``` text
YOU
```

Around it:

``` text
TEAM
```

Markers move according to heading.

Distance labels:

``` text
42 M
86 M
123 M
```

Compass rotates.

The visual should be premium outdoor instrumentation, not a military
game.

------------------------------------------------------------------------

# 25. FEATURE 11 --- NIGHT OPS

## Headline

# GECE DE

# ROTANDAN ÇIKMA.

Whole website section temporarily transitions into a darker red/orange
interface.

Map dims.

Text dims.

Route remains visible.

Compass glows.

SOS remains accessible.

Create a toggle:

``` text
NIGHT MODE
OFF → ON
```

Clicking it transforms the interface.

This should be a genuine interactive demonstration.

------------------------------------------------------------------------

# 26. FEATURE 12 --- SOS

This section should dramatically change the page.

Everything slows down.

Background becomes almost black.

Orange fades into red.

## Headline

# ACİL DURUMDA

# TEK DOKUNUŞ.

Central emergency UI:

``` text
┌───────────────────────┐
│                       │
│          SOS          │
│                       │
│     PRESS & HOLD      │
│                       │
└───────────────────────┘
```

User presses/holds.

Animation:

``` text
0.0
0.5
1.0
1.5
2.0
```

Then:

``` text
SOS ACTIVE
LOCATION SHARED
TEAM NOTIFIED
```

Signal waves expand across the screen.

Map coordinates appear.

------------------------------------------------------------------------

# 27. FEATURE 13 --- CRITICAL ALERT

## Headline

# TEHLİKE OLDUĞUNDA

# EKİP HABERDAR.

Simulation:

Normal team map.

One member becomes:

``` text
⚠ EMERGENCY
```

Red signal expands from that marker.

Other team members receive alert cards.

Screen UI:

``` text
KRİTİK ALARM

Bir ekip üyesi acil durum bildirdi.

SERCAN
41.8081 N
27.7828 E
```

Do not claim that a notification will always bypass device settings
unless actually supported.

------------------------------------------------------------------------

# 28. FEATURE 14 --- SURVIVAL GUIDE

## Headline

# İNTERNET OLMADAN

# BİLGİYE ULAŞ.

Animated emergency manual.

Topics:

``` text
KANAMA
YARALANMA
HİPOTERMİ
KAYBOLMA
SU
BARINAK
ACİL DURUM
```

Clicking a topic opens a card.

Use animated step-by-step diagrams.

No stock medical imagery required.

------------------------------------------------------------------------

# 29. FEATURE 15 --- EARTHQUAKE MODE

## Headline

# ACİL DURUMLAR

# TEK BİR SENARYODAN İBARET DEĞİL.

Earthquake feed animation.

Map shakes subtly.

Seismic wave visualization travels across map.

Cards appear:

``` text
4.2
EGE DENİZİ
```

``` text
3.7
MANİSA
```

Only use real-time data if an actual data source is connected.

Otherwise:

``` text
PRODUCT DEMO
```

------------------------------------------------------------------------

# 30. FEATURE 16 --- SOCIAL FEED

## Headline

# MACERANI

# PAYLAŞ.

Do not show a static screenshot.

Build a living feed UI.

Post appears:

``` text
SERCAN
✓ ROTA

AŞIK VEYSEL YÜRÜYÜŞ PİSTİ

7.49 KM
+712 M
83 DK
```

Animated:

-   post enters
-   route stats count up
-   heart reacts
-   comment count changes

------------------------------------------------------------------------

# 31. FEATURE 17 --- PROFILE

## Headline

# DAĞDAKİ

# KİMLİĞİN.

Profile card assembles itself.

``` text
SERCAN

2 GÖNDERİ
9 TAKİPÇİ
7 TAKİP

PREMIUM
SERTİFİKALI REHBER
```

Stats animate from 0.

Badges reveal individually.

------------------------------------------------------------------------

# 32. FEATURE 18 --- TEAM / CLUBS

## Headline

# TEK BAŞINA ÇIKMAK

# ZORUNDA DEĞİLSİN.

Animated team creation:

``` text
CREATE TEAM
      ↓
INVITE
      ↓
JOIN
      ↓
TRACK
```

Avatars connect to team node.

------------------------------------------------------------------------

# 33. FEATURE 19 --- DIRECT MESSAGING

## Headline

# EKİBİNLE

# İLETİŞİMDE KAL.

Build animated chat.

Message appears.

Location card appears.

Route share appears.

Example:

``` text
Sercan:
Zirveye yaklaşıyorum.

[ LOCATION ]
41.8081 N
27.7828 E
```

Typing animation should be subtle.

------------------------------------------------------------------------

# 34. FEATURE 20 --- AI NATURE ADVISOR

## Headline

# DOĞAYA ÇIKMADAN

# ÖNCE SOR.

Create an animated AI interface.

User asks:

``` text
Bu rota bugün uygun mu?
```

AI processes:

``` text
ROUTE
WEATHER
ELEVATION
EXPERIENCE
```

Then response:

``` text
ORTA RİSK

Rüzgar artıyor.
İrtifa kazanımı yüksek.

ÖNERİ:
• Su
• Yağmurluk
• Ek katman
```

The animation should visually show the reasoning inputs converging.

Do not imply medical or emergency decision-making beyond the actual
product's capability.

------------------------------------------------------------------------

# 35. FEATURE 21 --- AR PEAK FINDER

## Headline

# DAĞIN ADINI

# KAMERADAN GÖR.

Create a simulated camera viewport.

Mountain silhouette.

Labels float over peaks:

``` text
ULUDAĞ
2543 M
48.2 KM
```

Compass rotates.

Peak label locks onto terrain.

This can be a visual simulation if actual browser AR is not implemented.

------------------------------------------------------------------------

# 36. FEATURE 22 --- AR COMPASS

## Headline

# YÖNÜ

# GÖZÜNÜN ÖNÜNE GETİR.

Animated compass.

Camera-like background.

Heading changes as pointer moves.

``` text
N  018°
NE
E
```

------------------------------------------------------------------------

# 37. FEATURE 23 --- GPS / LOCATION

## Headline

# KONUMUNU

# KAYBETME.

Create a coordinate HUD.

``` text
LAT
41.808111

LNG
27.782839

ALT
712 M

ACC
±4 M
```

GPS satellite dots connect.

Signal strength changes.

------------------------------------------------------------------------

# 38. FEATURE 24 --- EMERGENCY RADAR / PROXIMITY

If the actual product includes a proximity/radar concept:

Show:

``` text
YOU
●

TEAM
42 M
86 M
123 M
```

A pulsing circle expands.

The closest team member becomes highlighted.

------------------------------------------------------------------------

# 39. FEATURE 25 --- ROUTE STATISTICS

## Headline

# HER ADIM

# BİR VERİ.

Animated dashboard:

``` text
7.49 KM
83 DK
712 M
9.999 ADIM
```

Numbers count upward as route progresses.

Elevation chart draws.

Step graph grows.

------------------------------------------------------------------------

# 40. FEATURE 26 --- ACTIVITY FEED / ROUTE POSTS

Show how a completed route becomes a social post.

Animation:

``` text
ROUTE FINISHED
       ↓
CALCULATE
       ↓
7.49 KM
       ↓
+712 M
       ↓
GENERATE POST
       ↓
SHARE
```

This connects navigation and social features.

------------------------------------------------------------------------

# 41. FEATURE 27 --- SAFETY SCORE / RISK VISUALIZATION

If the actual product supports a risk score, create an animated score
system.

If not, do not invent it as an existing feature.

Possible visualization:

``` text
ROUTE CONDITIONS

WEATHER       ●●●○○
ELEVATION     ●●●●○
NETWORK       ●●○○○
FIRE RISK     ●○○○○
```

Label it clearly as a product concept if it is not implemented.

------------------------------------------------------------------------

# 42. FEATURE 28 --- MAP LAYERS

Interactive map controls:

``` text
TOPO
SATELLITE
WEATHER
FIRE
ROUTE
TEAM
```

Click layer:

-   map changes
-   layer animates in
-   legend updates

This should feel like an actual mapping tool.

------------------------------------------------------------------------

# 43. FEATURE 29 --- FIRE + WEATHER + ROUTE COMBINATION

Create one advanced scene where three systems merge.

``` text
ROUTE
+
WEATHER
+
FIRE
```

Map displays:

-   route line
-   weather field
-   fire marker
-   user position

A warning appears only when demo conditions warrant it.

This demonstrates why the ecosystem is more valuable than isolated
tools.

------------------------------------------------------------------------

# 44. FEATURE 30 --- THE ROTA+ ECOSYSTEM

After all feature stories, zoom out.

Every system becomes a node:

``` text
              AR
              |
WEATHER — NAVIGATION — LIVE TRACKING
   |             |              |
FIRE           ROUTE           TEAM
   |             |              |
SAFETY ———— ROTA+ ———— COMMUNICATION
   |             |
  SOS        SOCIAL
   |
RESCUE
```

Connections animate.

This is the "aha" moment.

------------------------------------------------------------------------

# 45. PRODUCT SCREEN SHOWCASE

Only after the interactive feature stories, show the real app screens.

Use the provided screenshots.

But do NOT simply create:

``` text
image
image
image
image
```

Instead:

-   device frame
-   screenshot enters
-   camera perspective changes
-   UI elements highlight
-   labels point to functionality
-   screenshot transforms into the website's vector UI

This section proves:

> **The product shown in the animation actually exists as an app.**

------------------------------------------------------------------------

# 46. "FROM MAP TO EMERGENCY" MASTER STORY

Create one final cinematic scroll sequence.

The user walks along a route.

### Stage 01

Route planning.

### Stage 02

Navigation begins.

### Stage 03

Team joins.

### Stage 04

Weather changes.

### Stage 05

Network disappears.

### Stage 06

Offline mode activates.

### Stage 07

Fire risk appears.

### Stage 08

Team member stops.

### Stage 09

SOS activates.

### Stage 10

Team receives critical alert.

### Stage 11

Location is visible.

### Stage 12

System returns to normal.

This is the strongest storytelling section on the website.

------------------------------------------------------------------------

# 47. FINAL CTA

After the entire experience:

Black screen.

All animation slows.

Single orange GPS point.

Headline:

# HER ROTA'NIN

# BİR HİKÂYESİ VAR.

Then:

# ROTA+ İLE

# GÜVENDE KAL.

Buttons:

**GOOGLE PLAY**

**APP STORE**

Do NOT include pricing.

Do NOT include subscription cards.

Do NOT include a pricing section.

Do NOT include "Buy now".

------------------------------------------------------------------------

# 48. FOOTER

Minimal.

``` text
ROTA+

DOĞADA YALNIZ DEĞİLSİN.

Keşfet
Özellikler
Güvenlik
Canlı Takip
Rotalar
Hakkımızda
İletişim

Gizlilik
Kullanım Koşulları

© ROTA+ Emniyetteyim
```

------------------------------------------------------------------------

# 49. NO PRICING

This is explicit.

**DO NOT BUILD:**

-   pricing
-   subscription cards
-   plans
-   monthly prices
-   annual prices
-   comparison pricing
-   checkout
-   payment CTA

The website is a **product presentation and download experience**, not a
SaaS pricing page.

------------------------------------------------------------------------

# 50. NO FEATURE GRID AS PRIMARY CONTENT

A feature grid may exist as a compact index, but it must NOT be the
primary presentation.

Bad:

``` text
30 cards
30 icons
30 paragraphs
```

Good:

``` text
30 capabilities
30 interactive scenes
30 visual explanations
```

------------------------------------------------------------------------

# 51. MICRO-INTERACTIONS

Every interactive element needs motion.

## Buttons

Hover:

-   slight lift
-   orange glow
-   arrow movement

## Cards

Hover:

-   border illumination
-   content shift
-   data reveal

## Map markers

-   pulse
-   hover radius
-   information expansion

## Toggles

-   physical-feeling transition

## Tabs

-   sliding indicator

## Numbers

-   count-up

## Status

-   pulse

------------------------------------------------------------------------

# 52. SCROLL-BASED MOTION RULES

Use scroll to control:

-   camera
-   route
-   map zoom
-   UI assembly
-   data visualization
-   text reveal
-   transitions

Avoid making every text paragraph animate independently.

The page should feel like a continuous film.

------------------------------------------------------------------------

# 53. CINEMATIC TRANSITIONS

Examples:

### Route → Live Tracking

Orange route line expands until it becomes a full map.

### Live Tracking → Team

User marker splits into multiple markers.

### Team → Emergency

One marker turns red.

### Emergency → Rescue

Red pulse becomes a location signal.

### Fire → Weather

Fire map fades into environmental data.

### Offline → Communication

Network lines disappear, local nodes remain.

------------------------------------------------------------------------

# 54. MAP VISUAL SYSTEM

Map must never look like a random embedded map.

Use:

-   dark custom style
-   contour lines
-   terrain shading
-   orange route
-   minimal labels
-   glowing active markers

The map is a **product visualization**, not just a background.

------------------------------------------------------------------------

# 55. DATA VISUALIZATION

Use data as part of the design.

Examples:

``` text
DISTANCE
7.49 KM
```

``` text
ELEVATION
+712 M
```

``` text
TIME
83 MIN
```

``` text
STEPS
9,999
```

Animate values when the feature becomes active.

------------------------------------------------------------------------

# 56. DEVICE MOCKUPS

Use device mockups sparingly.

At most:

-   Hero
-   App proof section
-   Final download

The rest of the website should use **native recreated UI scenes**.

This is important.

The website should not depend on 20 screenshots.

------------------------------------------------------------------------

# 57. 3D DEVICE INTERACTION

Hero device can rotate subtly.

On scroll:

``` text
front
→
15°
→
side
→
map-focused
→
flat UI
```

Avoid excessive 3D rotation on mobile.

------------------------------------------------------------------------

# 58. PARTICLE / SIGNAL SYSTEM

Create one reusable signal system.

It can represent:

-   GPS
-   communication
-   SOS
-   radar
-   team connection

Particles should move along paths.

This gives the website a coherent motion language.

------------------------------------------------------------------------

# 59. TOPOGRAPHIC SYSTEM

Create animated SVG contour lines.

They can:

-   drift slowly
-   reveal on scroll
-   respond to cursor
-   transition into route lines

The contour system should appear in:

-   hero
-   route
-   navigation
-   final CTA

This becomes a signature Rota+ visual.

------------------------------------------------------------------------

# 60. LOADING EXPERIENCE

Do not show a generic spinner.

Create:

``` text
ROTA+

INITIALIZING
MAP
GPS
TRACKING
SAFETY
```

Progress:

``` text
00
25
50
75
100
```

Then:

``` text
READY
```

Keep loading short.

If assets are already cached, skip or reduce the loader.

------------------------------------------------------------------------

# 61. RESPONSIVE DESIGN

## Desktop

Maximum cinematic experience.

Use:

-   sticky scenes
-   large map
-   3D
-   layered HUD
-   horizontal transitions

## Tablet

Reduce:

-   particle count
-   3D
-   map complexity

## Mobile

Preserve the story.

Do NOT simply hide sections.

Instead:

``` text
desktop complex animation
→
mobile simplified animation
```

Every major feature must remain understandable.

------------------------------------------------------------------------

# 62. MOBILE HERO

Mobile hero:

``` text
ROTA+
DOĞADA
YALNIZ
DEĞİLSİN.
```

Map occupies lower portion.

CTA remains visible.

No cursor effects.

------------------------------------------------------------------------

# 63. MOBILE FEATURE ANIMATION

For each feature:

-   one focused viewport
-   vertical animation
-   simplified map
-   compact HUD
-   readable typography

No tiny desktop UI compressed into mobile.

------------------------------------------------------------------------

# 64. ACCESSIBILITY

Support:

-   keyboard navigation
-   visible focus
-   screen readers
-   semantic HTML
-   sufficient contrast
-   reduced motion

If:

``` css
prefers-reduced-motion: reduce
```

then:

-   disable parallax
-   disable continuous particles
-   shorten transitions
-   preserve state changes

Animation must never be required to understand content.

------------------------------------------------------------------------

# 65. PERFORMANCE

This is an animation-heavy website, so performance is mandatory.

Rules:

-   lazy load heavy scenes
-   dynamic import Three.js
-   use SVG where possible
-   Canvas only where useful
-   use transform/opacity for animation
-   avoid layout thrashing
-   pause off-screen animations
-   reduce particle count on mobile
-   compress assets
-   use AVIF/WebP
-   preload only critical hero assets

Target:

> **A premium experience that still feels fast.**

------------------------------------------------------------------------

# 66. COMPONENT ARCHITECTURE

Suggested:

``` text
app/
components/
  navigation/
  hero/
  terrain/
  hud/
  maps/
  routes/
  tracking/
  teams/
  emergency/
  fire/
  weather/
  radar/
  offline/
  communication/
  social/
  profile/
  ai/
  ar/
  earthquake/
  survival/
  devices/
  transitions/
  motion/
  ui/
```

Reusable components:

``` text
<FeatureScene />
<MapScene />
<HudPanel />
<Metric />
<StatusBadge />
<SignalPulse />
<RouteLine />
<FeatureIndex />
<SectionTransition />
```

------------------------------------------------------------------------

# 67. STATE MACHINE APPROACH

Interactive feature scenes should use explicit states.

Example SOS:

``` text
IDLE
↓
ARMED
↓
COUNTDOWN
↓
ACTIVE
↓
NOTIFIED
```

Offline:

``` text
ONLINE
↓
DOWNLOADING
↓
READY
↓
NETWORK_LOST
↓
OFFLINE_ACTIVE
```

Tracking:

``` text
IDLE
↓
STARTED
↓
MOVING
↓
PAUSED
↓
FINISHED
```

This creates professional-feeling interactions instead of random
animation.

------------------------------------------------------------------------

# 68. DEMO DATA

Create a central demo data object.

Example:

``` ts
const demoRoute = {
  name: "Aşık Veysel Yürüyüş Pisti",
  distance: 7.49,
  elevation: 712,
  duration: 83,
  steps: 9999
}
```

Use the same demo values consistently.

Do not randomly generate numbers in different sections.

------------------------------------------------------------------------

# 69. REAL VS DEMO DATA

Critical rule.

If no live API is connected:

``` text
PRODUCT DEMO
```

or

``` text
SIMULATION
```

can be shown subtly.

Never pretend:

-   a fake fire is live
-   a fake GPS is the user's location
-   fake team members are real
-   fake AI analysis is real
-   fake earthquake data is current

The site must maintain trust.

------------------------------------------------------------------------

# 70. SEO CONTENT STRUCTURE

Use semantic headings.

Primary H1:

``` text
Doğada yalnız değilsin.
```

Sections:

``` text
Rota Planlama
Canlı Takip
Acil Durum
Yangın Takibi
Offline Haritalar
Ekip Yönetimi
Hava Durumu
AI Doğa Danışmanı
```

Page title:

**Rota+ Emniyetteyim \| Doğa, Rota ve Acil Durum Güvenliği**

Meta description:

> Rota+ Emniyetteyim ile rotanı planla, ekibini takip et, çevrendeki
> riskleri gör ve doğada daha hazırlıklı ol.

------------------------------------------------------------------------

# 71. TRUST LANGUAGE

Avoid exaggerated claims.

Do NOT write:

> "Hayatınızı garanti altına alır."

> "Her durumda kurtarır."

> "Kesin konum tespiti."

Instead:

> "Acil durumlarda daha hazırlıklı ol."

> "Ekibinle bağlantıda kal."

> "Konum ve rota bilgilerini takip et."

------------------------------------------------------------------------

# 72. DESIGN QUALITY BAR

The result should feel closer to:

``` text
premium product launch
+
interactive data visualization
+
outdoor technology
+
cinematic editorial design
```

than:

``` text
startup template
```

------------------------------------------------------------------------

# 73. WHAT MUST NOT APPEAR

Never use:

-   generic purple AI gradients
-   stock business people
-   random office photos
-   generic mountain stock photo as the entire design
-   excessive glassmorphism
-   30 identical feature cards
-   pricing tables
-   fake testimonials
-   fake user numbers
-   fake awards
-   fake press logos
-   fake app ratings
-   unnecessary newsletter forms
-   unnecessary chatbot
-   cookie-style intrusive popups
-   huge blobs
-   generic "revolutionize your journey" copy

------------------------------------------------------------------------

# 74. OPTIONAL VISUAL ASSETS

The site should work without additional photos.

Prefer generating visuals procedurally:

``` text
SVG
Canvas
CSS
Three.js
Map layers
Native HTML UI
```

Use the provided app screenshots only as:

1.  product proof
2.  design reference
3.  final showcase

This solves the user's requirement:

> **"Her özellik için ayrı resim istemiyorum."**

Exactly.

------------------------------------------------------------------------

# 75. FEATURE INVENTORY --- MUST BE REPRESENTED

The following product capabilities must each have a dedicated visual
story or animation:

### Navigation

-   Smart Route Planning
-   Route Flyover
-   Live Navigation
-   Offline Maps
-   Map Layers
-   GPS / Location
-   Route Statistics

### Tracking

-   Live Tracking
-   Team Tracking
-   Proximity / Radar
-   Team Status
-   Activity History

### Safety

-   SOS
-   Critical Alert
-   Emergency Mode
-   Survival Guide
-   Rescue-oriented information

### Environmental

-   Fire Monitoring
-   Weather
-   Barometer
-   Terrain
-   Risk visualization where supported

### Communication

-   Chat
-   Location sharing
-   Team communication
-   Mesh / local communication concept if supported

### Social

-   Feed
-   Photo sharing
-   Followers
-   Profiles
-   Teams / Clubs
-   Likes / Comments

### Smart

-   AI Nature Advisor
-   Smart recommendations

### AR

-   Peak Finder
-   AR Compass

### Tactical

-   Radar
-   Night Operations

### Disaster

-   Earthquake Feed
-   Earthquake / Rescue Mode where supported

------------------------------------------------------------------------

# 76. FEATURE STORY TEMPLATE

Every feature should follow:

``` text
EYEBROW
↓
BIG HEADLINE
↓
ONE-SENTENCE VALUE
↓
INTERACTIVE VISUAL
↓
DATA / STATE
↓
MICRO INTERACTION
↓
NEXT FEATURE TRANSITION
```

Example:

``` text
OFFLINE MAPS

ŞEBEKE YOKSA
ROTA BİTMEZ.

Haritanı önceden indir.
Bağlantı koptuğunda rotanı kullanmaya devam et.

[INTERACTIVE MAP]

ONLINE
↓
DOWNLOADING
↓
OFFLINE

7.49 KM
+712 M
```

------------------------------------------------------------------------

# 77. DESKTOP PAGE STRUCTURE

``` text
01 PRELOADER
02 HERO
03 PRODUCT ECOSYSTEM
04 FEATURE INDEX
05 ROUTE PLANNING
06 ROUTE FLYOVER
07 LIVE TRACKING
08 TEAM
09 OFFLINE MAP
10 COMMUNICATION
11 FIRE
12 WEATHER
13 BAROMETER
14 RADAR
15 NIGHT OPS
16 SOS
17 CRITICAL ALERT
18 SURVIVAL
19 EARTHQUAKE
20 SOCIAL
21 PROFILE
22 AI
23 AR
24 GPS
25 ROUTE STATS
26 MASTER STORY
27 APP PROOF
28 DOWNLOAD CTA
29 FOOTER
```

This is intentionally long.

The website should feel like a **digital product experience**, not a
one-screen landing page.

------------------------------------------------------------------------

# 78. NAVIGATION

Header:

``` text
ROTA+
```

Links:

``` text
Ürün
Özellikler
Güvenlik
Canlı Takip
Rotalar
```

CTA:

``` text
UYGULAMAYI İNDİR
```

Clicking a nav item can smoothly scroll to the corresponding feature.

On desktop, the feature index can also remain visible as a subtle
vertical HUD.

------------------------------------------------------------------------

# 79. CURSOR SYSTEM

Desktop custom cursor:

Normal:

``` text
●
```

Interactive:

``` text
[ EXPLORE ]
```

Map:

``` text
GPS +
```

Feature:

``` text
VIEW
```

Do not make the cursor annoying.

Disable on mobile.

------------------------------------------------------------------------

# 80. AUDIO --- OPTIONAL

If sound is implemented, it must be optional.

Never autoplay loud audio.

Possible subtle sounds:

-   GPS lock
-   route completion
-   notification
-   SOS activation

Default:

``` text
SOUND OFF
```

------------------------------------------------------------------------

# 81. FINAL QUALITY TEST

Before delivering, inspect every scene as a real user.

Ask:

### At 5 seconds:

Do I know what Rota+ is?

### At 20 seconds:

Do I understand why it is useful?

### At 60 seconds:

Have I seen multiple actual capabilities?

### At 2 minutes:

Do I understand the ecosystem?

### At the end:

Do I want to install the application?

If not, redesign the storytelling.

------------------------------------------------------------------------

# 82. FINAL ANTIGRAVITY COMMAND

**Do not interpret this document as a request for a conventional landing
page.**

Build an **immersive, scroll-driven, interactive product website**.

Every feature must have its own visual explanation.

Do not solve the brief with screenshots.

Do not solve the brief with cards.

Do not solve the brief with icons.

Use:

-   animated maps
-   SVG
-   Canvas
-   route drawing
-   live data visualization
-   interactive HUDs
-   state machines
-   scroll-driven scenes
-   topology
-   signal animations
-   device UI reconstruction
-   subtle 3D
-   cinematic transitions
-   micro-interactions

The user should be able to **watch Rota+ work**.

The site should communicate:

``` text
I PLAN
I NAVIGATE
I TRACK
I CONNECT
I MONITOR
I PREPARE
I RESPOND
I SHARE
```

The entire experience should ultimately resolve into:

# ROTA+

# DOĞADA YALNIZ DEĞİLSİN.

And finally:

**UYGULAMAYI İNDİR**

No pricing.

No subscription section.

No unnecessary sales language.

No generic AI template.

No static feature wall.

No screenshot-dependent design.

**Build the product experience itself.**
