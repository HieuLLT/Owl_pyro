"""
enums.py — ModType definitions for Titan node modifiers.

Each modifier affects how the level generator calculates the tempo
(inter-node gap in milliseconds) for the next hop in the beatmap.
"""
from enum import Enum


class ModType(str, Enum):
    """
    Modifier applied to a ListNode that alters gameplay behaviour.

    The `str` mixin allows ModType values to serialise directly to/from
    JSON strings (e.g. "CHASER") without an extra conversion step in
    Pydantic schemas.
    """

    NONE = "NONE"
    """Standard beat. Tempo is unchanged (×1.0)."""

    CHASER = "CHASER"
    """Speed-up modifier. Multiplies the running tempo by 0.5 so the
    next node arrives in half the usual time, forcing faster inputs."""

    BLOCKADE = "BLOCKADE"
    """Slow-down modifier. Multiplies the running tempo by 2.0 so the
    next node takes twice as long, forcing a deliberate hold/delay."""

    DIVERTER = "DIVERTER"
    """Branch modifier. Blocks the standard next_node path; the player
    must press the correct directional key to route through alt_node.
    Tempo is unchanged (×1.0) for the branch hop itself."""

    # ------------------------------------------------------------------ #
    # Convenience helpers                                                  #
    # ------------------------------------------------------------------ #

    @property
    def tempo_multiplier(self) -> float:
        """Return the tempo multiplier associated with this modifier."""
        return _TEMPO_MULTIPLIERS[self]


_TEMPO_MULTIPLIERS: dict["ModType", float] = {
    ModType.NONE: 1.0,
    ModType.CHASER: 0.5,
    ModType.BLOCKADE: 2.0,
    ModType.DIVERTER: 1.0,
}
