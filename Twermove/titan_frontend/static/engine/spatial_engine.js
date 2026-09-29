/**
 * @fileoverview SpatialEngine — orchestrator / public API for the real-time
 * 3D spatial cross-section game.
 *
 * Architecture (Facade + Composition over Inheritance)
 * ─────────────────────────────────────────────────────
 * This class is a thin coordinator. It:
 *   1. Owns simulation state (world, player, enemies, game phase).
 *   2. Runs the requestAnimationFrame loop.
 *   3. Delegates all rendering to `WorldRenderer` and `HUDRenderer`.
 *   4. Delegates all input to a small set of event listeners that call
 *      the relevant `Player` or engine methods.
 *
 * Nothing in this file touches the Canvas API directly — that boundary is
 * strictly enforced so the renderer modules can be swapped or tested alone.
 *
 * @module SpatialEngine
 */

import { Plane, CONFIG }      from './constants.js';
import { Player, Enemy }      from './entities.js';
import { WorldRenderer }      from './world_renderer.js';
import { HUDRenderer }        from './hud_renderer.js';

/** @typedef {'playing'|'won'|'lost'} GameState */

// Keys that trigger plane swap (Shift, p, Space, Tab)
const SWAP_KEYS = new Set(['Shift', 'p', ' ', 'Tab']);

// Keys that control movement
const MOVE_KEYS = new Set([
  'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight',
  'w', 'a', 's', 'd',
]);

export class SpatialEngine {
  /**
   * Instantiate and immediately start the game loop.
   *
   * @param {HTMLCanvasElement} canvas  - Target canvas element.
   * @param {Object}            mapData - Response from `/api/spatial-map`.
   * @param {string[][][]}      mapData.world          - world[z][y][x] matrix.
   * @param {[number,number,number]} mapData.player_start - [x, y, z].
   * @param {[number,number,number][]} mapData.enemies  - Array of [x, y, z].
   * @param {[number,number,number]} mapData.exit       - [x, y, z].
   */
  constructor(canvas, mapData) {
    this._canvas = canvas;
    this._ctx    = canvas.getContext('2d');

    // ── World data ─────────────────────────────────────────────────────────
    this._world = mapData.world;
    this._DZ    = this._world.length;
    this._DY    = this._world[0].length;
    this._DX    = this._world[0][0].length;

    // ── Entities ───────────────────────────────────────────────────────────
    const [sx, sy, sz] = mapData.player_start;
    this._player = new Player(sx, sy, sz);

    this._enemies = mapData.enemies.map(([ex, ey, ez], i) =>
      new Enemy(
        ex, ey, ez,
        String.fromCharCode(CONFIG.ENEMY_GLYPH_BASE + i),  // 'E', 'F', 'G', …
        CONFIG.ENEMY_BASE_SPEED + i * CONFIG.ENEMY_SPEED_STEP,
      ),
    );

    const [exitX, exitY, exitZ] = mapData.exit;
    this._exitPos = { x: exitX, y: exitY, z: exitZ };

    // ── State ──────────────────────────────────────────────────────────────
    /** @type {GameState} */ this._state  = 'playing';
    this._winner  = /** @type {string|null} */ (null);
    this._scanY   = 0;
    this._layout  = this._recalcLayout();

    // ── Renderers (no logic, only drawing) ────────────────────────────────
    this._worldRenderer = new WorldRenderer(this._ctx);
    this._hudRenderer   = new HUDRenderer(this._ctx);

    // ── Callbacks (set via public API) ────────────────────────────────────
    /** @private @type {Function|null} */ this._onWin  = null;
    /** @private @type {Function|null} */ this._onLose = null;

    // ── Bootstrap ─────────────────────────────────────────────────────────
    this._boundKeyDown = this._handleKeyDown.bind(this);
    this._boundKeyUp   = this._handleKeyUp.bind(this);
    window.addEventListener('keydown', this._boundKeyDown);
    window.addEventListener('keyup',   this._boundKeyUp);
    this._bindMobileButton();

    this._raf      = null;
    this._lastTime = null;
    this._raf = requestAnimationFrame(t => this._loop(t));
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /**
   * Register a callback to fire when the player reaches the exit.
   * @param {Function} fn
   */
  onWin(fn)  { this._onWin  = fn; }

  /**
   * Register a callback to fire when an enemy catches the player.
   * @param {Function} fn
   */
  onLose(fn) { this._onLose = fn; }

  /**
   * Stop the game loop and remove all event listeners.
   * Always call this before re-instantiating (e.g. on restart) to prevent
   * dangling listener leaks and double-RAF frames.
   */
  destroy() {
    if (this._raf !== null) cancelAnimationFrame(this._raf);
    window.removeEventListener('keydown', this._boundKeyDown);
    window.removeEventListener('keyup',   this._boundKeyUp);
  }

  /**
   * Notify the engine that the canvas has been resized.
   * Should be called from the window `resize` event handler in the host page.
   */
  onResize() {
    this._layout = this._recalcLayout();
  }

  // ── Layout ─────────────────────────────────────────────────────────────────

  /** @private */
  _recalcLayout() {
    return WorldRenderer.calcLayout(
      this._canvas, this._DX, this._DY, this._DZ, this._player.plane,
    );
  }

  // ── Input handlers ─────────────────────────────────────────────────────────

  /** @private */
  _handleKeyDown(e) {
    if (this._state !== 'playing') return;

    if (SWAP_KEYS.has(e.key)) {
      e.preventDefault();
      this._swapPlane();
      return;
    }

    if (MOVE_KEYS.has(e.key)) {
      e.preventDefault();
      this._player.pressKey(e.key);
    }
  }

  /** @private */
  _handleKeyUp(e) {
    this._player.releaseKey(e.key);
  }

  /** @private */
  _bindMobileButton() {
    // The host page may include a #btnSwapPlane button for touch devices.
    document.getElementById('btnSwapPlane')
      ?.addEventListener('click', () => {
        if (this._state === 'playing') this._swapPlane();
      });
  }

  /** @private */
  _swapPlane() {
    this._player.swapPlane();
    // Recalculate layout because column count can change (DX vs DZ differ).
    this._layout = this._recalcLayout();
  }

  // ── Game loop ──────────────────────────────────────────────────────────────

  /**
   * Main requestAnimationFrame callback.
   * Clamps delta-time to prevent spiral-of-death after tab switches.
   * @private
   */
  _loop(now) {
    const dt = Math.min(
      (now - (this._lastTime ?? now)) / 1000,
      CONFIG.MAX_DT,
    );
    this._lastTime = now;

    if (this._state === 'playing') this._update(dt);
    this._draw(now / 1000);

    this._raf = requestAnimationFrame(t => this._loop(t));
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  /**
   * Advance all simulation state by `dt` seconds.
   * Win/lose checks run after entity updates so collisions are never missed.
   * @private
   */
  _update(dt) {
    this._player.update(dt, this._world);

    for (const enemy of this._enemies) {
      enemy.update(dt, this._player, this._world);
    }

    // Advance the scanline animation independently of game state.
    this._scanY = (this._scanY + CONFIG.SCANLINE_SPEED * dt) % this._canvas.height;

    this._checkWin();
    this._checkLose();
  }

  /** @private */
  _checkWin() {
    const { x, y, z } = this._player;
    const ep = this._exitPos;
    if (x === ep.x && y === ep.y && z === ep.z) {
      this._state = 'won';
      this._onWin?.();
    }
  }

  /** @private */
  _checkLose() {
    for (const enemy of this._enemies) {
      if (enemy.x === this._player.x &&
          enemy.y === this._player.y &&
          enemy.z === this._player.z) {
        this._state  = 'lost';
        this._winner = enemy.glyph;
        this._onLose?.();
        return; // only trigger once
      }
    }
  }

  // ── Draw ───────────────────────────────────────────────────────────────────

  /**
   * Full render pass: background → world → exit → entities → grid → scanline
   * → HUD → end-screen (if applicable).
   *
   * The camera shake is applied as a canvas translate so every subsequent
   * draw call is uniformly offset. `ctx.restore()` resets it at the end.
   *
   * @private
   * @param {number} nowSec - Current time in seconds.
   */
  _draw(nowSec) {
    const ctx    = this._ctx;
    const canvas = this._canvas;
    const shake  = this._player.shake;

    ctx.save();
    ctx.translate(shake.x, shake.y);

    this._worldRenderer.drawBackground(canvas);
    this._worldRenderer.drawWorld(this._world, this._player, this._layout);
    this._worldRenderer.drawExit(this._exitPos, this._player, this._layout, nowSec);
    this._worldRenderer.drawEntities(this._player, this._enemies, this._layout, nowSec);
    this._worldRenderer.drawGrid(this._layout);
    this._worldRenderer.drawScanline(this._scanY, canvas.width);
    this._hudRenderer.draw(this._player, this._enemies, this._exitPos, canvas, nowSec);

    if (this._state !== 'playing') {
      this._worldRenderer.drawEndScreen(
        this._state === 'won', this._winner, canvas, nowSec,
      );
    }

    ctx.restore();
  }
}
