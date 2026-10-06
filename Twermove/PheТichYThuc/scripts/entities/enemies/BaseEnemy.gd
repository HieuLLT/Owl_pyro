# BaseEnemy.gd
# Foundation for all Scavenger variants.
# Detection model: 3 axes — Visual (light), Audio (sound radius), Thermal (heat).
# State machine: IDLE → PATROL → SUSPICIOUS → HUNT → FRENZY

extends CharacterBody2D
class_name BaseEnemy

# ─────────────────────────────────────────────
# STATE MACHINE
# ─────────────────────────────────────────────

enum State { IDLE, PATROL, SUSPICIOUS, HUNT, FRENZY }
var current_state: State = State.IDLE
var _state_timer: float = 0.0
var _last_known_pos: Vector2 = Vector2.ZERO

# ─────────────────────────────────────────────
# DETECTION PARAMETERS (override in subclasses)
# ─────────────────────────────────────────────

@export var vision_range: float   = 300.0   # px
@export var audio_sensitivity: float = 1.0  # multiplier
@export var thermal_range: float  = 150.0   # px, only when мрак > 70°C
@export var patrol_speed: float   = 40.0
@export var hunt_speed: float     = 70.0
@export var suspicion_timeout: float = 4.0  # sec before de-escalate

# ─────────────────────────────────────────────
# NODE REFS
# ─────────────────────────────────────────────

# ── NODE REFS ──────────────────────────────────────
# sprite is optional — null until Aseprite art is assigned
var sprite: AnimatedSprite2D = null
@onready var nav_agent: NavigationAgent2D   = get_node_or_null("NavigationAgent2D")
@onready var vision_area: Area2D            = get_node_or_null("VisionArea")
@onready var sound_detect_area: Area2D      = get_node_or_null("SoundDetectArea")
@onready var state_label: Label             = get_node_or_null("DebugLabel")

# ─────────────────────────────────────────────
# PATROL WAYPOINTS
# ─────────────────────────────────────────────

@export var patrol_points: Array[NodePath] = []
var _patrol_nodes: Array[Node2D] = []
var _patrol_index: int = 0

# ─────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────

func _ready() -> void:
	add_to_group("enemies")
	for path in patrol_points:
		var n := get_node_or_null(path)
		if n:
			_patrol_nodes.append(n)
	# Detect sprite if present
	if has_node("AnimatedSprite2D"):
		sprite = $AnimatedSprite2D
	_set_state(State.IDLE if _patrol_nodes.is_empty() else State.PATROL)
	EventBus.mrak_sound_radius_changed.connect(_on_sound_radius_updated)

func _physics_process(delta: float) -> void:
	_state_timer += delta
	_run_state(delta)
	_check_detection()
	move_and_slide()
	_contact_damage(delta)
	_debug_label()

# ─────────────────────────────────────────────
# STATE MACHINE RUNNER
# ─────────────────────────────────────────────

func _run_state(delta: float) -> void:
	match current_state:
		State.IDLE:       _state_idle(delta)
		State.PATROL:     _state_patrol(delta)
		State.SUSPICIOUS: _state_suspicious(delta)
		State.HUNT:       _state_hunt(delta)
		State.FRENZY:     _state_frenzy(delta)

func _state_idle(_delta: float) -> void:
	velocity = Vector2.ZERO
	if not _patrol_nodes.is_empty() and _state_timer > 2.0:
		_set_state(State.PATROL)

func _state_patrol(_delta: float) -> void:
	if _patrol_nodes.is_empty():
		return
	var target: Vector2 = _patrol_nodes[_patrol_index].global_position
	_move_toward(target, patrol_speed, _delta)
	if global_position.distance_to(target) < 8.0:
		_patrol_index = (_patrol_index + 1) % _patrol_nodes.size()
		_set_state(State.IDLE)

func _state_suspicious(_delta: float) -> void:
	velocity = Vector2.ZERO
	if _state_timer >= suspicion_timeout:
		_set_state(State.PATROL if not _patrol_nodes.is_empty() else State.IDLE)
		EventBus.enemy_lost_target.emit(self)

func _state_hunt(_delta: float) -> void:
	if _last_known_pos == Vector2.ZERO:
		_set_state(State.SUSPICIOUS)
		return
	_move_toward(_last_known_pos, hunt_speed, _delta)
	if global_position.distance_to(_last_known_pos) < 12.0:
		_set_state(State.SUSPICIOUS)

func _state_frenzy(_delta: float) -> void:
	var mrak := _get_mrak()
	if mrak:
		_move_toward(mrak.global_position, hunt_speed * 1.4, _delta)
		_last_known_pos = mrak.global_position

# ─────────────────────────────────────────────
# DETECTION
# ─────────────────────────────────────────────

func _check_detection() -> void:
	var mrak := _get_mrak()
	if not mrak:
		return

	var dist: float = global_position.distance_to(mrak.global_position)
	var detected: bool = false

	# 1. VISUAL — only when мрак is NOT blind
	if not GameManager.is_blind and dist <= vision_range:
		if _has_line_of_sight(mrak):
			detected = true

	# 2. AUDIO — мрак's sound radius overlaps detection area
	if dist <= GameManager.current_sound_radius * audio_sensitivity:
		detected = true

	# 3. THERMAL — only when мрак's core is hot
	if dist <= thermal_range and GameManager.thermal >= 70.0:
		detected = true

	if detected:
		_last_known_pos = mrak.global_position
		_escalate_state()
	else:
		_de_escalate_state()

## Necrosis per second while a hunting enemy touches мрак.
const CONTACT_NECROSIS_PER_SEC: float = 6.0
const CONTACT_RANGE: float = 22.0

func _contact_damage(delta: float) -> void:
	if current_state != State.HUNT and current_state != State.FRENZY:
		return
	var mrak := _get_mrak()
	if mrak and global_position.distance_to(mrak.global_position) <= CONTACT_RANGE:
		GameManager.add_necrosis(CONTACT_NECROSIS_PER_SEC * delta)

func _has_line_of_sight(target: Node2D) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		target.global_position,
		0b00000010  # layer 2 = environment/walls
	)
	query.exclude = [self]
	var result := space.intersect_ray(query)
	# If ray hit nothing (clear path) or hit the target itself
	return result.is_empty() or result.get("collider") == target

func _escalate_state() -> void:
	match current_state:
		State.IDLE, State.PATROL:
			_set_state(State.SUSPICIOUS)
		State.SUSPICIOUS:
			_set_state(State.HUNT)
			EventBus.mrak_detected.emit(self)
			EventBus.scavenger_alarm_triggered.emit(global_position)
		State.HUNT:
			_set_state(State.FRENZY)

func _de_escalate_state() -> void:
	# Only de-escalate if in suspicious or lost hunt
	if current_state == State.FRENZY:
		_set_state(State.HUNT)  # Never de-escalate instantly from frenzy

# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────

func _set_state(new_state: State) -> void:
	current_state = new_state
	_state_timer = 0.0
	EventBus.enemy_state_changed.emit(self, State.keys()[new_state])
	_on_state_entered(new_state)

## Override in subclasses for custom state entry behavior
func _on_state_entered(_state: State) -> void:
	pass

func _move_toward(target: Vector2, speed: float, _delta: float) -> void:
	var dir: Vector2 = (target - global_position).normalized()
	velocity = dir * speed
	if sprite:
		if dir.x < 0:
			sprite.flip_h = true
		elif dir.x > 0:
			sprite.flip_h = false

func _get_mrak() -> Node2D:
	var nodes := get_tree().get_nodes_in_group("mrak")
	if nodes.is_empty():
		return null
	return nodes[0] as Node2D

func _on_sound_radius_updated(_radius: float) -> void:
	pass  # Detection is polled each frame; no action needed here

func _debug_label() -> void:
	if state_label:
		state_label.text = State.keys()[current_state]
