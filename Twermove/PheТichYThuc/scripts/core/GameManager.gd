# GameManager.gd
# Autoload singleton — Single source of truth for all мрак vitals and game state.
# Drives the core game loop logic, vital decay, and ending calculation.

extends Node

# ─────────────────────────────────────────────
# мрак VITALS
# ─────────────────────────────────────────────

## Battery level (0.0 – 100.0). Drains passively; faster when blind.
var pin: float = 100.0

## Thermal temperature in °C. Rises on activity, falls at rest.
var thermal: float = 20.0

## Necrosis percentage (0.0 – 100.0). Increases on detection events.
## > 70% → MEMORY LEAK dominates UI. 100% → Ending A.
var necrosis: float = 0.0

## Whether мрак is currently in Sensory Deprivation (Nhắm Mắt)
var is_blind: bool = false

## Current sound emission radius (px) — used by enemy AI
var current_sound_radius: float = 200.0

# ─────────────────────────────────────────────
# MEMORY STATE
# ─────────────────────────────────────────────

## IDs of all collected Memory Shards
var memory_shards_collected: Array[String] = []

## Lie Labyrinth choices: { shard_id: bool (true = chose truth) }
var truth_choices: Dictionary = {}

# ─────────────────────────────────────────────
# GAME STATE
# ─────────────────────────────────────────────

var current_floor: int = 0
var is_paused: bool = false
var game_started: bool = false

# Drain rates (per second)
const PIN_BASE_DRAIN: float = 0.08
const PIN_BLIND_DRAIN: float = 2.0
const THERMAL_IDLE_COOL: float = 5.0
const THERMAL_MOVE_HEAT: float = 3.0
const THERMAL_BLIND_HEAT: float = 1.0

# ─────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────

func _ready() -> void:
	EventBus.mrak_blink_toggled.connect(_on_blink_toggled)
	EventBus.mrak_detected.connect(_on_mrak_detected)
	EventBus.memory_shard_collected.connect(_on_shard_collected)
	EventBus.lie_choice_made.connect(_on_lie_choice)

func _process(delta: float) -> void:
	if is_paused or not game_started:
		return
	_process_pin(delta)
	_process_thermal(delta)
	_check_thresholds()

# ─────────────────────────────────────────────
# VITALS PROCESSING
# ─────────────────────────────────────────────

func _process_pin(delta: float) -> void:
	var drain = PIN_BASE_DRAIN
	if is_blind:
		drain += PIN_BLIND_DRAIN
	pin = clampf(pin - drain * delta, 0.0, 100.0)
	EventBus.mrak_pin_changed.emit(pin)

func _process_thermal(delta: float) -> void:
	# Placeholder: actual movement state will be set by Mrak.gd
	# For now cool slightly each frame
	thermal = clampf(thermal - THERMAL_IDLE_COOL * delta, 20.0, 120.0)
	EventBus.mrak_thermal_changed.emit(thermal)

func add_heat(amount: float) -> void:
	thermal = clampf(thermal + amount, 20.0, 120.0)
	EventBus.mrak_thermal_changed.emit(thermal)

func add_necrosis(amount: float) -> void:
	necrosis = clampf(necrosis + amount, 0.0, 100.0)
	EventBus.mrak_necrosis_changed.emit(necrosis)
	# Update UI chaos
	EventBus.ui_chaos_level_changed.emit(necrosis / 100.0)

func restore_pin(amount: float) -> void:
	pin = clampf(pin + amount, 0.0, 100.0)
	EventBus.mrak_pin_changed.emit(pin)

# ─────────────────────────────────────────────
# THRESHOLD CHECKS
# ─────────────────────────────────────────────

func _check_thresholds() -> void:
	# Pin critical — forced blink off
	if pin <= 0.0 and is_blind:
		is_blind = false
		EventBus.mrak_blink_toggled.emit(false)
		EventBus.firewall_speak.emit("CRITICAL — BATTERY DEPLETED. FORCED REACTIVATION.")
		add_necrosis(5.0)

	# Necrosis death
	if necrosis >= 100.0:
		EventBus.mrak_died.emit()
		_trigger_ending("A_FRAGMENTATION")

	# Necrosis > 70%: MEMORY LEAK dominance warning
	if necrosis >= 70.0 and necrosis < 71.0:
		EventBus.memory_leak_speak.emit(
			"ừ... bây giờ thì tôi có thể nói chuyện được rồi... бесконечность...",
			1.0
		)

	# Thermal overheat
	if thermal >= 100.0:
		EventBus.firewall_speak.emit("WARNING — THERMAL CRITICAL. MRAK DESTABILIZING.")
		add_necrosis(0.5)

# ─────────────────────────────────────────────
# EVENT HANDLERS
# ─────────────────────────────────────────────

func _on_blink_toggled(blind: bool) -> void:
	is_blind = blind

func _on_mrak_detected(_enemy: Node) -> void:
	add_necrosis(3.0)
	add_heat(10.0)
	EventBus.firewall_speak.emit("DETECTED. EVASION REQUIRED.")

func _on_shard_collected(shard_id: String) -> void:
	if shard_id not in memory_shards_collected:
		memory_shards_collected.append(shard_id)

func _on_lie_choice(shard_id: String, _word: String, is_truth: bool) -> void:
	truth_choices[shard_id] = is_truth

# ─────────────────────────────────────────────
# ENDING CALCULATION
# ─────────────────────────────────────────────

## Call this when мрак reaches the Boss chamber.
func calculate_ending() -> String:
	var shards_count: int = memory_shards_collected.size()
	var truth_count: int = 0
	for v in truth_choices.values():
		if v:
			truth_count += 1

	if necrosis >= 70.0:
		return "A_FRAGMENTATION"
	elif shards_count < 3 or truth_count == 0:
		return "B_FIREWALL"
	else:
		return "C_INTEGRATION"

func _trigger_ending(ending_id: String) -> void:
	EventBus.ending_triggered.emit(ending_id)

# ─────────────────────────────────────────────
# FLOOR MANAGEMENT
# ─────────────────────────────────────────────

func set_floor(floor_id: int) -> void:
	var prev = current_floor
	current_floor = floor_id
	EventBus.floor_transition_started.emit(prev, floor_id)

func complete_floor_transition() -> void:
	EventBus.floor_transition_completed.emit(current_floor)

# ─────────────────────────────────────────────
# SOUND RADIUS (set by Mrak.gd each frame)
# ─────────────────────────────────────────────

func set_sound_radius(radius: float) -> void:
	current_sound_radius = radius
	EventBus.mrak_sound_radius_changed.emit(radius)

# ─────────────────────────────────────────────
# SAVE / LOAD HELPERS
# ─────────────────────────────────────────────

func get_save_data() -> Dictionary:
	return {
		"pin": pin,
		"thermal": thermal,
		"necrosis": necrosis,
		"current_floor": current_floor,
		"memory_shards_collected": memory_shards_collected,
		"truth_choices": truth_choices,
	}

func load_save_data(data: Dictionary) -> void:
	pin = data.get("pin", 100.0)
	thermal = data.get("thermal", 20.0)
	necrosis = data.get("necrosis", 0.0)
	current_floor = data.get("current_floor", 0)
	memory_shards_collected = data.get("memory_shards_collected", [])
	truth_choices = data.get("truth_choices", {})
	game_started = true
