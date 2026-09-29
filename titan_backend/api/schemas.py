"""
schemas.py — Pydantic v2 request/response models for the Titan API.

All models use strict typing so that FastAPI can perform automatic
request validation and generate accurate OpenAPI documentation.
"""
from __future__ import annotations

from typing import Literal, Optional

from pydantic import BaseModel, Field


# ─────────────────────────────────────────────
# /generate-level
# ─────────────────────────────────────────────

class LevelConfig(BaseModel):
    """
    Parameters sent by the frontend to request a new compiled beatmap.
    """

    node_count: int = Field(
        default=20,
        ge=5,
        le=200,
        description="Total number of nodes in the main chain (excluding alt-branches).",
    )
    base_tempo_ms: int = Field(
        default=500,
        ge=100,
        le=3000,
        description="Gap in milliseconds between nodes at ×1.0 tempo.",
    )
    difficulty: Literal["easy", "medium", "hard"] = Field(
        default="medium",
        description=(
            "Preset that controls how frequently CHASER, BLOCKADE, and "
            "DIVERTER modifiers are injected into the chain."
        ),
    )
    seed: Optional[int] = Field(
        default=None,
        description=(
            "Optional RNG seed for deterministic level generation. "
            "Useful for leaderboards and replay validation."
        ),
    )

    model_config = {"json_schema_extra": {"examples": [
        {"node_count": 15, "base_tempo_ms": 500, "difficulty": "medium"}
    ]}}


class BeatmapNode(BaseModel):
    """A single compiled node as returned in the beatmap, mapped to a 3D cylinder."""

    node_id: int = Field(description="Unique sequential identifier for this node.")
    height_index: int = Field(
        description="Vertical height step of this node on the cylinder."
    )
    angle_offset: float = Field(
        description="Angular position (0 to 359 degrees) around the cylinder."
    )
    value: int = Field(
        description="Numeric value of this node for BST logic decisions."
    )
    modifier: str = Field(
        description="ModType name applied to this node (NONE, CHASER, BLOCKADE, DIVERTER)."
    )
    is_alt_branch: bool = Field(
        default=False,
        description="True when this node belongs to an incorrect or secondary branch.",
    )
    left_child_id: Optional[int] = Field(
        default=None, description="Node ID of the left child (if branching)."
    )
    right_child_id: Optional[int] = Field(
        default=None, description="Node ID of the right child (if branching)."
    )


class BeatmapResponse(BaseModel):
    """Response payload from /generate-level."""

    level_id: str = Field(description="UUID identifying this generated level.")
    nodes: list[BeatmapNode] = Field(
        description="Ordered list of all compiled beatmap nodes (main chain + alt branches)."
    )
    base_tempo_ms: int = Field(description="Base tempo echoed back for frontend reference.")
    difficulty: str = Field(description="Difficulty echoed back.")


# ─────────────────────────────────────────────
# /validate-run
# ─────────────────────────────────────────────

class PlayerAction(BaseModel):
    """One action event recorded by the frontend."""

    node_id: int = Field(description="The node_id this action corresponds to.")
    balance_factor: int = Field(
        description="The AVL balance factor of the tower when this node was reached."
    )
    chosen_child_id: Optional[int] = Field(
        default=None, description="The ID of the child node selected if this was a branch."
    )


class PlayerRunData(BaseModel):
    """
    Full run submission from the frontend.

    The frontend echoes back the beatmap so the backend stays truly
    stateless — no session cache is required.
    """

    level_id: str = Field(description="level_id returned by /generate-level.")
    beatmap: list[BeatmapNode] = Field(
        description="The exact beatmap returned by /generate-level, echoed back verbatim."
    )
    actions: list[PlayerAction] = Field(
        description="One action per beatmap node, in node_id order."
    )
    tolerance_ms: int = Field(
        default=50,
        ge=10,
        le=500,
        description="Maximum allowed delta (ms) between expected and actual time for a HIT.",
    )

    model_config = {"json_schema_extra": {"examples": [
        {
            "level_id": "abc-123",
            "beatmap": [{"node_id": 0, "height_index": 0, "angle_offset": 0, "value": 50, "modifier": "NONE", "is_alt_branch": False, "left_child_id": None, "right_child_id": None}],
            "actions": [{"node_id": 0, "actual_time_ms": 503, "actual_input": "SPACE"}],
            "tolerance_ms": 50,
        }
    ]}}


class NodeResult(BaseModel):
    """Per-node verdict from the validator."""

    node_id: int
    verdict: Literal["HIT", "MISS", "COLLAPSE"] = Field(
        description=(
            "HIT — valid path and balanced. "
            "MISS — wrong BST path chosen. "
            "COLLAPSE — AVL balance factor exceeded limit."
        )
    )


class RunResult(BaseModel):
    """Response payload from /validate-run."""

    level_id: str
    success: bool = Field(description="True only when every node is a HIT.")
    score: int = Field(description="hits×100 − misses×50, floored at 0.")
    accuracy: float = Field(description="Fraction of HIT nodes over total nodes (0.0–1.0).")
    hits: int
    misses: int
    wrong_inputs: int
    node_results: list[NodeResult]
