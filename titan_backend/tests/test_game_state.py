import pytest
import sys
import os
import random

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from game_state import GameState, BASE_DRAIN, DRAIN_GROWTH
from events import EVENTS, validate_events

def test_drain_math():
    gs = GameState("test_math")
    assert gs.drain_for(1) == 2.0
    assert round(gs.drain_for(10), 1) == 14.9

def test_stat_clamping():
    gs = GameState("test_clamp")
    gs.stats["memory"] = 150 # Above max
    gs.stats["integrity"] = -50 # Below min
    gs._clamp_stats()
    assert gs.stats["memory"] == 100
    assert gs.stats["integrity"] == 0

def test_client_deltas_ignored():
    gs = GameState("test_deltas")
    gs.apply_drain()
    gs.draw_event()
    
    event = gs._get_event(gs.current_event_id)
    choice_id = event["choices"][0]["id"]
    # We call advance(choice_id). It does not take client deltas.
    # So by design client deltas are ignored. 
    # Let's assert it applies exactly the server's delta
    expected_stats = gs.stats.copy()
    
    server_delta = event["choices"][0]["delta"]
    for k, v in server_delta.items():
        expected_stats[k] += v
    
    # Also drain for cycle 2
    drain_amt = gs.drain_for(2)
    for k in expected_stats:
        expected_stats[k] = max(0, min(100, expected_stats[k])) # Clamp before drain
        expected_stats[k] = max(0, min(100, expected_stats[k] - drain_amt))
        
    payload = gs.advance(choice_id)
    assert payload["stats"]["memory"] == round(expected_stats["memory"], 1)

def test_willpower_override():
    gs = GameState("test_override")
    gs.apply_drain()
    gs.draw_event()
    gs.stats["willpower"] = 0
    
    # Send choice A, even if it's not the worst
    event = gs._get_event(gs.current_event_id)
    # the worst choice is calculated by worst_choice
    worst = gs.worst_choice(event)
    
    # Try to pick the non-worst choice
    non_worst = "A" if worst == "B" else "B"
    payload = gs.advance(non_worst)
    
    # Should have overridden to the worst
    assert payload["applied"]["chosen_id"] == worst
    assert payload["applied"]["overridden"] is True

def test_game_over_two_collapsed():
    gs = GameState("test_game_over_multi")
    gs.apply_drain()
    gs.draw_event()
    
    # Mock apply_delta so it doesn't change our forced stats
    gs.apply_delta = lambda delta: None
    
    gs.stats["memory"] = 0
    gs.stats["integrity"] = 0
    # advance will subtract drain, so they will stay at 0
    payload = gs.advance("A") 
    
    assert gs.game_over is True
    assert gs.game_over_reason == "MULTI_SYSTEM_COLLAPSE"
    assert payload["game_over"] is True

def test_game_over_one_stat_three_cycles():
    gs = GameState("test_game_over_streak")
    gs.apply_drain()
    gs.draw_event()
    
    # Mock apply_delta so memory stays 0
    gs.apply_delta = lambda delta: None
    
    # Cycle 1: memory is 0
    gs.stats["memory"] = 0
    payload1 = gs.advance("A") # Now cycle 2, streak 1
    
    # Cycle 2: memory still 0
    gs.stats["memory"] = 0
    payload2 = gs.advance("A") # Now cycle 3, streak 2
    
    assert gs.game_over is False
    
    # Cycle 3: memory still 0
    gs.stats["memory"] = 0
    payload3 = gs.advance("A") # Now cycle 4, streak 3
    
    assert gs.game_over is True
    assert gs.game_over_reason == "MEMORY_TERMINAL"
    
def test_same_seed_same_events():
    rng1 = random.Random(42)
    gs1 = GameState("seed1", rng=rng1)
    gs1.apply_drain()
    gs1.draw_event()
    
    rng2 = random.Random(42)
    gs2 = GameState("seed2", rng=rng2)
    gs2.apply_drain()
    gs2.draw_event()
    
    assert gs1.current_event_id == gs2.current_event_id
    
    gs1.advance("A")
    gs2.advance("A")
    
    assert gs1.current_event_id == gs2.current_event_id

def test_validate_events():
    validate_events(EVENTS) # Should not raise
