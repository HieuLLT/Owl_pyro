/**
 * @fileoverview HUDRenderer — draws the information panel at the bottom of the canvas.
 *
 * Completely decoupled from simulation logic:
 * it reads entity state as plain data but never mutates it.
 */

import { Plane, CONFIG, PALETTE } from './constants.js';

export class HUDRenderer {
  /**
   * @param {CanvasRenderingContext2D} ctx
   */
  constructor(ctx) {
    /** @private */ this._ctx = ctx;
  }

  /**
   * Draw the full HUD panel below the tile grid.
   *
   * @param {import('./entities.js').Player} player
   * @param {import('./entities.js').Enemy[]} enemies
   * @param {{ x: number, y: number, z: number }} exitPos
   * @param {HTMLCanvasElement} canvas
   * @param {number} nowSec - Current time in seconds (for blinking hints).
   */
  draw(player, enemies, exitPos, canvas, nowSec) {
    const ctx = this._ctx;
    const { width: W, height: H } = canvas;
    const FS   = CONFIG.HUD_FONT_SIZE;
    const PAD  = 14;
    const hudH = Math.floor(H * (1 - CONFIG.GRID_HEIGHT_RATIO)) + 8;
    const hudY = H - hudH;

    // ── Panel backdrop ─────────────────────────────────────────────────────
    ctx.fillStyle = PALETTE.hud;
    ctx.fillRect(0, hudY, W, hudH);

    // Top border line
    ctx.strokeStyle = PALETTE.hudBorder;
    ctx.lineWidth   = 1;
    ctx.beginPath();
    ctx.moveTo(0, hudY);
    ctx.lineTo(W, hudY);
    ctx.stroke();

    // Corner bracket decorations (aesthetic only — signals "terminal UI")
    this._drawCornerBrackets(hudY, W);

    // ── Layout rows ────────────────────────────────────────────────────────
    const row1 = hudY + PAD;
    const row2 = row1 + FS + 8;
    const row3 = row2 + FS + 8;

    ctx.font         = `${FS}px 'Space Mono', monospace`;
    ctx.textBaseline = 'top';

    this._drawPlaneLabel(player, PAD, row1);
    this._drawPlayerPosition(player, PAD, row2);
    this._drawControlHint(nowSec, PAD, row3, FS);
    this._drawExitInfo(exitPos, W / 2, row1);
    this._drawEnemyPanel(player, enemies, W, PAD, FS, row2);
  }

  // ── Private section ────────────────────────────────────────────────────────

  /** @private */
  _drawCornerBrackets(hudY, W) {
    const ctx = this._ctx;
    const BL  = 16;
    ctx.strokeStyle = PALETTE.hudBorder;
    ctx.lineWidth   = 1.5;

    for (const [bx, dir] of [[0, 1], [W, -1]]) {
      ctx.beginPath();
      ctx.moveTo(bx + dir * BL, hudY);
      ctx.lineTo(bx, hudY);
      ctx.lineTo(bx, hudY + BL);
      ctx.stroke();
    }
  }

  /** @private */
  _drawPlaneLabel(player, x, y) {
    const ctx    = this._ctx;
    const isXY   = player.plane === Plane.XY;
    const colour = isXY ? PALETTE.planeXY : PALETTE.planeZY;
    const label  = isXY
      ? `[VIEW A]  XY Plane  --  Z locked = ${player.z}`
      : `[VIEW B]  ZY Plane  --  X locked = ${player.x}`;

    ctx.fillStyle   = colour;
    ctx.shadowColor = colour;
    ctx.shadowBlur  = 8;
    ctx.textAlign   = 'left';
    ctx.fillText(label, x, y);
    ctx.shadowBlur  = 0;
  }

  /** @private */
  _drawPlayerPosition(player, x, y) {
    const ctx = this._ctx;
    ctx.fillStyle = '#888';
    ctx.textAlign = 'left';
    ctx.fillText(`Player: (${player.x}, ${player.y}, ${player.z})`, x, y);
  }

  /** @private */
  _drawControlHint(nowSec, x, y, fs) {
    // Blink the hint text at 2 Hz so it does not distract during gameplay.
    if (Math.floor(nowSec * 2) % 2 !== 0) return;
    const ctx = this._ctx;
    ctx.fillStyle = '#555';
    ctx.textAlign = 'left';
    ctx.fillText('[SHIFT / P]  rotate plane', x, y);
  }

  /** @private */
  _drawExitInfo(exitPos, cx, y) {
    const ctx = this._ctx;
    ctx.fillStyle = '#665500';
    ctx.textAlign = 'center';
    ctx.fillText(`EXIT at (${exitPos.x},${exitPos.y},${exitPos.z})`, cx, y);
  }

  /**
   * Draw the enemy status panel on the right side of the HUD.
   * Colour-codes each enemy by Manhattan distance (red=danger, orange=caution, grey=far).
   * @private
   */
  _drawEnemyPanel(player, enemies, W, PAD, FS, baseRow) {
    const ctx    = this._ctx;
    const PANEL_W = 260;
    const panelX  = W - PANEL_W - PAD;

    ctx.fillStyle = '#333';
    ctx.textAlign = 'left';
    ctx.fillText('ENTITIES', panelX, baseRow - FS - 8);

    enemies.forEach((enemy, i) => {
      const dist    = enemy.distanceTo(player.x, player.y, player.z);
      const visible = enemy.isVisible(player.plane, player.lockedVal);
      const colour  = dist <= 3 ? '#ff4040' : dist <= 6 ? '#ff9900' : '#555';
      const visStr  = visible ? '[ VISIBLE ]' : '[ hidden  ]';

      ctx.fillStyle = colour;
      ctx.fillText(
        `${enemy.glyph} (${enemy.x},${enemy.y},${enemy.z})  d=${dist}  ${visStr}`,
        panelX,
        baseRow + i * (FS + 6),
      );
    });
  }
}
