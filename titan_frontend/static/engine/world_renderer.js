/**
 * @fileoverview WorldRenderer — pure Canvas 2D drawing of the spatial grid.
 *
 * Single responsibility
 * ─────────────────────
 * This class draws tiles, entities, the exit portal, the scanline beam, and
 * the grid overlay. It does **not** read input, update positions, or touch the
 * DOM outside of the canvas element it receives.
 *
 * All methods are prefixed with `draw` and are idempotent: calling them
 * multiple times with the same arguments produces the same output.
 */

import {
  Cell, Plane, CONFIG, PALETTE, getTileStyle,
} from './constants.js';

export class WorldRenderer {
  /**
   * @param {CanvasRenderingContext2D} ctx - Canvas 2D rendering context.
   */
  constructor(ctx) {
    /** @private */ this._ctx = ctx;
  }

  // ── Layout helpers ─────────────────────────────────────────────────────────

  /**
   * Calculate tile size and grid offset so the active slice is centred.
   *
   * We use the maximum column count (DX vs DZ) to compute `tileSize` so that
   * the canvas grid does not resize when the player swaps planes — preventing
   * a jarring layout shift on toggle.
   *
   * @param {HTMLCanvasElement} canvas
   * @param {number} DX,DY,DZ - World dimensions.
   * @param {string} plane     - Active `Plane` value.
   * @returns {{ tileSize: number, offX: number, offY: number, cols: number, rows: number }}
   */
  static calcLayout(canvas, DX, DY, DZ, plane) {
    const PAD      = CONFIG.GRID_PADDING;
    const maxCols  = Math.max(DX, DZ);
    const rows     = DY;
    const cols     = plane === Plane.XY ? DX : DZ;

    const gridH    = canvas.height * CONFIG.GRID_HEIGHT_RATIO;
    const tileByW  = Math.floor((canvas.width - PAD * 2) / maxCols);
    const tileByH  = Math.floor(gridH / rows);
    const tileSize = Math.min(tileByW, tileByH);

    const offX = Math.floor((canvas.width  - cols * tileSize) / 2);
    const offY = Math.floor((gridH - rows * tileSize) / 2) + 4;

    return { tileSize, offX, offY, cols, rows };
  }

  // ── Drawing methods ────────────────────────────────────────────────────────

  /**
   * Clear the canvas with the background colour.
   * @param {HTMLCanvasElement} canvas
   */
  drawBackground(canvas) {
    const ctx = this._ctx;
    // Extend fill beyond canvas bounds to cover the shake-translate offset.
    ctx.fillStyle = PALETTE.bg;
    ctx.fillRect(-10, -10, canvas.width + 20, canvas.height + 20);
  }

  /**
   * Draw all wall and floor tiles for the active 2-D slice.
   *
   * Slice selection:
   *   View XY → iterate cols=x, rows=y at fixed z=player.lockedVal.
   *   View ZY → iterate cols=z, rows=y at fixed x=player.lockedVal.
   *   The "col" variable is always the horizontal axis in the rendered image,
   *   while "row" is always vertical (Y), regardless of which 3D axes are active.
   *
   * @param {string[][][]} world
   * @param {import('./entities.js').Player} player
   * @param {{ tileSize: number, offX: number, offY: number, cols: number, rows: number }} layout
   */
  drawWorld(world, player, layout) {
    const ctx = this._ctx;
    const { plane, lockedVal }          = player;
    const { tileSize: T, offX, offY, cols, rows } = layout;

    for (let row = 0; row < rows; row++) {
      for (let col = 0; col < cols; col++) {
        // Derive absolute (tx, ty, tz) from slice coordinates.
        // In View XY: col→x, row→y, lockedVal→z.
        // In View ZY: lockedVal→x, row→y, col→z.
        const tx = plane === Plane.XY ? col        : lockedVal;
        const ty = row;
        const tz = plane === Plane.XY ? lockedVal  : col;

        const cell  = world[tz]?.[ty]?.[tx] ?? Cell.WALL;
        const style = getTileStyle(cell, tx, tz, plane);
        const px    = offX + col * T;
        const py    = offY + row * T;

        this._drawTile(px, py, T, style);
      }
    }
  }

  /**
   * Draw the exit portal tile with a pulsing yellow glow.
   *
   * The portal is only drawn when it lies within the active slice (i.e. its
   * locked-axis coordinate matches the player's locked value).
   *
   * @param {{ x: number, y: number, z: number }} exitPos
   * @param {import('./entities.js').Player} player
   * @param {{ tileSize: number, offX: number, offY: number }} layout
   * @param {number} nowSec - Current time in seconds (for animation).
   */
  drawExit(exitPos, player, layout, nowSec) {
    const { plane, lockedVal } = player;
    const { tileSize: T, offX, offY } = layout;

    // Exit is only visible when its hidden axis matches the camera's locked value.
    const onSlice = plane === Plane.XY
      ? exitPos.z === lockedVal
      : exitPos.x === lockedVal;
    if (!onSlice) return;

    const col  = plane === Plane.XY ? exitPos.x : exitPos.z;
    const row  = exitPos.y;
    const px   = offX + col * T;
    const py   = offY + row * T;
    const ctx  = this._ctx;
    const pulse = 0.5 + 0.5 * Math.sin(nowSec * 3);

    ctx.fillStyle = PALETTE.exitFill;
    ctx.fillRect(px, py, T, T);

    // Radial glow
    const grd = ctx.createRadialGradient(px + T/2, py + T/2, 0, px + T/2, py + T/2, T * 0.8);
    grd.addColorStop(0, `rgba(255,230,32,${0.4 + 0.25 * pulse})`);
    grd.addColorStop(1, 'transparent');
    ctx.fillStyle = grd;
    ctx.fillRect(px - 4, py - 4, T + 8, T + 8);

    ctx.strokeStyle = PALETTE.exitStroke;
    ctx.lineWidth   = 1.5;
    ctx.strokeRect(px + 0.5, py + 0.5, T - 1, T - 1);

    // 'X' glyph
    ctx.fillStyle    = PALETTE.exitStroke;
    ctx.font         = `bold ${Math.floor(T * 0.65)}px 'Space Mono', monospace`;
    ctx.textAlign    = 'center';
    ctx.textBaseline = 'middle';
    ctx.shadowColor  = PALETTE.exitStroke;
    ctx.shadowBlur   = 12 * pulse;
    ctx.fillText('X', px + T / 2, py + T / 2);
    ctx.shadowBlur   = 0;
  }

  /**
   * Draw the player (@) and all enemy glyphs (E, F, G…) on the slice.
   *
   * Entities off the current slice are invisible to the player — this is the
   * core stealth/surprise mechanic. A faint "ghost" indicator is drawn for
   * nearby enemies that are currently hidden to maintain spatial awareness.
   *
   * @param {import('./entities.js').Player} player
   * @param {import('./entities.js').Enemy[]} enemies
   * @param {{ tileSize: number, offX: number, offY: number }} layout
   * @param {number} nowSec - Current time in seconds (for animation).
   */
  drawEntities(player, enemies, layout, nowSec) {
    const ctx = this._ctx;
    const { plane, lockedVal } = player;
    const { tileSize: T, offX, offY } = layout;
    const fontSize = Math.floor(T * 0.72);

    ctx.font         = `bold ${fontSize}px 'Space Mono', monospace`;
    ctx.textAlign    = 'center';
    ctx.textBaseline = 'middle';

    // ── Enemies ─────────────────────────────────────────────────────────────
    for (const enemy of enemies) {
      if (!enemy.isVisible(plane, lockedVal)) {
        const dist = enemy.distanceTo(player.x, player.y, player.z);
        if (dist <= CONFIG.GHOST_THRESHOLD) {
          this._drawGhostIndicator(ctx, enemy, player, layout, dist);
        }
        continue;
      }

      const { col, row } = enemy.slicePos(plane);
      const px = offX + col * T;
      const py = offY + row * T;

      // Red aura
      const auraGrd = ctx.createRadialGradient(px+T/2, py+T/2, 0, px+T/2, py+T/2, T * 0.9);
      auraGrd.addColorStop(0, 'rgba(232,32,32,0.22)');
      auraGrd.addColorStop(1, 'transparent');
      ctx.fillStyle = auraGrd;
      ctx.fillRect(px - 4, py - 4, T + 8, T + 8);

      // Glitch flicker — uses a high-frequency sine so each enemy flickers independently.
      const flicker  = Math.sin(nowSec * 18 + enemy.x * 7) > 0.7;
      ctx.fillStyle  = flicker ? '#ff6060' : PALETTE.enemyGlyph;
      ctx.shadowColor = PALETTE.enemyGlyph;
      ctx.shadowBlur  = 14;
      ctx.fillText(enemy.glyph, px + T / 2, py + T / 2);
      ctx.shadowBlur  = 0;
    }

    // ── Player ───────────────────────────────────────────────────────────────
    const { col: pc, row: pr } = player.slicePos;
    const px = offX + pc * T;
    const py = offY + pr * T;

    // Green halo
    const haloGrd = ctx.createRadialGradient(px+T/2, py+T/2, 0, px+T/2, py+T/2, T * 0.85);
    haloGrd.addColorStop(0, 'rgba(0,255,136,0.18)');
    haloGrd.addColorStop(1, 'transparent');
    ctx.fillStyle = haloGrd;
    ctx.fillRect(px - 4, py - 4, T + 8, T + 8);

    // Breathing pulse — subtle scale oscillation tied to a slow sine wave.
    const breathe = 0.85 + 0.15 * Math.sin(nowSec * 2.5);
    ctx.save();
    ctx.translate(px + T / 2, py + T / 2);
    ctx.scale(breathe, breathe);
    ctx.fillStyle   = PALETTE.playerGlyph;
    ctx.shadowColor = PALETTE.playerGlyph;
    ctx.shadowBlur  = 18;
    ctx.fillText(CONFIG.PLAYER_GLYPH, 0, 0);
    ctx.shadowBlur  = 0;
    ctx.restore();
  }

  /**
   * Draw the subtle grid overlay on top of tiles.
   * @param {{ tileSize: number, offX: number, offY: number, cols: number, rows: number }} layout
   */
  drawGrid(layout) {
    const ctx = this._ctx;
    const { tileSize: T, offX, offY, cols, rows } = layout;

    ctx.strokeStyle = PALETTE.grid;
    ctx.lineWidth   = 0.5;

    for (let c = 0; c <= cols; c++) {
      const x = offX + c * T;
      ctx.beginPath();
      ctx.moveTo(x, offY);
      ctx.lineTo(x, offY + rows * T);
      ctx.stroke();
    }
    for (let r = 0; r <= rows; r++) {
      const y = offY + r * T;
      ctx.beginPath();
      ctx.moveTo(offX, y);
      ctx.lineTo(offX + cols * T, y);
      ctx.stroke();
    }
  }

  /**
   * Draw the animated CRT-style scanline beam.
   * @param {number} scanY        - Current Y position of the beam.
   * @param {number} canvasWidth
   */
  drawScanline(scanY, canvasWidth) {
    const ctx = this._ctx;
    const grd = ctx.createLinearGradient(0, scanY - 8, 0, scanY + 8);
    grd.addColorStop(0,   'transparent');
    grd.addColorStop(0.5, PALETTE.scanBeam);
    grd.addColorStop(1,   'transparent');
    ctx.fillStyle = grd;
    ctx.fillRect(0, scanY - 8, canvasWidth, 16);
  }

  /**
   * Draw end-game overlay (win or lose).
   * @param {boolean} won
   * @param {string|null} killerGlyph - Glyph of the enemy that caught the player.
   * @param {HTMLCanvasElement} canvas
   * @param {number} nowSec
   */
  drawEndScreen(won, killerGlyph, canvas, nowSec) {
    const ctx   = this._ctx;
    const { width: W, height: H } = canvas;
    const pulse = 0.5 + 0.5 * Math.sin(nowSec * 3);

    ctx.fillStyle = won ? 'rgba(0,20,10,0.82)' : 'rgba(20,0,0,0.88)';
    ctx.fillRect(0, 0, W, H);

    const colour = won ? PALETTE.playerGlyph : PALETTE.enemyGlyph;
    const header = won ? '** ESCAPED **' : '** CAUGHT **';
    const sub    = won
      ? 'Reality boundary breached.'
      : `Terminated by entity ${killerGlyph}.`;

    ctx.fillStyle    = colour;
    ctx.shadowColor  = colour;
    ctx.shadowBlur   = 30 * pulse;
    ctx.font         = `bold 36px 'Space Mono', monospace`;
    ctx.textAlign    = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(header, W / 2, H / 2 - 24);

    ctx.shadowBlur = 0;
    ctx.fillStyle  = '#888';
    ctx.font       = `14px 'Space Mono', monospace`;
    ctx.fillText(sub, W / 2, H / 2 + 20);

    ctx.fillStyle = '#444';
    ctx.font      = `12px 'Space Mono', monospace`;
    ctx.fillText('[R] restart', W / 2, H / 2 + 56);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /**
   * Draw a single coloured tile at canvas coordinates (px, py).
   * @private
   */
  _drawTile(px, py, T, style) {
    const ctx = this._ctx;

    ctx.fillStyle = style.fill;
    ctx.fillRect(px, py, T, T);

    if (!style.isWall) return;

    // Bevel highlight — top and left edges appear lighter to simulate depth.
    ctx.fillStyle = 'rgba(255,255,255,0.04)';
    ctx.fillRect(px, py, T, 2);
    ctx.fillRect(px, py, 2, T);

    // Shadow — bottom and right edges are darker.
    ctx.fillStyle = 'rgba(0,0,0,0.35)';
    ctx.fillRect(px, py + T - 2, T, 2);
    ctx.fillRect(px + T - 2, py, 2, T);

    // Red stroke border
    ctx.strokeStyle = style.edge;
    ctx.lineWidth   = 1;
    ctx.strokeRect(px + 0.5, py + 0.5, T - 1, T - 1);

    // Soft radial ambient glow
    const grd = ctx.createRadialGradient(px + T/2, py + T/2, 0, px + T/2, py + T/2, T * 0.8);
    grd.addColorStop(0, style.glow);
    grd.addColorStop(1, 'transparent');
    ctx.fillStyle = grd;
    ctx.fillRect(px - 2, py - 2, T + 4, T + 4);
  }

  /**
   * Draw a semi-transparent directional indicator for a hidden but nearby enemy.
   *
   * The indicator is placed on a circle whose radius is 40% of the canvas
   * half-width, pointing in the direction the enemy would appear if it were
   * projected onto the current slice. This gives the player situational
   * awareness without revealing the enemy's exact hidden position.
   *
   * @private
   */
  _drawGhostIndicator(ctx, enemy, player, layout, dist) {
    const alpha = Math.max(0, (CONFIG.GHOST_THRESHOLD - dist) / CONFIG.GHOST_THRESHOLD) * 0.45;
    if (alpha < 0.05) return;

    const { tileSize: T, offX, offY } = layout;
    const { plane } = player;

    // Project enemy into slice-space to get a direction vector.
    const ex = plane === Plane.XY
      ? offX + enemy.x * T + T / 2
      : offX + enemy.z * T + T / 2;
    const ey = offY + enemy.y * T + T / 2;

    const cw   = this._ctx.canvas.width;
    const ch   = this._ctx.canvas.height;
    const angle = Math.atan2(ey - ch / 2, ex - cw / 2);
    const ix    = cw / 2 + Math.cos(angle) * (cw * 0.4);
    const iy    = ch / 2 + Math.sin(angle) * (ch * 0.35);

    ctx.save();
    ctx.globalAlpha  = alpha;
    ctx.translate(ix, iy);
    ctx.rotate(angle);
    ctx.fillStyle    = PALETTE.enemyGlyph;
    ctx.font         = `bold 11px 'Space Mono', monospace`;
    ctx.textAlign    = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(`${enemy.glyph} ??`, 0, 0);
    ctx.restore();
  }
}
