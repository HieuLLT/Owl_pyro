# TERMINAL ATTRITION — Spatial Cross-Section Engine

> **A real-time 2.5D survival game where rotating your view plane transforms walls into corridors — and brings hidden enemies out of nowhere.**

---

## Core Mechanic: The 3D-to-2D Slice

The game world is stored as a true **3D matrix `world[z][y][x]`**, but you can only *see* a 2D cross-section of it at any time.

```
[VIEW A — XY Plane, Z locked = 0]       [PRESS SHIFT]      [VIEW B — ZY Plane, X locked = 5]

. . . . . . . . . . .                                      . . . . . . . . . . .
# # # # # # # # . . .  ← WALL blocks    ─────────→         . # . . . . . . . . .  ← only 1 pillar!
. . . . . @ . . . . .    escape up                          . . . . . @ . . . . .  ← path is open
. . . . . . . . . . .                                      . . . . . . . . . . .
# # # # # # # # # # #                                      # # # # # # # # # # #

(@=player  #=wall  .=empty)
```

**Pressing Shift** locks your current X coordinate and unlocks the Z axis. The entire map re-renders from a different angle. A wall that spanned 7 tiles now appears as a single pillar — and you can walk past it.

Enemy AI runs in full 3D. An enemy chasing you on Z=0 **becomes invisible** the moment you switch to a Z slice it does not occupy. But it keeps moving toward your absolute (x,y,z) coordinates, and will **materialise** the instant it enters your current slice.

---

## Architecture

```
Twermove/
├── titan_backend/
│   ├── app.py              # Flask server — routes only, no business logic
│   ├── spatial_map.py      # Pure domain module: 3D map generation + dataclasses
│   ├── game_state.py       # Terminal Attrition narrative game state
│   ├── events.py           # Event definitions
│   └── requirements.txt
│
├── titan_frontend/
│   ├── spatial.html        # Real-time Canvas game page
│   ├── static/
│   │   ├── engine/
│   │   │   ├── constants.js       # Frozen config, palette, BFS algorithm
│   │   │   ├── entities.js        # Player + Enemy simulation classes
│   │   │   ├── world_renderer.js  # Canvas tile/entity/portal drawing
│   │   │   ├── hud_renderer.js    # HUD panel drawing
│   │   │   └── spatial_engine.js  # Orchestrator + rAF game loop
│   │   ├── atmosphere.js   # Vent art, glitch, emotion fonts
│   │   └── style.css       # Design tokens (Vent Art / Glitch-Core aesthetic)
│   └── ...
│
└── spatial_core.py         # Standalone Python terminal prototype (no server needed)
```

**Key design decisions:**
- **Python = Data.** `spatial_map.py` is Flask-free and unit-testable. The backend only generates map data once per session and sends it to the client.
- **JavaScript = Simulation + Render.** The 60fps `requestAnimationFrame` loop, real-time BFS AI, and all Canvas drawing run client-side.
- **Module separation.** `constants.js` → `entities.js` → `world_renderer.js`/`hud_renderer.js` → `spatial_engine.js`. No circular dependencies. Each module has a single responsibility.
- **BFS optimisation.** Parent-map reconstruction instead of copying the path array at every node reduces memory from O(V²) to O(V).

---

## Quick Start

### Prerequisites

- Python 3.10+
- A modern browser (Chrome, Firefox, Edge — ES Modules required)

### 1. Clone

```bash
git clone https://github.com/YOUR_USERNAME/twermove.git
cd twermove
```

### 2. Install dependencies

```bash
cd titan_backend
pip install -r requirements.txt
```

### 3. Run the server

```bash
python app.py
```

Server starts at **http://127.0.0.1:8000**.

### 4. Play

| Page | URL | Description |
|---|---|---|
| Spatial game | `http://127.0.0.1:8000/spatial` | Real-time 3D cross-section Canvas game |
| Terminal game | *(no server)* | `python spatial_core.py` in repo root |
| Terminal demo | *(no server)* | `python spatial_core.py --demo` — BFS trace + ASCII views |

---

## Controls

| Key | Action |
|---|---|
| `W` / `↑` | Move up |
| `S` / `↓` | Move down |
| `A` / `←` | Move left (X in View A, Z in View B) |
| `D` / `→` | Move right (X in View A, Z in View B) |
| **`Shift` / `P` / `Space`** | **Rotate view plane (XY ↔ ZY)** |
| `R` | Restart |
| `Esc` | Return to menu |

---

## API Reference

### `GET /api/spatial-map?seed=<int>`

Returns the 3-D world as JSON. `seed` is optional — omit for a random layout.

```jsonc
{
  "dimensions": { "x": 12, "y": 10, "z": 12 },
  "player_start": [5, 5, 0],
  "enemies": [[1, 5, 0], [8, 2, 5], [5, 5, 10]],
  "exit": [10, 1, 11],
  "world": [/* world[z][y][x] — '#' wall, '.' empty, 'X' exit */]
}
```

---

## Visual Style

- **Environment:** Depth-shaded geometric block tiles with red edge glow and bevel shading. Wall colour darkens with distance from camera (simulated depth).
- **Entities:** Pure ASCII (`@`, `E`, `F`, …) overlaid with ANSI-style glow via Canvas `shadowBlur`. The contrast between geometric tiles and text glyphs creates a "code running inside a simulation" aesthetic.
- **Atmosphere:** CRT scanlines, vent art text, glitch tears, emotion-driven typography — all from the Project Titan atmosphere layer (`atmosphere.js`, `style.css`).

---

## Content Note

This project contains themes of psychological pressure and pursuit. Some atmospheric text may reference distressing subjects. A content toggle is planned for a future release.

---

## License

MIT — see `LICENSE`.
