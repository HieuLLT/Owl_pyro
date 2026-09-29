import time
import uuid
import threading
import random
from typing import Optional

from flask import Flask, request, jsonify

from game_state import GameState
from spatial_map import generate_spatial_map

app = Flask(__name__, static_folder="../titan_frontend", static_url_path="")


runs = {}
runs_lock = threading.Lock()
MAX_RUNS = 1000
RUN_TTL = 3600 # 1 hour

def cleanup_runs():
    now = time.time()
    # Remove old runs
    to_delete = [run_id for run_id, gs in runs.items() if now - gs.created_at > RUN_TTL]
    for run_id in to_delete:
        del runs[run_id]
        
    # Cap at 1000, remove oldest
    if len(runs) > MAX_RUNS:
        sorted_runs = sorted(runs.items(), key=lambda item: item[1].created_at)
        for i in range(len(runs) - MAX_RUNS):
            del runs[sorted_runs[i][0]]

@app.route("/spatial")
@app.route("/spatial.html")
def spatial():
    return app.send_static_file("spatial.html")

@app.route("/api/spatial-map", methods=["GET"])
def spatial_map() -> tuple:
    """Return the 3-D world data as JSON.

    Query params:
        seed (int, optional): RNG seed for reproducible map generation.

    Returns:
        JSON-serialised ``SpatialMapData``.
    """
    seed: Optional[int] = request.args.get("seed", type=int)
    data = generate_spatial_map(seed=seed)
    return jsonify(data.to_dict())

@app.route("/")
@app.route("/index.html")
def index():
    return app.send_static_file("index.html")
    
@app.route("/play.html")
def play():
    return app.send_static_file("play.html")
    
@app.route("/settings.html")
def settings():
    return app.send_static_file("settings.html")

@app.route("/preview.html")
def preview():
    return app.send_static_file("preview.html")

@app.route("/api/new-game", methods=["POST"])
def new_game():
    data = request.get_json(silent=True) or {}
    seed = data.get("seed")
    
    run_id = str(uuid.uuid4())
    rng = random.Random(seed) if seed is not None else random.Random()
    
    gs = GameState(run_id=run_id, rng=rng)
    gs.apply_drain()
    gs.draw_event()
    
    with runs_lock:
        cleanup_runs()
        runs[run_id] = gs
        
    return jsonify(gs.to_dict_initial())

@app.route("/api/next-cycle", methods=["POST"])
def next_cycle():
    data = request.get_json()
    if not data:
        return jsonify({"error": "Missing JSON body"}), 400
        
    run_id = data.get("run_id")
    choice_id = data.get("choice_id")
    
    if not run_id or not choice_id:
        return jsonify({"error": "Missing run_id or choice_id"}), 400
        
    with runs_lock:
        gs = runs.get(run_id)
        if not gs:
            return jsonify({"error": "Unknown run_id"}), 404
            
        if gs.game_over:
            return jsonify({"error": "Run already over"}), 409
            
        try:
            payload = gs.advance(choice_id)
            return jsonify(payload)
        except ValueError as e:
            return jsonify({"error": str(e)}), 400

@app.route("/api/state", methods=["GET"])
def get_state():
    run_id = request.args.get("run_id")
    if not run_id:
        return jsonify({"error": "Missing run_id"}), 400
        
    with runs_lock:
        gs = runs.get(run_id)
        if not gs:
            return jsonify({"error": "Unknown run_id"}), 404
            
        event_data = gs._get_event(gs.current_event_id) if not gs.game_over else None
        
        payload = {
            "run_id": gs.run_id,
            "cycle": gs.cycle,
            "stats": {k: round(v, 1) for k, v in gs.stats.items()},
            "collapsed": {k: (v <= 0) for k, v in gs.stats.items()},
            "drain_next": round(gs.drain_for(gs.cycle + 1), 1),
            "game_over": gs.game_over,
            "game_over_reason": gs.game_over_reason,
            "event": event_data
        }
        if gs.game_over:
            payload["cycles_survived"] = gs.cycle - 1
            
        return jsonify(payload)

if __name__ == "__main__":
    print("Starting Titan backend in single-process mode...")
    app.run(host="0.0.0.0", port=8000)
