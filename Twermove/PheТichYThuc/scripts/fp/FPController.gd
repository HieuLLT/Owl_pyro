# FPController.gd — first-person controller for мрак, the LEGLESS crawler.
# See docs/MRAK_FIRST_APPEARANCE.md: there are no legs, so there are no footsteps.
# Movement is a series of heavy arm-pulls: speed surges on each pull and stalls between
# them (never smooth). The camera sits low, rocks with the drag and kicks on every beat of
# the mechanical heart (60 -> 110 BPM as necrosis rises).
#
#   Mouse         look            W/A/S/D     drag in that direction
#   Space (HOLD)  close eyes (Sensory Deprivation)  — pitch black, only sound remains
#   Q             Vestige Needle (compass arm)      Esc  release mouse
class_name FPController
extends CharacterBody3D

const MAX_SPEED: float = 2.2          # m/s at the peak of a pull
const DRAG_HZ: float = 0.5            # full arm cycles per second (2 pulls: left, right)
const MOUSE_SENS: float = 0.0022
const EYE_HEIGHT: float = 0.55        # metres: a crawler's eye level
const BASE_FOV: float = 78.0
const SOUND_STILL: float = 30.0       # same scale as the 2D build
const SOUND_MOVING: float = 190.0
const SOUND_BLIND: float = 45.0

var is_blind: bool = false

var _pitch: float = 0.0
var _drag_phase: float = 0.0
var _prev_sin: float = 0.0
var _pulse: float = 0.0
var _beat_clock: float = 0.0
var _dub_pending: float = -1.0
var _beat_kick: float = 0.0
var _last_radius: float = -1.0
var _needle_on: bool = false
var _dead: bool = false
var _moving_now: bool = false

var compass_arm: CompassArm
var _drag_player: AudioStreamPlayer3D
var _heart_player: AudioStreamPlayer

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

func _ready() -> void:
	FPUtil.ensure_actions()
	add_to_group("mrak")
	GameManager.game_started = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	head.position.y = EYE_HEIGHT

	compass_arm = CompassArm.new()
	camera.add_child(compass_arm)

	_drag_player = AudioStreamPlayer3D.new()
	_drag_player.stream = FPUtil.load_sound("res://assets/audio/fp/drag.wav")
	_drag_player.unit_size = 4.0
	add_child(_drag_player)

	_heart_player = AudioStreamPlayer.new()
	_heart_player.stream = FPUtil.load_sound("res://assets/audio/fp/heartbeat.wav", true)
	_heart_player.volume_db = -4.0
	add_child(_heart_player)

	EventBus.mrak_blink_toggled.connect(_on_blink_changed)
	EventBus.mrak_died.connect(_on_died)

func _input(event: InputEvent) -> void:
	if _dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		rotate_y(-m.relative.x * MOUSE_SENS)
		_pitch = clampf(_pitch - m.relative.y * MOUSE_SENS, deg_to_rad(-60.0), deg_to_rad(65.0))
		head.rotation.x = _pitch
	elif event.is_action_pressed("vestige_needle"):
		_needle_on = not _needle_on
		EventBus.vestige_needle_toggled.emit(_needle_on)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if _dead:
		return
	var nec: float = GameManager.necrosis / 100.0
	var in_dir: Vector2 = Input.get_vector("fp_left", "fp_right", "fp_forward", "fp_back")
	var moving: bool = in_dir.length() > 0.1
	_moving_now = moving

	var target_speed: float = 0.0
	if moving:
		# Heavy, uneven drag: surge on each pull, stall in between
		_drag_phase += delta * TAU * DRAG_HZ * (1.0 - 0.35 * nec)
		var s: float = sin(_drag_phase)
		_pulse = pow(absf(s), 1.4)
		target_speed = MAX_SPEED * (1.0 - 0.55 * nec) * _pulse
		if is_blind:
			target_speed *= 0.6
		if (_prev_sin <= 0.0 and s > 0.0) or (_prev_sin >= 0.0 and s < 0.0):
			_on_drag_pull()
		_prev_sin = s
	else:
		_pulse = move_toward(_pulse, 0.0, delta * 3.0)
		_prev_sin = 0.0

	var wish: Vector3 = global_transform.basis * Vector3(in_dir.x, 0.0, in_dir.y)
	wish.y = 0.0
	wish = wish.normalized()
	var hv := Vector2(velocity.x, velocity.z)
	var accel: float = 14.0 if moving else 9.0
	hv = hv.move_toward(Vector2(wish.x, wish.z) * target_speed, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.y
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= 9.8 * delta
	move_and_slide()

	_update_sound_radius(moving)
	if global_position.y < -6.0:
		# Fell into the abyss of The Erasure
		EventBus.memory_leak_speak.emit("Không có đáy. Chỉ có tiếng nhiễu.", 1.0)
		GameManager.add_necrosis(100.0)

func _process(delta: float) -> void:
	if _dead:
		return
	_update_blind_input()
	_update_heartbeat(delta)
	# Camera: lurch with the drag, rock side to side, kick on the heartbeat
	head.position.y = EYE_HEIGHT - 0.05 * _pulse - 0.015 * _beat_kick
	head.position.x = sin(_drag_phase) * 0.02 * _pulse
	head.rotation.z = sin(_drag_phase) * 0.03 * _pulse + randf_range(-1.0, 1.0) * 0.003 * _beat_kick
	camera.fov = BASE_FOV + 2.0 * _beat_kick
	if compass_arm:
		compass_arm.beat = _beat_kick
		compass_arm.set_drag(_pulse, _drag_phase, _moving_now)

func _update_heartbeat(delta: float) -> void:
	var nec: float = GameManager.necrosis / 100.0
	var period: float = 60.0 / lerpf(60.0, 110.0, nec)
	_beat_clock += delta
	if _beat_clock >= period:
		_beat_clock -= period
		_beat_kick = maxf(_beat_kick, 1.0)
		_dub_pending = 0.22
	if _dub_pending >= 0.0:
		_dub_pending -= delta
		if _dub_pending < 0.0:
			_beat_kick = maxf(_beat_kick, 0.6)
	_beat_kick *= exp(-delta * 9.0)

func _on_drag_pull() -> void:
	if _drag_player and _drag_player.stream:
		_drag_player.volume_db = -26.0 if is_blind else -4.0
		_drag_player.pitch_scale = randf_range(0.9, 1.1)
		_drag_player.play()
	# Enemies hear the drag (the signal is 2D-shaped: x, z)
	EventBus.mrak_collision_sound.emit(Vector2(global_position.x, global_position.z), 0.3 if is_blind else 1.0)

func _update_sound_radius(moving: bool) -> void:
	var r: float = SOUND_MOVING if moving else SOUND_STILL
	if is_blind:
		r = SOUND_BLIND
	if not is_equal_approx(r, _last_radius):
		_last_radius = r
		GameManager.set_sound_radius(r)

## Story: "giữ phím Spacebar" — the eyes stay closed only while Space is HELD.
func _update_blind_input() -> void:
	var held: bool = Input.is_action_pressed("blink")
	if held and not is_blind:
		if GameManager.pin < 5.0:
			if Input.is_action_just_pressed("blink"):
				EventBus.firewall_speak.emit("WARNING — INSUFFICIENT POWER FOR SENSORY DEPRIVATION.")
			return
		GameManager.is_blind = true
		EventBus.mrak_blink_toggled.emit(true)
	elif not held and is_blind:
		GameManager.is_blind = false
		EventBus.mrak_blink_toggled.emit(false)

func _on_blink_changed(blind: bool) -> void:
	is_blind = blind
	if _heart_player and _heart_player.stream:
		if blind:
			_heart_player.play()
		else:
			_heart_player.stop()

func _on_died() -> void:
	_dead = true
	velocity = Vector3.ZERO
	if _heart_player:
		_heart_player.stop()
