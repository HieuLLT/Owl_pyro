# CompassArm.gd — the necrotic left arm in the lower-left of the first-person view.
# Built entirely in code from primitive meshes (no model files). The compass needle on the
# hand points at the nearest node in group "memory_shard" — but it LIES: the lie grows with
# `interference` (external, via EventBus) and with necrosis. Light is faint blue when honest,
# erratic red when deceiving. Child of the Camera3D.
class_name CompassArm
extends Node3D

const REST_POS: Vector3 = Vector3(-0.30, -0.30, -0.52)

## Heartbeat kick 0..1 (pushed by FPController).
var beat: float = 0.0

var _mat: ShaderMaterial
var _needle_pivot: Node3D
var _needle_mat: StandardMaterial3D
var _light: OmniLight3D
var _t: float = 0.0
var _active: bool = false
var _ext_interference: float = 0.0
var _drag_pulse: float = 0.0
var _drag_phase: float = 0.0
var _needle_yaw: float = 0.0

func _ready() -> void:
	position = REST_POS
	rotation_degrees = Vector3(8.0, -14.0, -6.0)

	_mat = FPUtil.make_shader_material("res://shaders/fp/arm_compass.gdshader")

	# Forearm: capsule lying along -Z
	var forearm := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.045
	cap.height = 0.55
	forearm.mesh = cap
	forearm.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	forearm.position = Vector3(0.0, 0.0, -0.1)
	forearm.material_override = _mat
	add_child(forearm)

	# Hand: flat slab that carries the compass
	var hand := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.11, 0.035, 0.12)
	hand.mesh = box
	hand.position = Vector3(0.0, 0.0, -0.42)
	hand.material_override = _mat
	add_child(hand)

	# Needle (pivots around the hand centre)
	_needle_pivot = Node3D.new()
	_needle_pivot.position = Vector3(0.0, 0.03, -0.42)
	add_child(_needle_pivot)
	var needle := MeshInstance3D.new()
	var nb := BoxMesh.new()
	nb.size = Vector3(0.008, 0.004, 0.10)
	needle.mesh = nb
	needle.position = Vector3(0.0, 0.0, -0.04)
	_needle_mat = StandardMaterial3D.new()
	_needle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_needle_mat.albedo_color = Color(0.4, 0.8, 1.0)
	needle.material_override = _needle_mat
	_needle_pivot.add_child(needle)

	# Compass roots bursting out of the forearm (black spikes)
	var root_mat := StandardMaterial3D.new()
	root_mat.albedo_color = Color(0.01, 0.01, 0.015)
	root_mat.roughness = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 6606
	for i in 6:
		var r := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.001
		cm.bottom_radius = 0.009
		cm.height = rng.randf_range(0.12, 0.24)
		r.mesh = cm
		r.material_override = root_mat
		r.position = Vector3(rng.randf_range(-0.03, 0.03), rng.randf_range(0.02, 0.05), rng.randf_range(-0.30, 0.05))
		r.rotation_degrees = Vector3(rng.randf_range(-40.0, 40.0), rng.randf_range(0.0, 360.0), rng.randf_range(-70.0, 70.0))
		add_child(r)

	# Light under the skin
	_light = OmniLight3D.new()
	_light.position = Vector3(0.0, 0.08, -0.40)
	_light.omni_range = 1.8
	_light.light_energy = 0.5
	_light.light_color = Color(0.1, 0.55, 1.0)
	add_child(_light)

	EventBus.vestige_needle_toggled.connect(func(on: bool) -> void: _active = on)
	EventBus.vestige_needle_interference.connect(func(level: float) -> void: _ext_interference = clampf(level, 0.0, 1.0))

func set_drag(pulse: float, phase: float) -> void:
	_drag_pulse = pulse
	_drag_phase = phase

func _interference() -> float:
	return clampf(_ext_interference + GameManager.necrosis / 100.0 * 0.7, 0.0, 1.0)

func _process(delta: float) -> void:
	_t += delta
	var inter: float = _interference()

	# Arm sways with the drag: dips and thrusts on every pull
	position = REST_POS + Vector3(
		sin(_t * 1.3) * 0.004 + sin(_drag_phase) * 0.02 * _drag_pulse,
		cos(_t * 1.7) * 0.004 - 0.03 * _drag_pulse,
		0.04 * _drag_pulse)

	# Needle: points at the nearest shard, then lies
	var target_yaw: float = _needle_yaw + delta * 0.8   # lazy spin when there is nothing to point at
	var cam := get_parent() as Camera3D
	var shard := _nearest_shard()
	if cam and shard:
		var local: Vector3 = cam.global_transform.affine_inverse() * shard.global_position
		target_yaw = atan2(-local.x, -local.z)
	if _active:
		target_yaw += sin(_t * 3.7) * 1.2 * inter + randf_range(-1.0, 1.0) * 0.5 * inter
	_needle_yaw = lerp_angle(_needle_yaw, target_yaw, clampf(delta * (6.0 if _active else 1.0), 0.0, 1.0))
	_needle_pivot.rotation.y = _needle_yaw

	# Light + shader
	var flick: float = 1.0
	if inter > 0.05:
		flick = 1.0 - inter * randf_range(0.0, 0.8) * (1.0 if randf() < 0.3 else 0.0)
	var glow: float = (1.3 if _active else 0.55) * flick
	var lc: Color = Color(0.1, 0.55, 1.0).lerp(Color(1.0, 0.08, 0.05), inter)
	_light.light_color = lc
	_light.light_energy = (0.9 if _active else 0.35) * flick + beat * 0.6
	_needle_mat.albedo_color = lc.lightened(0.3)
	_mat.set_shader_parameter("interference", inter)
	_mat.set_shader_parameter("glow", glow)
	_mat.set_shader_parameter("beat", beat)

func _nearest_shard() -> Node3D:
	var best: Node3D = null
	var best_d: float = INF
	for n in get_tree().get_nodes_in_group("memory_shard"):
		if n is Node3D:
			var d: float = (n as Node3D).global_position.distance_squared_to(global_position)
			if d < best_d:
				best_d = d
				best = n as Node3D
	return best
