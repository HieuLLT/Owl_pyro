# MemoryPuzzle.gd
# Manages the 3 types of Memory Decryption Puzzles.
# Triggered when мрак collects a Memory Shard (press E near glowing shard).
# All 3 puzzle types pause movement and demand focus.

extends Control

# ─────────────────────────────────────────────
# PUZZLE TYPES
# ─────────────────────────────────────────────

enum PuzzleType { SIGNAL_TUNING, FRAGMENT_ASSEMBLY, LIE_LABYRINTH }

var current_shard_id: String = ""
var current_type: PuzzleType = PuzzleType.SIGNAL_TUNING
var current_config: Dictionary = {}
var is_active: bool = false

# ─────────────────────────────────────────────
# SIGNAL TUNING STATE
# ─────────────────────────────────────────────

var tune_position: float    = 0.0   # Current knob position (0.0 - 1.0)
var tune_target: float      = 0.5   # Target frequency position
var tune_tolerance: float   = 0.05
var tune_speed: float       = 0.6

# ─────────────────────────────────────────────
# FRAGMENT ASSEMBLY STATE
# ─────────────────────────────────────────────

var fragments: Array[int]   = []   # Current order
var correct_order: Array[int] = []
var selected_index: int     = -1

# ─────────────────────────────────────────────
# LIE LABYRINTH STATE
# ─────────────────────────────────────────────

var lie_words: Array[Dictionary] = []
var chosen_words: Array[bool]    = []

# ─────────────────────────────────────────────
# NODE REFS (assigned by parent or editor)
# ─────────────────────────────────────────────

@onready var bg_overlay: ColorRect       = $BG
@onready var puzzle_container: Control   = $PuzzleContainer
@onready var signal_panel: Control       = $PuzzleContainer/SignalTuning
@onready var fragment_panel: Control     = $PuzzleContainer/FragmentAssembly
@onready var lie_panel: Control          = $PuzzleContainer/LieLabyrinth
@onready var tuner_bar: ColorRect        = $PuzzleContainer/SignalTuning/TunerBar
@onready var needle_marker: ColorRect    = $PuzzleContainer/SignalTuning/NeedleMarker
@onready var target_marker: ColorRect    = $PuzzleContainer/SignalTuning/TargetMarker
@onready var status_label: Label         = $PuzzleContainer/StatusLabel
@onready var close_timer: Timer          = $CloseTimer

# ─────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────

func _ready() -> void:
	visible = false
	close_timer.timeout.connect(_on_close_timer)
	close_timer.one_shot = true

func _process(delta: float) -> void:
	if not is_active:
		return
	match current_type:
		PuzzleType.SIGNAL_TUNING: _update_signal_tuning(delta)

func _input(event: InputEvent) -> void:
	if not is_active:
		return
	match current_type:
		PuzzleType.SIGNAL_TUNING:
			_input_signal_tuning(event)
		PuzzleType.FRAGMENT_ASSEMBLY:
			_input_fragment_assembly(event)
		PuzzleType.LIE_LABYRINTH:
			_input_lie_labyrinth(event)

# ─────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────

func start_puzzle(shard_id: String) -> void:
	current_shard_id = shard_id
	var data := MemorySystem.get_shard_data(shard_id) if Engine.has_singleton("MemorySystem") else {}
	current_config = MemorySystem.get_puzzle_config(shard_id) if Engine.has_singleton("MemorySystem") else {}

	var type_str: String = data.get("type", "SIGNAL_TUNING")
	match type_str:
		"SIGNAL_TUNING":      current_type = PuzzleType.SIGNAL_TUNING
		"FRAGMENT_ASSEMBLY":  current_type = PuzzleType.FRAGMENT_ASSEMBLY
		"LIE_LABYRINTH":      current_type = PuzzleType.LIE_LABYRINTH

	is_active = true
	visible = true

	match current_type:
		PuzzleType.SIGNAL_TUNING:     _setup_signal_tuning()
		PuzzleType.FRAGMENT_ASSEMBLY: _setup_fragment_assembly()
		PuzzleType.LIE_LABYRINTH:     _setup_lie_labyrinth()

# ─────────────────────────────────────────────
# PUZZLE TYPE 1 — SIGNAL TUNING
# ─────────────────────────────────────────────

func _setup_signal_tuning() -> void:
	tune_position = randf_range(0.0, 1.0)
	tune_target   = 0.5  # Normalized target
	if signal_panel: signal_panel.visible = true
	if fragment_panel: fragment_panel.visible = false
	if lie_panel: lie_panel.visible = false
	if status_label:
		status_label.text = "FIREWALL > Tune signal. [←][→] to adjust. Align with target frequency."

func _update_signal_tuning(delta: float) -> void:
	var dir: float = Input.get_axis("move_left", "move_right")
	tune_position = clampf(tune_position + dir * tune_speed * delta, 0.0, 1.0)

	# Update visuals
	if needle_marker:
		needle_marker.position.x = tune_position * 400.0 - 200.0
	if target_marker:
		target_marker.position.x = tune_target * 400.0 - 200.0

	# Check alignment
	if abs(tune_position - tune_target) < tune_tolerance:
		_on_puzzle_success()

func _input_signal_tuning(_event: InputEvent) -> void:
	pass  # Handled in _process above

# ─────────────────────────────────────────────
# PUZZLE TYPE 2 — FRAGMENT ASSEMBLY
# ─────────────────────────────────────────────

func _setup_fragment_assembly() -> void:
	correct_order = current_config.get("correct_order", [0, 1, 2, 3])
	fragments = correct_order.duplicate()
	fragments.shuffle()
	if signal_panel: signal_panel.visible = false
	if fragment_panel: fragment_panel.visible = true
	if lie_panel: lie_panel.visible = false
	if status_label:
		status_label.text = "FIREWALL > Arrange memory fragments in chronological order. [←][→] select. [E] swap."
	selected_index = 0

func _input_fragment_assembly(event: InputEvent) -> void:
	if event.is_action_pressed("move_left"):
		selected_index = max(0, selected_index - 1)
	if event.is_action_pressed("move_right"):
		selected_index = min(fragments.size() - 1, selected_index + 1)
	if event.is_action_pressed("interact"):
		# Swap with next
		if selected_index < fragments.size() - 1:
			var tmp := fragments[selected_index]
			fragments[selected_index] = fragments[selected_index + 1]
			fragments[selected_index + 1] = tmp
	# Check correct
	if fragments == correct_order:
		_on_puzzle_success()
	else:
		# Wrong arrangement trigger
		var wrong_text: String = current_config.get("wrong_order_text", "...")
		if randf() < 0.3:
			EventBus.memory_leak_speak.emit(wrong_text, 0.5)

# ─────────────────────────────────────────────
# PUZZLE TYPE 3 — LIE LABYRINTH
# ─────────────────────────────────────────────

func _setup_lie_labyrinth() -> void:
	lie_words = current_config.get("words", [])
	chosen_words = []
	chosen_words.resize(lie_words.size())
	chosen_words.fill(false)
	if signal_panel: signal_panel.visible = false
	if fragment_panel: fragment_panel.visible = false
	if lie_panel: lie_panel.visible = true
	if status_label:
		status_label.text = "FIREWALL > Select the words that represent the TRUTH. [E] to confirm each."

func _input_lie_labyrinth(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		# For simplicity: cycle through words
		for i in range(lie_words.size()):
			if not chosen_words[i]:
				chosen_words[i] = true
				var word_data: Dictionary = lie_words[i]
				EventBus.lie_choice_made.emit(
					current_shard_id,
					word_data.get("text", ""),
					word_data.get("is_truth", false)
				)
				# All words chosen?
				if chosen_words.all(func(v): return v):
					_on_puzzle_success()
				return

# ─────────────────────────────────────────────
# OUTCOME
# ─────────────────────────────────────────────

func _on_puzzle_success() -> void:
	EventBus.memory_puzzle_completed.emit(current_shard_id, true)
	EventBus.memory_shard_collected.emit(current_shard_id)
	if status_label:
		status_label.text = "FIREWALL > Fragment integrated."
	close_timer.start(1.5)

func _on_puzzle_failure() -> void:
	EventBus.memory_puzzle_completed.emit(current_shard_id, false)
	EventBus.memory_shard_collected.emit(current_shard_id)
	var interference: String = current_config.get("interference_text", "...")
	EventBus.memory_leak_speak.emit(interference, 0.9)
	close_timer.start(2.0)

func _on_close_timer() -> void:
	is_active = false
	visible = false
