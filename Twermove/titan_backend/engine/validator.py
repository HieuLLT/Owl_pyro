"""
validator.py — RunValidator: judges a player's spatial/BST run against the graph.
"""
from __future__ import annotations

from typing import Any


class RunValidator:
    """
    Stateless run judge for the cylindrical DSA graph.
    """

    def __init__(
        self,
        beatmap: list[dict[str, Any]],
        player_actions: list[dict[str, Any]],
        tolerance_ms: int = 50, # Ignored, kept for API compat
    ) -> None:
        self._beatmap = beatmap
        self._actions = player_actions

    def validate(self) -> dict[str, Any]:
        action_by_id: dict[int, dict[str, Any]] = {
            a["node_id"]: a for a in self._actions
        }

        node_results: list[dict[str, Any]] = []
        hits = misses = wrong_inputs = 0

        for bnode in self._beatmap:
            node_id: int = bnode["node_id"]
            action = action_by_id.get(node_id)

            if action is None:
                # If they didn't even reach the node, it's a miss
                verdict = "MISS"
                misses += 1
            else:
                balance_factor = action.get("balance_factor", 0)
                
                if abs(balance_factor) >= 4:
                    verdict = "COLLAPSE"
                    misses += 1
                elif bnode.get("is_alt_branch", False):
                    # They traversed onto an invalid branch
                    verdict = "MISS"
                    misses += 1
                else:
                    verdict = "HIT"
                    hits += 1

            node_results.append({
                "node_id": node_id,
                "verdict": verdict,
            })

        total = len(self._beatmap)
        score = max(0, hits * 100 - misses * 50)
        accuracy = round(hits / total, 4) if total > 0 else 0.0
        success = hits == total

        return {
            "success": success,
            "score": score,
            "accuracy": accuracy,
            "hits": hits,
            "misses": misses,
            "wrong_inputs": 0,
            "node_results": node_results,
        }
