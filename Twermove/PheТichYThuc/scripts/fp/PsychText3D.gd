# PsychText3D.gd — the WHITE voice (Firewall, pale blue-white) written INTO the world.
# Story (SRC/cot-truyen-day-du-phe-tich-y-thuc.md): white text is projected "trên da thịt
# hoặc mặt đất" (on flesh or on the ground) and guides the way; the GDD calls it "chữ nhạt
# màu, hướng dẫn đường đi". So:
#   firewall_speak   short line (<= SKIN_MAX chars) -> written on мрак's own forearm
#                    otherwise                      -> laid flat on the GROUND ahead
#   instruct()       tutorial / hint lines          -> etched on the nearest WALL (by its normal)
# The RED voice is NOT here: it lives in screen space (FPOverlay) because it must block the view.
# A fixed Label3D pool is reused (no allocations, tweens killed on release). Zero-g scenes can set
# `floating_only` so lines hang in mid-air instead.
class_name PsychText3D
extends Node3D

const POOL_SIZE: int = 8
const MAX_DISTANCE: float = 8.0
const MIN_DISTANCE: float = 1.1
const SKIN_MAX: int = 38
const WHITE_COLOR: Color = Color(0.72, 0.88, 1.0, 1.0)   # pale blue-white

## Zero-gravity / open-void mode: always float instead of sticking to surfaces.
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
		l.outline_modulate = Color(0.0, 0.02, 0.05, 0.9)
		l.shaded = false
		l.double_sided = false
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = 760.0
		l.set_meta("t0", 0.0)
		add_child(l)
		_pool.append(l)
	EventBus.firewall_speak.connect(_on_firewall)

func _on_firewall(msg: String) -> void:
	if GameManager.is_blind:
		return                                   # nothing is visible with the eyes closed
	var arm := _camera.get_node_or_null("CompassArm") as CompassArm
	if arm and msg.length() <= SKIN_MAX:
		arm.show_skin_text(msg)
	else:
		show_ground(msg)

## Lay a line flat on the ground ahead of мрак (readable from the crawl).
func show_ground(msg: String) -> void:
	_place(msg, true)

## Etch a tutorial/instruction line on a wall in view.
func instruct(msg: String) -> void:
	_place(msg, false)

func _place(msg: String, ground: bool) -> void:
	if _camera == null or msg.is_empty():
		return
	var label := _acquire()
	label.text = msg
	label.set_meta("t0", Time.get_ticks_msec() / 1000.0)
	label.modulate = Color(WHITE_COLOR.r, WHITE_COLOR.g, WHITE_COLOR.b, 0.0)

	var placed: bool = false
	var dist: float = 3.0
	if not floating_only:
		var hit: Dictionary = _find_ground() if ground else _find_wall()
		if not hit.is_empty():
			var n: Vector3 = hit["normal"]
			var p: Vector3 = hit["position"]
			dist = _camera.global_position.distance_to(p)
			var up := Vector3.UP
			if absf(n.dot(Vector3.UP)) > 0.9:
				var f: Vector3 = -_camera.global_transform.basis.z
				up = Vector3(f.x, 0.0, f.z).normalized()   # text reads away from the viewer
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

	label.pixel_size = 0.0024 * clampf(dist / 3.0, 0.7, 1.8)
	label.visible = true

	var hold: float = 5.0 + msg.length() * 0.05
	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 0.92, 0.45)
	tw.tween_interval(hold)
	tw.tween_property(label, "modulate:a", 0.0, 1.2)
	tw.tween_callback(_release.bind(label))
	label.set_meta("tween", tw)

func _cast(dir: Vector3) -> Dictionary:
	var origin: Vector3 = _camera.global_position
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * MAX_DISTANCE, 1)
	return get_world_3d().direct_space_state.intersect_ray(q)

## A spot on the floor 1.2-4 m ahead (ray dipped 18-40 degrees below the view axis).
func _find_ground() -> Dictionary:
	var basis: Basis = _camera.global_transform.basis
	var fallback: Dictionary = {}
	for attempt in 12:
		var yaw: float = randf_range(-0.45, 0.45)
		var pitch: float = -deg_to_rad(randf_range(18.0, 40.0))
		var dir: Vector3 = (-basis.z).rotated(basis.y, yaw).rotated(basis.x, pitch).normalized()
		var hit: Dictionary = _cast(dir)
		if hit.is_empty() or (hit["normal"] as Vector3).y < 0.6:
			continue
		if fallback.is_empty():
			fallback = hit
		if _is_clear(hit["position"]):
			return hit
	return fallback

## A wall in view (floors/ceilings skipped: text there reads upside-down).
func _find_wall() -> Dictionary:
	var basis: Basis = _camera.global_transform.basis
	var fallback: Dictionary = {}
	for attempt in 14:
		var yaw: float = randf_range(-0.7, 0.7)
		var pitch: float = randf_range(-0.2, 0.45)
		var dir: Vector3 = (-basis.z).rotated(basis.y, yaw).rotated(basis.x, pitch).normalized()
		var hit: Dictionary = _cast(dir)
		if hit.is_empty():
			continue
		var d: float = _camera.global_position.distance_to(hit["position"])
		var nrm: Vector3 = hit["normal"]
		if d < MIN_DISTANCE or nrm.dot(-dir) <= 0.4 or absf(nrm.y) > 0.7:
			continue
		if fallback.is_empty():
			fallback = hit
		if _is_clear(hit["position"]):
			return hit
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
