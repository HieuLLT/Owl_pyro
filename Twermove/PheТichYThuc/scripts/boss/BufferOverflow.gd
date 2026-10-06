# BufferOverflow.gd
# BOSS — The Accumulation of All Erased Memories.
# Buffer Overflow is not a physical entity — it is a SOUND WAVE ENTITY.
# It cannot be killed. It must be OVERWRITTEN (forgiven).
# Victory condition: Solve 5 Memory Puzzles within the chamber while dodging sonic waves.

extends Node2D

# ─────────────────────────────────────────────
# BOSS PHASES
# ─────────────────────────────────────────────

enum Phase {
	P1_SWEEP,     # Horizontal sweeping sine waves — dodge by Nhắm Mắt
	P2_RANDOM,    # 360° random bursts — read animation, predict
	P3_CHAOS      # UI chaos + simultaneous puzzle + full sonic barrage
}

var current_phase: Phase = Phase.P1_SWEEP
var puzzles_solved: int  = 0
const PUZZLES_TO_WIN: int = 5

# ─────────────────────────────────────────────
# NODE REFS
# ─────────────────────────────────────────────

@onready var wave_emitter: Node2D         = $WaveEmitter
@onready var wave_sprite: AnimatedSprite2D = $WaveSprite
@onready var ambient_audio: AudioStreamPlayer = $AmbientAudio
@onready var phase_label: Label           = $DebugPhaseLabel  # Debug only
@onready var overwrite_vfx: CPUParticles2D = $OverwriteVFX

# Wave danger areas (Area2D nodes that deal necrosis on overlap)
@onready var wave_areas: Array = []

# ─────────────────────────────────────────────
# PHASE TIMERS
# ─────────────────────────────────────────────

var _phase_timer: float = 0.0
var _wave_timer: float  = 0.0

const P1_WAVE_INTERVAL: float = 3.0
const P2_WAVE_INTERVAL: float = 1.8
const P3_WAVE_INTERVAL: float = 1.2

var _p1_direction: float = 1.0   # Sweep direction
var _p2_angle_pool: Array[float] = []

# ─────────────────────────────────────────────
# INIT
# ─────────────────────────────────────────────

func _ready() -> void:
	EventBus.memory_puzzle_completed.connect(_on_puzzle_solved)
	_enter_phase(Phase.P1_SWEEP)

	# Collect all wave Area2D children
	for child in wave_emitter.get_children():
		if child is Area2D:
			wave_areas.append(child)
			child.body_entered.connect(_on_wave_hit.bind(child))

# ─────────────────────────────────────────────
# MAIN LOOP
# ─────────────────────────────────────────────

func _process(delta: float) -> void:
	_phase_timer += delta
	_wave_timer  += delta
	_run_phase(delta)
	_check_phase_transition()

func _run_phase(_delta: float) -> void:
	match current_phase:
		Phase.P1_SWEEP:   _phase_sweep()
		Phase.P2_RANDOM:  _phase_random()
		Phase.P3_CHAOS:   _phase_chaos()

# ─────────────────────────────────────────────
# PHASE 1 — HORIZONTAL SWEEP
# ─────────────────────────────────────────────

func _phase_sweep() -> void:
	if _wave_timer < P1_WAVE_INTERVAL:
		return
	_wave_timer = 0.0

	# Emit a horizontal wave
	_emit_wave(Vector2(_p1_direction, 0.0), 180.0)
	_p1_direction *= -1.0

	EventBus.firewall_speak.emit("SONIC WAVE DETECTED — BEARING: %.0f° — ENGAGE SENSORY DEPRIVATION" % \
		(90.0 if _p1_direction > 0.0 else 270.0))

# ─────────────────────────────────────────────
# PHASE 2 — RANDOM 360°
# ─────────────────────────────────────────────

func _phase_random() -> void:
	if _wave_timer < P2_WAVE_INTERVAL:
		return
	_wave_timer = 0.0

	var angle: float = randf_range(0.0, TAU)
	_emit_wave(Vector2(cos(angle), sin(angle)), rad_to_deg(angle))
	# FIREWALL can only give bearing, not predict this one
	EventBus.firewall_speak.emit("WAVE — BEARING: %.0f°" % rad_to_deg(angle))

# ─────────────────────────────────────────────
# PHASE 3 — FULL CHAOS
# ─────────────────────────────────────────────

func _phase_chaos() -> void:
	if _wave_timer < P3_WAVE_INTERVAL:
		return
	_wave_timer = 0.0

	# Three waves simultaneously
	for i in range(3):
		var angle: float = randf_range(0.0, TAU)
		_emit_wave(Vector2(cos(angle), sin(angle)), rad_to_deg(angle))

	# UI chaos maxes out
	EventBus.ui_chaos_level_changed.emit(1.0)
	# MEMORY LEAK floods screen
	EventBus.memory_leak_speak.emit(
		"ể̶̡̧̠͕ r̴̟̻̲̖̗̩̅̑̑a̷͔̔̑̾̅ ̸̺͉͕̄͋ṅ̷̡̡̡̢̲̰̱̫̗͕̙͚̘͕͖͕͉̝͚͇̳̹͖͓͍̼̹̻̯͉͚͈̼̯͓̃͐̾̉̿̒̎̋̄̆̊̉̃̒̉̉̀̾̆͑̃̎̊̉̆̿̋̇͒̊̚͘͝͝͠͝ǫ̵̛̗͔̙̤̆̿ͅi̸̭̥̖̯̠̟̜͖̙̠̙͖̰̓̃̃̿̈͘ ̶̡̹̤̯̩̩͙̅̇͊̿͒͒͋͝b̸̰̞̝̖̱̲̮̪̫̤͍͓̤̙̬̰̤͖̬̺̐̈́̓̄̾̿̈͛̀̑̎̈́̑̄̀̀͗̒͑̕ạ̷̲͙̩̬̻̦͕̰̪͊̂̽̾̋̒̈́̑̊̕̕͝ͅñ̶̨̡̧̡̛̖̬͕̺̤̘͖͍̫̗͈̟͔̓̍̑̑̎̑͗̌̋̌̇̕h̴̡̡̧̡̡̲̙͖̙̠͙̩̤̯͈͎̱͓̙͔͔̮̹̦̗͓͗̑̿̀̎́͗͌̏̕̕̚͜͜͜ͅ...",
		1.0
	)

# ─────────────────────────────────────────────
# WAVE EMISSION
# ─────────────────────────────────────────────

func _emit_wave(direction: Vector2, _bearing_deg: float) -> void:
	# Animate wave sprite in given direction
	wave_sprite.play("emit")
	# Tween wave areas in the direction
	for area in wave_areas:
		var a := area as Area2D
		var target_pos: Vector2 = direction * 800.0
		var tween := create_tween()
		tween.tween_property(a, "position", target_pos, 1.5)
		tween.tween_callback(func(): a.position = Vector2.ZERO)

func _on_wave_hit(body: Node2D, _area: Area2D) -> void:
	if body.is_in_group("mrak"):
		# Nhắm Mắt is the counter — if мрак is blind, wave passes through
		if not GameManager.is_blind:
			GameManager.add_necrosis(8.0)
			EventBus.memory_leak_speak.emit("S̷ó̵n̷g̸ ̵â̸m̴ ̸x̵u̵y̸ê̵n̷ ̸q̷u̴a̵ ̷b̸ạ̷n̸...", 0.9)

# ─────────────────────────────────────────────
# PHASE TRANSITIONS
# ─────────────────────────────────────────────

func _check_phase_transition() -> void:
	if current_phase == Phase.P1_SWEEP and puzzles_solved >= 2:
		_enter_phase(Phase.P2_RANDOM)
	elif current_phase == Phase.P2_RANDOM and puzzles_solved >= 4:
		_enter_phase(Phase.P3_CHAOS)

func _enter_phase(new_phase: Phase) -> void:
	current_phase = new_phase
	_phase_timer  = 0.0
	_wave_timer   = 0.0

	match new_phase:
		Phase.P1_SWEEP:
			EventBus.firewall_speak.emit("BUFFER OVERFLOW INITIATED. SONIC HAZARD: LEVEL 1.")
		Phase.P2_RANDOM:
			EventBus.firewall_speak.emit("PHASE 2 — PATTERN RANDOMIZED. PREDICTION: IMPOSSIBLE.")
			EventBus.memory_leak_speak.emit("...bạn nghĩ bạn có thể đoán trước tôi sao...", 0.7)
		Phase.P3_CHAOS:
			EventBus.firewall_speak.emit("PHASE 3 — CRITICAL. PUZZLE RESOLUTION REQUIRED.")
			EventBus.memory_leak_speak.emit("g̵i̴ả̶i̷ ̶n̵ó̵ ̴đ̸i̷.̴.̵.̶ N̴Ế̷U̷ ̴B̵Ạ̵N̸ ̵D̸Á̶M̷...", 1.0)

# ─────────────────────────────────────────────
# PUZZLE COMPLETION (WIN CONDITION)
# ─────────────────────────────────────────────

func _on_puzzle_solved(shard_id: String, _is_truth: bool) -> void:
	puzzles_solved += 1
	EventBus.firewall_speak.emit(
		"OVERWRITE PROGRESS: %d/%d" % [puzzles_solved, PUZZLES_TO_WIN]
	)

	if puzzles_solved >= PUZZLES_TO_WIN:
		_trigger_overwrite()

func _trigger_overwrite() -> void:
	# The ending — мрак overwrites Buffer Overflow with truth, not violence
	overwrite_vfx.emitting = true
	wave_sprite.play("dissolve")
	ambient_audio.stop()

	var ending := GameManager.calculate_ending()
	await get_tree().create_timer(3.5).timeout
	EventBus.ending_triggered.emit(ending)
