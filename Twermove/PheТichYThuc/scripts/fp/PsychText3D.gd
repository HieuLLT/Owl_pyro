# PsychText3D.gd — diegetic psychological UI in 3D space.
# White voice (Firewall) and Red voice (Memory Leak) lines are physically placed in the
# world: a ray is cast from the camera and the text is laid flat ON the wall it hits,
# oriented by the surface normal (etched into the concrete). If nothing solid is in view
# (or `floating_only` is set — zero-gravity scenes) it hangs in mid-air as a billboard.
#
# A fixed pool of Label3D nodes is reused (no allocations at runtime, tweens are killed on
# release). Closing the eyes (Sensory Deprivation) silences and clears the Red voice.
class_name PsychText3D
extends Node3D

enum Voice { WHITE, RED }

const POOL_SIZE: int = 10
const MAX_DISTANCE: float = 8.0
const MIN_DISTANCE: float = 1.2
const WHITE_COLOR: Color = Color(0.86, 0.94, 1.0, 1.0)
const RED_COLOR: Color = Color(1.0, 0.08, 0.06, 1.0)

## Zero-gravity / open-void mode: always float instead of sticking to walls.
@export var floating_only: bool = false

var _camera: Camera3D
var _pool: Array[Label3D] = []

func setup(camera: Camera3D) -> void:
	_camera = camera
	for i in POOL_SIZE:
		var l := Label3D.new()
		l.visible = false
		l.font_size = 64
		l.outline_size = 10
		l.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
		l.shaded = false
		l.double_sided = false
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = 760.0
		l.set_meta("t0", 0.0)
		l.set_meta("voice", Voice.WHITE)
		add_child(l)
		_pool.append(l)
	EventBus.firewall_speak.connect(func(msg: String) -> void: show_text(msg, Voice.WHITE, 0.5))
	EventBus.memory_leak_speak.connect(_on_leak)
	EventBus.mrak_blink_toggled.connect(_on_blink)

func _on_leak(msg: String, intensity: float) -> void:
	if GameManager.is_blind:
		return
	show_text(msg, Voice.RED, intensity)

func _on_blink(blind: bool) -> void:
	if blind:
		clear_red()

func clear_red() -> void:
	for l in _pool:
		if l.visible and l.get_meta("voice") == Voice.RED:
			_release(l)

func show_text(msg: String, voice: Voice, intensity: float = 0.6) -> void:
	if _camera == null or msg.is_empty():
		return
	var label := _acquire()
	label.text = msg
	label.set_meta("voice", voice)
	label.set_meta("t0", Time.get_ticks_msec() / 1000.0)
	var col: Color = WHITE_COLOR if voice == Voice.WHITE else RED_COLOR
	label.modulate = Color(col.r, col.g, col.b, 0.0)
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9) if voice == Voice.WHITE else Color(0.15, 0.0, 0.0, 0.95)

	var placed: bool = false
	var dist: float = 3.0
	if not floating_only:
		var hit := _find_wall()
		if not hit.is_empty():
			var n: Vector3 = hit["normal"]
			var p: Vector3 = hit["position"]
			dist = _camera.global_position.distance_to(p)
			var up := Vector3.UP
			if absf(n.dot(Vector3.UP)) > 0.9:
				var f: Vector3 = -_camera.global_transform.basis.z
				up = Vector3(f.x, 0.0, f.z).normalized()
			label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			label.global_position = p + n * 0.02
			# Label3D faces +Z; look_at aims -Z, so aim at the opposite side of the normal.
			label.look_at(label.global_position - n, up)
			placed = true
	if not placed:
		var fwd: Vector3 = -_camera.global_transform.basis.z
		var jitter := Vector3(randf_range(-1.2, 1.2), randf_range(-0.4, 0.8), randf_range(-0.3, 0.3))
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.global_position = _camera.global_position + fwd * 3.0 + jitter
		var drift := create_tween()
		drift.tween_property(label, "global_position:y", label.global_position.y + 0.25, 8.0)
		label.set_meta("drift", drift)

	label.pixel_size = 0.0024 * clampf(dist / 3.0, 0.7, 1.8) * (1.0 + 0.25 * intensity * float(voice == Voice.RED))
	label.visible = true

	var hold: float = 5.0 + msg.length() * 0.05
	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 0.92 if voice == Voice.WHITE else 1.0, 0.45)
	if voice == Voice.RED:
		# Red text stutters like a bad signal while it is held
		var steps: int = int(hold / 0.12)
		for i in steps:
			tw.tween_property(label, "modulate:a", randf_range(0.35, 1.0), 0.06)
			tw.tween_property(label, "modulate:a", 1.0, 0.06)
	else:
		tw.tween_interval(hold)
	tw.tween_property(label, "modulate:a", 0.0, 1.2)
	tw.tween_callback(_release.bind(label))
	label.set_meta("tween", tw)

func _find_wall() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var basis: Basis = _camera.global_transform.basis
	var origin: Vector3 = _camera.global_position
	var fallback: Dictionary = {}
	for attempt in 14:
		var yaw: float = randf_range(-0.7, 0.7)
		var pitch: float = randf_range(-0.35, 0.45)
		var dir: Vector3 = (-basis.z).rotated(basis.y, yaw).rotated(basis.x, pitch).normalized()
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * MAX_DISTANCE, 1)
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			continue
		var d: float = origin.distance_to(hit["position"])
		var facing: float = (hit["normal"] as Vector3).dot(-dir)
		# Walls only: text on floors/ceilings reads upside-down, so skip those.
		if d < MIN_DISTANCE or facing <= 0.4 or absf((hit["normal"] as Vector3).y) > 0.7:
			continue
		if fallback.is_empty():
			fallback = hit
		if _is_clear(hit["position"]):
			return hit          # prefer a spot that does not overlap existing text
	return fallback

## True when no visible label is within ~1.4 m of `p` (keeps lines from piling up).
func _is_clear(p: Vector3) -> bool:
	for l in _pool:
		if l.visible and l.global_position.distance_to(p) < 1.4:
			return false
	return true

func _acquire() -> Label3D:
	for l in _pool:
		if not l.visible:
			return l
	var oldest: Label3D = _pool[0]
	for l in _pool:
		if (l.get_meta("t0") as float) < (oldest.get_meta("t0") as float):
			oldest = l
	_release(oldest)
	return oldest

func _release(label: Label3D) -> void:
	for key in ["tween", "drift"]:
		if label.has_meta(key):
			var t = label.get_meta(key)
			if t is Tween and (t as Tween).is_valid():
				(t as Tween).kill()
			label.remove_meta(key)
	label.visible = false
