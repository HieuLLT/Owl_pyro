# PHẾ TÍCH Ý THỨC — *Ruins of Consciousness*
### 2D Psychological Horror · Narrative Platformer · Pure Stealth

> *"Một trò chơi không muốn bạn chơi — nó muốn bạn sống sót qua chính ký ức của mình."*

---

## 🕹️ Về Game

**мрак** (*mrak* — tiếng Nga: bóng tối / gloom) là một thực thể ý thức bị phân mảnh, nửa sinh học nửa cơ học đang hoại tử. Bạn điều khiển мрак lết qua 5 tầng của **The Residuum** — một cơ sở dữ liệu tâm trí đổ nát — thu thập ký ức bị xóa và đối mặt với chính mình.

---

## 🔑 Cơ Chế Cốt Lõi

| Phím | Hành động |
|---|---|
| `A / D` | Lết trái / phải |
| `W` | Leo dây cáp / bám thành |
| `Ctrl / ↓` | Khom / nằm xuống |
| `Space` | **Nhắm Mắt** — Sensory Deprivation |
| `E` | Tương tác / Thu thập Mảnh Ký Ức |
| `Q` (giữ) | **La Bàn Dối Trái** — Vestige Needle |

---

## ⚙️ Yêu Cầu Cài Đặt

- **Engine:** [Godot 4.3](https://godotengine.org/download) (tải bản Stable, không cần .NET)
- **Hệ điều hành:** Windows 10/11, Linux

### Cài đặt:
1. Tải Godot 4.3 từ godotengine.org
2. Mở Godot → **Import** → chọn thư mục `PheТichYThuc/`
3. Chờ import assets xong
4. Tạo các scene theo hướng dẫn trong `scenes/SCENE_SETUP_GUIDE.gd`
5. Nhấn **F5** để chạy

---

## 📁 Cấu Trúc Project

```
PheТichYThuc/
├── project.godot              ← Mở bằng Godot 4.3
├── scripts/
│   ├── core/
│   │   ├── EventBus.gd        ← Signal hub (Autoload)
│   │   ├── GameManager.gd     ← Vitals & game state (Autoload)
│   │   └── SaveSystem.gd      ← JSON save/load (Autoload)
│   ├── entities/
│   │   ├── Mrak.gd            ← мрак player controller
│   │   ├── MrakBody.gd        ← Diegetic stats on body
│   │   └── enemies/
│   │       ├── BaseEnemy.gd   ← 5-state AI + 3-axis detection
│   │       ├── Crawler.gd     ← Tier 1 — sound-based
│   │       ├── Watcher.gd     ← Tier 2 — vision cone sweep
│   │       ├── Swarmer.gd     ← Tier 3 — thermal + pack
│   │       └── Echo.gd        ← Special — invisible, audio only
│   ├── systems/
│   │   ├── SensoryDeprivation.gd  ← Nhắm Mắt mechanic
│   │   ├── SchizophrenicUI.gd     ← FIREWALL + MEMORY LEAK UI
│   │   ├── VestigeNeedle.gd       ← La Bàn Dối Trái
│   │   └── MemorySystem.gd        ← Shard data + collection
│   └── boss/
│       └── BufferOverflow.gd      ← Final boss — sonic entity
├── shaders/
│   ├── crt_scanline.gdshader
│   ├── glitch_displacement.gdshader
│   ├── vignette_dynamic.gdshader
│   ├── heat_distortion.gdshader
│   └── pixel_dissolve.gdshader
├── data/dialogues/            ← Yarn Spinner dialogue files
└── assets/                    ← Sprites, audio, fonts (add your art here)
```

---

## 🎨 Visual Style

| Layer | Style | Tool |
|---|---|---|
| Nhân vật & Kẻ thù | **Pixel Art 64×64** | Aseprite |
| Background & Kiến trúc | **Vector / Hand-drawn** | Procreate / Clip Studio |
| UI Text & Glitch FX | **Godot Shader động** | gdshader |
| Flash-back Ký ức | **2D đen trắng, phác thảo** | Clip Studio |

---

## 🗺️ Roadmap

- [x] **Milestone 0** — Project structure, EventBus, GameManager, мрак controller
- [ ] **Milestone 1** — Sensory Deprivation, Scavenger AI, Diegetic UI, Floor 0
- [ ] **Milestone 2** — Memory Puzzle, Vestige Needle, Schizophrenic UI, Floor 1
- [ ] **Milestone 3** — Full content (Floor 2-4, Boss, 3 endings, Shaders)
- [ ] **Milestone 4** — Polish, Audio, Steam build

---

## 🌑 Aesthetic References
- **Brutalist Architecture:** Barbican Centre, Park Hill, Soviet-era Panelkás
- **Trauma-core:** Silent Hill 2 (psychological horror), Disco Elysium (fractured inner voice)
- **Cybernetic Decay:** Blame! (Nihei), Evangelion Unit-01 decay sequences
- **Glitch-core:** Undertale genocide route UI manipulation

---

*Phế Tích Ý Thức v0.1 · мрак Edition*
