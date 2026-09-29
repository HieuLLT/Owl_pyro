/**
 * @fileoverview Domain logic: Player and Enemy entity classes.
 *
 * Separation of concerns
 * ──────────────────────
 * This module owns **simulation state only**. It knows nothing about Canvas,
 * DOM, or rendering. The rule: if it touches `ctx`, it does not belong here.
 *
 * Both classes follow the single-responsibility principle:
 *   - `Player`  → manages position, active plane, and held-key input state.
 *   - `Enemy`   → manages position, BFS pathfinding, and sub-tile lerp.
 */

import { Cell, Plane, CONFIG, bfs3D } from './constants.js';

// ─── Player ───────────────────────────────────────────────────────────────────

export class Player {
  /**
   * @param {number} x - Starting column (X axis).
   * @param {number} y - Starting row    (Y axis, 0 = top).
   * @param {number} z - Starting layer  (Z axis / depth).
   */
  constructor(x, y, z) {
    /** @type {number} */ this.x = x;
    /** @type {number} */ this.y = y;
    /** @type {number} */ this.z = z;

    /** Active view plane. @type {string} */ this.plane = Plane.XY;

    // ── Camera-shake state (driven by plane swap) ──────────────────────────
    /** @private */ this._shakeFrames = 0;

    // ── Held-key repeat movement ───────────────────────────────────────────
    /** @private @type {Set<string>} */ this._keysHeld  = new Set();
    /** @private */ this._moveTimer = 0;
  }

  // ── Accessors ──────────────────────────────────────────────────────────────

  /**
   * The axis value that the camera is currently locked to.
   * - View XY locks Z  → returns `this.z`.
   * - View ZY locks X  → returns `this.x`.
   * @returns {number}
   */
  get lockedVal() {
    return this.plane === Plane.XY ? this.z : this.x;
  }

  /**
   * Position in slice-space (column, row) for the active 2-D view.
   * - View XY: col=x, row=y.
   * - View ZY: col=z, row=y  (Z becomes the horizontal axis).
   * @returns {{ col: number, row: number }}
   */
  get slicePos() {
    return this.plane === Plane.XY
      ? { col: this.x, row: this.y }
      : { col: this.z, row: this.y };
  }

  /**
   * Current camera shake offset in pixels.
   * Intensity fades linearly as `_shakeFrames` decrements each frame.
   * @returns {{ x: number, y: number }}
   */
  get shake() {
    if (this._shakeFrames <= 0) return { x: 0, y: 0 };
    const intensity = CONFIG.SHAKE_MAGNITUDE * (this._shakeFrames / CONFIG.SHAKE_FRAMES);
    return {
      x: (Math.random() * 2 - 1) * intensity,
      y: (Math.random() * 2 - 1) * intensity,
    };
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  /**
   * Attempt to move the player by (dx, dy, dz).
   * Enforces world bounds and wall collision.
   *
   * @param {number}      dx,dy,dz - Integer deltas (−1, 0, or +1 each).
   * @param {string[][][]} world   - world[z][y][x] collision matrix.
   * @returns {boolean} True if the move was accepted.
   */
  tryMove(dx, dy, dz, world) {
    const nx = this.x + dx;
    const ny = this.y + dy;
    const nz = this.z + dz;

    const DZ = world.length;
    const DY = world[0].length;
    const DX = world[0][0].length;

    if (nx < 0 || nx >= DX || ny < 0 || ny >= DY || nz < 0 || nz >= DZ) return false;
    if (world[nz][ny][nx] === Cell.WALL) return false;

    this.x = nx;
    this.y = ny;
    this.z = nz;
    return true;
  }

  /**
   * Toggle the active view plane (XY ↔ ZY) and trigger a camera shake.
   *
   * The locked axis is not changed explicitly: `lockedVal` always derives
   * from the current position, so the swap is instantaneous and reversible.
   */
  swapPlane() {
    this.plane        = this.plane === Plane.XY ? Plane.ZY : Plane.XY;
    this._shakeFrames = CONFIG.SHAKE_FRAMES;
  }

  /**
   * Tick: process held-key movement and decrement shake counter.
   *
   * Movement keys use a "first-press immediate, then auto-repeat" scheme:
   * the key is added to `_keysHeld` with `_moveTimer = 0` on keydown so the
   * first move fires instantly, and subsequent moves fire every MOVE_REPEAT_DELAY
   * seconds as long as the key stays held.
   *
   * @param {number}       dt    - Delta time in seconds since last frame.
   * @param {string[][][]} world - Collision matrix.
   * @param {Function|null} [onMove] - Optional callback fired on successful move.
   */
  update(dt, world, onMove = null) {
    if (this._shakeFrames > 0) this._shakeFrames--;

    this._moveTimer -= dt;
    if (this._moveTimer > 0 || this._keysHeld.size === 0) return;

    let moved = false;
    for (const key of this._keysHeld) {
      const delta = this._keyToDelta(key);
      if (delta && this.tryMove(delta.dx, delta.dy, delta.dz, world)) {
        moved = true;
      }
    }

    if (moved && onMove) onMove();
    this._moveTimer = CONFIG.MOVE_REPEAT_DELAY;
  }

  /**
   * Register a key as currently held (called from keydown handler).
   * Resets the move timer to 0 to fire an immediate first move.
   * @param {string} key - KeyboardEvent.key value.
   */
  pressKey(key) {
    if (!this._keysHeld.has(key)) {
      this._keysHeld.add(key);
      this._moveTimer = 0; // trigger immediate move on first press
    }
  }

  /**
   * Deregister a held key (called from keyup handler).
   * @param {string} key - KeyboardEvent.key value.
   */
  releaseKey(key) {
    this._keysHeld.delete(key);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /**
   * Map a KeyboardEvent.key string to a (dx, dy, dz) movement delta.
   * Horizontal direction depends on the active plane:
   *   - XY: left/right changes X.
   *   - ZY: left/right changes Z (depth), because X is the locked axis.
   *
   * @private
   * @param {string} key
   * @returns {{ dx: number, dy: number, dz: number }|null}
   */
  _keyToDelta(key) {
    switch (key) {
      case 'ArrowUp':    case 'w': return { dx:  0, dy: -1, dz:  0 };
      case 'ArrowDown':  case 's': return { dx:  0, dy:  1, dz:  0 };
      case 'ArrowLeft':  case 'a':
        return this.plane === Plane.XY
          ? { dx: -1, dy: 0, dz:  0 }
          : { dx:  0, dy: 0, dz: -1 };
      case 'ArrowRight': case 'd':
        return this.plane === Plane.XY
          ? { dx:  1, dy: 0, dz:  0 }
          : { dx:  0, dy: 0, dz:  1 };
      default: return null;
    }
  }
}

// ─── Enemy ────────────────────────────────────────────────────────────────────

export class Enemy {
  /**
   * @param {number} x,y,z   - Absolute 3-D spawn position (integer).
   * @param {string} glyph   - Single ASCII character rendered on canvas.
   * @param {number} speed   - World-units per second for movement.
   */
  constructor(x, y, z, glyph, speed) {
    /** @type {number} */ this.x = x;
    /** @type {number} */ this.y = y;
    /** @type {number} */ this.z = z;

    /** @type {string} */ this.glyph = glyph;
    /** @type {number} */ this.speed = speed;

    // Sub-tile fractional positions for smooth visual interpolation.
    // These are the values read by the renderer; the integer x/y/z
    // represent the logical tile the enemy "occupies" for collision.
    /** @type {number} */ this.fx = x;
    /** @type {number} */ this.fy = y;
    /** @type {number} */ this.fz = z;

    // BFS state
    /** @private @type {{ x: number, y: number, z: number }[]} */ this._path = [];
    /** @private @type {string|null} */ this._pathTargetKey = null;
    /** @private @type {number} */      this._bfsTimer      = 0;
    /** @private @type {number} */      this._stepProgress  = 0; // 0..1 lerp
  }

  // ── Accessors ──────────────────────────────────────────────────────────────

  /**
   * Whether this enemy is visible in the player's current 2-D slice.
   *
   * An entity is visible only when its rounded position on the *locked* axis
   * matches the locked axis value. E.g. in View XY (Z locked), the enemy is
   * visible only if it is on the same Z layer as the player.
   *
   * @param {string} plane     - Active `Plane` value.
   * @param {number} lockedVal - Player's locked axis value.
   * @returns {boolean}
   */
  isVisible(plane, lockedVal) {
    return plane === Plane.XY
      ? Math.round(this.fz) === lockedVal
      : Math.round(this.fx) === lockedVal;
  }

  /**
   * Slice-space render position for the current plane.
   * Uses fractional values (fx, fz) so movement appears smooth between tiles.
   *
   * @param {string} plane - Active `Plane` value.
   * @returns {{ col: number, row: number }}
   */
  slicePos(plane) {
    return plane === Plane.XY
      ? { col: this.fx, row: this.fy }
      : { col: this.fz, row: this.fy };
  }

  /**
   * 3-D Manhattan distance to a point (typically the player's position).
   * @param {number} px,py,pz - Target position.
   * @returns {number}
   */
  distanceTo(px, py, pz) {
    return Math.abs(this.x - px) + Math.abs(this.y - py) + Math.abs(this.z - pz);
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  /**
   * Tick: recalculate BFS when needed, then advance one lerp step toward the
   * next path node.
   *
   * BFS recalculation strategy:
   *   Recalc is triggered when (a) the cooldown timer expires AND the cached
   *   path is exhausted, OR (b) the player moved to a new tile (target key
   *   changed). This two-condition gate prevents thrashing while still
   *   reacting promptly to player movement.
   *
   * @param {number}      dt     - Delta time in seconds.
   * @param {Player}      player - The player entity (read-only).
   * @param {string[][][]} world - Collision matrix.
   */
  update(dt, player, world) {
    this._bfsTimer -= dt;

    const targetKey = `${player.x},${player.y},${player.z}`;
    const targetMoved = this._pathTargetKey !== targetKey;

    // Recalculate only when the path is empty (avoiding mid-path interruptions)
    // and either the cooldown expired or the player changed tiles.
    if (this._path.length === 0 && (targetMoved || this._bfsTimer <= 0)) {
      this._path = bfs3D(
        world,
        Math.round(this.fx), Math.round(this.fy), Math.round(this.fz),
        player.x, player.y, player.z,
      );
      this._pathTargetKey = targetKey;
      this._bfsTimer      = CONFIG.BFS_INTERVAL;
      this._stepProgress  = 0;
    }

    if (this._path.length === 0) return;

    const next = this._path[0];
    this._stepProgress += this.speed * dt;

    if (this._stepProgress >= 1) {
      // Snap to the next discrete tile and dequeue it.
      this.fx = next.x; this.fy = next.y; this.fz = next.z;
      this.x  = next.x; this.y  = next.y; this.z  = next.z;
      this._path.shift();
      this._stepProgress = 0;
    } else {
      // Linear interpolation from current logical tile to next tile.
      // This is purely visual; the logical integer position does not change
      // until the lerp completes, keeping collision detection tile-accurate.
      this.fx = this.x + (next.x - this.x) * this._stepProgress;
      this.fy = this.y + (next.y - this.y) * this._stepProgress;
      this.fz = this.z + (next.z - this.z) * this._stepProgress;
    }
  }
}
