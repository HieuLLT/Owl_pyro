/**
 * ═══════════════════════════════════════════════════════════════
 *  dialogue.js — Twermove Dialogue Engine
 * ═══════════════════════════════════════════════════════════════
 *
 *  MODULE MAP
 *  ──────────
 *  § 1  Constants & Config
 *  § 2  Glitch Renderer  — ký tự nhiễu loạn cho Red voice
 *  § 3  DialogueQueue    — hàng đợi, không cho 2 voice cùng hiện
 *  § 4  VoiceRenderer    — vẽ White / Red lên DOM
 *  § 5  TriggerSystem    — nhận condition → chọn đúng dòng → push queue
 *  § 6  DialogueEngine   — public API: init, trigger, fire, destroy
 *
 *  PUBLIC API (window.DialogueEngine)
 *  ────────────────────────────────────
 *  DialogueEngine.init()                → load JSON, khởi động engine
 *  DialogueEngine.trigger(conditionId)  → kích hoạt theo condition
 *  DialogueEngine.fire(dialogueId)      → kích hoạt theo ID cụ thể
 *  DialogueEngine.setSuppressRed(bool)  → tắt Red voice (khi nhắm mắt)
 *  DialogueEngine.setGameState(obj)     → cập nhật state game (energy, hp, v.v.)
 */

"use strict";

(function () {

  /* ═══════════════════════════════════════════════════════════════
     § 1 · CONSTANTS & CONFIG
  ═══════════════════════════════════════════════════════════════ */

  const DIALOGUE_SRC = "/static/dialogue.json";

  const CFG = {
    // White voice
    white: {
      fadeInMs:  600,
      holdMs:   3200,
      fadeOutMs: 700,
      // Vị trí: dưới màn hình, căn trái — diegetic feel
      positionTop:  "auto",
      positionBottom: "clamp(80px, 10vh, 140px)",
      positionLeft: "clamp(28px, 5vw, 80px)",
    },
    // Red voice
    red: {
      fadeInMs:   80,    // xuất hiện đột ngột
      holdMs:    2600,
      fadeOutMs: 400,
      // Vị trí: random, có thể che tầm nhìn
      positionRandom: true,
    },
    // Queue
    minGapMs:      1400,   // khoảng nghỉ tối thiểu giữa 2 dòng
    maxQueueSize:  3,      // không buffer quá 3 dòng chờ
    // Glitch
    glitchChars:   "01#$%&@*÷∑∆≠≈?/|\\<>{}[]█▓░",
    glitchTickMs:  55,     // tốc độ scramble
    glitchPasses:  6,      // số lần scramble trước khi reveal
  };

  /* ═══════════════════════════════════════════════════════════════
     § 2 · GLITCH RENDERER
  ═══════════════════════════════════════════════════════════════ */

  /**
   * Hiển thị text với hiệu ứng scramble từ nhiễu → rõ chữ dần.
   * @param {HTMLElement} el     element chứa text
   * @param {string}      text   chuỗi đích
   * @param {Function}    onDone callback khi xong
   */
  function glitchReveal(el, text, onDone) {
    const chars   = CFG.glitchChars;
    const total   = CFG.glitchPasses;
    const tickMs  = CFG.glitchTickMs;
    let   pass    = 0;

    function tick() {
      if (pass >= total) {
        el.textContent = text;
        onDone?.();
        return;
      }
      const ratio = pass / total;       // 0 → 1: sạch dần
      let result  = "";
      for (let i = 0; i < text.length; i++) {
        if (text[i] === " " || text[i] === "\n") {
          result += text[i];
        } else if (Math.random() > ratio) {
          result += chars[Math.floor(Math.random() * chars.length)];
        } else {
          result += text[i];
        }
      }
      el.textContent = result;
      pass++;
      setTimeout(tick, tickMs);
    }

    tick();
  }

  /* ═══════════════════════════════════════════════════════════════
     § 3 · DIALOGUE QUEUE
  ═══════════════════════════════════════════════════════════════ */

  const Queue = (() => {
    let _queue    = [];     // [{dialogue, priority}]
    let _busy     = false;  // true khi đang hiển thị
    let _lastEnd  = 0;      // timestamp kết thúc dòng cuối

    function _next() {
      if (_busy || _queue.length === 0) return;
      const gap = CFG.minGapMs - (performance.now() - _lastEnd);
      if (gap > 0) {
        setTimeout(_next, gap);
        return;
      }
      _busy = true;
      const { dialogue } = _queue.shift();
      VoiceRenderer.show(dialogue, () => {
        _busy    = false;
        _lastEnd = performance.now();
        _next();
      });
    }

    return {
      push(dialogue, priority = 0) {
        if (_queue.length >= CFG.maxQueueSize) return; // drop nếu đầy
        _queue.push({ dialogue, priority });
        // sort: priority cao hơn lên trước (0 = normal, 1 = urgent)
        _queue.sort((a, b) => b.priority - a.priority);
        _next();
      },
      clear() { _queue = []; },
      get busy() { return _busy; },
    };
  })();

  /* ═══════════════════════════════════════════════════════════════
     § 4 · VOICE RENDERER
  ═══════════════════════════════════════════════════════════════ */

  const VoiceRenderer = (() => {
    let _container = null;

    function _ensureContainer() {
      if (_container) return;
      _container = document.createElement("div");
      _container.id = "dialogue-layer";
      Object.assign(_container.style, {
        position: "fixed",
        inset:    "0",
        zIndex:   "500",
        pointerEvents: "none",
      });
      document.body.appendChild(_container);
    }

    /** Tạo element cho White voice (survival_white) */
    function _buildWhite(text) {
      const el = document.createElement("div");
      el.className = "dlg-white";
      el.textContent = text;
      Object.assign(el.style, {
        position:   "fixed",
        bottom:     CFG.white.positionBottom,
        left:       CFG.white.positionLeft,
        maxWidth:   "clamp(260px, 42vw, 560px)",
        fontFamily: "'Share Tech Mono', 'Space Mono', monospace",
        fontSize:   "clamp(10px, 1.2vw, 13px)",
        letterSpacing: "0.12em",
        lineHeight: "1.7",
        color:      "rgba(180, 220, 255, 0.82)",
        textShadow: "0 0 14px rgba(100,180,255,0.4)",
        opacity:    "0",
        transition: `opacity ${CFG.white.fadeInMs}ms ease`,
        pointerEvents: "none",
        userSelect: "none",
        // Diegetic: không có border/background, chữ khắc vào void
        padding:    "0",
        background: "none",
        border:     "none",
      });
      return el;
    }

    /** Tạo element cho Red voice (manipulation_red) */
    function _buildRed(text) {
      const el = document.createElement("div");
      el.className = "dlg-red";

      // Vị trí random — che khuất tầm nhìn, unpredictable
      const topPct  = 8  + Math.random() * 68;   // 8% → 76%
      const leftPct = 4  + Math.random() * 60;   // 4% → 64%
      const tilt    = (Math.random() - 0.5) * 14; // -7° → +7°

      Object.assign(el.style, {
        position:   "fixed",
        top:        `${topPct}%`,
        left:       `${leftPct}%`,
        maxWidth:   "clamp(200px, 52vw, 720px)",
        fontFamily: "'MTO Getting Angry', 'KillCrazy', 'Space Mono', monospace",
        fontSize:   `clamp(13px, ${1.4 + Math.random() * 1.4}vw, 28px)`,
        letterSpacing: "0.06em",
        lineHeight: "1.3",
        color:      `rgba(${200 + Math.floor(Math.random()*55)}, ${Math.floor(Math.random()*40)}, ${Math.floor(Math.random()*40)}, 0.93)`,
        textShadow: `0 0 18px rgba(255,0,0,0.7), 0 0 40px rgba(180,0,0,0.3), 2px 2px 0 rgba(0,0,0,0.9)`,
        transform:  `rotate(${tilt}deg)`,
        opacity:    "0",
        transition: `opacity ${CFG.red.fadeInMs}ms step-end`,  // muncul mendadak
        pointerEvents: "none",
        userSelect: "none",
        mixBlendMode: "screen",
        zIndex:     "501",
        padding:    "0",
        background: "none",
        border:     "none",
      });
      return el;
    }

    return {
      /**
       * Hiển thị một dòng dialogue, gọi onDone() khi kết thúc.
       * @param {Object}   dialogue  {id, type, text, trigger}
       * @param {Function} onDone
       */
      show(dialogue, onDone) {
        _ensureContainer();

        const isRed = dialogue.type === "manipulation_red";
        const el    = isRed ? _buildRed(dialogue.text) : _buildWhite(dialogue.text);
        el.dataset.id = dialogue.id;

        _container.appendChild(el);

        if (isRed) {
          // Red: scramble rồi reveal, sau đó fade in ngay
          glitchReveal(el, dialogue.text, () => {
            el.style.opacity = "1";
          });

          // Hold → fade out
          const totalMs = (CFG.glitchPasses * CFG.glitchTickMs)
                        + CFG.red.holdMs;
          setTimeout(() => {
            el.style.transition = `opacity ${CFG.red.fadeOutMs}ms ease`;
            el.style.opacity    = "0";
            setTimeout(() => { el.remove(); onDone?.(); }, CFG.red.fadeOutMs);
          }, totalMs);

        } else {
          // White: fade in mượt → hold → fade out
          requestAnimationFrame(() => requestAnimationFrame(() => {
            el.style.opacity = "1";
          }));
          setTimeout(() => {
            el.style.transition = `opacity ${CFG.white.fadeOutMs}ms ease`;
            el.style.opacity    = "0";
            setTimeout(() => { el.remove(); onDone?.(); }, CFG.white.fadeOutMs);
          }, CFG.white.fadeInMs + CFG.white.holdMs);
        }
      },

      /** Xóa ngay tất cả Red voice đang hiện (khi nhắm mắt) */
      clearRed() {
        if (!_container) return;
        _container.querySelectorAll(".dlg-red").forEach(el => {
          el.style.transition = "opacity 120ms ease";
          el.style.opacity    = "0";
          setTimeout(() => el.remove(), 130);
        });
      },
    };
  })();

  /* ═══════════════════════════════════════════════════════════════
     § 5 · TRIGGER SYSTEM
  ═══════════════════════════════════════════════════════════════ */

  const TriggerSystem = (() => {
    let _db          = [];        // toàn bộ dialogues từ JSON
    let _suppressRed = false;     // true khi mắt nhắm
    // Cooldown per trigger: không spam cùng 1 condition
    const _cooldowns = new Map(); // trigger → timestamp last fire
    const COOLDOWN_MS = 8000;

    /** Lọc dialogues theo trigger, loại trừ đang cooldown */
    function _getPool(triggerId, type) {
      return _db.filter(d => {
        if (type && d.type !== type) return false;
        return d.trigger === triggerId || d.trigger === "generic";
      });
    }

    /** Chọn ngẫu nhiên 1 entry từ pool */
    function _pick(pool) {
      if (!pool.length) return null;
      return pool[Math.floor(Math.random() * pool.length)];
    }

    /** Kiểm tra cooldown */
    function _onCooldown(key) {
      const last = _cooldowns.get(key) ?? 0;
      return (performance.now() - last) < COOLDOWN_MS;
    }

    return {
      load(db) { _db = db; },

      /**
       * Kích hoạt theo conditionId.
       * Engine tự quyết White hay Red dựa trên tỷ lệ 60/40.
       * (Red bị chặn nếu _suppressRed = true)
       * @param {string} conditionId  VD: "energy_below_20"
       * @param {number} priority     0 = normal, 1 = urgent
       */
      fire(conditionId, priority = 0) {
        const coolKey = conditionId;
        if (_onCooldown(coolKey)) return;

        // Tỷ lệ 60% White / 40% Red (Red bị chặn nếu nhắm mắt)
        const preferRed = !_suppressRed && Math.random() < 0.40;
        const type      = preferRed ? "manipulation_red" : "survival_white";

        const pool = _getPool(conditionId, type);
        if (!pool.length) return;

        const picked = _pick(pool);
        if (!picked) return;

        _cooldowns.set(coolKey, performance.now());
        Queue.push(picked, priority);
      },

      /** Kích hoạt theo ID cụ thể (bypass cooldown) */
      fireById(id) {
        const found = _db.find(d => d.id === id);
        if (!found) return;
        if (found.type === "manipulation_red" && _suppressRed) return;
        Queue.push(found, 1);
      },

      setSuppressRed(bool) {
        _suppressRed = bool;
        if (bool) VoiceRenderer.clearRed(); // xóa ngay khi nhắm mắt
      },
    };
  })();

  /* ═══════════════════════════════════════════════════════════════
     § 6 · DIALOGUE ENGINE — PUBLIC API
  ═══════════════════════════════════════════════════════════════ */

  let _loaded = false;

  const DialogueEngine = {
    /**
     * Load JSON và khởi động engine.
     * Phải gọi trước bất kỳ hàm nào khác.
     * @returns {Promise<void>}
     */
    async init() {
      if (_loaded) return;
      try {
        const resp = await fetch(DIALOGUE_SRC);
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        const data = await resp.json();
        TriggerSystem.load(data.dialogues);
        _loaded = true;
        console.info(`[DialogueEngine] Loaded ${data.dialogues.length} entries.`);
      } catch (err) {
        console.error("[DialogueEngine] Failed to load dialogue.json:", err);
      }
    },

    /**
     * Kích hoạt theo condition. Engine tự chọn White/Red.
     * @param {string} conditionId  VD: "energy_below_20"
     * @param {number} priority     0 = normal, 1 = urgent
     */
    trigger(conditionId, priority = 0) {
      if (!_loaded) { console.warn("[DialogueEngine] Not loaded yet."); return; }
      TriggerSystem.fire(conditionId, priority);
    },

    /**
     * Kích hoạt theo ID cụ thể (dùng để test hoặc scripted moment).
     * @param {string} id   VD: "W_001", "R_007"
     */
    fire(id) {
      if (!_loaded) { console.warn("[DialogueEngine] Not loaded yet."); return; }
      TriggerSystem.fireById(id);
    },

    /**
     * Tắt/bật Red voice.
     * Gọi với `true` khi player nhắm mắt (hold Space).
     * @param {boolean} bool
     */
    setSuppressRed(bool) {
      TriggerSystem.setSuppressRed(bool);
    },

    /** Xóa hàng đợi hiện tại. */
    clearQueue() {
      Queue.clear();
    },

    /** Kiểm tra engine đã load chưa. */
    get ready() { return _loaded; },
  };

  window.DialogueEngine = DialogueEngine;

})();
