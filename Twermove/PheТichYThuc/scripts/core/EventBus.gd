# EventBus.gd
# Autoload singleton — Central event bus for all game systems.
# No direct node references between systems; everything communicates via signals.
# мрак (мрак) = protagonist name

# Suppress "signal declared but never explicitly used" lint warning.
# All signals ARE connected at runtime via .connect() — static analysis misses this.
@warning_ignore_start("unused_signal")

extends Node

# ─────────────────────────────────────────────
# мрак VITAL SIGNALS
# ─────────────────────────────────────────────

## Emitted when мрак's battery level changes (0.0 – 100.0)
signal mrak_pin_changed(new_value: float)

## Emitted when мрак's thermal core temperature changes (°C)
signal mrak_thermal_changed(new_value: float)

## Emitted when мрак's necrosis percentage changes (0.0 – 100.0)
signal mrak_necrosis_changed(new_value: float)

## Emitted when мрак enters or exits Sensory Deprivation (Nhắm Mắt)
signal mrak_blink_toggled(is_blind: bool)

## Emitted when мрак is spotted by an enemy
signal mrak_detected(by_enemy: Node)

## Emitted when мрак successfully hides again
signal mrak_hidden()

## Emitted when мрак dies / necrosis reaches 100%
signal mrak_died()

# ─────────────────────────────────────────────
# MOVEMENT & SOUND SIGNALS
# ─────────────────────────────────────────────

## Emitted when мрак's sound emission radius changes (used by enemies)
signal mrak_sound_radius_changed(radius: float)

## Emitted when мрак collides with the environment (sound spike)
signal mrak_collision_sound(position: Vector2, intensity: float)

# ─────────────────────────────────────────────
# MEMORY SYSTEM SIGNALS
# ─────────────────────────────────────────────

## Emitted when a Memory Shard is collected
signal memory_shard_collected(shard_id: String)

## Emitted when a Memory Puzzle begins
signal memory_puzzle_started(puzzle_data: Dictionary)

## Emitted when a Memory Puzzle is completed
## is_truth: whether the player chose the truthful interpretation
signal memory_puzzle_completed(shard_id: String, is_truth: bool)

## Emitted when a Lie Labyrinth choice is made
signal lie_choice_made(shard_id: String, word: String, is_truth: bool)

# ─────────────────────────────────────────────
# VESTIGE NEEDLE (LA BÀN DỐI TRÁI)
# ─────────────────────────────────────────────

## Emitted when Vestige Needle is activated/deactivated
signal vestige_needle_toggled(is_active: bool)

## Emitted when needle interference level changes
signal vestige_needle_interference(level: float)  # 0.0 clean, 1.0 corrupted

# ─────────────────────────────────────────────
# SCHIZOPHRENIC UI SIGNALS
# ─────────────────────────────────────────────

## FIREWALL (White Voice) — rational, cold, survival-focused
signal firewall_speak(message: String)

## MEMORY LEAK (Red Voice) — manipulative, guilt-driven, glitched
## intensity: 0.0 = whisper, 1.0 = screaming glitch
signal memory_leak_speak(message: String, intensity: float)

## Overall UI chaos level (driven by necrosis %)
signal ui_chaos_level_changed(level: float)  # 0.0 – 1.0

# ─────────────────────────────────────────────
# ENEMY SIGNALS
# ─────────────────────────────────────────────

## Enemy state machine changed
signal enemy_state_changed(enemy: Node, new_state: String)

## Scavenger raised alarm at a position
signal scavenger_alarm_triggered(position: Vector2)

## Enemy lost track of мрак
signal enemy_lost_target(enemy: Node)

# ─────────────────────────────────────────────
# SCENE / GAME FLOW SIGNALS
# ─────────────────────────────────────────────

## Floor transition
signal floor_transition_started(from_floor: int, to_floor: int)
signal floor_transition_completed(new_floor: int)

## Game ending triggered
signal ending_triggered(ending_id: String)  # "A_FRAGMENTATION" / "B_FIREWALL" / "C_INTEGRATION"

## Pause / unpause
signal game_paused()
signal game_resumed()
