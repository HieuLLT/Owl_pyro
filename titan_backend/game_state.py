import time
import random
from dataclasses import dataclass, field
from typing import Dict, List, Optional
from events import EVENTS

START_STAT = 100
STAT_MIN = 0
STAT_MAX = 100
BASE_DRAIN = 2.0
DRAIN_GROWTH = 1.25
COLLAPSE_LIMIT = 3

@dataclass
class GameState:
    run_id: str
    cycle: int = 1
    stats: Dict[str, float] = field(default_factory=lambda: {"memory": START_STAT, "integrity": START_STAT, "willpower": START_STAT})
    collapsed_streak: Dict[str, int] = field(default_factory=lambda: {"memory": 0, "integrity": 0, "willpower": 0})
    current_event_id: Optional[str] = None
    event_bag: List[str] = field(default_factory=list)
    rng: random.Random = field(default_factory=lambda: random.Random())
    game_over: bool = False
    game_over_reason: Optional[str] = None
    created_at: float = field(default_factory=time.time)
    
    def drain_for(self, cycle: int) -> float:
        return BASE_DRAIN * (DRAIN_GROWTH ** (cycle - 1))
        
    def _clamp_stats(self):
        for k in self.stats:
            self.stats[k] = max(STAT_MIN, min(STAT_MAX, self.stats[k]))
            
    def apply_delta(self, delta: Dict[str, float]):
        for k, v in delta.items():
            self.stats[k] += v
        self._clamp_stats()
        
    def apply_drain(self):
        drain_amt = self.drain_for(self.cycle)
        for k in self.stats:
            self.stats[k] -= drain_amt
        self._clamp_stats()
        
    def _get_event(self, event_id: str):
        for e in EVENTS:
            if e["id"] == event_id:
                return e
        return None

    def worst_choice(self, event) -> str:
        # most negative sum of deltas
        # tie -> leaves the lowest single stat
        choices = event["choices"]
        
        def score_choice(choice):
            delta = choice["delta"]
            sum_delta = sum(delta.values())
            # Simulate leaving stat
            min_left = float('inf')
            for stat_name in self.stats:
                val = max(STAT_MIN, min(STAT_MAX, self.stats[stat_name] + delta.get(stat_name, 0)))
                min_left = min(min_left, val)
            return (sum_delta, min_left) # We want minimum sum, then minimum min_left
            
        return min(choices, key=score_choice)["id"]
        
    def draw_event(self):
        if not self.event_bag:
            self.event_bag = [e["id"] for e in EVENTS]
            self.rng.shuffle(self.event_bag)
            
            # Avoid repeating the last event
            if self.current_event_id and self.event_bag[0] == self.current_event_id:
                # Swap the first element with a random other element (if len > 1)
                if len(self.event_bag) > 1:
                    idx = self.rng.randint(1, len(self.event_bag) - 1)
                    self.event_bag[0], self.event_bag[idx] = self.event_bag[idx], self.event_bag[0]
                    
        self.current_event_id = self.event_bag.pop(0)

    def advance(self, choice_id: str) -> dict:
        if self.game_over:
            raise ValueError("Run already over")
            
        event = self._get_event(self.current_event_id)
        if not event:
            raise ValueError("Invalid current event")
            
        valid_choices = [c["id"] for c in event["choices"]]
        if choice_id not in valid_choices:
            raise ValueError("Invalid choice_id")
            
        overridden = False
        if self.stats["willpower"] <= 0:
            choice_id = self.worst_choice(event)
            overridden = True
            
        choice = next(c for c in event["choices"] if c["id"] == choice_id)
        
        self.apply_delta(choice["delta"])
        
        self.cycle += 1
        self.apply_drain()
        
        for k in self.stats:
            if self.stats[k] <= 0:
                self.collapsed_streak[k] += 1
            else:
                self.collapsed_streak[k] = 0
                
        collapsed_stats = [k for k, v in self.stats.items() if v <= 0]
        if len(collapsed_stats) >= 2:
            self.game_over = True
            self.game_over_reason = "MULTI_SYSTEM_COLLAPSE"
        else:
            for k, streak in self.collapsed_streak.items():
                if streak >= COLLAPSE_LIMIT:
                    self.game_over = True
                    self.game_over_reason = f"{k.upper()}_TERMINAL"
                    break
                    
        if not self.game_over:
            self.draw_event()
            
        # Return payload
        event_data = self._get_event(self.current_event_id) if not self.game_over else None
        
        payload = {
            "run_id": self.run_id,
            "cycle": self.cycle,
            "stats": {k: round(v, 1) for k, v in self.stats.items()},
            "collapsed": {k: (v <= 0) for k, v in self.stats.items()},
            "applied": {
                "chosen_id": choice_id,
                "overridden": overridden,
                "choice_delta": choice["delta"],
                "drain": round(self.drain_for(self.cycle - 1), 1) if self.cycle > 1 else 0 # drain applied during advance was drain_for(cycle) which was incremented
            },
            "drain_next": round(self.drain_for(self.cycle + 1), 1),
            "game_over": self.game_over,
            "game_over_reason": self.game_over_reason,
            "event": event_data
        }
        
        if self.game_over:
            payload["cycles_survived"] = self.cycle - 1
            
        return payload

    def to_dict_initial(self):
        return {
            "run_id": self.run_id,
            "cycle": self.cycle,
            "stats": {k: round(v, 1) for k, v in self.stats.items()},
            "collapsed": {k: (v <= 0) for k, v in self.stats.items()},
            "drain_next": round(self.drain_for(self.cycle + 1), 1), # On new game, cycle is 1, next drain is for cycle 2? Wait.
            # "creates a run, applies drain_for(1), draws event 1." -> new game does this.
            "game_over": self.game_over,
            "event": self._get_event(self.current_event_id)
        }
