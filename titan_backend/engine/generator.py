"""
generator.py — LevelGenerator: 3D Cylindrical Graph Builder + BST logic.

Builds a sequence of nodes mapped to a 3D cylinder. DIVERTER nodes spawn a fork
where one branch adheres to BST rules and the other breaks them.
"""
from __future__ import annotations

import random
import uuid
from collections import deque
from dataclasses import dataclass
from typing import Any

from titan_backend.core.enums import ModType
from titan_backend.core.node import ListNode


@dataclass(frozen=True)
class DifficultyPreset:
    chaser_interval: int
    blockade_interval: int
    diverter_interval: int
    alt_branch_len: int


PRESETS: dict[str, DifficultyPreset] = {
    "easy":   DifficultyPreset(chaser_interval=8,  blockade_interval=10, diverter_interval=15, alt_branch_len=2),
    "medium": DifficultyPreset(chaser_interval=5,  blockade_interval=8,  diverter_interval=12, alt_branch_len=3),
    "hard":   DifficultyPreset(chaser_interval=3,  blockade_interval=5,  diverter_interval=8,  alt_branch_len=4),
}


class LevelGenerator:
    """
    Builds a Titan level as a 3D cylindrical graph.
    """

    def __init__(
        self,
        node_count: int = 20,
        base_tempo_ms: int = 500, # Kept for API compatibility, unused in generation
        difficulty: str = "medium",
        seed: int | None = None,
    ) -> None:
        if difficulty not in PRESETS:
            raise ValueError(f"Unknown difficulty {difficulty!r}. Choose from {list(PRESETS)}.")

        self._node_count = node_count
        self._preset = PRESETS[difficulty]
        self._difficulty = difficulty
        self._rng = random.Random(seed)
        self._id_counter = 0

    def generate(self) -> tuple[str, list[dict[str, Any]]]:
        head = self._build_topology()
        beatmap = self._compile_graph(head)
        level_id = str(uuid.uuid4())
        return level_id, beatmap

    def _next_id(self) -> int:
        node_id = self._id_counter
        self._id_counter += 1
        return node_id

    def _choose_modifier(self, position: int) -> ModType:
        if position == 0:
            return ModType.NONE

        p = self._preset
        if p.diverter_interval and position % p.diverter_interval == 0:
            return ModType.DIVERTER
        if p.blockade_interval and position % p.blockade_interval == 0:
            return ModType.BLOCKADE
        if p.chaser_interval and position % p.chaser_interval == 0:
            return ModType.CHASER
        return ModType.NONE

    def _build_alt_branch(self, branch_len: int) -> ListNode:
        head: ListNode | None = None
        tail: ListNode | None = None
        for _ in range(branch_len):
            node = ListNode(node_id=self._next_id(), modifier=ModType.NONE)
            if tail is not None:
                tail.next_node = node
            tail = node
            if head is None:
                head = node
        assert head is not None
        return head

    def _build_topology(self) -> ListNode:
        nodes: list[ListNode] = []

        for position in range(self._node_count):
            modifier = self._choose_modifier(position)
            node = ListNode(node_id=self._next_id(), modifier=modifier)
            nodes.append(node)

        for i in range(len(nodes) - 1):
            nodes[i].next_node = nodes[i + 1]

        for node in nodes:
            if node.modifier == ModType.DIVERTER:
                branch = self._build_alt_branch(self._preset.alt_branch_len)
                node.alt_node = branch

        return nodes[0]

    def _compile_graph(self, head: ListNode) -> list[dict[str, Any]]:
        beatmap: list[dict[str, Any]] = []
        visited: set[int] = set()
        
        # Queue entries: (node, height_index, angle_offset, is_alt_branch)
        queue: deque[tuple[ListNode, int, float, bool]] = deque()
        queue.append((head, 0, 0.0, False))

        while queue:
            node, height, angle, is_alt = queue.popleft()

            if node.node_id in visited:
                continue
            visited.add(node.node_id)

            # Default value assignment for standard nodes
            val = self._rng.randint(10, 99)
            left_child_id = None
            right_child_id = None

            if node.modifier == ModType.DIVERTER and node.alt_node is not None:
                # BST Fork logic
                val = self._rng.randint(30, 70)
                
                # Determine which branch is main and which is alt
                main_child = node.next_node
                alt_child = node.alt_node
                
                # Randomly assign left/right spatial positions
                is_main_left = self._rng.choice([True, False])
                
                if is_main_left:
                    # Main child is left, Alt child is right
                    left_child = main_child
                    right_child = alt_child
                    left_is_alt = False
                    right_is_alt = True
                else:
                    # Main child is right, Alt child is left
                    left_child = alt_child
                    right_child = main_child
                    left_is_alt = True
                    right_is_alt = False

                left_child_id = left_child.node_id
                right_child_id = right_child.node_id
                
                # One branch must follow BST, the other breaks it. 
                # The main branch ALWAYS follows BST. The alt branch ALWAYS breaks it.
                if is_main_left:
                    # Left is correct (should be < val). Right is incorrect (should be > val, but we make it <= val)
                    left_val = self._rng.randint(10, val - 1)
                    right_val = self._rng.randint(10, val - 1) # BREAKS BST
                else:
                    # Right is correct (should be > val). Left is incorrect (should be < val, but we make it >= val)
                    right_val = self._rng.randint(val + 1, 99)
                    left_val = self._rng.randint(val + 1, 99) # BREAKS BST

                # Assign values to the children
                left_child.value = left_val
                right_child.value = right_val

                # Queue the children
                queue.append((left_child, height + 1, (angle - 45) % 360, left_is_alt))
                queue.append((right_child, height + 1, (angle + 45) % 360, right_is_alt))

            elif node.next_node is not None:
                # Normal linear progression
                # Angle might naturally spiral or stay straight. Let's make it spiral slightly.
                next_angle = (angle + self._rng.choice([-15, 0, 15])) % 360
                # Preserve pre-assigned value if it was set by a parent DIVERTER
                if not hasattr(node, 'value'):
                    node.value = val
                
                queue.append((node.next_node, height + 1, next_angle, is_alt))

            if not hasattr(node, 'value'):
                node.value = val

            beatmap.append({
                "node_id": node.node_id,
                "height_index": height,
                "angle_offset": angle,
                "value": node.value,
                "modifier": node.modifier.value,
                "is_alt_branch": is_alt,
                "left_child_id": left_child_id,
                "right_child_id": right_child_id,
            })

        beatmap.sort(key=lambda n: (n["is_alt_branch"], n["height_index"]))
        return beatmap
