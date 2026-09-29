# -*- coding: utf-8 -*-
import sys, io
# Force UTF-8 output so Unicode box chars render on Windows terminals
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
"""
╔══════════════════════════════════════════════════════════════════════════╗
║         SPATIAL CROSS-SECTION ENGINE — Python Logic Core                ║
║                                                                          ║
║  World: 3D matrix  map[z][y][x]                                         ║
║  View A (XY Plane): Lock Z → move in X,Y                               ║
║  View B (ZY Plane): Lock X → move in Z,Y                               ║
║  P/Space key switches between the two planes instantly.                 ║
║                                                                          ║
║  Entity AI: 3D BFS to find shortest path to player.                    ║
╚══════════════════════════════════════════════════════════════════════════╝

Usage:
  python spatial_core.py           # interactive game
  python spatial_core.py --demo    # BFS + view demo, no input needed
"""

import os
import sys
from collections import deque

# ─── Terminal colour helpers (ANSI) ───────────────────────────────────────────
RESET   = "\033[0m"
BOLD    = "\033[1m"
DIM     = "\033[2m"
RED     = "\033[91m"
GREEN   = "\033[92m"
YELLOW  = "\033[93m"
CYAN    = "\033[96m"
BLUE    = "\033[94m"
MAGENTA = "\033[95m"
WHITE   = "\033[97m"

def clr(text: str, colour: str) -> str:
    return f"{colour}{text}{RESET}"

def clear_screen():
    os.system("cls" if os.name == "nt" else "clear")

# ─── Constants ────────────────────────────────────────────────────────────────
WALL   = "#"
EMPTY  = "."
PLAYER = "@"
ENEMY  = "E"
EXIT   = "X"

WORLD_X = 9   # columns  (x-axis)
WORLD_Y = 7   # rows     (y-axis, 0=top)
WORLD_Z = 9   # layers   (z-axis / depth)

PLANE_XY = "XY"   # View A: camera locked to player.z
PLANE_ZY = "ZY"   # View B: camera locked to player.x


# ─── Level builder ────────────────────────────────────────────────────────────
def build_world() -> list:
    """
    Return world[z][y][x] filled with EMPTY and WALL.

    The layout is designed so that a horizontal wall in View A (XY)
    appears as only a single pillar in View B (ZY), letting the player
    understand the axis-rotation escape mechanic immediately.
    """
    W, H, D = WORLD_X, WORLD_Y, WORLD_Z

    world = [[[EMPTY for _ in range(W)] for _ in range(H)] for _ in range(D)]

    for z in range(D):
        # Floor (y=H-1), ceiling (y=0), left (x=0), right (x=W-1)
        for x in range(W):
            world[z][0][x]   = WALL
            world[z][H-1][x] = WALL
        for y in range(H):
            world[z][y][0]   = WALL
            world[z][y][W-1] = WALL

    # ── Layer z=0: wide horizontal wall at y=2, x=1..5 ──
    # In XY view the player @(4,3,0) is trapped below it.
    # In ZY view (x locked at 4) only world[0][2][4] is a wall → escapable.
    for x in range(1, 6):
        world[0][2][x] = WALL

    # ── Layer z=1: sparse obstacles ──
    world[1][2][4] = WALL
    world[1][3][2] = WALL
    world[1][3][6] = WALL

    # ── Layer z=2 ──
    world[2][2][2] = WALL
    world[2][2][3] = WALL
    world[2][3][5] = WALL

    # ── Layer z=3: horizontal shelf at y=3, x=2..6 ──
    for x in range(2, 7):
        world[3][3][x] = WALL

    # ── Layers z=4..8: open corridors with light pillars ──
    for z in range(4, D):
        world[z][3][3] = WALL
        world[z][3][5] = WALL

    return world


# ─── SpatialMap ───────────────────────────────────────────────────────────────
class SpatialMap:
    """Wrapper around world[z][y][x] with bounds-checked helpers."""

    def __init__(self, world: list):
        self.world  = world
        self.depth  = len(world)          # Z size
        self.height = len(world[0])       # Y size
        self.width  = len(world[0][0])    # X size

    def in_bounds(self, x, y, z) -> bool:
        return 0 <= x < self.width and 0 <= y < self.height and 0 <= z < self.depth

    def is_passable(self, x, y, z) -> bool:
        return self.in_bounds(x, y, z) and self.world[z][y][x] != WALL

    def get_xy_slice(self, z: int) -> list:
        """Copy of world[z] (rows × cols)."""
        return [row[:] for row in self.world[z]]

    def get_zy_slice(self, x: int) -> list:
        """
        Build a 2-D grid [y][z] for a fixed x value.
        Columns represent Z depth; rows represent Y height.
        """
        return [
            [self.world[z][y][x] for z in range(self.depth)]
            for y in range(self.height)
        ]


# ─── Player ───────────────────────────────────────────────────────────────────
class Player:
    def __init__(self, x: int, y: int, z: int):
        self.x     = x
        self.y     = y
        self.z     = z
        self.plane = PLANE_XY

    @property
    def pos(self):
        return (self.x, self.y, self.z)

    def _try_move(self, dx, dy, dz, smap: SpatialMap) -> bool:
        nx, ny, nz = self.x + dx, self.y + dy, self.z + dz
        if smap.is_passable(nx, ny, nz):
            self.x, self.y, self.z = nx, ny, nz
            return True
        return False

    def move_up(self, smap):    return self._try_move( 0, -1,  0, smap)
    def move_down(self, smap):  return self._try_move( 0,  1,  0, smap)

    def move_left(self, smap):
        # XY plane → change X;  ZY plane → go to smaller Z (depth)
        return self._try_move(-1, 0, 0, smap) if self.plane == PLANE_XY else \
               self._try_move( 0, 0,-1, smap)

    def move_right(self, smap):
        return self._try_move( 1, 0, 0, smap) if self.plane == PLANE_XY else \
               self._try_move( 0, 0, 1, smap)

    def toggle_plane(self):
        self.plane = PLANE_ZY if self.plane == PLANE_XY else PLANE_XY

    def __repr__(self):
        return f"Player(pos={self.pos}, plane={self.plane})"


# ─── Entity (enemy with 3-D BFS AI) ──────────────────────────────────────────
class Entity:
    """
    Enemy that lives in the full 3-D world.
    Uses 6-directional 3-D BFS to find the shortest path to the player.
    """

    # Six cardinal neighbours in 3-D space
    _DIRS = [(1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1),(0,0,-1)]

    def __init__(self, x: int, y: int, z: int, name: str = "E"):
        self.x    = x
        self.y    = y
        self.z    = z
        self.name = name
        self._cached_path:  list  = []
        self._path_target: tuple  = None

    @property
    def pos(self):
        return (self.x, self.y, self.z)

    def bfs_path(self, target: tuple, smap: SpatialMap) -> list:
        """
        3-D BFS: returns list of (x,y,z) from next-step to target,
        or [] if unreachable.
        """
        start = self.pos
        if start == target:
            return []

        visited = {start}
        queue   = deque([(start, [])])

        while queue:
            (cx, cy, cz), path = queue.popleft()
            for dx, dy, dz in self._DIRS:
                npos = (cx+dx, cy+dy, cz+dz)
                if npos in visited:
                    continue
                nx, ny, nz = npos
                if not smap.in_bounds(nx, ny, nz):
                    continue
                if smap.world[nz][ny][nx] == WALL:
                    continue
                new_path = path + [npos]
                if npos == target:
                    return new_path
                visited.add(npos)
                queue.append((npos, new_path))

        return []   # no path

    def step_toward_player(self, player: Player, smap: SpatialMap):
        """Take one BFS step toward the player's 3-D position."""
        target = player.pos

        # Invalidate cache when target moved or path is empty
        if self._path_target != target or not self._cached_path:
            self._cached_path  = self.bfs_path(target, smap)
            self._path_target  = target

        if self._cached_path:
            nx, ny, nz = self._cached_path.pop(0)
            if smap.is_passable(nx, ny, nz):
                self.x, self.y, self.z = nx, ny, nz
            else:
                self._cached_path = []   # recalc next turn

    def manhattan(self, player: Player) -> int:
        return abs(self.x - player.x) + abs(self.y - player.y) + abs(self.z - player.z)

    def __repr__(self):
        return f"Entity({self.name} @ {self.pos})"


# ─── Renderer ─────────────────────────────────────────────────────────────────
class Renderer:
    """Converts game state → coloured ASCII grid strings."""

    @staticmethod
    def _colour_cell(ch: str) -> str:
        if ch == WALL:   return clr("█", DIM + "\033[90m")
        if ch == EMPTY:  return clr("·", "\033[90m")
        if ch == PLAYER: return clr("@", BOLD + GREEN)
        if ch == ENEMY:  return clr("E", BOLD + RED)
        if ch == EXIT:   return clr("X", BOLD + YELLOW)
        return ch

    def render_view(self, smap: SpatialMap, player: Player,
                    entities: list, exit_pos: tuple) -> str:
        """
        Build the current 2-D ASCII display.
        Enemies appear only if they share the locked-axis value with the player.
        """
        ex, ey, ez = exit_pos

        if player.plane == PLANE_XY:
            lz   = player.z
            grid = smap.get_xy_slice(lz)
            # Overlays
            grid[player.y][player.x] = PLAYER
            if ez == lz:
                grid[ey][ex] = EXIT
            for ent in entities:
                if ent.z == lz and (ent.x, ent.y) != (player.x, player.y):
                    grid[ent.y][ent.x] = ENEMY
        else:  # PLANE_ZY
            lx   = player.x
            grid = smap.get_zy_slice(lx)   # grid[y][z]
            grid[player.y][player.z] = PLAYER
            if ex == lx:
                grid[ey][ez] = EXIT
            for ent in entities:
                if ent.x == lx and (ent.z, ent.y) != (player.z, player.y):
                    grid[ent.y][ent.z] = ENEMY

        rows = []
        for row in grid:
            rows.append("  ".join(self._colour_cell(c) for c in row))
        return "\n".join(" " + r for r in rows)

    def axis_bar(self, player: Player, smap: SpatialMap) -> str:
        if player.plane == PLANE_XY:
            ticks = "  ".join(
                clr(str(x), CYAN if x == player.x else DIM)
                for x in range(smap.width)
            )
            locked = f"Z locked = {player.z}"
            axes   = "→ X axis  (↓ Y axis)"
        else:
            ticks = "  ".join(
                clr(str(z), CYAN if z == player.z else DIM)
                for z in range(smap.depth)
            )
            locked = f"X locked = {player.x}"
            axes   = "→ Z axis  (↓ Y axis)"
        return f"  {ticks}\n  {clr(axes, CYAN)}  [{clr(locked, YELLOW)}]"


# ─── HUD ──────────────────────────────────────────────────────────────────────
def draw_hud(player: Player, entities: list, turn: int, msg: str) -> str:
    W = 52

    def row(content: str) -> str:
        visible_len = len(content.encode("ascii", errors="ignore"))  # rough
        # strip ANSI for length calc
        import re
        plain = re.sub(r"\033\[[0-9;]*m", "", content)
        pad   = max(0, W - 2 - len(plain))
        return clr("║", CYAN) + " " + content + " " * pad + clr("║", CYAN)

    plane_str = (
        clr("[XY Plane] — View A", BOLD + GREEN)
        if player.plane == PLANE_XY
        else clr("[ZY Plane] — View B", BOLD + MAGENTA)
    )

    HR = clr("+" + "-" * W + "+", CYAN)
    lines = [
        HR,
        row(f"  SPATIAL ENGINE  Turn {clr(str(turn), YELLOW)}"),
        HR,
        row(f"  Player ({clr(str(player.x),GREEN)},{clr(str(player.y),GREEN)},{clr(str(player.z),GREEN)})   {plane_str}"),
        row(f"  P / Space = rotate plane   W/A/S/D = move"),
        HR,
    ]

    for ent in entities:
        d = ent.manhattan(player)
        col = RED if d <= 3 else YELLOW if d <= 6 else "\033[90m"
        visible = (
            (player.plane == PLANE_XY and ent.z == player.z) or
            (player.plane == PLANE_ZY and ent.x == player.x)
        )
        vis = clr("VISIBLE", RED + BOLD) if visible else clr("hidden ", DIM)
        lines.append(row(
            f"  {clr(ent.name, col)} @ ({ent.x},{ent.y},{ent.z})  dist={clr(str(d),col)}  [{vis}]"
        ))

    lines += [
        HR,
        row(f"  {clr(msg[:W - 4], WHITE)}"),
        HR,
    ]
    return "\n".join(lines)


# ─── Cross-platform keypress ──────────────────────────────────────────────────
def get_key() -> str:
    if os.name == "nt":
        import msvcrt
        ch = msvcrt.getwch()
        if ch in ("\x00", "\xe0"):
            ch2 = msvcrt.getwch()
            return {"H": "up", "P": "down", "K": "left", "M": "right"}.get(ch2, "?")
        return ch.lower()
    else:
        import tty, termios
        fd  = sys.stdin.fileno()
        old = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            ch = sys.stdin.read(1)
            if ch == "\x1b":
                ch2 = sys.stdin.read(2)
                return {"[A": "up", "[B": "down", "[D": "left", "[C": "right"}.get(ch2, "esc")
            return ch.lower()
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old)


# ─── Game loop ────────────────────────────────────────────────────────────────
def run_game():
    world  = build_world()
    smap   = SpatialMap(world)

    # Player starts trapped by the wide wall in View A (z=0, y=2 wall at x=1..5)
    player  = Player(x=4, y=3, z=0)

    enemies = [
        Entity(x=1, y=3, z=0, name="E"),
        Entity(x=7, y=1, z=4, name="F"),
    ]

    exit_pos = (7, 1, 8)    # far corner of the map

    turn    = 0
    msg     = "Trapped? Press P to rotate the plane and escape!"
    rdr     = Renderer()
    ended   = False

    while not ended:
        clear_screen()
        print(draw_hud(player, enemies, turn, msg))
        print()
        print(rdr.axis_bar(player, smap))
        print()
        print(rdr.render_view(smap, player, enemies, exit_pos))
        print()

        key = get_key()

        if   key in ("w", "up"):    ok = player.move_up(smap);    msg = "↑ Up"    if ok else "⚠ Wall!"
        elif key in ("s", "down"):  ok = player.move_down(smap);  msg = "↓ Down"  if ok else "⚠ Wall!"
        elif key in ("a", "left"):  ok = player.move_left(smap);  msg = "← Left"  if ok else "⚠ Wall!"
        elif key in ("d", "right"): ok = player.move_right(smap); msg = "→ Right" if ok else "⚠ Wall!"
        elif key in ("p", " ", "\t"):
            old = player.plane
            player.toggle_plane()
            msg = f"⟳  {old} → {player.plane}  (axis locked, world re-rendered)"
        elif key == "q":
            print(clr("  Quit.\n", DIM)); break
        else:
            msg = f"Unknown key {repr(key)}. Use W/A/S/D, P=rotate, Q=quit"
            continue

        turn += 1

        # ── Enemy AI step ────────────────────────────────────────────────────
        for ent in enemies:
            ent.step_toward_player(player, smap)

        # ── Win / lose ───────────────────────────────────────────────────────
        if player.pos == exit_pos:
            clear_screen()
            print(rdr.render_view(smap, player, enemies, exit_pos))
            print(clr("\n  +----------------------+", YELLOW))
            print(clr("  |   ** YOU ESCAPED! **  |", BOLD + YELLOW))
            print(clr("  +----------------------+\n", YELLOW))
            ended = True
        for ent in enemies:
            if ent.pos == player.pos:
                clear_screen()
                print(rdr.render_view(smap, player, enemies, exit_pos))
                print(clr(f"\n  [X] Caught by {ent.name}! GAME OVER\n", BOLD + RED))
                ended = True
                break


# ─── Demo (no interactive input) ─────────────────────────────────────────────
def demo():
    """Print BFS path + both views without needing keyboard input."""
    world  = build_world()
    smap   = SpatialMap(world)
    player = Player(x=4, y=3, z=0)
    enemy  = Entity(x=1, y=3, z=4, name="E")
    rdr    = Renderer()

    print(clr("\n== BFS Demo ==\n", BOLD + CYAN))
    path = enemy.bfs_path(player.pos, smap)
    print(f"Enemy {enemy.pos} -> Player {player.pos}")
    if path:
        print(f"Path length: {len(path)} steps")
        for i, step in enumerate(path, 1):
            print(f"  {i:2d}: {step}")
    else:
        print("No path found.")

    print(clr("\n== View A: XY Plane (Z locked = 0) ==\n", BOLD + GREEN))
    print(rdr.axis_bar(player, smap))
    print()
    print(rdr.render_view(smap, player, [enemy], (7, 1, 8)))

    player.toggle_plane()
    print(clr("\n== View B: ZY Plane (X locked = 4) ==\n", BOLD + MAGENTA))
    print(rdr.axis_bar(player, smap))
    print()
    print(rdr.render_view(smap, player, [enemy], (7, 1, 8)))

    print(clr("\nNote: wide wall in View A = only 1 pillar in View B!", YELLOW))
    print(clr("Demo done.\n", DIM))


# ─── Entry ────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    if "--demo" in sys.argv:
        demo()
    else:
        try:
            run_game()
        except KeyboardInterrupt:
            print(clr("\n  Interrupted.\n", DIM))
