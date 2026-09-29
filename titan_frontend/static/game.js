export const TerminalGame = (function() {
  let currentRunId = null;
  let isProcessing = false;
  let lastPayload = null;
  let abortController = null;

  async function init() {
    const savedRun = sessionStorage.getItem('titan_run_id');
    try {
      if (savedRun) {
        const res = await fetch(`/api/state?run_id=${savedRun}`);
        if (res.ok) {
          const data = await res.json();
          currentRunId = data.run_id;
          render(data);
          return;
        }
      }
      
      // New game
      const res = await fetch('/api/new-game', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({seed: null})
      });
      if (!res.ok) throw new Error("Failed to init game");
      const data = await res.json();
      currentRunId = data.run_id;
      sessionStorage.setItem('titan_run_id', currentRunId);
      render(data);
    } catch (e) {
      showError("BACKEND_OFFLINE // RETRYING...");
      setTimeout(init, 3000);
    }
  }

  function render(payload) {
    lastPayload = payload;
    
    // Update labels
    document.getElementById('cycleLabel').textContent = `CYCLE ${String(payload.cycle).padStart(2, '0')}`;
    document.getElementById('drainLabel').textContent = `NEXT DRAIN -${payload.drain_next.toFixed(1)}`;

    // Update bars
    updateBar('memory', payload.stats.memory, payload.collapsed.memory);
    updateBar('integrity', payload.stats.integrity, payload.collapsed.integrity);
    updateBar('willpower', payload.stats.willpower, payload.collapsed.willpower);

    if (payload.game_over) {
      showGameOver(payload);
    } else if (payload.event) {
      renderEvent(payload.event);
    }
    
    applyVisuals(payload.stats, payload.collapsed);
  }

  function updateBar(statName, value, isCollapsed) {
    const barWrap = document.getElementById(`bar-${statName}`);
    if (!barWrap) return;
    
    const fill = barWrap.querySelector('.stat-fill');
    const readout = barWrap.querySelector('.stat-readout');
    
    // Steps easing for hard-edged feel, animated width
    fill.style.transition = 'width 250ms steps(10, end), background-color 250ms steps(3, end)';
    fill.style.width = `${value}%`;
    readout.textContent = value.toFixed(1);
    
    // Colour logic: >60 white/red, 30-60 amber, <30 red flicker (handled via CSS classes)
    barWrap.classList.remove('level-high', 'level-mid', 'level-low', 'level-collapsed');
    if (isCollapsed) {
      barWrap.classList.add('level-collapsed');
    } else if (value < 30) {
      barWrap.classList.add('level-low');
    } else if (value <= 60) {
      barWrap.classList.add('level-mid');
    } else {
      barWrap.classList.add('level-high');
    }
  }

  function formatDelta(val, stat) {
    const sign = val >= 0 ? '+' : '';
    const code = stat === 'memory' ? 'MEM' : stat === 'integrity' ? 'INT' : 'WILL';
    return `<span class="delta-chip ${val < 0 ? 'negative' : 'positive'}">${sign}${val} ${code}</span>`;
  }

  function renderEvent(event) {
    const eventText = document.getElementById('eventText');
    const choiceRow = document.getElementById('choiceRow');
    
    // Reset emotion classes
    eventText.className = 'event-text';
    if (event.emotion) {
      eventText.classList.add(`emotion-${event.emotion}`);
    }
    
    eventText.textContent = event.text;
    
    choiceRow.innerHTML = '';
    event.choices.forEach(choice => {
      const btn = document.createElement('button');
      btn.className = 'btn choice-btn';
      btn.id = `choice-${choice.id}`;
      
      const deltas = Object.entries(choice.delta)
        .filter(([_, v]) => v !== 0)
        .map(([k, v]) => formatDelta(v, k))
        .join('  ');
        
      let displayLabel = choice.label;
      if (lastPayload.stats.willpower < 30 && !lastPayload.collapsed.willpower) {
          displayLabel = `WILL_FAILING // ${choice.label}`;
      }
        
      btn.innerHTML = `<span class="choice-label">${displayLabel}</span> <div class="delta-group">${deltas}</div>`;
      btn.onclick = () => choose(choice.id);
      choiceRow.appendChild(btn);
    });
  }

  async function choose(choiceId) {
    if (isProcessing || !currentRunId) return;
    isProcessing = true;
    
    // Disable buttons
    document.querySelectorAll('.choice-btn').forEach(b => {
      b.disabled = true;
      b.classList.add('processing-btn');
    });
    document.getElementById('errorBanner').style.display = 'none';

    abortController = new AbortController();
    const timeout = setTimeout(() => abortController.abort(), 8000);

    try {
      const res = await fetch('/api/next-cycle', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ run_id: currentRunId, choice_id: choiceId }),
        signal: abortController.signal
      });
      clearTimeout(timeout);
      
      if (!res.ok) throw new Error("HTTP " + res.status);
      
      const data = await res.json();
      
      if (data.applied && data.applied.overridden) {
        // Willpower override flow
        const banner = document.getElementById('overrideBanner');
        banner.style.display = 'block';
        
        // Highlight forced option
        document.querySelectorAll('.choice-btn').forEach(b => {
           b.style.opacity = '0.2';
        });
        const forcedBtn = document.getElementById(`choice-${data.applied.chosen_id}`);
        if (forcedBtn) {
            forcedBtn.style.opacity = '1';
            forcedBtn.classList.add('forced-choice');
        }
        
        setTimeout(() => {
          banner.style.display = 'none';
          isProcessing = false;
          render(data);
        }, 1200);
      } else {
        isProcessing = false;
        render(data);
      }
      
    } catch (e) {
      clearTimeout(timeout);
      const isTimeout = e.name === 'AbortError';
      showError(isTimeout ? "TIMEOUT // RETRYING" : "CONNECTION LOST // RETRYING");
      
      setTimeout(() => {
        isProcessing = false;
        render(lastPayload); // Reset buttons
      }, 2000);
    }
  }

  function showError(msg) {
    const banner = document.getElementById('errorBanner');
    banner.textContent = msg;
    banner.style.display = 'block';
  }

  function showGameOver(payload) {
    document.getElementById('resultsOverlay').style.display = 'flex';
    document.getElementById('resultStatus').textContent = "SYSTEM COLLAPSE";
    document.getElementById('resultScore').textContent = payload.cycles_survived;
    document.getElementById('resultCause').textContent = payload.game_over_reason;
    
    document.getElementById('finalMem').textContent = payload.stats.memory.toFixed(1);
    document.getElementById('finalInt').textContent = payload.stats.integrity.toFixed(1);
    document.getElementById('finalWill').textContent = payload.stats.willpower.toFixed(1);
    
    let best = parseInt(localStorage.getItem('titan_best_cycle') || '0', 10);
    if (payload.cycles_survived > best) {
      best = payload.cycles_survived;
      localStorage.setItem('titan_best_cycle', best);
    }
    document.getElementById('resultBest').textContent = `BEST: ${best}`;
  }

  function applyVisuals(stats, collapsed) {
    // Hooks for Atmosphere (implemented in step 5)
    if (window.Atmosphere) {
      if (window.Atmosphere.setIntegrity) window.Atmosphere.setIntegrity(stats.integrity, collapsed.integrity);
      if (window.Atmosphere.setMemory) window.Atmosphere.setMemory(stats.memory, collapsed.memory);
      if (window.Atmosphere.setWillpower) window.Atmosphere.setWillpower(stats.willpower, collapsed.willpower);
    }
  }

  // Keyboard binding
  window.addEventListener('keydown', (e) => {
    if (isProcessing) return;
    if (!lastPayload || lastPayload.game_over) return;
    
    if (e.key === '1' || e.key.toLowerCase() === 'a') {
      const btnA = document.querySelector('.choice-btn:nth-child(1)');
      if (btnA) btnA.click();
    } else if (e.key === '2' || e.key.toLowerCase() === 'b') {
      const btnB = document.querySelector('.choice-btn:nth-child(2)');
      if (btnB) btnB.click();
    }
  });

  return { init, choose };
})();
