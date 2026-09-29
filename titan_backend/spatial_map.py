"""
spatial_map.py — Pure domain logic for the Spatial Cross-Section game world.

Separation of concerns
──────────────────────
This module has **no Flask dependency**. It contains only:
  - Data classes describing the map structure.
  - The deterministic `generate_spatial_map()` function.

This makes it independently unit-testable and reusable outside the web
context (e.g. by ``spatial_core.py`` for terminal play).

3-D matrix convention: ``world[z][y][x]``
  - Z is depth (layers).
  - Y is height (rows, 0 = ceiling/top).
  - X is columns (left = 0).
"""

from __future__ import annotations

import random
from dataclasses import dataclass, field
from typing import Optional

# ─── Cell symbols ─────────────────────────────────────────────────────────────

WALL  = '#'
EMPTY = '.'
EXIT  = 'X'

# ─── World dimensions ─────────────────────────────────────────────────────────

WORLD_DX: int = 12   # columns  (x-axis)
WORLD_DY: int = 10   # rows     (y-axis, 0 = top / ceiling)
WORLD_DZ: int = 12   # layers   (z-axis / depth)

# ─── Data classes ─────────────────────────────────────────────────────────────

# We use dataclasses instead of plain dicts so the structure is self-documenting
# and type-checkable. ``to_dict()`` is provided for JSON serialisation.

@dataclass
class MapDimensions:
    """Axis sizes of the 3-D world matrix."""
    x: int
    y: int
    z: int

    def to_dict(self) -> dict:
        return {"x": self.x, "y": self.y, "z": self.z}


@dataclass
class SpatialMapData:
    """Complete description of a generated spatial level.

    Attributes:
        world:        3-D matrix ``world[z][y][x]`` of cell symbols.
        player_start: Absolute (x, y, z) spawn position for the player.
        enemies:      List of absolute (x, y, z) spawn positions for enemies.
        exit:         Absolute (x, y, z) position of the exit portal.
        dimensions:   World axis sizes.
    """
    world:        list[list[list[str]]]
    player_start: tuple[int, int, int]
    enemies:      list[tuple[int, int, int]]
    exit:         tuple[int, int, int]
    dimensions:   MapDimensions

    def to_dict(self) -> dict:
        """Serialise to a plain dict for ``flask.jsonify``."""
        return {
            "world":        self.world,
            "player_start": list(self.player_start),
            "enemies":      [list(e) for e in self.enemies],
            "exit":         list(self.exit),
            "dimensions":   self.dimensions.to_dict(),
        }


# ─── Generator ────────────────────────────────────────────────────────────────

def generate_spatial_map(seed: Optional[int] = None) -> SpatialMapData:
    """Generate a deterministic 3-D spatial map for the cross-section game.

    The level is hand-crafted to teach the core mechanic on first play:

    *   **Layer z=0** has a wide horizontal wall spanning x=1..7 at y=3.
        In View A (XY plane, z locked) the player spawning at (5, 5, 0) is
        completely blocked from moving upward by this wall.

    *   **Layer z=1** has only a single pillar at x=5, y=3.
        In View B (ZY plane, x=5 locked) the equivalent row shows this single
        pillar, so the player can navigate freely around it after swapping planes.

    This wall-to-pillar transition is the "aha moment" that demonstrates why
    rotating the view plane is the primary escape mechanic.

    Layers z=5..10 are procedurally generated using ``rng`` so repeated runs
    (with different seeds) produce varied back-half layouts.

    Args:
        seed: Optional integer seed for reproducible generation.
              ``None`` produces a random map each call.

    Returns:
        A fully populated ``SpatialMapData`` instance.
    """
    rng = random.Random(seed)
    DX, DY, DZ = WORLD_DX, WORLD_DY, WORLD_DZ

    world = _init_empty_world(DX, DY, DZ)
    _add_solid_borders(world, DX, DY, DZ)
    _add_hand_crafted_layers(world)
    _add_procedural_layers(world, rng, DX, DY, DZ)

    # Exit tile — must be set after procedural generation to avoid being overwritten.
    exit_pos: tuple[int, int, int] = (10, 1, 11)
    world[exit_pos[2]][exit_pos[1]][exit_pos[0]] = EXIT

    return SpatialMapData(
        world=world,
        player_start=(5, 5, 0),
        enemies=[
            (1, 5, 0),    # Same z-layer as player → visible in View A immediately.
            (8, 2, 5),    # Different z → hidden in View A; visible after plane swap.
            (5, 5, 10),   # Deep in z → only revealed in View B (ZY plane).
        ],
        exit=exit_pos,
        dimensions=MapDimensions(x=DX, y=DY, z=DZ),
    )


# ─── Private builders ─────────────────────────────────────────────────────────

def _init_empty_world(dx: int, dy: int, dz: int) -> list[list[list[str]]]:
    """Return a fresh world[z][y][x] filled entirely with EMPTY cells."""
    return [[[EMPTY] * dx for _ in range(dy)] for _ in range(dz)]


def _add_solid_borders(
    world: list[list[list[str]]],
    dx: int,
    dy: int,
    dz: int,
) -> None:
    """Fill the outermost row/column/layer of every z-slice with WALL.

    The border acts as an impassable arena boundary so the player and
    enemies can never move out of bounds.
    """
    for z in range(dz):
        # Ceiling (y=0) and floor (y=dy-1)
        for x in range(dx):
            world[z][0][x]      = WALL
            world[z][dy - 1][x] = WALL
        # Left (x=0) and right (x=dx-1) walls
        for y in range(dy):
            world[z][y][0]      = WALL
            world[z][y][dx - 1] = WALL


def _add_hand_crafted_layers(world: list[list[list[str]]]) -> None:
    """Populate the deterministic, puzzle-designed z=0..4 layers.

    Each layer is commented to explain its pedagogical or tactical role.
    """
    # ── z=0: Trap layer ────────────────────────────────────────────────────
    # Wide wall at y=3 spanning x=1..7. In View A this completely blocks the
    # player (spawn: x=5, y=5). In View B (x=5 locked) only one cell of this
    # wall exists at (z=0, y=3), revealing the escape route after plane swap.
    for x in range(1, 8):
        world[0][3][x] = WALL
    world[0][5][2] = WALL   # pillar — narrows the escape corridor below
    world[0][6][7] = WALL   # pillar — symmetric asymmetry for visual interest

    # ── z=1: Sparse layer ──────────────────────────────────────────────────
    # The wide wall is now just three isolated pillars, demonstrating that the
    # 3-D structure changes with depth.
    world[1][3][5] = WALL
    world[1][4][3] = WALL
    world[1][5][8] = WALL

    # ── z=2 ───────────────────────────────────────────────────────────────
    world[2][3][2] = WALL
    world[2][3][3] = WALL
    world[2][4][6] = WALL
    world[2][5][9] = WALL

    # ── z=3: Horizontal shelf ──────────────────────────────────────────────
    # A corridor-blocking shelf forces the player to switch planes or go around.
    for x in range(2, 9):
        world[3][4][x] = WALL
    world[3][3][6] = WALL

    # ── z=4 ───────────────────────────────────────────────────────────────
    world[4][5][5] = WALL
    world[4][3][3] = WALL
    world[4][6][8] = WALL


def _add_procedural_layers(
    world: list[list[list[str]]],
    rng: random.Random,
    dx: int,
    dy: int,
    dz: int,
) -> None:
    """Scatter random pillars in layers z=5..(dz-2).

    z=dz-1 is kept clear so the exit tile (placed later) has open surroundings.
    Pillar count per layer is randomised in [2, 5] to vary density.

    Args:
        world: Mutable world matrix modified in place.
        rng:   Seeded RNG for reproducibility.
        dx,dy,dz: World axis sizes.
    """
    for z in range(5, dz - 1):
        pillar_count = rng.randint(2, 5)
        for _ in range(pillar_count):
            # Keep pillars away from borders (1 ≤ x ≤ dx-2, same for y).
            px = rng.randint(1, dx - 2)
            py = rng.randint(1, dy - 2)
            world[z][py][px] = WALL
