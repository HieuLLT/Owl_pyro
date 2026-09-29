# Project Titan → TERMINAL ATTRITION
### Project review · Formal build instructions · Remove/Update report

Status of source reviewed: `Twermove/titan_backend` (FastAPI), `Twermove/titan_frontend` (static HTML/CSS/JS), root `README.md` (empty).

---

## PART 1 — PROJECT REVIEW

### 1.1 What exists today

| Layer | Files | Role today |
|---|---|---|
| Backend (FastAPI) | `api/main.py`, `api/schemas.py`, `engine/generator.py`, `engine/validator.py`, `core/node.py`, `core/enums.py` | Generates a 3D cylindrical BST/AVL graph, validates a run |
| Frontend pages | `index.html`, `settings.html`, `play.html`, `preview.html` | Menu, level config, canvas game, dev hub |
| Frontend assets | `static/style.css`, `static/vent.js`, `static/game.js` | Theme, animated vent text, cylinder-tower engine |
| Tooling | `links.py`, `links.txt`, `requirements.txt` | Local static server on :3000, link list |

The strongest asset is the **atmosphere layer** (vent art, emotion fonts, flash monologue, system tear, brutalist buttons). The pivot keeps all of it. The **mechanics layer** (graph generator, validator, cylinder game) is fully replaced.

### 1.2 Findings that block or affect the pivot

1. **No `app.py`, and no Flask.** The backend is FastAPI + Pydantic. The pivot specifies Flask. `requirements.txt` must change.
2. **`.system-tear` exists only inside `index.html`'s inline `<style>` and inline JS.** `play.html` loads only `style.css`, so the Integrity → glitch hook cannot work on the game page until this CSS and the scheduler are moved into shared files.
3. **The emotion classes (`.flash-phrase.is-rage/envy/despair/shame/hatred`, `.vent-phrase.*-tint`) and the 220-node chaos background are also inline in `index.html`.** They must be extracted so the game page can use them (this is also what keeps the emotion fonts alive on the game page).
4. **Backend URL is hardcoded** (`http://127.0.0.1:8000`) in `index.html` and `settings.html`, plus a CORS allow-list for :3000/:5173/:8080. Serving the frontend from Flask removes both problems.
5. **Scanline overlay conflict:** `style.css` draws CRT scanlines on `body::after`; `index.html` redefines `body.system-tear::after`, so the scanlines vanish during every tear. Use a dedicated overlay element for the tear lines.

### 1.3 Bugs in the old code (evidence for dropping it, not fixing it)

- `/validate-run` would return **HTTP 500**: `main.py` reads `nr["delta_ms"]`, `["expected_input"]`, `["actual_input"]` from the validator output, but the validator only returns `node_id` and `verdict` (and `NodeResult` in `schemas.py` has no such fields).
- `game.js → _climb()`: main-chain nodes have `left_child_id`/`right_child_id = null`, so from node 0 `children.length === 0` fires and the game declares **instant victory**.
- `game.js` never calls `/validate-run`; the client is authoritative even though `preview.html` says the backend validates the run.
- `LevelConfig` has no `tolerance_ms` but the frontend sends it (silently ignored).
- `PlayerAction` example in `schemas.py` doesn't match the model (`actual_time_ms`, `actual_input`).
- `ModType` docstrings describe tempo multipliers the generator no longer uses.

### 1.4 Performance and hygiene

- `index.html` animates **220 spans** by rewriting `style.left/top` every frame (forces layout each frame) and applies per-element `filter: blur()`. Use `transform`, cap the count on the game page (~80), and pre-bucket blur levels.
- Google Fonts are pulled with a **blocking `@import`**; dev on an offline machine silently falls back.
- Local font files use awkward paths (`[UEE] Press Start2P.ttf`, `TeddyUpdates_25.3.2019/…`, a name with spaces). Rename and move to `static/fonts/`.
- `links.txt` contains a personal absolute path (`C:\Users\PREDATOR\OneDrive\...`). Delete it.
- `README.md` is empty.
- The monologue contains strong language and themes of despair and self-hatred. That fits the concept, but add a short **content note** on the title screen.

### 1.5 Gaps and contradictions in the concept as written (must be resolved before coding)

| # | Issue | Why it matters | Decision made in this spec |
|---|---|---|---|
| A | The concept says a stat at 0 triggers an effect (scramble / permanent glitch / auto-pick worst). Task 1 says any stat ≤ 0 = Game Over. | With the Game Over rule, the zero-stat effects can never be seen. | A stat ≤ 0 becomes **collapsed** (effect latches on). **Game Over when two or more stats are collapsed**, or when any stat has been collapsed for 3 consecutive cycles. |
| B | The sample choices never touch Willpower. | Willpower only drains: total drain = 8·(1.25ⁿ − 1), which passes 100 at **cycle 12**. Every run would end at ~cycle 12 with the same cause. | Some events must change Willpower (see 2.4 content rules). |
| C | "Drain at the start of every cycle" vs Task 1 order (choice → drain → increment). | Ambiguous which cycle's drain applies. | New game applies drain(1). On each transition: apply choice → increment cycle → apply drain(new cycle). |
| D | "Flask server managing game state" with one `GameState`. | A single global object is shared by every tab/player. | One `GameState` **per run**, keyed by `run_id`. |
| E | Client sends "the player's choice". | If the client sent deltas it could cheat. | Client sends only `choice_id` (`"A"`/`"B"`); the server looks up deltas from the current event it issued. |
| F | "Drains 2%". | Percent of current value never reaches 0. | Drain is **flat points on the 0–100 scale**. |
| G | Stats can rise (+10) with no ceiling. | Stat could exceed 100 and break bars. | Clamp every stat to **[0, 100]**. |
| H | Memory 0 scrambles "the screen text". | Scrambling the choice buttons makes the game unplayable. | Scramble narrative text and background; **numbers, bar labels and delta chips stay legible**. |
| I | Integrity 0 = "permanent and blinding" glitch. | Strobing is a photosensitivity hazard. | Cap flashes to ≤ 3 per second; honour `prefers-reduced-motion`; add an in-game toggle. Permanent effect = heavy static tear, not a strobe. |

Drain math used throughout: `drain(n) = 2 · 1.25^(n−1)` → cycle 1 = 2.0, 5 = 4.9, 10 = 14.9, 12 = 23.3, 15 = 44.8.

---

## PART 2 — FORMAL BUILD INSTRUCTIONS

Read this whole part before writing code. Where this document conflicts with the earlier prompt, this document wins.

### 2.1 Scope

**In scope:** a turn-based, narrative, resource-drain game. Flask backend, plain HTML/CSS/JS frontend, existing dark brutalist trauma-core theme.

**Out of scope / must be deleted:** grids, mazes, rotating tower, BST/AVL logic, canvas rendering, BFS ping, beatmaps, tolerance/tempo, ModTypes, level seeds as level generators.

### 2.2 Target layout

```
Twermove/
  README.md                      (rewrite)
  titan_backend/
    requirements.txt             flask>=3.0
    app.py                       Flask app + routes + static serving
    game_state.py                GameState, constants, drain/clamp/game-over logic
    events.py                    EVENTS list + validation helper
    tests/test_game_state.py
  titan_frontend/
    index.html  play.html  settings.html  preview.html
    static/
      style.css                  theme + moved shared CSS
      atmosphere.js              chaos background + system tear + scramble (shared)
      vent.js                    trimmed
      game.js                    new UI/API controller
      fonts/                     renamed local fonts
```

`app.py` creates `Flask(__name__, static_folder="../titan_frontend", static_url_path="")` so pages load at `http://127.0.0.1:8000/index.html` and every `fetch` is same-origin and relative (`/api/...`). No CORS needed. Run with `python app.py` on port **8000** (keeps the existing footer text accurate).

### 2.3 Backend specification (`game_state.py`, `app.py`)

**Constants**

```
START_STAT       = 100
STAT_MIN, MAX    = 0, 100
BASE_DRAIN       = 2.0
DRAIN_GROWTH     = 1.25
COLLAPSE_LIMIT   = 3     # consecutive cycles a stat may stay at 0
```

**`GameState` (dataclass) fields**
`run_id: str`, `cycle: int = 1`, `stats: dict{memory, integrity, willpower}`, `collapsed_streak: dict[stat → int]`, `current_event_id: str`, `event_bag: list[str]` (shuffle bag), `rng: random.Random`, `game_over: bool`, `game_over_reason: str | None`, `created_at: float`.

**Methods**
- `drain_for(cycle) -> float` = `BASE_DRAIN * DRAIN_GROWTH ** (cycle - 1)`.
- `apply_delta(delta: dict)` — add, then clamp all stats to [0, 100].
- `apply_drain()` — subtract `drain_for(self.cycle)` from all three stats, clamp.
- `worst_choice(event) -> choice_id` — the choice with the most negative sum of deltas; tie → the one that leaves the lowest single stat.
- `advance(choice_id) -> dict` — executes the transition below.
- `draw_event()` — pop from shuffle bag; refill and reshuffle when empty; never repeat the same event twice in a row across a refill.

**Transition order in `advance(choice_id)` (must be exactly this)**
1. Reject if `game_over`.
2. If `willpower <= 0` → `choice_id = worst_choice(current_event)` and set `overridden = True`.
3. Apply the chosen choice's delta (from the server-side event, never from the client).
4. `cycle += 1`.
5. Apply `drain_for(cycle)`.
6. Update collapse streaks: for each stat, `streak = streak + 1 if stat <= 0 else 0`.
7. Game over if **≥ 2 stats ≤ 0** (reason `"MULTI_SYSTEM_COLLAPSE"`) or **any streak ≥ COLLAPSE_LIMIT** (reason `"<STAT>_TERMINAL"`).
8. If not over, `draw_event()` and store `current_event_id`.
9. Return payload (below).

**Endpoints**

`POST /api/new-game` (body optional: `{"seed": int|null}`)
→ creates a run, applies `drain_for(1)`, draws event 1.
```json
{
  "run_id": "uuid4",
  "cycle": 1,
  "stats": {"memory": 98.0, "integrity": 98.0, "willpower": 98.0},
  "collapsed": {"memory": false, "integrity": false, "willpower": false},
  "drain_next": 2.5,
  "game_over": false,
  "event": {
    "id": "face_burning", "emotion": "despair",
    "text": "A memory of a face is burning out. Power the eyes, or let it fade?",
    "choices": [
      {"id": "A", "label": "SAVE THE EYES", "delta": {"memory": 10, "integrity": -25, "willpower": 0}},
      {"id": "B", "label": "LET IT BURN",  "delta": {"memory": -25, "integrity": 10, "willpower": 0}}
    ]
  }
}
```
`delta` is sent **for display only**.

`POST /api/next-cycle` — body `{"run_id": "...", "choice_id": "A" | "B"}`
```json
{
  "run_id": "...", "cycle": 2,
  "stats": {"memory": 0, "integrity": 0, "willpower": 0},
  "collapsed": {"memory": false, "integrity": false, "willpower": false},
  "applied": {"chosen_id": "A", "overridden": false, "choice_delta": {}, "drain": 2.5},
  "drain_next": 3.1,
  "game_over": false, "game_over_reason": null,
  "cycles_survived": 1,
  "event": { "…same shape as above…" }
}
```
On game over: `event` is `null`, `game_over: true`, `cycles_survived = cycle - 1`.

`GET /api/state?run_id=…` — returns the same payload as the last response (for page reload resume).

**Errors** (JSON `{"error": "..."}`): `400` bad/missing `choice_id` or `run_id`; `404` unknown `run_id`; `409` run already over.

**Run store:** in-memory `dict[run_id → GameState]` guarded by a `threading.Lock`; evict runs older than 1 hour and cap at 1000 runs. State clearly that this is single-process only.

### 2.4 Event pool (`events.py`)

Schema per event: `id` (unique slug), `emotion` (`rage|envy|despair|shame|hatred|fragment`), `text`, `choices` (exactly two, ids `A` and `B`, each with `label` and a full `delta` for all three stats).

Content rules — enforce with a `validate_events()` that runs at import and raises on violation:
1. **At least 24 events** (a run of ~12–15 cycles should not repeat).
2. Both choices must be net-negative (sum of delta between **−10 and −25**); no free options.
3. Each choice changes **at least one stat**; **every stat appears in at least 6 choices** (this fixes gap B — Willpower must be affectable, e.g. "resist" = `+15 willpower, −20 memory`).
4. The two choices of an event must hurt **different** stats.
5. `emotion` drives the frontend font/colour class, so the pool should use all six emotions roughly evenly.
6. Reuse the existing monologue lines from `index.html` as source text where they fit.

### 2.5 Frontend specification

**`play.html`** — remove canvas, HUD timer, balance factor, BFS ping, key indicators, verdict pop-up. Add:
- `#vent-bg` + `#chaos-container` (same layers as `index.html`), vignette, CRT overlay, `.system-tear-slice`.
- `#cycleLabel` ("CYCLE 07") and `#drainLabel` ("NEXT DRAIN −3.1").
- Three **large brutalist bars** (`.stat-bar` × 3: `#bar-memory`, `#bar-integrity`, `#bar-willpower`), each with label, numeric readout, fill element, and a hard-edged 2px border, zero rounding. Fill colour by level: >60 white/red, 30–60 amber, <30 red flicker.
- `#eventPanel` containing `#eventText` and `#choiceRow` (buttons generated in JS).
- `#resultsOverlay` repurposed: status, **cycles survived** (big number), best run (localStorage `titan_best_cycle`), cause, final stats, buttons RETRY / MAIN TERMINAL.

**`game.js` (rewrite; no canvas code)** — exports a `TerminalGame` controller with:
- `init()` — reuse `sessionStorage.titan_run_id` if present (`GET /api/state`), else `POST /api/new-game`.
- `render(payload)` — update bars (animate width 250ms, `steps()` easing for hard-edged feel), cycle/drain labels, event text (via `textContent`, never `innerHTML`), event emotion class, then build **exactly two** `<button class="btn choice-btn">` elements showing label + delta chips (e.g. `+10 MEM  −25 INT`).
- `choose(id)` — disable both buttons, `fetch('/api/next-cycle', {method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({run_id, choice_id: id})})`, 8 s `AbortController` timeout, error banner + retry on failure, then `render()`.
- Keyboard: `1`/`A` = choice A, `2`/`B` = choice B.
- Willpower override: when `applied.overridden` is true, show `CHOICE_OVERRIDDEN // WILL_UNAVAILABLE`, highlight the forced option for 1.2 s, then continue.
- `applyVisuals(stats, collapsed)` — the visual hooks below, called after every `render`.

**Visual hooks (`atmosphere.js` API used by `game.js`)**

| Stat state | Effect |
|---|---|
| Integrity > 60 | Tear every 3–7 s (current index behaviour) |
| Integrity 30–60 | Tear delay scales linearly from ~5 s down to ~1.2 s |
| Integrity < 30 | **`.system-tear` triggers constantly**: 150 ms on, 100–350 ms off (max 3 flashes/s) |
| Integrity ≤ 0 (collapsed) | `body.system-tear` held permanently plus `.integrity-dead` (heavy static + white wash). Must not strobe faster than 3 Hz |
| Memory | Background phrase corruption probability = `((100 − memory)/100)²`; corrupted phrases are replaced with hex/binary garbage of similar length; existing spans are swapped gradually, not all at once |
| Memory ≤ 0 (collapsed) | `#eventText` and all background text scrambled (re-rolled at ≤ 4 Hz). Bars, numbers, delta chips stay legible |
| Willpower < 30 | Choice buttons jitter slightly; label shows `WILL_FAILING` |
| Willpower ≤ 0 (collapsed) | Buttons locked, override flow above |

Public functions: `Atmosphere.init(opts)`, `Atmosphere.setIntegrity(pct, collapsed)`, `Atmosphere.setMemory(pct, collapsed)`, `Atmosphere.scramble(str, intensity)`, `Atmosphere.setReducedMotion(bool)`.

**Accessibility / safety**
- Respect `prefers-reduced-motion: reduce` and a stored toggle (`titan_reduce_flash`, editable in the repurposed `settings.html`). In reduced mode: no tear toggling, static offset instead; scramble updates at 1 Hz.
- Never flash more than 3 times per second.
- Title screen content note (one line) about themes of despair and self-harm-adjacent language.

**Style rules** — `border-radius: 0` everywhere, Space Mono for UI, emotion fonts only through the emotion classes (`.emotion-rage`, etc., moved into `style.css`), red `#e82020` accent, all new colours as CSS variables in `:root`, no new webfonts.

### 2.6 Acceptance criteria

Backend (`pytest`):
1. `drain_for(1) == 2.0`; `round(drain_for(10), 1) == 14.9`.
2. Stats never exceed 100 or go below 0.
3. Client-supplied deltas are ignored (send a forged `delta` in the body → no effect).
4. Willpower ≤ 0 forces the worst choice and returns `overridden: true`.
5. Game-over rules: two collapsed stats ends the run; one stat collapsed for 3 consecutive cycles ends the run; one collapsed stat for 1–2 cycles does not.
6. Same `seed` → same event order.
7. `404` unknown run, `409` finished run, `400` bad choice.
8. `validate_events()` passes; no immediate event repeats.

Frontend (manual):
1. Page loads with 3 bars at ~98, cycle 1, two buttons.
2. Choosing updates bars and event without page reload.
3. Integrity < 30 produces near-constant tears; Integrity 0 is permanent and does not strobe.
4. Memory low turns background phrases to hex; Memory 0 scrambles text but numbers stay readable.
5. Backend offline → error banner and retry, no frozen UI.
6. Reduced-motion toggle removes flicker.
7. Reload mid-run resumes the same run.

### 2.7 Build order (iterate, verify each step)

1. `game_state.py` + `events.py` + tests (no Flask yet).
2. `app.py` with the three endpoints; verify with `curl`.
3. Move shared CSS/JS out of `index.html` into `style.css` / `atmosphere.js`; confirm the menu still looks identical.
4. New `play.html` + `game.js` (bars, event panel, buttons, fetch).
5. Visual hooks and accessibility.
6. Cleanup pass (Part 3), README, final test run.

---

## PART 3 — REPORT: WHAT TO REMOVE / WHAT TO UPDATE

### 3.1 Remove

| Item | Reason |
|---|---|
| `titan_backend/api/main.py`, `api/schemas.py` (+ `api/__init__.py`) | FastAPI/Pydantic replaced by `app.py` |
| `titan_backend/engine/generator.py`, `engine/validator.py` (+ package) | Graph/beatmap logic gone |
| `titan_backend/core/node.py`, `core/enums.py` (+ package) | ListNode, ModType, tempo multipliers unused |
| `fastapi`, `uvicorn[standard]`, `pydantic` in `requirements.txt` | Replace with `flask>=3.0` |
| `links.txt` | Personal absolute Windows path; obsolete |
| `links.py` | Redundant once Flask serves the frontend (or keep and change port to 8000) |
| All of the old `game.js` (cylinder projection, `_rotateTower`, `_climb`, `_triggerPing`, canvas loop, AVL collapse) | Old mechanic |
| `play.html`: `<canvas>`, `#hudValue`, `#hudProgress`, `#hudBalance`, `#hudPing`, `.hud-keys` A/W/D indicators, `#verdictPopup`, `#resultCombo` "death cause" wiring | Old HUD |
| `style.css`: `#gameCanvas`, `.hud-combo`, `.combo-num`, `.combo-lbl`, `.hud-keys`, `.key-ind`, `#verdictPopup`, `.hud-timer/.hud-progress` | Old HUD styles |
| `style.css`: `.index-container`, `.index-eyebrow`, `.index-title`, `.index-divider`, `.index-subtitle`, `.btn-group`, `.top-line`, `.sr-only`, `.cursor` | Appear unused by any current page (**grep before deleting**; keep `.sr-only` if you use it for accessibility labels) |
| `settings.html` controls: node count, base tempo, tolerance, difficulty, generate flow, `#backendStatus` pulse CSS | Level-generation settings no longer exist |
| `index.html`: `DEFAULT_CONFIG`, `/generate-level` call, `titan_beatmap`, `titan_level_id`, `titan_config` localStorage writes | Replaced by `/api/new-game` |
| `preview.html`: descriptions "BPM / tolerance / key mapping", "Nodes: NONE / CHASER / BLOCKADE / DIVERTER", "Validates against /validate-run" | Wrong after pivot |

### 3.2 Update

| File | Change |
|---|---|
| `requirements.txt` | `flask>=3.0` |
| `index.html` | Quick-launch → `POST /api/new-game`, store `run_id` in `sessionStorage`, then fade to `play.html`. Footer: `SEQUENCE_ENGINE` text, backend link. Move inline emotion/tear CSS to `style.css`, chaos + tear JS to `atmosphere.js`. Add content note. `System_Config` button → repurposed settings |
| `settings.html` | Repurpose: **reduce-flashing toggle**, optional RNG seed. Drop all generator controls |
| `play.html` | Full rebuild per 2.5 |
| `game.js` | Full rewrite per 2.5 |
| `style.css` | Add `.stat-bar`, `.event-panel`, `.choice-btn`, `.delta-chip`, `.emotion-*` classes, `.system-tear-slice`, `body.system-tear …`, `.integrity-dead`; fix scanline conflict by moving tear lines to their own overlay element |
| `vent.js` | Trim font pool and phrases (see fonts), add a hook so corrupted phrases can be swapped for hex/binary |
| `preview.html` | Update card copy and route list; either apply emotion fonts to the legend samples or drop the font claims (samples currently all render in Space Mono, so the legend is misleading) |
| `README.md` | Concept, run instructions (`pip install -r requirements.txt` → `python app.py` → open `http://127.0.0.1:8000`), API contract, test command |

### 3.3 Fonts

Evidence from the code as uploaded:

| Font | Loaded from | Where it's actually used | Recommendation |
|---|---|---|---|
| **Space Mono** | Google | `--font` (all UI), canvas HUD text, vent pool | **Keep.** Trim the request to `wght@400;700` (italics are never used) |
| **VT323** | Google | Only in `vent.js` random font pool | Keep (fits terminal theme) **or** remove if you drop it from the pool |
| **Share Tech Mono** | Google | Only in `vent.js` pool | Keep (same reason) |
| **Orbitron** | Google | Only in `vent.js` pool, at 10–26px, opacity 0.10–0.28 | **Remove** — clean sci-fi look clashes with the trauma-core theme, near-invisible at that opacity |
| **Major Mono Display** | Google | Only in `vent.js` pool | **Remove** — same reason; also a display face that reads poorly at small sizes |
| **Courier Prime** | Google | Only in `vent.js` pool | **Remove** — redundant with Space Mono/VT323 |
| **MTO Getting Angry** | local | `--font-angry`: fragments (`I—`, `I can't—`) and hatred | **Keep.** Note: `.is-fragment` sets `font-weight: 700` but this family only has one weight, so the browser fakes bold; set it to normal |
| **KillCrazy** | local | `--font-rage`: rage flash + rage-tint background | **Keep** |
| **Hundred Watt Regular** | local | `--font-envy`: envy flash + background | **Keep** |
| **Hundred Watt Bold** | local | `@font-face` declared, but no envy element sets a bold weight | **Remove** the `@font-face` block and the `.ttf` file |
| **Skippy Sharpi** | local | `--font-despair` | **Keep** |
| **MTO Grunge Sans** | local | `--font-shame` | **Keep** |
| **Press Start 2P** | local | `--font-system`: only the six `system-tint` background phrases | **Keep** (light use, but it is the natural "corrupted system" voice); optional to drop if you want to cut a file |

After trimming: 1 Google request with Space Mono (+ VT323, Share Tech Mono if kept) instead of 6 families, and 5 local font files instead of 7 (6 if Press Start 2P goes too).

Two conditions so the emotion fonts don't become dead weight after the pivot:
1. Every event carries an `emotion`, and the game page applies the matching `.emotion-*` class to `#eventText`.
2. Rename files into `static/fonts/` without spaces or brackets and update the six `@font-face` `src` URLs together.

Also consider switching Google Fonts from `@import` to a `<link rel="preconnect">` + `<link rel="stylesheet">` in each HTML `<head>` (non-blocking), or self-hosting Space Mono/VT323 in `static/fonts/` so the whole game runs offline.

### 3.4 Keep as-is

Brutalist `.btn` system, `.metal-btn` menu buttons, breathing void, vignette, static noise, flash monologue engine (`ShuffleBag`, `flashPhrase`), the emotion palette, `.results-panel` styling, `.status-bar`, `.glitch` title effect, `#missFlash` (reuse as choice-confirmation flash).

---

## Decisions to confirm before implementation

1. **Game-over rule** (gap A): two collapsed stats, or one collapsed for 3 cycles. Alternative: any stat ≤ 0 ends the run (simpler, but the zero-stat effects are then never shown).
2. **Choice costs visible** on the buttons (recommended, keeps the choice "agonizing" rather than random).
3. **Willpower must be touched by events** (otherwise every run ends around cycle 12).
4. **Frontend served by Flask** on port 8000 (removes CORS and hardcoded URLs).
