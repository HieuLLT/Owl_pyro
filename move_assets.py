import re
import os

base_dir = r"c:\Users\PREDATOR\OneDrive\Desktop\Twermove\titan_frontend"
index_path = os.path.join(base_dir, "index.html")
style_path = os.path.join(base_dir, "static", "style.css")
atmos_path = os.path.join(base_dir, "static", "atmosphere.js")

with open(index_path, "r", encoding="utf-8") as f:
    html = f.read()

# Extract inline CSS
style_match = re.search(r'<style>(.*?)</style>', html, re.DOTALL)
if style_match:
    css_content = style_match.group(1).strip()
    with open(style_path, "a", encoding="utf-8") as f:
        f.write("\n/* --- Moved from index.html --- */\n")
        f.write(css_content)
        f.write("\n")
    # Remove from index.html
    html = html.replace(style_match.group(0), "")

# Extract inline JS
script_match = re.search(r'<script>\s*/\* =+(.*?)</script>', html, re.DOTALL)
if script_match:
    js_content = "/* =" + script_match.group(1).strip()
    
    # Write to atmosphere.js
    with open(atmos_path, "w", encoding="utf-8") as f:
        f.write(js_content)
        f.write("\n")
        
    # Replace in index.html with new script tag and new quick launch script
    new_script = """<script src="static/atmosphere.js"></script>
  <script>
    (function initQuickLaunch() {
      const btn  = document.getElementById('btnStart');
      const veil = document.getElementById('transition-veil');
      if (!btn || !veil) return;

      btn.addEventListener('click', async function (e) {
        e.preventDefault();
        btn.textContent = 'CONNECTING…';
        btn.classList.add('processing');

        const ctrl = new AbortController();
        const timeout = setTimeout(() => ctrl.abort(), 6000);

        try {
          const res = await fetch('/api/new-game', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({seed: null}),
            signal: ctrl.signal,
          });
          clearTimeout(timeout);

          if (!res.ok) throw new Error(`HTTP ${res.status}`);

          const data = await res.json();
          sessionStorage.setItem('titan_run_id', data.run_id);

          btn.textContent = 'SEQUENCE_COMPILED';
          veil.classList.add('active');
          setTimeout(() => { window.location.href = 'play.html'; }, 950);

        } catch (err) {
          clearTimeout(timeout);
          btn.classList.remove('processing');
          btn.classList.add('error-state');
          btn.textContent = 'BACKEND_OFFLINE';
          setTimeout(() => { window.location.href = 'settings.html'; }, 2000);
        }
      });
    })();
  </script>"""
    html = html.replace(script_match.group(0), new_script)

with open(index_path, "w", encoding="utf-8") as f:
    f.write(html)

print("Done extracting assets.")
