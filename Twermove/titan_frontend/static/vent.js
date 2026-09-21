/**
 * vent.js — Animated vent-text background system
 *
 * Behaviour
 * ─────────
 * • 2 independent "slots" each cycle through random phrases.
 * • Each slot independently: picks a random phrase, font, position,
 *   size, and rotation → fades in over a random duration → holds
 *   for a random duration → fades out → waits a random gap → repeats.
 * • Because the two slots are staggered and fully independent, the
 *   visible count at any moment is organically 0, 1, or 2.
 * • Call `startVentText('elementId')` once the DOM is ready.
 */

(function () {
  'use strict';

  /* ── Phrase pool ─────────────────────────────── */
  const PHRASES = [
    'SYSTEM_CORRUPTION_IMMINENT',
    'ERROR_404_SOUL_NOT_FOUND',
    'OVERRIDE_PROTOCOL_ENGAGED',
    'NEURAL_LINK_DEGRADED',
    'TITAN_PROTOCOL_ACTIVE',
    'INPUT_STREAM_CORRUPTED',
    'SEQUENCE_BREACH_DETECTED',
    'MEMORY_ALLOCATION_FAILED',
    'CHASER_UNIT_DEPLOYED',
    'BLOCKADE_ENCOUNTERED',
    'DIVERTER_SEQUENCE_INITIATED',
    'HEARTBEAT_SIGNAL_LOST',
    'DATA_INTEGRITY_COMPROMISED',
    'TEMPORAL_SYNC_ERROR',
    'RHYTHM_PATTERN_UNKNOWN',
    'LINKED_LIST_TRAVERSAL_ERROR',
    'CORE_MEMORY_BLEEDING',
    'SIGNAL_LOST_IN_STATIC',
    'NO_RETURN_PATH_FOUND',
    'RECURSIVE_FAILURE_DETECTED',
    'IDENTITY_CORRUPTED',
    'EMOTIONAL_OVERFLOW',
    'SELF_DESTRUCT_PENDING',
    'HATRED_PROCESS_RUNNING',
    'RAGE_BUFFER_FULL',
    'SHAME_INDEX_MAX',
  ];

  /* ── Font pool (loaded via CSS @import) ─────── */
  const FONTS = [
    "'VT323', monospace",
    "'Orbitron', sans-serif",
    "'Share Tech Mono', monospace",
    "'Major Mono Display', monospace",
    "'Space Mono', monospace",
    "'Courier Prime', monospace",
  ];

  /* ── Helpers ─────────────────────────────────── */
  function pick(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
  }

  function rand(min, max) {
    return min + Math.random() * (max - min);
  }

  /**
   * Animate one slot element through a single phrase cycle.
   * When done, automatically recurses to start the next cycle.
   *
   * @param {HTMLElement} el   - The span element for this slot
   * @param {HTMLElement} container - Parent container (for bounds)
   */
  function cyclePhrase(el, container) {
    /* ── Pick random phrase properties ── */
    const phrase      = pick(PHRASES);
    const font        = pick(FONTS);
    const fontSize    = rand(10, 26);            // px
    const letterSp    = rand(2, 8);              // px
    const rotation    = rand(-18, 18);           // deg
    const targetOpacity = rand(0.10, 0.28);      // subtle, never harsh
    const fadeInMs    = rand(1200, 2800);         // how long to fade IN
    const holdMs      = rand(2500, 7500);         // how long to stay visible
    const fadeOutMs   = rand(1500, 3000);         // how long to fade OUT
    const gapMs       = rand(400, 2200);          // dark gap before next phrase

    /* ── Position: keep fully within viewport ── */
    const maxLeft = Math.max(10, 100 - (phrase.length * fontSize * 0.6 / window.innerWidth * 100));
    const leftPct = rand(2, maxLeft);
    const topPct  = rand(5, 88);

    /* ── Apply new phrase appearance ── */
    el.textContent         = phrase;
    el.style.fontFamily    = font;
    el.style.fontSize      = `${fontSize}px`;
    el.style.letterSpacing = `${letterSp}px`;
    el.style.left          = `${leftPct}%`;
    el.style.top           = `${topPct}%`;
    el.style.transform     = `rotate(${rotation}deg)`;
    el.style.opacity       = '0';
    el.style.transition    = 'opacity 0s';      // snap to 0 before fade-in

    /* Double rAF to flush the 0-opacity before starting the transition */
    requestAnimationFrame(() => requestAnimationFrame(() => {
      /* FADE IN */
      el.style.transition = `opacity ${fadeInMs}ms ease`;
      el.style.opacity    = String(targetOpacity);

      /* After fade-in + hold → FADE OUT */
      setTimeout(() => {
        el.style.transition = `opacity ${fadeOutMs}ms ease`;
        el.style.opacity    = '0';

        /* After fade-out → gap → next phrase */
        setTimeout(() => cyclePhrase(el, container), fadeOutMs + gapMs);
      }, fadeInMs + holdMs);
    }));
  }

  /**
   * Initialise the vent-text system inside `containerId`.
   * Creates 2 independent slot elements and starts them cycling
   * with a staggered initial delay so they don't always fire together.
   *
   * @param {string} containerId - id of the .vent-bg div
   */
  window.startVentText = function startVentText(containerId) {
    const container = document.getElementById(containerId);
    if (!container) return;

    const SLOT_COUNT = 2;

    for (let i = 0; i < SLOT_COUNT; i++) {
      const el = document.createElement('span');
      el.className = 'vt';
      container.appendChild(el);

      /* Stagger start: first slot begins almost immediately,
         second waits a random 1-4 s so they're out of sync */
      const stagger = i === 0 ? rand(200, 800) : rand(1000, 4000);
      setTimeout(() => cyclePhrase(el, container), stagger);
    }
  };
}());
