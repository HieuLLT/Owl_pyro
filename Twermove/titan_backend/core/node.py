"""
node.py — ListNode: the fundamental data structure for Titan levels.

A ListNode is a node in a singly-linked list that can optionally branch
into a graph when its modifier is DIVERTER.  All fields are plain Python
attributes; no ORM or serialisation logic lives here — that belongs in
the engine and API layers.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional

from titan_backend.core.enums import ModType


@dataclass
class ListNode:
    """
    A single node in the Titan level graph.

    Attributes
    ----------
    node_id : int
        Unique identifier, assigned sequentially by the generator.
    modifier : ModType
        The gameplay modifier applied at this node.  Defaults to NONE.
    next_node : ListNode | None
        Pointer to the next node on the *standard* path.
        None for the terminal node of a chain.
    alt_node : ListNode | None
        Pointer to the head of the *alternative* branch.
        Only populated when modifier == DIVERTER; None otherwise.
    required_input : str
        The key the player must press to correctly traverse *to* this
        node from its predecessor.  Set by the generator during
        beatmap compilation.  Defaults to "SPACE" for main-chain nodes.
    """

    node_id: int
    modifier: ModType = field(default=ModType.NONE)
    next_node: Optional["ListNode"] = field(default=None, repr=False)
    alt_node: Optional["ListNode"] = field(default=None, repr=False)
    required_input: str = field(default="SPACE")

    # ------------------------------------------------------------------ #
    # Convenience helpers                                                  #
    # ------------------------------------------------------------------ #

    @property
    def is_terminal(self) -> bool:
        """True when this node has no outgoing edges (end of a chain)."""
        return self.next_node is None and self.alt_node is None

    @property
    def is_branching(self) -> bool:
        """True when this node forks into an alt path (DIVERTER)."""
        return self.modifier == ModType.DIVERTER and self.alt_node is not None

    def __str__(self) -> str:  # pragma: no cover
        next_id = self.next_node.node_id if self.next_node else "None"
        alt_id = self.alt_node.node_id if self.alt_node else "None"
        return (
            f"ListNode(id={self.node_id}, mod={self.modifier.value}, "
            f"input={self.required_input!r}, next={next_id}, alt={alt_id})"
        )
