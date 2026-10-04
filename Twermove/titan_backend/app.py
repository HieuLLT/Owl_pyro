"""
app.py
------
Twermove — Flask backend (clean slate).

Hiện tại chỉ phục vụ Main Menu (index.html) và static assets.
Các route API sẽ được thêm vào khi có định hướng gameplay mới.
"""

from flask import Flask

app = Flask(__name__, static_folder="../titan_frontend", static_url_path="")


# ── Pages ─────────────────────────────────────────────────────────────────────

@app.route("/")
@app.route("/index.html")
def index():
    return app.send_static_file("index.html")


@app.route("/play")
@app.route("/play.html")
def play():
    return app.send_static_file("play.html")


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("Twermove backend — http://localhost:8000")
    app.run(host="0.0.0.0", port=8000, debug=True)
