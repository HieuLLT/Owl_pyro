"""
main.py — FastAPI application for the Titan backend.

Endpoints
---------
POST /generate-level
    Accepts LevelConfig, runs LevelGenerator, returns BeatmapResponse.

POST /validate-run
    Accepts PlayerRunData (including the echoed beatmap), runs RunValidator,
    returns RunResult.

The server is intentionally stateless: no database, no session cache.
All level state lives in the beatmap payload that the frontend echoes back.
"""
from __future__ import annotations

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from titan_backend.api.schemas import (
    BeatmapNode,
    BeatmapResponse,
    LevelConfig,
    NodeResult,
    PlayerRunData,
    RunResult,
)
from titan_backend.engine.generator import LevelGenerator
from titan_backend.engine.validator import RunValidator

# ─────────────────────────────────────────────────────────────────────────────
# App setup
# ─────────────────────────────────────────────────────────────────────────────

app = FastAPI(
    title="Titan Backend",
    description=(
        "Stateless Level Compiler and Run Judge for the Titan rhythm game. "
        "The backend generates JSON beatmaps and validates player run submissions."
    ),
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# Allow all localhost origins so any frontend dev server can reach the API.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://localhost:3000",
        "http://localhost:5173",
        "http://localhost:8080",
        "http://127.0.0.1",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:5173",
        "http://127.0.0.1:8080",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─────────────────────────────────────────────────────────────────────────────
# Health check
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/health", tags=["Meta"], summary="Health check")
def health() -> dict[str, str]:
    """Returns 200 OK when the server is running."""
    return {"status": "ok"}


# ─────────────────────────────────────────────────────────────────────────────
# POST /generate-level
# ─────────────────────────────────────────────────────────────────────────────

@app.post(
    "/generate-level",
    response_model=BeatmapResponse,
    tags=["Level"],
    summary="Compile a new beatmap",
    description=(
        "Accepts difficulty parameters and returns a fully compiled JSON beatmap. "
        "The frontend should store the returned `level_id` and `nodes` array and "
        "echo them back verbatim when submitting a run."
    ),
)
def generate_level(config: LevelConfig) -> BeatmapResponse:
    """
    Run the two-phase level generator and return the beatmap.
    """
    try:
        generator = LevelGenerator(
            node_count=config.node_count,
            base_tempo_ms=config.base_tempo_ms,
            difficulty=config.difficulty,
            seed=config.seed,
        )
        level_id, raw_beatmap = generator.generate()
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    nodes = [
        BeatmapNode(
            node_id=entry["node_id"],
            height_index=entry["height_index"],
            angle_offset=entry["angle_offset"],
            value=entry["value"],
            modifier=entry["modifier"],
            is_alt_branch=entry["is_alt_branch"],
            left_child_id=entry.get("left_child_id"),
            right_child_id=entry.get("right_child_id"),
        )
        for entry in raw_beatmap
    ]

    return BeatmapResponse(
        level_id=level_id,
        nodes=nodes,
        base_tempo_ms=config.base_tempo_ms,
        difficulty=config.difficulty,
    )


# ─────────────────────────────────────────────────────────────────────────────
# POST /validate-run
# ─────────────────────────────────────────────────────────────────────────────

@app.post(
    "/validate-run",
    response_model=RunResult,
    tags=["Run"],
    summary="Judge a player's run",
    description=(
        "Accepts the player's timestamped input array alongside the echoed beatmap. "
        "Returns a per-node verdict breakdown, aggregate score, and a success flag."
    ),
)
def validate_run(run_data: PlayerRunData) -> RunResult:
    """
    Feed the echoed beatmap and player actions to RunValidator and return the result.
    """
    if len(run_data.actions) == 0:
        raise HTTPException(status_code=422, detail="actions array must not be empty.")

    # Convert Pydantic models to plain dicts for the pure validator
    beatmap_dicts = [node.model_dump() for node in run_data.beatmap]
    action_dicts = [action.model_dump() for action in run_data.actions]

    validator = RunValidator(
        beatmap=beatmap_dicts,
        player_actions=action_dicts,
        tolerance_ms=run_data.tolerance_ms,
    )
    result = validator.validate()

    node_results = [
        NodeResult(
            node_id=nr["node_id"],
            verdict=nr["verdict"],
            delta_ms=nr["delta_ms"],
            expected_input=nr["expected_input"],
            actual_input=nr["actual_input"],
        )
        for nr in result["node_results"]
    ]

    return RunResult(
        level_id=run_data.level_id,
        success=result["success"],
        score=result["score"],
        accuracy=result["accuracy"],
        hits=result["hits"],
        misses=result["misses"],
        wrong_inputs=result["wrong_inputs"],
        node_results=node_results,
    )
