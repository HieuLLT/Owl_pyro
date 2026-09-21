/**
 * game.js — Project Titan 3D Cylindrical DSA Engine
 *
 * Architecture
 * ─────────────
 * Renders a 3D cylindrical graph using orthographic projection.
 * 
 * Mechanics:
 * - A/D to rotate tower (simulates AVL rotations, affects Balance Factor)
 * - W to climb to the node currently facing the front
 * - SPACE for BFS Ping (highlights shortest path temporarily)
 */

'use strict';

/* ══════════════════════════════════════════════════
   CONSTANTS
══════════════════════════════════════════════════ */
const CYLINDER_RADIUS = 280;
const NODE_Y_GAP      = 100;
const MAX_BALANCE     = 4;

const MOD_STYLE = {
  NONE:     { stroke: '#f0f0f0', fill: 'rgba(240,240,240,0.07)', text: '#f0f0f0', glow: 'rgba(240,240,240,0.5)' },
  CHASER:   { stroke: '#ff3535', fill: 'rgba(255,53,53,0.14)',   text: '#ff5555', glow: 'rgba(255,32,32,0.7)'   },
  BLOCKADE: { stroke: '#1a5fff', fill: 'rgba(26,95,255,0.14)',   text: '#4488ff', glow: 'rgba(26,95,255,0.7)'   },
  DIVERTER: { stroke: '#ff6b00', fill: 'rgba(255,107,0,0.14)',   text: '#ffaa44', glow: 'rgba(255,107,0,0.7)'   },
};

/* ══════════════════════════════════════════════════
   TITAN GAME ENGINE
══════════════════════════════════════════════════ */
class TitanGame {
  constructor() {
    this.canvas = document.getElementById('gameCanvas');
    this.ctx    = this.canvas.getContext('2d');
    this._resize();
    window.addEventListener('resize', () => this._resize());

    /* Load graph data */
    const rawBeatmap = localStorage.getItem('titan_beatmap');
    if (!rawBeatmap || rawBeatmap === '[]') {
      document.getElementById('noBeatmap').style.display = 'flex';
      return;
    }

    this.nodes = JSON.parse(rawBeatmap); // List of GraphNodes
    this.nodeMap = new Map();
    this.nodes.forEach(n => this.nodeMap.set(n.node_id, n));

    /* Game State */
    this.phase = 'playing'; // 'playing', 'done'
    
    // Player state
    this.currentNodeId = this.nodes[0].node_id;
    this.cameraAngle = this.nodes[0].angle_offset; // Look at starting node
    this.targetCameraAngle = this.cameraAngle;
    this.cameraY = 0;
    this.targetCameraY = 0;
    
    // Mechanics
    this.balanceFactor = 0;
    this.bfsPingActive = 0; // cooldown / alpha timer
    this.bfsPingCooldown = false;
    
    // Stats
    this.nodesCleared = 0;
    this.errors = 0;
    this.deathCause = '';

    /* Setup */
    this._setupInput();
    document.getElementById('retryBtn').addEventListener('click', () => window.location.reload());
    
    this._updateHUD();
    requestAnimationFrame(ts => this._loop(ts));
  }

  _resize() {
    this.canvas.width  = window.innerWidth;
    this.canvas.height = window.innerHeight;
    this.CX = this.canvas.width / 2;
    this.CY = this.canvas.height * 0.75; // Player sits in bottom quarter of screen
    this.NODE_SIZE = Math.max(38, Math.min(50, this.canvas.height * 0.05));
  }

  /* ── Input ──────────────────────────────────── */
  _setupInput() {
    document.addEventListener('keydown', e => {
      if (this.phase !== 'playing') return;
      if (e.repeat) return;
      
      const key = e.key.toUpperCase();
      if (key === 'A') this._rotateTower(1);
      if (key === 'D') this._rotateTower(-1);
      if (key === 'W') this._climb();
      if (key === ' ') this._triggerPing();
      
      this._setKeyUI(key, true);
    });

    document.addEventListener('keyup', e => {
      const key = e.key.toUpperCase();
      this._setKeyUI(key, false);
    });
  }

  _setKeyUI(key, active) {
    const ids = { 'A': 'key-a', 'W': 'key-w', 'D': 'key-d', ' ': 'key-w' }; // Map space to climb for now if they press it
    if (ids[key]) {
      const el = document.getElementById(ids[key]);
      if (el) el.classList.toggle('active', active);
    }
  }

  /* ── Mechanics ──────────────────────────────── */
  _rotateTower(direction) {
    // direction: 1 = left, -1 = right
    this.targetCameraAngle += direction * 45;
    this.balanceFactor += direction;
    this._updateHUD();
    
    // Check AVL Collapse
    if (Math.abs(this.balanceFactor) >= MAX_BALANCE) {
      this._triggerMissEffect();
      this.deathCause = 'AVL BALANCE COLLAPSE';
      this._endGame();
    }
  }

  _climb() {
    const current = this.nodeMap.get(this.currentNodeId);
    
    // Find children
    const children = [];
    if (current.left_child_id !== null) children.push(this.nodeMap.get(current.left_child_id));
    if (current.right_child_id !== null) children.push(this.nodeMap.get(current.right_child_id));
    
    if (children.length === 0) {
      this._endGame(); // Victory
      return;
    }

    // Find the child that is currently facing the front (closest to camera angle)
    let bestChild = null;
    let minDiff = 999;

    for (const child of children) {
      // Normalize angle diff
      let diff = Math.abs((child.angle_offset - this.targetCameraAngle) % 360);
      if (diff > 180) diff = 360 - diff;
      
      if (diff < minDiff) {
        minDiff = diff;
        bestChild = child;
      }
    }

    if (!bestChild || minDiff > 25) {
      // No stair in front of you to climb
      this._triggerMissEffect();
      return;
    }

    // Check if the chosen child is a trap (breaks BST)
    if (bestChild.is_alt_branch) {
      this.errors++;
      this._triggerMissEffect();
      this.deathCause = 'BST VIOLATION DETECTED';
      this._endGame();
      return;
    }

    // Success! Climb to it
    this.currentNodeId = bestChild.node_id;
    this.nodesCleared++;
    
    // Reset balance factor on successful climb? Or keep it?
    // Let's keep it to make it challenging, but maybe shrink it towards 0.
    if (this.balanceFactor > 0) this.balanceFactor--;
    else if (this.balanceFactor < 0) this.balanceFactor++;
    
    this._updateHUD();
    
    // Flash green
    const flash = document.getElementById('missFlash');
    if (flash) {
      flash.style.background = 'rgba(0, 255, 136, 0.2)';
      flash.classList.add('active');
      setTimeout(() => {
        flash.classList.remove('active');
        flash.style.background = 'rgba(232, 32, 32, 0)';
      }, 100);
    }
    
    // Check if won
    if (bestChild.left_child_id === null && bestChild.right_child_id === null) {
      setTimeout(() => this._endGame(), 500);
    }
  }

  _triggerPing() {
    if (this.bfsPingCooldown) return;
    this.bfsPingActive = 1.0;
    this.bfsPingCooldown = true;
    
    const ps = document.getElementById('pingStatus');
    if (ps) {
      ps.textContent = 'RECHARGING...';
      ps.style.color = '#ff6b00';
    }
    
    setTimeout(() => {
      this.bfsPingCooldown = false;
      if (ps) {
        ps.textContent = 'READY [SPACE]';
        ps.style.color = '#00ff88';
      }
    }, 3000);
  }

  _triggerMissEffect() {
    document.body.classList.remove('shake');
    void document.body.offsetWidth;
    document.body.classList.add('shake');
    
    const flash = document.getElementById('missFlash');
    if (flash) {
      flash.style.background = 'rgba(232, 32, 32, 0)'; // Reset to red
      flash.classList.add('active');
      setTimeout(() => flash.classList.remove('active'), 100);
    }
  }

  _updateHUD() {
    const current = this.nodeMap.get(this.currentNodeId);
    if (!current) return;
    
    const valEl = document.getElementById('hudValue');
    if (valEl) valEl.textContent = `VAL: ${current.value}`;
    
    const progEl = document.getElementById('hudProgress');
    if (progEl) progEl.textContent = `${this.nodesCleared} CLIMBED`;
    
    const balEl = document.getElementById('balanceValue');
    if (balEl) {
      balEl.textContent = this.balanceFactor;
      // Color code balance
      let color = '#fff';
      if (Math.abs(this.balanceFactor) >= MAX_BALANCE - 1) color = '#ff3535';
      else if (Math.abs(this.balanceFactor) > 1) color = '#ffaa44';
      balEl.style.color = color;
    }
  }

  /* ── Render Loop ────────────────────────────── */
  _loop(ts) {
    const ctx = this.ctx;
    const w = this.canvas.width;
    const h = this.canvas.height;

    ctx.fillStyle = '#030303';
    ctx.fillRect(0, 0, w, h);

    if (this.phase === 'playing') {
      // Smooth camera interpolation
      this.cameraAngle += (this.targetCameraAngle - this.cameraAngle) * 0.15;
      
      const current = this.nodeMap.get(this.currentNodeId);
      if (current) {
        this.targetCameraY = current.height_index * NODE_Y_GAP;
      }
      this.cameraY += (this.targetCameraY - this.cameraY) * 0.1;
      
      this._drawBackground(ctx, w, h);
      this._drawCylinderGrid(ctx, w, h);
      this._drawNodes(ctx, w, h);
    }
    
    // BFS Ping decay
    if (this.bfsPingActive > 0) {
      this.bfsPingActive -= 0.015;
      if (this.bfsPingActive < 0) this.bfsPingActive = 0;
    }

    if (this.phase !== 'done') requestAnimationFrame(ts => this._loop(ts));
  }

  _drawBackground(ctx, w, h) {
    const grad = ctx.createRadialGradient(w * 0.5, h * 0.5, h * 0.1, w * 0.5, h * 0.5, h * 0.85);
    grad.addColorStop(0, 'transparent');
    grad.addColorStop(1, 'rgba(0,0,0,0.85)');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, w, h);
  }

  _drawCylinderGrid(ctx, w, h) {
    ctx.save();
    ctx.strokeStyle = 'rgba(232,32,32,0.08)';
    ctx.lineWidth = 1;
    
    // Draw vertical lines for the cylinder
    for (let i = 0; i < 8; i++) {
      const a = (i * 45) - this.cameraAngle;
      const rad = a * Math.PI / 180;
      const z = CYLINDER_RADIUS * Math.cos(rad);
      
      // Only draw lines on the front half
      if (z > -50) {
        const x = this.CX + CYLINDER_RADIUS * Math.sin(rad);
        ctx.beginPath();
        ctx.moveTo(x, 0);
        ctx.lineTo(x, h);
        ctx.stroke();
      }
    }
    ctx.restore();
  }

  _drawNodes(ctx, w, h) {
    // Sort nodes by Z depth so front nodes render on top of back nodes
    const renderList = this.nodes.map(node => {
      const a = node.angle_offset - this.cameraAngle;
      const rad = a * Math.PI / 180;
      return {
        node,
        x: this.CX + CYLINDER_RADIUS * Math.sin(rad),
        y: this.CY - (node.height_index * NODE_Y_GAP) + this.cameraY,
        z: CYLINDER_RADIUS * Math.cos(rad),
        isCurrent: node.node_id === this.currentNodeId
      };
    });
    
    renderList.sort((a, b) => a.z - b.z);

    // Identify the shortest path for BFS Ping
    const validPathIds = new Set();
    if (this.bfsPingActive > 0) {
      let curr = this.nodes[0];
      while (curr) {
        validPathIds.add(curr.node_id);
        if (curr.left_child_id && !this.nodeMap.get(curr.left_child_id).is_alt_branch) {
          curr = this.nodeMap.get(curr.left_child_id);
        } else if (curr.right_child_id && !this.nodeMap.get(curr.right_child_id).is_alt_branch) {
          curr = this.nodeMap.get(curr.right_child_id);
        } else {
          curr = this.nodes.find(n => n.node_id > curr.node_id && !n.is_alt_branch);
        }
      }
    }

    for (const item of renderList) {
      const { node, x, y, z, isCurrent } = item;
      
      // Cull off-screen vertically
      if (y > h + 100 || y < -100) continue;

      // Base opacity and scale from Z depth
      const depthRatio = (z + CYLINDER_RADIUS) / (2 * CYLINDER_RADIUS); // 0 (back) to 1 (front)
      let alpha = 0.1 + depthRatio * 0.9;
      let scale = 0.5 + depthRatio * 0.5;

      // Make back nodes very faint
      if (z < 0) {
        alpha *= 0.2;
      }

      this._drawSingleNode(ctx, node, x, y, alpha, scale, isCurrent, validPathIds.has(node.node_id));
      
      // Draw connection lines to children
      if (z > -100) {
        ctx.save();
        ctx.strokeStyle = `rgba(232,32,32,${alpha * 0.3})`;
        ctx.lineWidth = 2 * scale;
        
        const drawLineTo = (childId) => {
          if (childId !== null) {
            const child = this.nodeMap.get(childId);
            const ca = child.angle_offset - this.cameraAngle;
            const cx = this.CX + CYLINDER_RADIUS * Math.sin(ca * Math.PI / 180);
            const cy = this.CY - (child.height_index * NODE_Y_GAP) + this.cameraY;
            ctx.beginPath();
            ctx.moveTo(x, y);
            ctx.lineTo(cx, cy);
            ctx.stroke();
          }
        };
        
        drawLineTo(node.left_child_id);
        drawLineTo(node.right_child_id);
        
        // Linear fallback if no explicit children but not end of list
        if (node.left_child_id === null && node.right_child_id === null) {
           const next = this.nodes.find(n => n.height_index === node.height_index + 1 && n.angle_offset === node.angle_offset);
           if (next) drawLineTo(next.node_id);
        }
        
        ctx.restore();
      }
    }
  }

  _drawSingleNode(ctx, node, x, y, alpha, scale, isCurrent, isPingedPath) {
    const s = MOD_STYLE[node.modifier] || MOD_STYLE.NONE;
    const sz = this.NODE_SIZE * scale;
    const h = sz / 2;

    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.translate(x, y);

    // BFS Ping highlight
    if (isPingedPath && this.bfsPingActive > 0) {
      ctx.shadowColor = '#00ff88';
      ctx.shadowBlur = 20 * this.bfsPingActive;
      ctx.fillStyle = `rgba(0, 255, 136, ${0.4 * this.bfsPingActive})`;
      ctx.beginPath();
      ctx.arc(0, 0, sz, 0, Math.PI * 2);
      ctx.fill();
    }

    // Current player indicator (pulsing glow)
    if (isCurrent) {
      const pulse = Math.sin(performance.now() / 150) * 0.5 + 0.5;
      ctx.shadowColor = s.glow;
      ctx.shadowBlur = 15 + pulse * 20;
    } else {
      ctx.shadowColor = 'transparent';
      ctx.shadowBlur = 0;
    }

    ctx.beginPath();
    if (node.modifier === 'DIVERTER') {
      ctx.moveTo(0, -h * 1.2); ctx.lineTo(h * 1.2, 0);
      ctx.lineTo(0, h * 1.2); ctx.lineTo(-h * 1.2, 0);
    } else if (node.modifier === 'CHASER') {
      ctx.moveTo(-h + 8, -h); ctx.lineTo(h + 8, -h);
      ctx.lineTo(h - 8, h); ctx.lineTo(-h - 8, h);
    } else {
      ctx.rect(-h, -h, sz, sz);
    }
    ctx.closePath();

    ctx.fillStyle = isCurrent ? 'rgba(255,255,255,0.9)' : s.fill;
    ctx.fill();

    ctx.strokeStyle = isCurrent ? '#fff' : s.stroke;
    ctx.lineWidth = isCurrent ? 3 : 2;
    ctx.stroke();

    // Node Value
    ctx.shadowBlur = 0;
    ctx.fillStyle = isCurrent ? '#000' : s.text;
    ctx.font = `bold ${Math.round(sz * 0.4)}px Space Mono`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(node.value, 0, 0);

    ctx.restore();
  }

  _endGame() {
    this.phase = 'done';
    
    // Stop body shake if it was active
    document.body.classList.remove('shake');
    
    const panel = document.getElementById('resultsOverlay');
    const status = document.getElementById('resultStatus');
    const accuracy = document.getElementById('resultAccuracy');
    
    panel.style.display = 'flex';
    
    if (this.deathCause) {
      status.textContent = 'SEQUENCE_FAILED';
      status.className = 'result-status fail';
      document.getElementById('resultCombo').textContent = this.deathCause;
    } else {
      status.textContent = 'SEQUENCE_CLEARED';
      status.className = 'result-status success';
      status.style.color = '#00ff88';
      document.getElementById('resultCombo').textContent = 'SURVIVED';
      document.getElementById('resultCombo').style.color = '#00ff88';
    }
    
    const total = this.nodes.filter(n => !n.is_alt_branch).length;
    document.getElementById('resultHits').textContent = this.nodesCleared;
    document.getElementById('resultMisses').textContent = this.errors;
    
    const acc = total > 0 ? Math.round((this.nodesCleared / total) * 100) : 0;
    accuracy.textContent = `${acc}%`;
  }
}

// ─────────────────────────────────────────────────────────────
// Init
// ─────────────────────────────────────────────────────────────
window.addEventListener('DOMContentLoaded', () => {
  window.titanGame = new TitanGame();
});
