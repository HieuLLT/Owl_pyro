# DialogueSystem.gd
# Autoload. Ported from the web DialogueEngine (titan_frontend/static/dialogue.js).
# Loads res://data/dialogues/dialogue.json and routes lines to the two voices:
#   survival_white     -> EventBus.firewall_speak
#   manipulation_red   -> EventBus.memory_leak_speak
#
# Usage:
#   DialogueSystem.trigger("near_phantom")          # random White/Red line for that condition
#   DialogueSystem.trigger("near_erasure", true)    # urgent: bypasses cooldown
#   DialogueSystem.fire("DIA_R_PHANTOM_02")         # exact line
#
# Condition triggers that depend only on game state are detected automatically
# (standing_still_5s, energy_below_20, hp_low, eyes_closed_long, compass_active).

extends Node

const DIALOGUE_PATH: String = "res://data/dialogues/dialogue.json"

## Chance that a trigger picks the Red voice (Red is never picked while blind).
const RED_CHANCE: float = 0.40
## Per-condition cooldown (seconds).
const COOLDOWN: float = 8.0
## Minimum gap between ANY two lines (seconds) — keeps the screen readable.
const MIN_GAP: float = 1.4

const STILL_SECONDS: float = 5.0
const EYES_CLOSED_SECONDS: float = 4.0
const ENERGY_LOW: float = 20.0
const NECROSIS_HIGH: float = 60.0

var _db: Array = []
var _by_trigger: Dictionary = {}     # trigger -> { "survival_white": [..], "manipulation_red": [..] }
var _by_id: Dictionary = {}
var _cooldowns: Dictionary = {}      # trigger -> time (sec) of last fire
var _last_line_time: float = -100.0
var _loaded: bool = false

# auto-trigger state
var _still_time: float = 0.0
var _blind_time: float = 0.0
var _compass_on: bool = false
var _flags: Dictionary = {}          # one-shot edge flags

func _ready() -> void:
	_load()
	EventBus.vestige_needle_toggled.connect(_on_needle_toggled)
	EventBus.memory_shard_collected.connect(_on_shard_collected)

func _on_needle_toggled(active: bool) -> void:
	_compass_on = active
	if active:
		trigger("compass_active")

func _on_shard_collected(_shard_id: String) -> void:
	trigger("found_memory_core", true)

func _load() -> void:
	if not FileAccess.file_exists(DIALOGUE_PATH):
		push_warning("[DialogueSystem] Missing %s" % DIALOGUE_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIALOGUE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("dialogues"):
		push_error("[DialogueSystem] Bad dialogue.json")
		return
	_db = parsed["dialogues"]
	for d in _db:
		var trig: String = d.get("trigger", "generic")
		var type: String = d.get("type", "survival_white")
		if not _by_trigger.has(trig):
			_by_trigger[trig] = {"survival_white": [], "manipulation_red": []}
		_by_trigger[trig][type].append(d)
		_by_id[d["id"]] = d
	_loaded = true

# ─────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────

## Fire a random line for a condition. urgent=true bypasses the cooldowns.
func trigger(condition_id: String, urgent: bool = false) -> void:
	if not _loaded:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if not urgent:
		if now - _cooldowns.get(condition_id, -100.0) < COOLDOWN:
			return
		if now - _last_line_time < MIN_GAP:
			return

	var want_red: bool = (not GameManager.is_blind) and randf() < RED_CHANCE
	var line: Dictionary = _pick(condition_id, want_red)
	if line.is_empty():
		return
	_cooldowns[condition_id] = now
	_emit_line(line, now)

## Fire an exact line by id (scripted moments). Red lines are skipped while blind.
func fire(dialogue_id: String) -> void:
	var line: Dictionary = _by_id.get(dialogue_id, {})
	if line.is_empty():
		return
	if line["type"] == "manipulation_red" and GameManager.is_blind:
		return
	_emit_line(line, Time.get_ticks_msec() / 1000.0)

# ─────────────────────────────────────────────
# INTERNALS
# ─────────────────────────────────────────────

func _pick(condition_id: String, want_red: bool) -> Dictionary:
	var type: String = "manipulation_red" if want_red else "survival_white"
	var pool: Array = []
	if _by_trigger.has(condition_id):
		pool = _by_trigger[condition_id][type]
	# Fall back to the other voice for this condition, then to "generic"
	if pool.is_empty() and _by_trigger.has(condition_id):
		var other: String = "survival_white" if want_red else "manipulation_red"
		if other == "survival_white" or not GameManager.is_blind:
			pool = _by_trigger[condition_id][other]
	if pool.is_empty() and _by_trigger.has("generic"):
		pool = _by_trigger["generic"][type]
	if pool.is_empty():
		return {}
	return pool[randi() % pool.size()]

func _emit_line(line: Dictionary, now: float) -> void:
	_last_line_time = now
	var text: String = line["text"]
	if line["type"] == "manipulation_red":
		EventBus.memory_leak_speak.emit(text, randf_range(0.5, 0.9))
	else:
		EventBus.firewall_speak.emit(text)

func _process(delta: float) -> void:
	if not _loaded or not GameManager.game_started or GameManager.is_paused:
		return

	# standing_still_5s
	# Works for both the 2D (CharacterBody2D) and first-person (CharacterBody3D) player.
	var mrak: Node = get_tree().get_first_node_in_group("mrak")
	if mrak and "velocity" in mrak and mrak.velocity.length() < 1.0 and not GameManager.is_blind:
		_still_time += delta
		if _still_time >= STILL_SECONDS:
			_still_time = 0.0
			trigger("standing_still_5s")
	else:
		_still_time = 0.0

	# eyes_closed_long
	if GameManager.is_blind:
		_blind_time += delta
		if _blind_time >= EYES_CLOSED_SECONDS:
			_blind_time = 0.0
			trigger("eyes_closed_long")
	else:
		_blind_time = 0.0

	# energy_below_20 / hp_low (necrosis is мрак's "health"): fire on crossing
	_edge("energy_low", GameManager.pin < ENERGY_LOW, "energy_below_20")
	_edge("hp_low", GameManager.necrosis >= NECROSIS_HIGH, "hp_low")

func _edge(key: String, active: bool, condition_id: String) -> void:
	if active and not _flags.get(key, false):
		trigger(condition_id, true)
	_flags[key] = active
