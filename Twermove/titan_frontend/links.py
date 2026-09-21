"""
links.py — Project Titan local dev launcher
============================================
Run this file to:
  1. Start a local HTTP server at http://localhost:3000/
  2. Pick which page to open in your browser from a menu.

Usage:
    python links.py

Press Ctrl+C to stop the server.
"""

import http.server
import threading
import webbrowser
import os
import sys

# ── Config ────────────────────────────────────────────────────
PORT     = 3000
BASE_URL = f"http://localhost:{PORT}"

PAGES = {
    "1": ("MAIN MENU  — flash monologue + chaos background", "index.html"),
    "2": ("SETTINGS   — BPM, tolerance, key config",         "settings.html"),
    "3": ("PLAY       — game canvas",                        "play.html"),
    "4": ("DEV HUB    — all links + emotion legend",         "preview.html"),
}

# ── Start server in background thread ─────────────────────────
os.chdir(os.path.dirname(os.path.abspath(__file__)))

handler  = http.server.SimpleHTTPRequestHandler
httpd    = http.server.HTTPServer(("", PORT), handler)
thread   = threading.Thread(target=httpd.serve_forever, daemon=True)
thread.start()

print()
print("╔══════════════════════════════════════════════════════╗")
print("║           PROJECT TITAN — LOCAL DEV LAUNCHER        ║")
print("╠══════════════════════════════════════════════════════╣")
print(f"║  Server running at  {BASE_URL:<32}║")
print("╠══════════════════════════════════════════════════════╣")

for key, (label, _) in PAGES.items():
    print(f"║  [{key}]  {label:<46}║")

print("║  [0]  Exit                                           ║")
print("╚══════════════════════════════════════════════════════╝")
print()

while True:
    try:
        choice = input("  Open page (1-4) or 0 to exit: ").strip()
    except (KeyboardInterrupt, EOFError):
        break

    if choice == "0":
        break

    if choice in PAGES:
        label, file = PAGES[choice]
        url = f"{BASE_URL}/{file}"
        print(f"  → Opening {url}")
        webbrowser.open(url)
        print()
    else:
        print("  ! Invalid choice. Enter 1-4 or 0.\n")

print()
print("  Server stopped. Goodbye.")
httpd.shutdown()
sys.exit(0)
