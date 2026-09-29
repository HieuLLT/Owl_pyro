/* ===================================================
   ATMOSPHERE.JS
   Vent text, flash monologues, system tears, and
   visual hooks for Terminal Attrition.
=================================================== */

(function() {
  const BG_POOL = [
    { text: "My life is over.",                 tint: "despair-tint" },
    { text: "I'll never see them again.",       tint: "despair-tint" },
    { text: "I'm so tired.",                    tint: "despair-tint" },
    { text: "What's the point.",                tint: "despair-tint" },
    { text: "I can't do this anymore.",         tint: "despair-tint" },
    { text: "Nobody knows.",                    tint: "despair-tint" },
    { text: "I've already lost.",               tint: "despair-tint" },
    { text: "It's over.",                       tint: "despair-tint" },
    { text: "I am hollow.",                     tint: "despair-tint" },
    { text: "I'm crying.",                      tint: "despair-tint" },
    { text: "It's been a while.",               tint: "despair-tint" },
    { text: "I'll never\u2014",                 tint: "despair-tint" },
    { text: "Nothing changes.",                 tint: "despair-tint" },
    { text: "Nobody's coming.",                 tint: "despair-tint" },
    { text: "I used to be fine.",               tint: "despair-tint" },
    { text: "It wasn't supposed to be this.",   tint: "despair-tint" },
    { text: "WHY WON'T IT STOP.",               tint: "rage-tint" },
    { text: "I WANT TO BREAK EVERYTHING.",      tint: "rage-tint" },
    { text: "JUST LET ME OUT.",                 tint: "rage-tint" },
    { text: "STOP LOOKING AT ME.",              tint: "rage-tint" },
    { text: "I COULD SCREAM.",                  tint: "rage-tint" },
    { text: "GET OUT OF MY HEAD.",              tint: "rage-tint" },
    { text: "SHUT UP SHUT UP SHUT UP.",         tint: "rage-tint" },
    { text: "I'M DONE.",                        tint: "rage-tint" },
    { text: "Man up.",                          tint: "rage-tint" },
    { text: "Stop that.",                       tint: "rage-tint" },
    { text: "I hate what I've become.",         tint: "rage-tint" },
    { text: "I hate them.",                     tint: "rage-tint" },
    { text: "They deserved it.",                tint: "rage-tint" },
    { text: "I hate myself most of all.",       tint: "shame-tint" },
    { text: "Why do they get to be happy.",     tint: "envy-tint" },
    { text: "Look at them. Just look.",         tint: "envy-tint" },
    { text: "They never had to fight.",         tint: "envy-tint" },
    { text: "It should have been me.",          tint: "envy-tint" },
    { text: "Why not me.",                      tint: "envy-tint" },
    { text: "They all saw.",                    tint: "shame-tint" },
    { text: "I knew they would find out.",      tint: "shame-tint" },
    { text: "Don't look at me.",                tint: "shame-tint" },
    { text: "I am disgusting.",                 tint: "shame-tint" },
    { text: "I deserve this.",                  tint: "shame-tint" },
    { text: "You would hate me if you knew.",   tint: "shame-tint" },
    { text: "They know what I am.",             tint: "shame-tint" },
    { text: "Who am I kidding?",                tint: "shame-tint" },
    { text: "I\u2014",                          tint: "shame-tint" },
    { text: "Oh. I'm having one of these.",     tint: "shame-tint" },
    { text: "ERROR_NULL_POINTER",               tint: "system-tint" },
    { text: "SEQUENCE_BREACH",                  tint: "rage-tint"   },
    { text: "HEARTBEAT_LOST",                   tint: "system-tint" },
    { text: "NEURAL_LINK_DEGRADED",             tint: "despair-tint"},
    { text: "MEMORY_FAULT",                     tint: "system-tint" },
    { text: "IDENTITY_CORRUPTED",               tint: "shame-tint"  },
    { text: "CORE_INTEGRITY_FAIL",              tint: "rage-tint"   },
    { text: "ENVY_LOOP_DETECTED",               tint: "envy-tint"   },
    { text: "EMOTIONAL_OVERFLOW",               tint: "rage-tint"   },
    { text: "SELF_DESTRUCT_PENDING",            tint: "despair-tint"},
    { text: "RAGE_BUFFER_FULL",                 tint: "rage-tint"   },
    { text: "SHAME_INDEX_MAX",                  tint: "shame-tint"  },
    { text: "HATRED_PROCESS_RUNNING",           tint: "system-tint" },
    { text: "TEMPORAL_SYNC_ERROR",              tint: "system-tint" },
    { text: "INPUT_STREAM_CORRUPTED",           tint: "system-tint" },
  ];

  const MONOLOGUE = [
    { text: "My life is over.",                         size: 1.65, emotion: 'despair' },
    { text: "I'll never see them again.",               size: 1.45, emotion: 'despair' },
    { text: "It's been a while.",                       size: 1.15, emotion: 'despair' },
    { text: "Fuck. I'm crying.",                        size: 1.6,  emotion: 'despair' },
    { text: "I am so tired.",                           size: 1.3,  emotion: 'despair' },
    { text: "I've already lost.",                       size: 1.4,  emotion: 'despair' },
    { text: "Nobody's coming.",                         size: 1.3,  emotion: 'despair' },
    { text: "Something is wrong with me.",              size: 1.35, emotion: 'despair' },
    { text: "Make it stop. Please.",                    size: 1.5,  emotion: 'despair' },
    { text: "I'm tired of pretending I'm fine.",        size: 1.25, emotion: 'despair' },
    { text: "I used to be fine.",                       size: 1.2,  emotion: 'despair' },
    { text: "Nothing changes.",                         size: 1.25, emotion: 'despair' },
    { text: "I'll never\u2014",                         size: 1.6,  emotion: 'despair' },
    { text: "Why? It's not like I'll ever\u2014",        size: 1.15, emotion: 'despair' },
    { text: "This wasn't how it was supposed to go.",   size: 1.2,  emotion: 'despair' },
    { text: "WHY WON'T IT STOP.",                       size: 1.7,  emotion: 'rage'   },
    { text: "GET OUT OF MY HEAD.",                      size: 1.45, emotion: 'rage'   },
    { text: "Stop that. Fucking\u2026 man up.",          size: 1.2,  emotion: 'rage'   },
    { text: "I COULD SCREAM.",                          size: 1.6,  emotion: 'rage'   },
    { text: "JUST LET ME OUT.",                         size: 1.5,  emotion: 'rage'   },
    { text: "STOP LOOKING AT ME.",                      size: 1.4,  emotion: 'rage'   },
    { text: "SHUT UP SHUT UP SHUT UP.",                 size: 1.75, emotion: 'rage'   },
    { text: "I WANT TO BREAK EVERYTHING.",              size: 1.5,  emotion: 'rage'   },
    { text: "Why do they get to be happy.",             size: 1.3,  emotion: 'envy'   },
    { text: "It should have been me.",                  size: 1.2,  emotion: 'envy'   },
    { text: "Look at them. Just look.",                 size: 1.2,  emotion: 'envy'   },
    { text: "They never had to fight.",                 size: 1.25, emotion: 'envy'   },
    { text: "Why not me.",                              size: 1.6,  emotion: 'envy'   },
    { text: "They don't even try.",                    size: 1.15, emotion: 'envy'   },
    { text: "They know what I am.",                     size: 1.55, emotion: 'shame'  },
    { text: "Who am I kidding?",                        size: 1.2,  emotion: 'shame'  },
    { text: "Oh. Here we go again.",                    size: 1.35, emotion: 'shame'  },
    { text: "They all saw.",                            size: 1.2,  emotion: 'shame'  },
    { text: "You would hate me if you knew.",           size: 1.15, emotion: 'shame'  },
    { text: "\u2026I should stop saying that.",         size: 1.35, emotion: 'shame'  },
    { text: "Don't look at me.",                        size: 1.3,  emotion: 'shame'  },
    { text: "I am disgusting.",                         size: 1.4,  emotion: 'shame'  },
    { text: "I deserve this.",                          size: 1.35, emotion: 'shame'  },
    { text: "I hate what I've become.",                 size: 1.3,  emotion: 'hatred' },
    { text: "I hate them.",                             size: 1.2,  emotion: 'hatred' },
    { text: "I hate myself most of all.",               size: 1.35, emotion: 'hatred' },
    { text: "They deserved it.",                        size: 1.3,  emotion: 'hatred' },
    { text: "I\u2014",          size: 5.0,  emotion: 'fragment' },
    { text: "I can't\u2014",    size: 4.2,  emotion: 'fragment' },
    { text: "Why won't\u2014",  size: 3.8,  emotion: 'fragment' },
  ];

  function ShuffleBag(source) {
    this._src = source;
    this._bag = [];
    this._fill = function () {
      this._bag = [...this._src];
      for (let i = this._bag.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [this._bag[i], this._bag[j]] = [this._bag[j], this._bag[i]];
      }
    };
    this.draw = function () {
      if (this._bag.length === 0) this._fill();
      return this._bag.pop();
    };
    this._fill();
  }

  // Configuration and State
  let config = {
    reducedMotion: false,
    integrity: 100,
    memory: 100,
    willpower: 100,
    intCollapsed: false,
    memCollapsed: false,
    willCollapsed: false
  };

  // Check initial accessibility
  if (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    config.reducedMotion = true;
  }
  if (localStorage.getItem('titan_reduce_flash') === 'true') {
    config.reducedMotion = true;
  }

  // --- Background Setup ---
  const chaosContainer = document.getElementById('chaos-container');
  const bgBag = new ShuffleBag(BG_POOL);
  const bgNodes = [];
  
  if (chaosContainer) {
    for (let i = 0; i < 220; i++) {
      const entry = bgBag.draw();
      const span = document.createElement('span');
      span.classList.add('vent-phrase');
      if (entry.tint) span.classList.add(entry.tint);
      span.dataset.original = entry.text;
      span.innerText = entry.text;
      span.style.left = `${Math.random() * 112 - 6}vw`;
      span.style.top  = `${Math.random() * 112 - 6}vh`;
      const rot = Math.random() > 0.90 ? 90 : (Math.random() * 50 - 25);
      span.style.transform = `rotate(${rot}deg)`;
      const depth = Math.random();
      span.style.fontSize = `${depth * 4.5 + 0.4}rem`;
      span.style.filter   = `blur(${(1 - depth) * 4.5}px)`;
      span.style.opacity  = (depth * 0.32 + 0.015).toFixed(3);
      chaosContainer.appendChild(span);
      bgNodes.push(span);
    }
  }

  // --- Monologue System ---
  const _activeTexts = new Set();
  const flashStage = document.getElementById('flash-container');
  const EMOTION_CLASS = {
    rage: 'emotion-rage', envy: 'emotion-envy', despair: 'emotion-despair',
    shame: 'emotion-shame', hatred: 'emotion-hatred', fragment: 'emotion-fragment',
  };

  function flashPhrase(entry) {
    if (!flashStage) return Promise.resolve();
    const isClimax = entry.emotion === 'fragment';
    
    // In reduced motion, avoid jarring punch
    const reduced = config.reducedMotion;
    const fadeIn  = isClimax && !reduced ? 60 : 280 + Math.random() * 300;
    const hold    = isClimax ? 1800 + Math.random() * 1200 : 900 + Math.random() * 1400;
    const fadeOut = isClimax ? 1400 : 380 + Math.random() * 300;

    return new Promise(resolve => {
      const el = document.createElement('span');
      el.classList.add('flash-phrase');
      if (entry.emotion && EMOTION_CLASS[entry.emotion]) {
        el.classList.add(EMOTION_CLASS[entry.emotion]);
      }
      el.textContent = entry.text;
      _activeTexts.add(entry.text); 

      const scaled = entry.size * 1.15;
      el.style.fontSize = `clamp(${(scaled * 0.55).toFixed(2)}rem, ${(scaled * 1.5).toFixed(1)}vw, ${scaled.toFixed(2)}rem)`;

      const col = Math.floor(Math.random() * 3);
      const row = Math.floor(Math.random() * 3);
      el.style.left = `${4  + col * 28 + Math.random() * 22}vw`;
      el.style.top  = `${6  + row * 26 + Math.random() * 18}vh`;
      
      let tilt = 0;
      if (!reduced) {
         tilt = isClimax ? 0
          : entry.emotion === 'rage'  ? (Math.random() - 0.5) * 22
          : entry.emotion === 'shame' ? (Math.random() - 0.5) * 12
          : (Math.random() - 0.5) * 8;
      }
      el.style.transform = `rotate(${tilt}deg)`;
      flashStage.appendChild(el);

      if (isClimax && !reduced) {
        el.classList.add('climax-flash');
        setTimeout(() => {
          el.style.transition = `opacity ${fadeOut}ms ease`;
          el.style.opacity = '0';
          setTimeout(() => { _activeTexts.delete(entry.text); el.remove(); resolve(); }, fadeOut);
        }, hold);
      } else {
        requestAnimationFrame(() => requestAnimationFrame(() => {
          el.style.transition = `opacity ${fadeIn}ms ease`;
          el.style.opacity = '1';
        }));
        setTimeout(() => {
          el.style.transition = `opacity ${fadeOut}ms ease`;
          el.style.opacity = '0';
          setTimeout(() => { _activeTexts.delete(entry.text); el.remove(); resolve(); }, fadeOut);
        }, fadeIn + hold);
      }
    });
  }

  const _standard = MONOLOGUE.filter(e => e.emotion !== 'fragment');
  const _climax   = MONOLOGUE.filter(e => e.emotion === 'fragment');
  const _bagStd  = new ShuffleBag(_standard);
  const _bagFrag = new ShuffleBag(_climax);

  function pickSafe() {
    const useClimax = Math.random() < 0.20 && _climax.length > 0;
    const bag  = useClimax ? _bagFrag : _bagStd;
    const pool = useClimax ? _climax  : _standard;
    for (let t = 0; t < pool.length; t++) {
      const entry = bag.draw();
      if (!_activeTexts.has(entry.text)) return entry;
      bag._bag.unshift(entry); 
    }
    return bag.draw();
  }

  function startStream(streamIndex) {
    function fire() {
      // Scramble check for Memory collapse
      let entry = Object.assign({}, pickSafe());
      if (config.memCollapsed) {
          entry.text = scrambleString(entry.text, 1.0);
      }
      
      flashPhrase(entry);
      const gap = 1200 + Math.random() * 3800;
      setTimeout(fire, gap);
    }
    const stagger = streamIndex * (800 + Math.random() * 1600);
    setTimeout(fire, stagger);
  }

  if (flashStage) {
    setTimeout(() => {
      for (let i = 0; i < 3; i++) startStream(i);
    }, 300);
  }

  // --- Integrity System Tear Logic ---
  let tearTimer = null;
  const tearSlice = document.querySelector('.system-tear-slice');

  function scheduleTear() {
    clearTimeout(tearTimer);
    if (config.intCollapsed || config.reducedMotion) return; // handled statically

    let delay = 3000 + Math.random() * 4000;
    
    if (config.integrity < 30) {
      // 150ms on, 100-350ms off.
      delay = 100 + Math.random() * 250;
      // Cap at 3Hz (approx 333ms total cycle, since ON is 150ms, OFF must be at least 183ms)
      if (delay < 183) delay = 183; 
    } else if (config.integrity <= 60) {
      // linear 30->60 maps to 1.2s -> 5s (1200 -> 5000)
      const pct = (config.integrity - 30) / 30; // 0 to 1
      const baseDelay = 1200 + pct * 3800;
      delay = baseDelay + (Math.random() * 1000 - 500);
    }

    tearTimer = setTimeout(fireTear, delay);
  }

  function fireTear() {
    if (config.intCollapsed || config.reducedMotion) return;

    if (tearSlice) tearSlice.style.top = `${20 + Math.random() * 48}%`;
    document.body.classList.add('system-tear');
    
    setTimeout(() => {
      if (!config.intCollapsed) {
         document.body.classList.remove('system-tear');
      }
      scheduleTear(); 
    }, 150);
  }

  // Start tear loop
  scheduleTear();


  // --- Memory Corruption Logic ---
  let scrambleTimer = null;

  function scrambleString(str, intensity) {
    if (intensity <= 0) return str;
    const chars = "01#$%&@*+?/<>{}[]";
    let res = "";
    for (let i = 0; i < str.length; i++) {
      if (str[i] === ' ' || str[i] === '\n') {
        res += str[i];
      } else if (Math.random() < intensity) {
        res += chars[Math.floor(Math.random() * chars.length)];
      } else {
        res += str[i];
      }
    }
    return res;
  }

  function updateMemoryCorruption() {
    if (!chaosContainer) return;
    
    // Prob = ((100-memory)/100)^2
    const memProb = Math.pow((100 - config.memory) / 100, 2);
    
    // Scramble up to 20 nodes per tick to be gradual
    const maxUpdate = 20;
    let updated = 0;
    
    for (let i = 0; i < bgNodes.length; i++) {
       if (updated >= maxUpdate) break;
       // pick random node
       const idx = Math.floor(Math.random() * bgNodes.length);
       const node = bgNodes[idx];
       
       if (config.memCollapsed) {
           node.innerText = scrambleString(node.dataset.original, 0.8);
           updated++;
       } else if (Math.random() < memProb) {
           node.innerText = scrambleString(node.dataset.original, 0.6);
           updated++;
       } else {
           if (node.innerText !== node.dataset.original) {
               node.innerText = node.dataset.original;
               updated++;
           }
       }
    }

    // Event text scrambling during collapse
    if (config.memCollapsed) {
       const eventText = document.getElementById('eventText');
       if (eventText && !eventText.dataset.original) {
           eventText.dataset.original = eventText.textContent;
       }
       if (eventText) {
           eventText.textContent = scrambleString(eventText.dataset.original, 0.5);
       }
    } else {
       const eventText = document.getElementById('eventText');
       if (eventText && eventText.dataset.original && eventText.textContent !== eventText.dataset.original) {
           eventText.textContent = eventText.dataset.original;
       }
    }
  }

  // Scramble loop at 4Hz (or 1Hz reduced)
  setInterval(updateMemoryCorruption, config.reducedMotion ? 1000 : 250);


  // --- Public API ---
  window.Atmosphere = {
    init: function(opts) {
       if (opts && typeof opts.reducedMotion !== 'undefined') {
           this.setReducedMotion(opts.reducedMotion);
       }
    },

    setIntegrity: function(pct, collapsed) {
      config.integrity = pct;
      config.intCollapsed = collapsed;
      
      if (collapsed) {
         document.body.classList.add('system-tear', 'integrity-dead');
      } else {
         document.body.classList.remove('integrity-dead');
         // system-tear removed dynamically by fireTear loop unless it's running
      }
      
      if (config.reducedMotion) {
         document.body.classList.remove('system-tear');
         if (pct < 60 || collapsed) document.body.style.transform = 'translate(2px, 2px)';
         else document.body.style.transform = 'none';
      }
    },

    setMemory: function(pct, collapsed) {
      config.memory = pct;
      config.memCollapsed = collapsed;
      
      const eventText = document.getElementById('eventText');
      if (eventText) {
         // Reset original tracking so next render captures it properly
         delete eventText.dataset.original;
      }
    },

    setWillpower: function(pct, collapsed) {
      config.willpower = pct;
      config.willCollapsed = collapsed;
      
      const btns = document.querySelectorAll('.choice-btn');
      btns.forEach(b => {
          if (pct < 30 && !collapsed) {
              b.style.transform = `translate(${(Math.random()-0.5)*2}px, ${(Math.random()-0.5)*2}px)`;
          } else {
              b.style.transform = 'none';
          }
      });
    },

    scramble: function(str, intensity) {
      return scrambleString(str, intensity);
    },

    setReducedMotion: function(bool) {
      config.reducedMotion = bool;
      localStorage.setItem('titan_reduce_flash', bool);
      if (bool) {
          document.body.classList.remove('system-tear');
      }
    }
  };

  // Setup Willpower Jitter Loop
  setInterval(() => {
     if (config.willpower < 30 && !config.willCollapsed && !config.reducedMotion) {
        window.Atmosphere.setWillpower(config.willpower, config.willCollapsed);
     }
  }, 100);

})();
