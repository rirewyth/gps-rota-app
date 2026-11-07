# VIDEO AI STUDIO

## AI-Powered Professional Video Generation & Creative Direction Platform

**Project Type:** AI Video Creation Platform
**Target Environment:** Google Antigravity
**Architecture:** Modular AI Pipeline
**Status:** Product Specification / Development Blueprint
**Version:** 1.0.0

---

# 1. PROJE TANIMI

VIDEO AI STUDIO, kullanıcının yalnızca bir video fikri veya kısa açıklama girerek profesyonel seviyede video üretmesini sağlayan yapay zekâ destekli yaratıcı video platformudur.

Platformun temel çalışma mantığı:

> **Fikir → Analiz → Senaryo → Görsel Yönetmenlik → Stil Seçimi → Storyboard → Video Prompt → Video Üretimi → Önizleme → Revizyon → Final**

Kullanıcı teknik video üretim bilgisine sahip olmak zorunda değildir.

Örneğin kullanıcı:

> "İzmir'de gün batımında motosiklet kullanan bir adam, sinematik ve gerçekçi olsun."

yazdığında sistem otomatik olarak:

* Sahneyi analiz eder.
* Mekânı belirler.
* Kamera açısını önerir.
* Işıklandırmayı belirler.
* Hareketleri tanımlar.
* Uygun video stilini seçer.
* Süreyi belirler.
* Shot list oluşturur.
* Profesyonel video promptu oluşturur.
* Video üretim motoruna gönderir.
* Sonucu kullanıcıya gösterir.

---

# 2. ANA HEDEF

Platformun amacı:

**"Bir fikir yaz, profesyonel videoya dönüştür."**

Kullanıcıdan teknik prompt yazmasını isteme.

Sistem kullanıcının doğal dilde verdiği fikri anlayarak profesyonel video üretim parametrelerine dönüştürmelidir.

---

# 3. HEDEF KULLANICI

Platform aşağıdaki kullanıcı gruplarına hitap etmelidir:

* Sosyal medya içerik üreticileri
* YouTuberlar
* Instagram içerik üreticileri
* Reklam ajansları
* Markalar
* Sinema/video ekipleri
* Freelancer video editörleri
* Pazarlama ekipleri
* Film öğrencileri
* Kurumsal şirketler
* Bireysel kullanıcılar

Teknik bilgi seviyesi:

**Başlangıç → Profesyonel**

---

# 4. TEMEL KULLANICI AKIŞI

## STEP 01 — FİKİR

Ana ekranda büyük bir fikir kutusu bulunmalıdır.

Placeholder:

> "Nasıl bir video oluşturmak istiyorsun?"

Örnek:

> "Yağmurlu bir gecede İstanbul sokaklarında yürüyen bir adam. Sinematik, karanlık ve gerçekçi."

Buton:

**FİKRİ VİDEOYA DÖNÜŞTÜR**

---

# 5. AI FİKİR ANALİZ MOTORU

Kullanıcı fikri gönderdiğinde AI aşağıdaki parametreleri otomatik çıkarmalıdır:

```json
{
  "subject": "",
  "environment": "",
  "location": "",
  "time_of_day": "",
  "weather": "",
  "lighting": "",
  "camera": "",
  "camera_movement": "",
  "composition": "",
  "action": "",
  "emotion": "",
  "visual_style": "",
  "realism": "",
  "duration": "",
  "aspect_ratio": "",
  "audio": "",
  "color_grading": ""
}
```

AI eksik bilgileri kendisi tamamlayabilmelidir.

Ancak kullanıcı tarafından açıkça belirtilen bilgiler ASLA değiştirilmemelidir.

---

# 6. VİDEO MODLARI

Platformun en önemli özelliklerinden biri farklı üretim modlarıdır.

## 6.1 REALISTIC MODE

Gerçek kamera ile çekilmiş hissi.

Özellikler:

* Photorealistic
* Natural skin texture
* Real-world lighting
* Physical camera behavior
* Natural motion blur
* Realistic shadows
* Realistic reflections
* Natural depth of field
* Cinematic lens characteristics

Hedef:

> İzleyici bunun AI üretimi olduğunu ilk bakışta anlamamalıdır.

---

## 6.2 CINEMATIC MODE

Film estetiği.

Özellikler:

* Cinema camera
* Anamorphic lens
* Cinematic lighting
* Depth of field
* Film grain
* Professional color grading
* Controlled camera movement
* Dramatic composition

---

## 6.3 ANIMATION MODE

Profesyonel animasyon üretimi.

Alt modlar:

* 2D Animation
* 3D Animation
* Stylized Animation
* Cartoon
* Anime-inspired
* Motion Graphics
* Cinematic Animation

---

## 6.4 HYPER REALISTIC MODE

Maksimum gerçekçilik.

Özellikler:

* Ultra detailed textures
* Realistic skin
* Physically accurate lighting
* Natural imperfections
* Realistic environment
* Realistic motion
* High detail
* Photographic composition

---

## 6.5 COMMERCIAL MODE

Reklam filmi üretimi.

Özellikler:

* Product hero shot
* Brand-focused composition
* Premium lighting
* Controlled camera movement
* Product close-ups
* Slow motion
* Advertising-grade color grading

---

## 6.6 SOCIAL MEDIA MODE

Dikey sosyal medya videoları.

Platformlar:

* Instagram Reels
* TikTok
* YouTube Shorts

Default:

**9:16**

Önerilen süre:

**5–30 saniye**

---

## 6.7 DOCUMENTARY MODE

Belgesel estetiği.

Özellikler:

* Natural camera movement
* Handheld camera
* Natural lighting
* Real environments
* Documentary framing
* Authentic atmosphere

---

## 6.8 TRAILER MODE

Film fragmanı estetiği.

Özellikler:

* Dramatic cuts
* Dynamic camera
* Hero shots
* Atmospheric lighting
* Fast/slow pacing
* Cinematic transitions

---

# 7. OTOMATİK MOD SEÇİMİ

Kullanıcı mod seçmezse AI otomatik karar vermelidir.

Örneğin:

> "Yeni telefonum için reklam videosu."

AI:

**COMMERCIAL MODE**

> "Dağda yürüyen gerçek bir adam."

AI:

**REALISTIC MODE**

> "Ejderhanın şehre saldırdığı fantastik sahne."

AI:

**CINEMATIC / HYPER REALISTIC**

> "Anime tarzında savaş sahnesi."

AI:

**ANIMATION MODE**

Kullanıcı isterse AI önerisini değiştirebilir.

---

# 8. STYLE SELECTOR

Kullanıcıya görsel stil seçenekleri sunulmalıdır.

Örnek:

### REALISTIC

Gerçek kamera

### CINEMATIC

Film estetiği

### DARK

Karanlık atmosfer

### FUTURISTIC

Gelecek teknolojisi

### VINTAGE

Retro film

### DOCUMENTARY

Belgesel

### LUXURY

Premium reklam

### EPIC

Büyük ölçekli sinematik

### MINIMAL

Sade ve temiz

### DREAMLIKE

Gerçeküstü

### ANIMATION

Animasyon

### CUSTOM

Kullanıcının kendi stili

---

# 9. AI CREATIVE DIRECTOR

Platformun merkezi zekâsı "AI Creative Director" olmalıdır.

AI Creative Director:

1. Kullanıcı fikrini analiz eder.
2. Fikrin amacını belirler.
3. Uygun video modunu önerir.
4. Görsel dili oluşturur.
5. Kamera dilini belirler.
6. Işıklandırmayı belirler.
7. Renk paletini oluşturur.
8. Kamera hareketlerini belirler.
9. Sahne sıralamasını oluşturur.
10. Video promptunu hazırlar.
11. Negative prompt oluşturur.
12. Ses tasarımını önerir.
13. Final üretim parametrelerini oluşturur.

---

# 10. STORYBOARD SYSTEM

Video üretiminden önce AI storyboard oluşturmalıdır.

Örnek:

### SHOT 01

**Duration:** 3 sec

**Scene:**
Gece vakti yağmurlu İstanbul sokağı.

**Camera:**
Low-angle tracking shot.

**Subject:**
Siyah montlu erkek karakter.

**Movement:**
Karakter kameraya doğru yürür.

**Lighting:**
Sokak lambaları + araç farları.

---

### SHOT 02

**Duration:** 2 sec

**Camera:**
Close-up.

**Subject:**
Karakterin yüzü.

**Lighting:**
Soft neon reflections.

---

### SHOT 03

**Duration:** 4 sec

**Camera:**
Wide cinematic shot.

**Action:**
Karakter kalabalık caddede yürümeye devam eder.

---

# 11. PROMPT ENGINE

Platform kullanıcıya yalnızca basit bir prompt üretmemelidir.

Profesyonel prompt aşağıdaki yapıda oluşturulmalıdır:

```text
SUBJECT

ENVIRONMENT

ACTION

CAMERA

LENS

CAMERA MOVEMENT

LIGHTING

COMPOSITION

DEPTH OF FIELD

MATERIALS

ATMOSPHERE

COLOR GRADING

MOTION

REALISM

AUDIO

NEGATIVE PROMPT
```

---

# 12. NEGATIVE PROMPT ENGINE

AI otomatik olarak hataları azaltacak negative prompt üretmelidir.

Örnek:

```text
deformed anatomy,
extra fingers,
extra limbs,
unnatural face,
plastic skin,
artificial movement,
floating objects,
warped background,
flickering,
frame inconsistency,
unstable geometry,
distorted hands,
bad physics,
unnatural shadows,
low detail,
compression artifacts
```

Mode'a göre negative prompt otomatik değişmelidir.

---

# 13. VIDEO PARAMETERS

Kullanıcı veya AI aşağıdaki ayarları belirleyebilmelidir:

### Duration

* 5 sec
* 10 sec
* 15 sec
* 30 sec
* 60 sec

### Aspect Ratio

* 16:9
* 9:16
* 1:1
* 4:5
* 21:9

### Resolution

* 720p
* 1080p
* 2K
* 4K

### FPS

* 24
* 25
* 30
* 60

### Camera

* Static
* Handheld
* Gimbal
* Drone
* Dolly
* Tracking
* Crane
* FPV

---

# 14. CAMERA INTELLIGENCE

AI kamera hareketini rastgele seçmemelidir.

Sahneye göre uygun kamera hareketini belirlemelidir.

Örnek:

Duygusal sahne:

> Slow push-in

Aksiyon:

> Dynamic tracking

Manzara:

> Slow cinematic crane

Ürün:

> Controlled orbit

Gerilim:

> Handheld subtle movement

Sosyal medya:

> Dynamic vertical tracking

---

# 15. AUDIO INTELLIGENCE

Video sadece görüntü üretmemelidir.

AI aşağıdaki sesleri de analiz etmelidir:

* Background ambience
* Footsteps
* Wind
* Rain
* Traffic
* Birds
* Nature
* Dialogue
* Foley
* Cinematic impacts
* Music suggestion

Kullanıcı:

**AI AUDIO**

seçeneğini açabilmelidir.

---

# 16. VOICE / DIALOGUE

Kullanıcı video fikrine konuşma ekleyebilir.

Örnek:

> "Adam kameraya dönüp 'Burası düşündüğümden çok daha güzelmiş' desin."

AI:

* Dialogue
* Voice tone
* Emotion
* Lip synchronization
* Timing

parametrelerini oluşturmalıdır.

---

# 17. CHARACTER CONSISTENCY

Aynı karakter birden fazla sahnede kullanılıyorsa:

**Character Lock**

aktif olmalıdır.

Sistem karakter özelliklerini saklamalıdır:

```json
{
  "gender": "",
  "age_range": "",
  "hair": "",
  "face": "",
  "clothing": "",
  "body_type": "",
  "accessories": ""
}
```

Sonraki sahnelerde karakter değişmemelidir.

---

# 18. OBJECT CONSISTENCY

Aynı araç, ürün veya nesne farklı sahnelerde kullanılıyorsa görünümü korunmalıdır.

Örnek:

Bir otomobil:

* Model
* Renk
* Jant
* Plaka
* Hasar
* Body shape

değişmemelidir.

---

# 19. IMAGE-TO-VIDEO

Kullanıcı referans görsel yükleyebilmelidir.

Sistem:

**IMAGE → VIDEO**

dönüşümü yapmalıdır.

Kullanıcı seçenekleri:

* Animate
* Camera movement
* Character movement
* Environment movement
* Cinematic motion
* Product animation

---

# 20. TEXT-TO-VIDEO

Ana üretim sistemi:

**TEXT → VIDEO**

olmalıdır.

---

# 21. VIDEO-TO-VIDEO

Mevcut videonun stilini değiştirme:

* Cinematic
* Realistic
* Animation
* Vintage
* Futuristic
* Commercial

---

# 22. AI IDEA ENHANCER

Kullanıcı çok kısa fikir yazabilir.

Örneğin:

> "Dağ videosu"

AI bunu otomatik olarak geliştirmelidir:

> "Gün doğumunda sisli bir dağ zirvesinde yürüyen yalnız bir dağcı, drone kamera ile geniş açıdan takip ediliyor..."

Kullanıcıya:

**AI FİKRİ GELİŞTİRSİN**

butonu gösterilmelidir.

---

# 23. IDEA GENERATOR

Kullanıcı isterse AI kendisi fikir üretebilmelidir.

Kategori seçenekleri:

* Social Media
* Advertisement
* Travel
* Adventure
* Nature
* Technology
* Fashion
* Automotive
* Cinema
* Horror
* Documentary
* Product
* Brand
* Education

Buton:

**FİKİR ÜRET**

AI 5 farklı konsept oluşturmalıdır.

---

# 24. VIDEO PREVIEW

Üretim tamamlandığında:

* Video preview
* Play/Pause
* Timeline
* Fullscreen
* Download
* Regenerate
* Edit
* Extend
* Shorten
* Change Style

özellikleri bulunmalıdır.

---

# 25. REGENERATE SYSTEM

Kullanıcı videoyu tamamen yeniden üretmek zorunda olmamalıdır.

Seçenekler:

**Regenerate Scene**

**Change Camera**

**Change Lighting**

**Change Character**

**Change Style**

**Make More Realistic**

**Make More Cinematic**

**Make More Dynamic**

---

# 26. AI EDITOR

Basit timeline tabanlı editör.

Kullanıcı:

* Shot sıralamasını değiştirebilir.
* Shot silebilir.
* Shot uzatabilir.
* Yeni shot ekleyebilir.
* Müzik değiştirebilir.
* Ses ekleyebilir.
* Text overlay ekleyebilir.

---

# 27. AUTOMATIC SOCIAL MEDIA EXPORT

Video tamamlandığında AI platforma göre optimize etmelidir.

Instagram:

**9:16 / 1080x1920**

TikTok:

**9:16 / 1080x1920**

YouTube:

**16:9**

YouTube Shorts:

**9:16**

---

# 28. UI / UX TASARIMI

Arayüz modern AI creative studio hissi vermelidir.

Tasarım dili:

* Premium
* Minimal
* Dark UI
* High contrast
* Smooth animations
* Glassmorphism
* Subtle gradients
* Professional typography

Ana renkler:

```text
Background: #080808
Surface: #111111
Primary: #FFFFFF
Secondary: #A0A0A0
Accent: #6C5CE7
```

Accent renk gerektiğinde AI ürünün temasına göre değiştirebilmelidir.

---

# 29. ANA SAYFA

Ana sayfa:

```text
----------------------------------------

VIDEO AI STUDIO

Turn your ideas into professional videos.

[ Describe your idea...                 ]

[ AI ENHANCE ]     [ GENERATE VIDEO ]

----------------------------------------

Choose your style

[ Realistic ]
[ Cinematic ]
[ Animation ]
[ Commercial ]
[ Documentary ]

----------------------------------------

Recent Projects

[ Project ] [ Project ] [ Project ]

----------------------------------------
```

---

# 30. GENERATION SCREEN

Video üretilirken kullanıcı boş bir loading ekranı görmemelidir.

AI'ın yaptığı işlemler gösterilmelidir:

```text
✓ Analyzing idea
✓ Building story
✓ Selecting visual style
✓ Designing camera movement
✓ Creating storyboard
✓ Optimizing prompt
● Generating video
○ Applying cinematic processing
○ Finalizing
```

AI'nın çalıştığı hissedilmelidir.

---

# 31. AI EXPLANATION

Üretim sırasında kısa açıklamalar:

> "I'm designing a low-angle cinematic shot to emphasize the character."

> "The lighting is being adjusted for a natural sunset look."

> "Character consistency is locked across all scenes."

Bu mesajlar kısa olmalıdır.

---

# 32. PROJECT SYSTEM

Her video proje olarak kaydedilmelidir.

Project:

```json
{
  "id": "",
  "name": "",
  "idea": "",
  "style": "",
  "duration": "",
  "aspect_ratio": "",
  "storyboard": [],
  "prompts": [],
  "assets": [],
  "versions": [],
  "created_at": ""
}
```

---

# 33. VERSION CONTROL

Her üretim versiyon olarak kaydedilmelidir.

Örneğin:

```text
Version 1
Version 2
Version 3
Version 4
```

Kullanıcı eski versiyona geri dönebilmelidir.

---

# 34. AI MODEL ABSTRACTION

Video üretim sistemi tek bir AI modeline bağımlı olmamalıdır.

Architecture:

```text
VIDEO ENGINE
      ↓
MODEL ADAPTER
      ↓
---------------------------
| Model A | Model B | Model C |
---------------------------
```

Böylece gelecekte farklı video üretim API'leri kolayca eklenebilmelidir.

---

# 35. API ARCHITECTURE

Önerilen yapı:

```text
Frontend
   ↓
API Gateway
   ↓
AI Orchestrator
   ↓
Creative Director
   ↓
Prompt Engine
   ↓
Video Model Adapter
   ↓
Video Generation
   ↓
Post Processing
   ↓
Storage
   ↓
Frontend
```

---

# 36. AI ORCHESTRATOR

AI Orchestrator bütün sistemi yönetmelidir.

Görevleri:

1. User Input
2. Intent Detection
3. Idea Enhancement
4. Mode Selection
5. Story Generation
6. Shot Generation
7. Prompt Creation
8. Video Generation
9. Quality Check
10. Regeneration if necessary
11. Final Delivery

---

# 37. QUALITY CONTROL AI

Video üretildikten sonra ikinci bir AI kalite kontrol yapmalıdır.

Kontrol:

* Face consistency
* Hand anatomy
* Object consistency
* Motion stability
* Lighting consistency
* Background stability
* Physics
* Frame flickering
* Artifacts
* Prompt compliance

Kalite düşükse sistem:

**Automatic Regeneration**

başlatabilmelidir.

---

# 38. SMART AUTO-REGENERATION

Örneğin:

AI kalite kontrol:

```text
Face consistency: 92%
Motion: 96%
Lighting: 94%
Background: 88%
Overall: 93%
```

Minimum kalite eşiği:

**90%**

Altındaysa sistem sorunlu alanı belirleyerek yeniden üretmelidir.

---

# 39. PROMPT PREVIEW

İleri seviye kullanıcılar için:

**View AI Prompt**

özelliği olmalıdır.

Kullanıcı:

* Promptu görebilir.
* Düzenleyebilir.
* Kopyalayabilir.
* Yeniden üretebilir.

Başlangıç kullanıcılarında teknik detaylar gizlenebilir.

---

# 40. SIMPLE / PRO MODE

## SIMPLE MODE

Kullanıcı sadece:

* Fikir
* Stil
* Süre
* Oran

seçer.

Geri kalanını AI yapar.

## PRO MODE

Kullanıcı:

* Kamera
* Lens
* FPS
* Lighting
* Color grading
* Motion
* Seed
* Negative prompt
* Character lock
* Object lock

gibi gelişmiş seçenekleri değiştirebilir.

---

# 41. SMART DEFAULTS

Kullanıcı hiçbir ayar seçmezse sistem:

```text
Mode: Auto
Style: AI Selected
Duration: 10 sec
Aspect Ratio: 16:9
FPS: 24
Quality: High
Audio: Auto
Camera: AI Selected
```

kullanmalıdır.

---

# 42. ERROR HANDLING

Video üretimi başarısız olursa teknik hata kullanıcıya gösterilmemelidir.

Örneğin:

KÖTÜ:

> API Error 500

İYİ:

> "Video üretimi tamamlanamadı. Sahneyi yeniden optimize ediyoruz."

Buton:

**TEKRAR DENE**

---

# 43. COST AWARENESS

Sistem üretim maliyetini kontrol etmelidir.

Kullanıcı üretimden önce:

> Estimated generation cost

görebilir.

AI mümkün olduğunda daha düşük maliyetli modeli seçebilir.

---

# 44. SECURITY

API anahtarları frontend içerisinde tutulmamalıdır.

Tüm hassas anahtarlar:

**SERVER SIDE**

saklanmalıdır.

Rate limiting uygulanmalıdır.

Authentication uygulanmalıdır.

User project isolation uygulanmalıdır.

---

# 45. DATABASE

Önerilen:

**Firebase / PostgreSQL**

Database tabloları:

```text
users
projects
generations
shots
prompts
assets
models
subscriptions
usage
```

---

# 46. STORAGE

Video ve görseller:

* Cloud Storage
* CDN
* Signed URLs

üzerinden sunulmalıdır.

Büyük video dosyaları doğrudan uygulama sunucusunda tutulmamalıdır.

---

# 47. RESPONSIVE DESIGN

Platform:

* Desktop
* Laptop
* Tablet
* Mobile

uyumlu olmalıdır.

Desktop ana üretim deneyimi olmalıdır.

---

# 48. PERFORMANCE

Hedefler:

* Fast UI
* Lazy loading
* Progressive preview
* Background generation
* Queue system
* CDN delivery

Video üretimi frontend'i bloke etmemelidir.

---

# 49. GENERATION QUEUE

Birden fazla üretim olduğunda:

```text
Queued
Processing
Rendering
Post Processing
Completed
Failed
```

durumları takip edilmelidir.

---

# 50. FUTURE FEATURES

Mimari aşağıdaki özelliklere açık bırakılmalıdır:

* AI voice generation
* Lip sync
* AI music
* AI sound effects
* Automatic subtitles
* Multi-language video
* Digital avatars
* Virtual presenters
* Product placement
* Brand kit
* Team collaboration
* Shared projects
* Cloud editing
* API access
* Batch generation
* Template marketplace
* AI director presets
* Custom AI styles

---

# 51. MVP

İlk sürümde mutlaka çalışması gereken özellikler:

### CORE

* Idea input
* AI idea analysis
* Automatic style selection
* Realistic mode
* Cinematic mode
* Animation mode
* Social media mode
* Text-to-video
* Storyboard generation
* Prompt generation
* Video generation
* Preview
* Regenerate
* Project saving

### ADVANCED

* Image-to-video
* Character consistency
* Negative prompt
* Aspect ratio
* Duration
* Simple / Pro mode

---

# 52. MVP USER JOURNEY

```text
USER
 ↓
ENTER IDEA
 ↓
AI ANALYSIS
 ↓
AI CREATIVE DIRECTOR
 ↓
STYLE SELECTION
 ↓
STORYBOARD
 ↓
PROMPT ENGINE
 ↓
VIDEO GENERATION
 ↓
QUALITY CONTROL
 ↓
AUTO REGENERATION IF NEEDED
 ↓
VIDEO PREVIEW
 ↓
EDIT / REGENERATE
 ↓
EXPORT
```

---

# 53. ÖRNEK KULLANIM

USER:

> "İzmir'de yağmurlu bir gecede motosiklet kullanan genç bir adam. Film gibi olsun."

AI OUTPUT:

```text
Mode:
Cinematic Realism

Duration:
10 sec

Aspect:
16:9

Environment:
Rainy İzmir city street

Lighting:
Wet asphalt reflections,
street lamps,
vehicle headlights

Camera:
Low-angle tracking shot

Lens:
35mm cinematic lens

Movement:
Smooth tracking movement

Color:
Dark teal shadows,
warm highlights

Atmosphere:
Moody cinematic night

Audio:
Rain,
engine,
city ambience
```

AI storyboard:

```text
SHOT 01 — 3 sec
Wide establishing shot

SHOT 02 — 4 sec
Tracking motorcycle shot

SHOT 03 — 3 sec
Close-up character shot
```

Ardından video üretimi başlatılır.

---

# 54. AI SYSTEM PROMPT PRENSİBİ

AI'nın temel görevi:

> "You are an expert film director, cinematographer, storyboard artist, VFX supervisor, video prompt engineer and creative director."

AI her kullanıcı fikrini profesyonel video üretim planına dönüştürmelidir.

AI:

* Gereksiz detay eklememeli.
* Kullanıcının ana fikrini değiştirmemeli.
* Fiziksel olarak mümkün olmayan hareketleri kontrol etmeli.
* Karakter tutarlılığını korumalı.
* Kamera hareketlerini sahneye uygun seçmeli.
* Görsel kaliteyi maksimuma çıkarmalı.

---

# 55. IMPORTANT PRODUCT PRINCIPLE

Platform:

**"Prompt Generator"**

olarak tasarlanmamalıdır.

Platformun gerçek amacı:

> **AI Video Director + AI Video Generator**

olmaktır.

Prompt üretimi sistemin yalnızca bir parçasıdır.

Kullanıcı mümkün olduğunca az teknik bilgiyle profesyonel sonuç almalıdır.

---

# 56. ANTIGRAVITY DEVELOPMENT INSTRUCTION

Google Antigravity bu dokümanı temel alarak uygulamayı modüler ve ölçeklenebilir şekilde geliştirmelidir.

Öncelik sırası:

```text
1. UI/UX
2. Idea Input
3. AI Creative Director
4. Storyboard Engine
5. Prompt Engine
6. Video Model Adapter
7. Generation Queue
8. Video Preview
9. Regeneration
10. Project Management
11. Quality Control
12. Pro Features
```

Kod yapısı gelecekte yeni AI video modelleri eklenebilecek şekilde abstraction kullanmalıdır.

Tek bir video üretim sağlayıcısına hard-code bağımlılık oluşturulmamalıdır.

---

# 57. FINAL PRODUCT VISION

VIDEO AI STUDIO'nun nihai deneyimi şu kadar basit olmalıdır:

```text
Kullanıcı:

"Gece ormanda yürüyen bir dağcı.
Sisli, gizemli ve gerçekçi olsun."

↓

AI:

Fikri analiz eder.

↓

AI:

En uygun video stilini seçer.

↓

AI:

Storyboard oluşturur.

↓

AI:

Kamera + ışık + hareket + atmosfer tasarlar.

↓

AI:

Profesyonel video promptunu oluşturur.

↓

AI:

Video üretir.

↓

AI:

Kaliteyi kontrol eder.

↓

AI:

Gerekirse hatalı sahneyi yeniden üretir.

↓

USER:

Videoyu izler.

↓

USER:

"Biraz daha sinematik yap."

↓

AI:

Aynı projeyi yeni versiyon olarak üretir.
```

---

# 58. CORE PRODUCT PHILOSOPHY

**ONE IDEA.
ONE CLICK.
PROFESSIONAL VIDEO.**

Kullanıcı prompt mühendisliği öğrenmek zorunda değildir.

Kullanıcı yönetmen olmak zorunda değildir.

Kullanıcı kamera tekniklerini bilmek zorunda değildir.

Sistem bütün yaratıcı ve teknik süreci AI ile yönetmelidir.

**Kullanıcı fikri verir.
AI yönetmenlik yapar.
Video sistemi üretir.**

---

# END OF SPECIFICATION
