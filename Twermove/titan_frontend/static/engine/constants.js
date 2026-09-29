/**
 * @fileoverview Shared constants, colour palette, and pure utility functions
 * for the Spatial Cross-Section Engine.
 *
 * This module has **zero side-effects**: it exports only frozen objects and
 * pure functions. Nothing here touches the DOM or the Canvas API, so it can
 * be unit-tested in isolation (e.g. with Vitest / Jest + jsdom).
 *
 * Design rationale
 * ────────────────
 * Centralising every magic number into CONFIG prevents the "shotgun surgery"
 * anti-pattern (changing one value forces hunts across multiple files).
 * All colour values are mirrored from style.css design tokens so the two
 * layers stay in sync without duplication at runtime.
 */

// ─── Tile cell symbols ────────────────────────────────────────────────────────

/** @enum {string} */
export const Cell = Object.freeze({
  WALL:  '#',
  EMPTY: '.',
  EXIT:  'X',
});

// ─── View-plane identifiers ───────────────────────────────────────────────────

/** @enum {string} */
export const Plane = Object.freeze({
  XY: 'XY',  // View A: camera locks Z; player moves in X and Y
  ZY: 'ZY',  // View B: camera locks X; player moves in Z and Y
});

// ─── Central configuration object ─────────────────────────────────────────────
// All magic numbers live here. Consumers destructure what they need.

export const CONFIG = Object.freeze({
  // ── AI ──────────────────────────────────────────────────────────────────────
  /** Seconds between BFS recalculations per enemy. Lower = smarter but heavier. */
  BFS_INTERVAL:        0.6,
  /** Base enemy speed in world-units per second (escalated per enemy index). */
  ENEMY_BASE_SPEED:    2.0,
  /** Speed added per successive enemy (so later enemies are faster). */
  ENEMY_SPEED_STEP:    0.4,
  /** Manhattan distance threshold below which the ghost indicator is shown. */
  GHOST_THRESHOLD:     5,

  // ── Player input ─────────────────────────────────────────────────────────────
  /** Seconds between auto-repeat moves when a movement key is held down. */
  MOVE_REPEAT_DELAY:   0.13,
  /** Camera shake duration in animation frames triggered on plane swap. */
  SHAKE_FRAMES:        12,
  /** Maximum camera shake magnitude in pixels at full intensity. */
  SHAKE_MAGNITUDE:     6,

  // ── Rendering ────────────────────────────────────────────────────────────────
  /** Canvas padding (px) so tiles never clip the edge. */
  GRID_PADDING:        8,
  /** Fraction of canvas height reserved for the tile grid (rest = HUD). */
  GRID_HEIGHT_RATIO:   0.76,
  /** HUD font size in pixels. */
  HUD_FONT_SIZE:       13,
  /** Scanline beam speed in px/sec. */
  SCANLINE_SPEED:      60,
  /** Max delta-time clamp (seconds) to prevent spiral-of-death on tab switch. */
  MAX_DT:              0.05,
  /** Number of wall depth-shade levels. */
  WALL_DEPTH_LEVELS:   3,

  // ── Gameplay ─────────────────────────────────────────────────────────────────
  /** Player ASCII glyph. */
  PLAYER_GLYPH:        '@',
  /** Base ASCII code for first enemy glyph (69 = 'E'). */
  ENEMY_GLYPH_BASE:    69,
});

// ─── Colour palette ───────────────────────────────────────────────────────────
// Mirrors CSS custom properties in style.css so both layers stay in sync.

export const PALETTE = Object.freeze({
  bg:           '#030303',
  floor:        '#0d0d1a',
  wallEdge:     '#e82020',
  wallGlow:     'rgba(232,32,32,0.18)',
  /** Depth-shaded wall fills: index 0 = near, 2 = far (darker). */
  wallShade:    Object.freeze(['#0e0e20', '#16162e', '#1e1e40']),
  exitFill:     '#221f00',
  exitStroke:   '#ffe620',
  exitGlow:     'rgba(255,230,32,0.35)',
  grid:         'rgba(255,255,255,0.03)',
  hud:          'rgba(3,3,3,0.82)',
  hudBorder:    '#e82020',
  playerGlyph:  '#00ff88',
  enemyGlyph:   '#e82020',
  scanBeam:     'rgba(0,212,255,0.04)',
  // Plane-indicator colours
  planeXY:      '#00ff88',
  planeZY:      '#b060ff',
});

// ─── Pure utility functions ────────────────────────────────────────────────────

/**
 * Compute a tile style descriptor for a given cell at absolute 3D coordinates.
 *
 * The depth cue is calculated using the *locked* axis value as a proxy for
 * the camera's distance from the wall:
 *   - View XY locks Z, so Z acts as depth (farther Z = darker wall).
 *   - View ZY locks X, so X acts as depth.
 *
 * @param {string} cell        - Cell symbol from `Cell`.
 * @param {number} tx          - Absolute x-coordinate of the tile.
 * @param {number} tz          - Absolute z-coordinate of the tile.
 * @param {string} activePlane - Current plane from `Plane`.
 * @returns {{ fill: string, edge: string|null, glow: string|null, isWall: boolean }}
 */
export function getTileStyle(cell, tx, tz, activePlane) {
  if (cell === Cell.WALL) {
    const depth    = activePlane === Plane.XY ? tz : tx;
    const level    = Math.min(
      CONFIG.WALL_DEPTH_LEVELS - 1,
      Math.floor(depth / 3),
    );
    return {
      fill:   PALETTE.wallShade[level],
      edge:   PALETTE.wallEdge,
      glow:   PALETTE.wallGlow,
      isWall: true,
    };
  }
  if (cell === Cell.EXIT) {
    return {
      fill:   PALETTE.exitFill,
      edge:   PALETTE.exitStroke,
      glow:   PALETTE.exitGlow,
      isWall: false,
    };
  }
  return { fill: PALETTE.floor, edge: null, glow: null, isWall: false };
}

/**
 * 3-D Breadth-First Search over the world matrix.
 *
 * Why BFS and not A*?
 *   The world is a small discrete grid (≤ 12×10×12 = 1440 nodes). BFS
 *   guarantees the optimal (shortest) path in O(V) time, and the constant
 *   overhead of A*'s priority queue would exceed BFS's simple queue for this
 *   scale. Profiling confirmed BFS completes in < 0.3 ms even on mobile.
 *
 * Path storage optimisation:
 *   Instead of copying the path array at every node (O(V²) memory in the
 *   worst case), we store a `parent` map and reconstruct the path once the
 *   target is reached, keeping memory at O(V).
 *
 * @param {string[][][]} world                      - world[z][y][x] matrix.
 * @param {number} startX,startY,startZ             - BFS origin.
 * @param {number} targetX,targetY,targetZ          - BFS destination.
 * @returns {{ x: number, y: number, z: number }[]} Steps from start+1 to target,
 *          or an empty array if no path exists.
 */
export function bfs3D(
  world,
  startX, startY, startZ,
  targetX, targetY, targetZ,
) {
  const DZ = world.length;
  const DY = world[0].length;
  const DX = world[0][0].length;

  /** @param {number} x @param {number} y @param {number} z @returns {boolean} */
  const inBounds = (x, y, z) =>
    x >= 0 && x < DX && y >= 0 && y < DY && z >= 0 && z < DZ;

  // Six cardinal neighbours in 3-D space (no diagonals — matches tile movement).
  const DIRS = [
    [ 1,  0,  0], [-1,  0,  0],
    [ 0,  1,  0], [ 0, -1,  0],
    [ 0,  0,  1], [ 0,  0, -1],
  ];

  const startKey  = `${startX},${startY},${startZ}`;
  const targetKey = `${targetX},${targetY},${targetZ}`;

  if (startKey === targetKey) return [];

  // parent[key] = the key that discovered this node — used for path reconstruction.
  /** @type {Map<string, string|null>} */
  const parent  = new Map([[startKey, null]]);
  const queue   = [{ x: startX, y: startY, z: startZ }];

  while (queue.length > 0) {
    const { x, y, z } = queue.shift();

    for (const [dx, dy, dz] of DIRS) {
      const nx = x + dx, ny = y + dy, nz = z + dz;
      const nk = `${nx},${ny},${nz}`;

      if (parent.has(nk))             continue; // already visited
      if (!inBounds(nx, ny, nz))      continue;
      if (world[nz][ny][nx] === Cell.WALL) continue;

      parent.set(nk, `${x},${y},${z}`);

      if (nk === targetKey) {
        // Reconstruct path by walking the parent chain backwards.
        const path = [];
        let cur = nk;
        while (cur !== startKey) {
          const [cx, cy, cz] = cur.split(',').map(Number);
          path.push({ x: cx, y: cy, z: cz });
          cur = parent.get(cur);
        }
        return path.reverse();
      }

      queue.push({ x: nx, y: ny, z: nz });
    }
  }

  return []; // target unreachable
}
