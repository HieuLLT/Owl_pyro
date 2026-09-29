/**
 * ╔══════════════════════════════════════════════════════════════════╗
 * ║  SPATIAL ENGINE — Real-Time 3D Cross-Section Canvas Game        ║
 * ║                                                                  ║
 * ║  World:    map[z][y][x]  — 3D matrix from Python backend        ║
 * ║  View A:   XY Plane (camera locked to player.z)                 ║
 * ║  View B:   ZY Plane (camera locked to player.x)                 ║
 * ║  Shift:    Instant plane swap — walls become gaps, gaps become   ║
 * ║            walls. Enemies moving in 3D flicker in/out of view.  ║
 * ║                                                                  ║
 * ║  Entities: ASCII art characters overlaid on coloured geo tiles  ║
 * ║  AI:       Continuous 3D BFS pathfinding at configurable speed  ║
 * ╚══════════════════════════════════════════════════════════════════╝
 */

// ─── Constants ───────────────────────────────────────────────────────────────
const WALL  = '#';
const EMPTY = '.';
const EXIT  = 'X';

const PLANE_XY = 'XY';
const PLANE_ZY = 'ZY';

// ─── Colour palette (matching style.css tokens) ───────────────────────────────
const C = {
  bg:         '#030303',
  wall:       '#1a1a2e',
  wallEdge:   '#e82020',
  wallGlow:   'rgba(232,32,32,0.18)',
  floor:      '#0d0d1a',
  void:       '#000000',
  exit:       '#ffe620',
  exitGlow:   'rgba(255,230,32,0.35)',
  grid:       'rgba(255,255,255,0.03)',
  scanline:   'rgba(0,0,0,0.12)',
  hud:        'rgba(3,3,3,0.82)',
  hudBorder:  '#e82020',
  playerText: '#00ff88',
  enemyText:  '#e82020',
  dimText:    '#444',
  white:      '#f0f0f0',
  cyan:       '#00d4ff',
  // Wall depth shading — 3 levels
  wallShade:  ['#0e0e20', '#16162e', '#1e1e40'],
};

// ─── Tile rendering palette — depth-shaded coloured blocks ───────────────────
function getTileStyle(cell, tx, ty, tz, activePlane, lockedVal) {
  if (cell === WALL) {
    // Depth cue: walls further from camera are darker
    const depth = activePlane === PLANE_XY ? tz : tx;
    const shade = C.wallShade[Math.min(2, Math.floor(depth / 3))];
    return { fill: shade, edge: C.wallEdge, glow: C.wallGlow, isWall: true };
  }
  if (cell === EXIT) {
    return { fill: '#221f00', edge: C.exit, glow: C.exitGlow, isWall: false };
  }
  return { fill: C.floor, edge: null, glow: null, isWall: false };
}

// ─── BFS 3D (runs synchronously — world is ≤12×10×12 = trivial) ──────────────
function bfs3D(world, startX, startY, startZ, targetX, targetY, targetZ) {
  const D = world.length;
  const H = world[0].length;
  const W = world[0][0].length;

  function inBounds(x, y, z) {
    return x >= 0 && x < W && y >= 0 && y < H && z >= 0 && z < D;
  }
  function passable(x, y, z) {
    return inBounds(x, y, z) && world[z][y][x] !== WALL;
  }

  const key = (x, y, z) => `${x},${y},${z}`;
  const DIRS = [[1,0,0],[-1,0,0],[0,1,0],[0,-1,0],[0,0,1],[0,0,-1]];

  const visited = new Set([key(startX, startY, startZ)]);
  const queue = [{ x: startX, y: startY, z: startZ, path: [] }];

  while (queue.length) {
    const { x, y, z, path } = queue.shift();
    for (const [dx, dy, dz] of DIRS) {
      const nx = x + dx, ny = y + dy, nz = z + dz;
      const nk = key(nx, ny, nz);
      if (visited.has(nk)) continue;
      if (!inBounds(nx, ny, nz)) continue;
      if (world[nz][ny][nx] === WALL) continue;
      const newPath = [...path, { x: nx, y: ny, z: nz }];
      if (nx === targetX && ny === targetY && nz === targetZ) return newPath;
      visited.add(nk);
      queue.push({ x: nx, y: ny, z: nz, path: newPath });
    }
  }
  return [];
}

// ─── Enemy class ─────────────────────────────────────────────────────────────
class Enemy {
  /**
   * @param {number} x,y,z  — absolute 3D spawn position
   * @param {string} glyph  — ASCII character to render (E, F, G …)
   * @param {number} speed  — world-units per second
   */
  constructor(x, y, z, glyph = 'E', speed = 2.2) {
    this.x = x; this.y = y; this.z = z;
    this.glyph = glyph;
    this.speed = speed;

    // Sub-tile fractional position for smooth movement
    this.fx = x; this.fy = y; this.fz = z;

    this._path = [];
    this._pathTarget = null;
    this._stepProgress = 0;     // 0..1 lerp toward next node
    this._bfsTimer = 0;         // cooldown before next BFS recalc
    this.BFS_INTERVAL = 0.6;    // seconds between recalcs
  }

  /** Recalculate BFS if needed, then move continuously toward next node. */
  update(dt, player, world) {
    this._bfsTimer -= dt;

    const tgt = `${player.x},${player.y},${player.z}`;
    const needsRecalc = this._bfsTimer <= 0 || this._pathTarget !== tgt;

    if (needsRecalc && this._path.length === 0) {
      this._path = bfs3D(
        world,
        Math.round(this.fx), Math.round(this.fy), Math.round(this.fz),
        player.x, player.y, player.z
      );
      this._pathTarget = tgt;
      this._bfsTimer = this.BFS_INTERVAL;
      this._stepProgress = 0;
    }

    if (this._path.length === 0) return;

    // Advance lerp progress toward next node
    const next = this._path[0];
    this._stepProgress += this.speed * dt;

    if (this._stepProgress >= 1) {
      // Snap to node, move to next
      this.fx = next.x; this.fy = next.y; this.fz = next.z;
      this.x = next.x; this.y = next.y; this.z = next.z;
      this._path.shift();
      this._stepProgress = 0;
    } else {
      // Smooth interpolation for sub-tile position
      const prev = { x: this.x, y: this.y, z: this.z };
      this.fx = prev.x + (next.x - prev.x) * this._stepProgress;
      this.fy = prev.y + (next.y - prev.y) * this._stepProgress;
      this.fz = prev.z + (next.z - prev.z) * this._stepProgress;
    }
  }

  /** Is this enemy visible in the current slice? */
  isVisible(activePlane, lockedVal) {
    if (activePlane === PLANE_XY) return Math.round(this.fz) === lockedVal;
    return Math.round(this.fx) === lockedVal;
  }

  /** Get render position in slice coordinates. */
  slicePos(activePlane) {
    if (activePlane === PLANE_XY) return { col: this.fx, row: this.fy };
    return { col: this.fz, row: this.fy };
  }

  manhattan(px, py, pz) {
    return Math.abs(this.x - px) + Math.abs(this.y - py) + Math.abs(this.z - pz);
  }
}

// ─── Player class ─────────────────────────────────────────────────────────────
class Player {
  constructor(x, y, z) {
    this.x = x; this.y = y; this.z = z;
    this.plane = PLANE_XY;

    // Animation: smooth camera shake on plane swap
    this._shakeFrames = 0;
    this._shakeAmt = 0;

    // Input buffer — keys held down for continuous movement
    this._keysHeld = new Set();
    this._moveTimer = 0;
    this.MOVE_REPEAT = 0.13;   // seconds between repeated moves
  }

  tryMove(dx, dy, dz, world) {
    const nx = this.x + dx;
    const ny = this.y + dy;
    const nz = this.z + dz;
    const D = world.length, H = world[0].length, W = world[0][0].length;
    if (nx < 0 || nx >= W || ny < 0 || ny >= H || nz < 0 || nz >= D) return false;
    if (world[nz][ny][nx] === WALL) return false;
    this.x = nx; this.y = ny; this.z = nz;
    return true;
  }

  swapPlane() {
    this.plane = this.plane === PLANE_XY ? PLANE_ZY : PLANE_XY;
    this._shakeFrames = 12;
    this._shakeAmt = 6;
  }

  update(dt, world, onMove) {
    // Held-key repeat movement
    this._moveTimer -= dt;
    if (this._moveTimer <= 0 && this._keysHeld.size > 0) {
      let moved = false;
      for (const k of this._keysHeld) {
        let dx = 0, dy = 0, dz = 0;
        if (this.plane === PLANE_XY) {
          if (k === 'ArrowLeft'  || k === 'a') dx = -1;
          if (k === 'ArrowRight' || k === 'd') dx =  1;
        } else {
          if (k === 'ArrowLeft'  || k === 'a') dz = -1;
          if (k === 'ArrowRight' || k === 'd') dz =  1;
        }
        if (k === 'ArrowUp'   || k === 'w') dy = -1;
        if (k === 'ArrowDown' || k === 's') dy =  1;
        if (dx || dy || dz) moved = this.tryMove(dx, dy, dz, world) || moved;
      }
      if (moved && onMove) onMove();
      this._moveTimer = this.MOVE_REPEAT;
    }

    if (this._shakeFrames > 0) this._shakeFrames--;
  }

  get shake() {
    if (this._shakeFrames <= 0) return { x: 0, y: 0 };
    const s = this._shakeAmt * (this._shakeFrames / 12);
    return {
      x: (Math.random() * 2 - 1) * s,
      y: (Math.random() * 2 - 1) * s,
    };
  }

  get lockedVal() {
    return this.plane === PLANE_XY ? this.z : this.x;
  }

  slicePos() {
    if (this.plane === PLANE_XY) return { col: this.x, row: this.y };
    return { col: this.z, row: this.y };
  }
}

// ─── Main SpatialEngine ───────────────────────────────────────────────────────
export class SpatialEngine {
  /**
   * @param {HTMLCanvasElement} canvas
   * @param {object} mapData  — { world, player_start, enemies, exit }
   *        from /api/spatial-map
   */
  constructor(canvas, mapData) {
    this.canvas = canvas;
    this.ctx    = canvas.getContext('2d');

    this.world  = mapData.world;          // world[z][y][x]
    this.DZ     = this.world.length;
    this.DY     = this.world[0].length;
    this.DX     = this.world[0][0].length;

    this.player = new Player(
      mapData.player_start[0],
      mapData.player_start[1],
      mapData.player_start[2]
    );

    this.enemies = (mapData.enemies || []).map((e, i) =>
      new Enemy(e[0], e[1], e[2],
        String.fromCharCode(69 + i),   // E, F, G…
        2.0 + i * 0.4                  // escalating speed
      )
    );

    this.exit = mapData.exit;            // [x,y,z]
    this.exitPos = { x: this.exit[0], y: this.exit[1], z: this.exit[2] };

    this.state  = 'playing';             // 'playing' | 'won' | 'lost'
    this.winner = null;

    this._lastTime  = null;
    this._raf       = null;
    this._scanY     = 0;                 // animated scanline

    // Tile size — auto-calculated to fill canvas
    this._calcTileSize();

    // Font sizes
    this.entityFont = Math.floor(this.tileW * 0.72);
    this.hudFont    = 13;

    this._bindInput();
    this._loop(performance.now());
  }

  _calcTileSize() {
    // Show the wider dimension (XY or ZY slice)
    const colsXY = this.DX, colsZY = this.DZ;
    const maxCols = Math.max(colsXY, colsZY);
    const rows    = this.DY;

    const PAD = 8;   // px padding on each side
    this.tileW = Math.floor((this.canvas.width  - PAD * 2) / maxCols);
    this.tileH = Math.floor((this.canvas.height * 0.76    ) / rows);
    this.tileW = this.tileH = Math.min(this.tileW, this.tileH);

    // Grid offset to center
    const cols = this.player.plane === PLANE_XY ? this.DX : this.DZ;
    this.offX = Math.floor((this.canvas.width  - cols * this.tileW) / 2);
    this.offY = Math.floor((this.canvas.height * 0.76 - rows * this.tileH) / 2) + 4;
  }

  // ── Input ──────────────────────────────────────────────────────────────────
  _bindInput() {
    const MOVE_KEYS = new Set([
      'ArrowUp','ArrowDown','ArrowLeft','ArrowRight','w','a','s','d'
    ]);
    const SWAP_KEYS = new Set(['Shift','p',' ','Tab']);

    window.addEventListener('keydown', e => {
      if (this.state !== 'playing') return;
      if (SWAP_KEYS.has(e.key)) {
        e.preventDefault();
        this.player.swapPlane();
        this._calcTileSize();
        return;
      }
      if (MOVE_KEYS.has(e.key)) {
        e.preventDefault();
        if (!this.player._keysHeld.has(e.key)) {
          // Immediate first move
          this.player._keysHeld.add(e.key);
          this.player._moveTimer = 0;
        }
      }
    });

    window.addEventListener('keyup', e => {
      this.player._keysHeld.delete(e.key);
    });

    // Mobile / touch swap button (if present)
    document.getElementById('btnSwapPlane')?.addEventListener('click', () => {
      if (this.state !== 'playing') return;
      this.player.swapPlane();
      this._calcTileSize();
    });
  }

  // ── Game loop ──────────────────────────────────────────────────────────────
  _loop(now) {
    const dt = Math.min((now - (this._lastTime ?? now)) / 1000, 0.05);
    this._lastTime = now;

    if (this.state === 'playing') {
      this._update(dt);
    }
    this._draw();

    this._raf = requestAnimationFrame(t => this._loop(t));
  }

  _update(dt) {
    // Player movement
    this.player.update(dt, this.world, null);

    // Enemy AI
    for (const enemy of this.enemies) {
      enemy.update(dt, this.player, this.world);
    }

    // Scanline animation
    this._scanY = (this._scanY + 60 * dt) % this.canvas.height;

    // Win check — player reaches exit
    if (this.player.x === this.exitPos.x &&
        this.player.y === this.exitPos.y &&
        this.player.z === this.exitPos.z) {
      this.state = 'won';
      this._onWin?.();
    }

    // Lose check — any enemy on same tile
    for (const enemy of this.enemies) {
      if (enemy.x === this.player.x &&
          enemy.y === this.player.y &&
          enemy.z === this.player.z) {
        this.state = 'lost';
        this.winner = enemy.glyph;
        this._onLose?.();
        break;
      }
    }
  }

  // ── Drawing ────────────────────────────────────────────────────────────────
  _draw() {
    const ctx = this.ctx;
    const { width: W, height: H } = this.canvas;
    const shake = this.player.shake;

    ctx.save();
    ctx.translate(shake.x, shake.y);

    // Background
    ctx.fillStyle = C.bg;
    ctx.fillRect(-10, -10, W + 20, H + 20);

    this._drawWorld();
    this._drawExit();
    this._drawEntities();
    this._drawGrid();
    this._drawScanline();
    this._drawHUD();

    if (this.state === 'won')  this._drawEndScreen(true);
    if (this.state === 'lost') this._drawEndScreen(false);

    ctx.restore();
  }

  _tileRect(col, row) {
    return {
      x: this.offX + col * this.tileW,
      y: this.offY + row * this.tileH,
      w: this.tileW,
      h: this.tileH,
    };
  }

  _drawWorld() {
    const ctx = this.ctx;
    const { plane, lockedVal } = this.player;
    const T = this.tileW;

    const cols = plane === PLANE_XY ? this.DX : this.DZ;
    const rows = this.DY;

    for (let row = 0; row < rows; row++) {
      for (let col = 0; col < cols; col++) {
        let cell, tx, ty, tz;
        if (plane === PLANE_XY) {
          tx = col; ty = row; tz = lockedVal;
          cell = this.world[tz]?.[ty]?.[tx] ?? WALL;
        } else {
          tx = lockedVal; ty = row; tz = col;
          cell = this.world[tz]?.[ty]?.[tx] ?? WALL;
        }

        const { x, y, w, h } = this._tileRect(col, row);
        const style = getTileStyle(cell, tx, ty, tz, plane, lockedVal);

        if (style.isWall) {
          // Base fill
          ctx.fillStyle = style.fill;
          ctx.fillRect(x, y, w, h);

          // Inner bevel — top/left highlight
          ctx.fillStyle = 'rgba(255,255,255,0.04)';
          ctx.fillRect(x, y, w, 2);
          ctx.fillRect(x, y, 2, h);

          // Bottom/right shadow
          ctx.fillStyle = 'rgba(0,0,0,0.35)';
          ctx.fillRect(x, y + h - 2, w, 2);
          ctx.fillRect(x + w - 2, y, 2, h);

          // Red edge glow
          ctx.strokeStyle = style.edge;
          ctx.lineWidth = 1;
          ctx.strokeRect(x + 0.5, y + 0.5, w - 1, h - 1);

          // Ambient glow (soft, corners)
          const grd = ctx.createRadialGradient(
            x + w/2, y + h/2, 0,
            x + w/2, y + h/2, w * 0.8
          );
          grd.addColorStop(0, style.glow);
          grd.addColorStop(1, 'transparent');
          ctx.fillStyle = grd;
          ctx.fillRect(x - 2, y - 2, w + 4, h + 4);

        } else {
          // Empty floor tile — very dark with subtle grid
          ctx.fillStyle = style.fill;
          ctx.fillRect(x, y, w, h);
        }
      }
    }
  }

  _drawExit() {
    const ctx = this.ctx;
    const { plane, lockedVal } = this.player;
    const ep = this.exitPos;

    // Is exit on this slice?
    let visible = false;
    let col, row;
    if (plane === PLANE_XY && ep.z === lockedVal) {
      visible = true; col = ep.x; row = ep.y;
    } else if (plane === PLANE_ZY && ep.x === lockedVal) {
      visible = true; col = ep.z; row = ep.y;
    }
    if (!visible) return;

    const { x, y, w, h } = this._tileRect(col, row);
    const t = performance.now() / 1000;

    // Pulsing yellow portal
    ctx.fillStyle = '#110f00';
    ctx.fillRect(x, y, w, h);

    const pulse = 0.5 + 0.5 * Math.sin(t * 3);
    const grd = ctx.createRadialGradient(x+w/2, y+h/2, 0, x+w/2, y+h/2, w * 0.8);
    grd.addColorStop(0, `rgba(255,230,32,${0.4 + 0.25 * pulse})`);
    grd.addColorStop(1, 'transparent');
    ctx.fillStyle = grd;
    ctx.fillRect(x - 4, y - 4, w + 8, h + 8);

    ctx.strokeStyle = C.exit;
    ctx.lineWidth = 1.5;
    ctx.strokeRect(x + 0.5, y + 0.5, w - 1, h - 1);

    // Render 'X' character
    ctx.fillStyle = C.exit;
    ctx.font = `bold ${Math.floor(w * 0.65)}px 'Space Mono', monospace`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.shadowColor = C.exit;
    ctx.shadowBlur  = 12 * pulse;
    ctx.fillText('X', x + w / 2, y + h / 2);
    ctx.shadowBlur = 0;
  }

  _drawEntities() {
    const ctx = this.ctx;
    const { plane, lockedVal } = this.player;
    const t = performance.now() / 1000;
    const fs = Math.floor(this.tileW * 0.72);

    ctx.font = `bold ${fs}px 'Space Mono', monospace`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    // ── Enemies ──────────────────────────────────────────────────────
    for (const enemy of this.enemies) {
      if (!enemy.isVisible(plane, lockedVal)) {
        // Draw a faint "ghost" indicator at the edge when nearby
        const dist = enemy.manhattan(this.player.x, this.player.y, this.player.z);
        if (dist <= 5) this._drawGhostIndicator(enemy, dist);
        continue;
      }

      const { col, row } = enemy.slicePos(plane);
      const { x, y, w, h } = this._tileRect(col, row);

      // Red aura behind enemy glyph
      const auraSize = w * 0.9;
      const auraGrd = ctx.createRadialGradient(x+w/2, y+h/2, 0, x+w/2, y+h/2, auraSize);
      auraGrd.addColorStop(0, 'rgba(232,32,32,0.22)');
      auraGrd.addColorStop(1, 'transparent');
      ctx.fillStyle = auraGrd;
      ctx.fillRect(x - 4, y - 4, w + 8, h + 8);

      // Glitch flicker
      const flicker = Math.sin(t * 18 + enemy.x * 7) > 0.7;
      ctx.fillStyle = flicker ? '#ff6060' : C.enemyText;
      ctx.shadowColor = C.enemyText;
      ctx.shadowBlur  = 14;
      ctx.fillText(enemy.glyph, x + w / 2, y + h / 2);
      ctx.shadowBlur = 0;
    }

    // ── Player ────────────────────────────────────────────────────────
    const { col: pc, row: pr } = this.player.slicePos();
    const { x: px, y: py, w: pw, h: ph } = this._tileRect(pc, pr);

    // Green halo
    const halo = pw * 0.85;
    const haloGrd = ctx.createRadialGradient(px+pw/2, py+ph/2, 0, px+pw/2, py+ph/2, halo);
    haloGrd.addColorStop(0, 'rgba(0,255,136,0.18)');
    haloGrd.addColorStop(1, 'transparent');
    ctx.fillStyle = haloGrd;
    ctx.fillRect(px - 4, py - 4, pw + 8, ph + 8);

    // Breathing pulse
    const breathe = 0.85 + 0.15 * Math.sin(t * 2.5);
    ctx.save();
    ctx.translate(px + pw / 2, py + ph / 2);
    ctx.scale(breathe, breathe);
    ctx.fillStyle = C.playerText;
    ctx.shadowColor = C.playerText;
    ctx.shadowBlur  = 18;
    ctx.fillText('@', 0, 0);
    ctx.shadowBlur  = 0;
    ctx.restore();
  }

  /** Show a faint indicator on the nearest edge when enemy is off-slice but close */
  _drawGhostIndicator(enemy, dist) {
    const ctx  = this.ctx;
    const { plane, x: px, y: py, z: pz } = this.player;
    const alpha = Math.max(0, (5 - dist) / 5) * 0.45;
    if (alpha < 0.05) return;

    // Arrow on canvas edge pointing toward the enemy's 3D position
    const MARGIN = 18;
    let ex, ey;
    if (plane === PLANE_XY) {
      ex = this.offX + enemy.x * this.tileW + this.tileW / 2;
      ey = this.offY + enemy.y * this.tileH + this.tileH / 2;
    } else {
      ex = this.offX + enemy.z * this.tileW + this.tileW / 2;
      ey = this.offY + enemy.y * this.tileH + this.tileH / 2;
    }
    const angle = Math.atan2(ey - this.canvas.height/2, ex - this.canvas.width/2);
    const cx = this.canvas.width  / 2 + Math.cos(angle) * (this.canvas.width * 0.4);
    const cy = this.canvas.height / 2 + Math.sin(angle) * (this.canvas.height * 0.35);

    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.translate(cx, cy);
    ctx.rotate(angle);
    ctx.fillStyle = C.enemyText;
    ctx.font = `bold 11px 'Space Mono', monospace`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(`${enemy.glyph} ??`, 0, 0);
    ctx.restore();
  }

  _drawGrid() {
    const ctx = this.ctx;
    const cols = this.player.plane === PLANE_XY ? this.DX : this.DZ;
    const rows = this.DY;

    ctx.strokeStyle = C.grid;
    ctx.lineWidth   = 0.5;
    for (let c = 0; c <= cols; c++) {
      const x = this.offX + c * this.tileW;
      ctx.beginPath();
      ctx.moveTo(x, this.offY);
      ctx.lineTo(x, this.offY + rows * this.tileH);
      ctx.stroke();
    }
    for (let r = 0; r <= rows; r++) {
      const y = this.offY + r * this.tileH;
      ctx.beginPath();
      ctx.moveTo(this.offX, y);
      ctx.lineTo(this.offX + cols * this.tileW, y);
      ctx.stroke();
    }
  }

  _drawScanline() {
    const ctx = this.ctx;
    const { width: W } = this.canvas;

    // Slow horizontal scanline beam
    const grd = ctx.createLinearGradient(0, this._scanY - 8, 0, this._scanY + 8);
    grd.addColorStop(0,   'transparent');
    grd.addColorStop(0.5, 'rgba(0,212,255,0.04)');
    grd.addColorStop(1,   'transparent');
    ctx.fillStyle = grd;
    ctx.fillRect(0, this._scanY - 8, W, 16);
  }

  _drawHUD() {
    const ctx = this.ctx;
    const { width: W, height: H } = this.canvas;
    const p = this.player;
    const t = performance.now() / 1000;

    const hudH    = Math.floor(H * 0.22);
    const hudY    = H - hudH;
    const PAD     = 14;
    const fs      = this.hudFont;

    // HUD panel backdrop
    ctx.fillStyle = C.hud;
    ctx.fillRect(0, hudY, W, hudH);

    ctx.strokeStyle = C.hudBorder;
    ctx.lineWidth   = 1;
    ctx.beginPath();
    ctx.moveTo(0, hudY);
    ctx.lineTo(W, hudY);
    ctx.stroke();

    // Decorative corner brackets
    const BL = 16;
    ctx.strokeStyle = C.hudBorder;
    ctx.lineWidth   = 1.5;
    [[0, hudY], [W, hudY]].forEach(([bx, by]) => {
      const dir = bx === 0 ? 1 : -1;
      ctx.beginPath();
      ctx.moveTo(bx + dir * BL, by);
      ctx.lineTo(bx, by);
      ctx.lineTo(bx, by + BL);
      ctx.stroke();
    });

    ctx.font      = `${fs}px 'Space Mono', monospace`;
    ctx.textAlign = 'left';
    ctx.textBaseline = 'top';

    const row1 = hudY + PAD;
    const row2 = row1 + fs + 8;
    const row3 = row2 + fs + 8;

    // Plane label
    const planeColour = p.plane === PLANE_XY ? '#00ff88' : '#b060ff';
    const planeLabel  = p.plane === PLANE_XY
      ? `[VIEW A]  XY Plane  —  Z locked = ${p.z}`
      : `[VIEW B]  ZY Plane  —  X locked = ${p.x}`;

    ctx.fillStyle = planeColour;
    ctx.shadowColor = planeColour;
    ctx.shadowBlur  = 8;
    ctx.fillText(planeLabel, PAD, row1);
    ctx.shadowBlur  = 0;

    // Player position
    ctx.fillStyle = '#888';
    ctx.fillText(`Player: (${p.x}, ${p.y}, ${p.z})`, PAD, row2);

    // Swap hint — blink
    if (Math.floor(t * 2) % 2 === 0) {
      ctx.fillStyle = '#555';
      ctx.fillText('[SHIFT / P]  rotate plane', PAD, row3);
    }

    // Enemies panel — right side
    const exW = 240;
    const ex0 = W - exW - PAD;

    ctx.fillStyle = '#333';
    ctx.fillText('ENTITIES', ex0, row1);

    this.enemies.forEach((enemy, i) => {
      const dist = enemy.manhattan(p.x, p.y, p.z);
      const visible = enemy.isVisible(p.plane, p.lockedVal);
      const col = dist <= 3 ? '#ff4040' : dist <= 6 ? '#ff9900' : '#555';

      const ey = row2 + i * (fs + 6);
      ctx.fillStyle = col;
      ctx.textAlign = 'left';
      ctx.fillText(
        `${enemy.glyph} (${enemy.x},${enemy.y},${enemy.z})  d=${dist}  ${visible ? '[ VISIBLE ]' : '[ hidden  ]'}`,
        ex0, ey
      );
    });

    // Exit indicator
    const ex = this.exitPos;
    ctx.fillStyle = '#665500';
    ctx.textAlign = 'center';
    ctx.fillText(`EXIT at (${ex.x},${ex.y},${ex.z})`, W / 2, row1);
  }

  _drawEndScreen(won) {
    const ctx = this.ctx;
    const { width: W, height: H } = this.canvas;
    const t = performance.now() / 1000;

    // Darkened overlay
    ctx.fillStyle = won ? 'rgba(0,20,10,0.82)' : 'rgba(20,0,0,0.88)';
    ctx.fillRect(0, 0, W, H);

    const pulse = 0.5 + 0.5 * Math.sin(t * 3);
    const msg   = won ? '** ESCAPED **' : '** CAUGHT **';
    const sub   = won
      ? 'Reality boundary breached.'
      : `Terminated by entity ${this.winner}.`;

    const col = won ? C.playerText : C.enemyText;
    ctx.fillStyle = col;
    ctx.shadowColor = col;
    ctx.shadowBlur  = 30 * pulse;
    ctx.font = `bold 36px 'Space Mono', monospace`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(msg, W / 2, H / 2 - 24);

    ctx.shadowBlur = 0;
    ctx.fillStyle  = '#888';
    ctx.font       = `14px 'Space Mono', monospace`;
    ctx.fillText(sub, W / 2, H / 2 + 20);

    ctx.fillStyle  = '#444';
    ctx.font       = `12px 'Space Mono', monospace`;
    ctx.fillText('[R] restart', W / 2, H / 2 + 56);
  }

  // ── Public API ────────────────────────────────────────────────────────────
  onWin(fn)  { this._onWin  = fn; }
  onLose(fn) { this._onLose = fn; }

  destroy() {
    if (this._raf) cancelAnimationFrame(this._raf);
  }
}
