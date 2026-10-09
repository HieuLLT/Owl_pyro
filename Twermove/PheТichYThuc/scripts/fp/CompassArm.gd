# CompassArm.gd — the two dragging arms of мрак in first person (child of the Camera3D).
# мрак has NO legs (docs/MRAK_FIRST_APPEARANCE.md): the long arms are the only body the
# player ever sees, planted on the floor ahead and pulling the torso along, one after the other.
#
#   LEFT arm  : the compass arm. Gray necrotic flesh, a sunken wound baring a tarnished bone,
#               a rusted compass crooked into the forearm with black metal ROOTS bursting out of
#               the skin (glinting blue, or red when it lies). Short white-voice lines can appear
#               on the skin itself.
#   RIGHT arm : plain dead flesh and claws.
#
# All geometry is generated (RuinGen.tube_mesh): lumpy tubes, nothing is a clean primitive
# except the compass dial. The needle points at the nearest "memory_shard" — but per the GDD the
# compass is wrong ~30% of the time and then points at the nearest "lair" (the Erasure), and it
# jitters with interference. Eyes closed = bio-light off (the arm goes dark).
class_name CompassArm
extends Node3D

const SHOULDER_L: Vector3 = Vector3(-0.30, -0.24, 0.12)
const SHOULDER_R: Vector3 = Vector3(0.32, -0.24, 0.12)
const PULL_DISTANCE: float = 0.30
const LIFT_HEIGHT: float = 0.09
const LIE_CHANCE: float = 0.3

## Heartbeat kick 0..1 (pushed by FPController).
var beat: float = 0.0

var _mat_l: ShaderMaterial
var _mat_r: ShaderMaterial
var _left: Node3D
var _right: Node3D
var _needle_pivot: Node3D
var _needle_mat: StandardMaterial3D
var _tip_mats: Array[StandardMaterial3D] = []
var _light: OmniLight3D
var _skin_label: Label3D
var _skin_tween: Tween

var _t: float = 0.0
var _active: bool = false
var _blind: bool = false
var _ext_interference: float = 0.0
var _needle_yaw: float = 0.0
var _lie_timer: float = 0.0
var _lying: bool = false

var _drag_phase: float = 0.0
var _drag_pulse: float = 0.0
var _moving_blend: float = 0.0
var _moving: bool = false

func _ready() -> void:
	name = "CompassArm"
	_mat_l = FPUtil.make_shader_material("res://shaders/fp/arm_compass.gdshader")
	_mat_r = FPUtil.make_shader_material("res://shaders/fp/arm_compass.gdshader")
	_mat_r.set_shader_parameter("flesh_color", Color(0.24, 0.25, 0.27))
	_mat_r.set_shader_parameter("glow", 0.0)

	_left = _build_arm(true)
	_left.position = SHOULDER_L
	add_child(_left)
	_right = _build_arm(false)
	_right.position = SHOULDER_R
	add_child(_right)

	EventBus.vestige_needle_toggled.connect(func(on: bool) -> void: _active = on)
	EventBus.vestige_needle_interference.connect(func(level: float) -> void: _ext_interference = clampf(level, 0.0, 1.0))
	EventBus.mrak_blink_toggled.connect(func(b: bool) -> void: _blind = b)

# ── geometry ────────────────────────────────────────────────────────────────
func _metal(tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	var tex := FPUtil.load_texture("res://assets/textures/fp/rust.png")
	if tex:
		m.albedo_texture = tex
		m.uv1_triplanar = true          # object-space triplanar: sticks to the arm as it moves
		m.uv1_scale = Vector3(3.0, 3.0, 3.0)
	m.metallic = 0.45
	m.roughness = 0.65
	return m

func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _build_arm(is_left: bool) -> Node3D:
	var arm := Node3D.new()
	var sgn: float = -1.0 if is_left else 1.0
	var seed_base: int = 660 if is_left else 770
	var mat: ShaderMaterial = _mat_l if is_left else _mat_r

	# Spine of the arm: shoulder -> elbow knob -> sunken forearm -> wrist -> palm (extends along -Z)
	var ctrl: Array = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(-sgn * 0.01, 0.025, -0.26),
		Vector3(-sgn * 0.03, 0.045, -0.50),    # elbow knob, raised
		Vector3(-sgn * 0.02, -0.07, -0.76),
		Vector3(0.0, -0.22, -0.96),
		Vector3(sgn * 0.01, -0.305, -1.06),    # palm planted on the floor (eye is 0.55 m up)
	]
	var pts: PackedVector3Array = RuinGen.spline(ctrl, 28)
	var n: int = pts.size()
	var radii := PackedFloat32Array()
	for i in n:
		var t: float = float(i) / float(n - 1)
		var r: float = lerpf(0.075, 0.034, t)
		r *= 1.0 + 0.35 * exp(-pow((t - 0.45) / 0.07, 2.0))     # elbow knob
		r *= 1.0 - 0.45 * exp(-pow((t - 0.66) / 0.08, 2.0))     # sunken wound
		radii.append(r)
	_mesh(arm, RuinGen.tube_mesh(pts, radii, 10, 0.16, seed_base, true, true), mat)

	# Exposed bone running through the wound and out past the wrist
	var bone_pts := PackedVector3Array()
	for i in range(int(n * 0.50), int(n * 0.93)):
		bone_pts.append(pts[i] + Vector3(0.0, 0.004, 0.0))
	var bone_r := PackedFloat32Array([0.013, 0.012, 0.011, 0.009])
	var bone_mat: StandardMaterial3D = _metal(Color(0.85, 0.75, 0.55))
	_mesh(arm, RuinGen.tube_mesh(bone_pts, bone_r, 6, 0.1, seed_base + 1, true, true), bone_mat)

	# Claws: long, uneven, scraping the floor
	var palm: Vector3 = pts[n - 1]
	var claw_mat: StandardMaterial3D = _metal(Color(0.6, 0.5, 0.38))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base + 2
	for f in 4:
		var x_off: float = (float(f) - 1.5) * 0.026
		var claw_len: float = rng.randf_range(0.09, 0.17)
		var curl: Array = [
			palm + Vector3(x_off * 0.4, 0.0, 0.0),
			palm + Vector3(x_off, -0.004, -claw_len * 0.5),
			palm + Vector3(x_off * 1.35 + rng.randf_range(-0.01, 0.01), -0.02, -claw_len),
		]
		var cp: PackedVector3Array = RuinGen.spline(curl, 6)
		_mesh(arm, RuinGen.tube_mesh(cp, PackedFloat32Array([0.012, 0.008, 0.005, 0.002]), 5, 0.1, seed_base + 10 + f, true, true), claw_mat)

	# Two rusty shackle bands biting into the forearm
	var band_mat: StandardMaterial3D = _metal(Color(0.5, 0.3, 0.2))
	for bi in 2:
		var idx: int = int(n * (0.30 + 0.12 * bi))
		var tor := TorusMesh.new()
		tor.inner_radius = radii[idx] * 0.95
		tor.outer_radius = radii[idx] * 1.12
		tor.rings = 10
		tor.ring_segments = 6
		var band := _mesh(arm, tor, band_mat, pts[idx])
		band.rotation_degrees = Vector3(90.0 + rng.randf_range(-8.0, 8.0), rng.randf_range(-10.0, 10.0), 0.0)

	if is_left:
		_build_compass(arm, pts, radii, seed_base)
	return arm

func _build_compass(arm: Node3D, pts: PackedVector3Array, radii: PackedFloat32Array, seed_base: int) -> void:
	var n: int = pts.size()
	var ci: int = int(n * 0.76)
	var base: Vector3 = pts[ci] + Vector3(0.0, radii[ci] * 0.8, 0.0)
	var housing := Node3D.new()
	housing.position = base
	housing.rotation_degrees = Vector3(7.0, 20.0, -10.0)   # jammed in crooked
	arm.add_child(housing)

	var metal: StandardMaterial3D = _metal(Color(0.7, 0.45, 0.32))
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.058
	cyl.bottom_radius = 0.066
	cyl.height = 0.034
	cyl.radial_segments = 11
	_mesh(housing, cyl, metal)

	var bez := TorusMesh.new()
	bez.inner_radius = 0.047
	bez.outer_radius = 0.064
	bez.rings = 12
	bez.ring_segments = 6
	_mesh(housing, bez, metal, Vector3(0.0, 0.017, 0.0))

	var dial := CylinderMesh.new()
	dial.top_radius = 0.049
	dial.bottom_radius = 0.049
	dial.height = 0.004
	dial.radial_segments = 14
	var dial_mat := StandardMaterial3D.new()
	dial_mat.albedo_color = Color(0.02, 0.05, 0.07)
	dial_mat.roughness = 0.4
	_mesh(housing, dial, dial_mat, Vector3(0.0, 0.016, 0.0))

	# Cracked glass: a flattened, barely-there dome
	var dome := SphereMesh.new()
	dome.radius = 0.05
	dome.height = 0.03
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.5, 0.7, 0.9, 0.16)
	glass.roughness = 0.05
	glass.metallic = 0.3
	_mesh(housing, dome, glass, Vector3(0.0, 0.022, 0.0))

	# Needle
	_needle_pivot = Node3D.new()
	_needle_pivot.position = Vector3(0.0, 0.022, 0.0)
	housing.add_child(_needle_pivot)
	_needle_mat = StandardMaterial3D.new()
	_needle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_needle_mat.albedo_color = Color(0.4, 0.8, 1.0)
	var nb := PrismMesh.new()
	nb.size = Vector3(0.012, 0.075, 0.003)
	var needle := _mesh(_needle_pivot, nb, _needle_mat, Vector3(0.0, 0.0, -0.03))
	needle.rotation_degrees = Vector3(-90.0, 0.0, 0.0)   # prism tip points forward (-Z), lies flat

	# Light under the skin
	_light = OmniLight3D.new()
	_light.position = base + Vector3(0.0, 0.07, 0.0)
	_light.omni_range = 1.8
	_light.light_energy = 0.5
	_light.light_color = Color(0.1, 0.55, 1.0)
	arm.add_child(_light)

	# Black metal roots bursting out of the arm and the compass rim (jagged random walks)
	var root_mat := StandardMaterial3D.new()
	root_mat.albedo_color = Color(0.015, 0.015, 0.02)
	root_mat.roughness = 0.9
	root_mat.metallic = 0.3
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base + 99
	for i in 9:
		var t: float = rng.randf_range(0.42, 0.92)
		var k: int = int(n * t)
		var p: Vector3 = pts[k] + Vector3(rng.randf_range(-0.02, 0.02), radii[k] * 0.7, rng.randf_range(-0.02, 0.02))
		var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.4, 1.0), rng.randf_range(-0.8, 0.5)).normalized()
		var path := PackedVector3Array([p])
		var rr := PackedFloat32Array([0.011])
		for s in 5:
			dir = (dir + Vector3(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.5, 0.6), rng.randf_range(-0.9, 0.9))).normalized()
			p += dir * rng.randf_range(0.04, 0.09)
			path.append(p)
			rr.append(maxf(0.0015, 0.011 * (1.0 - float(s + 1) / 6.0)))
		_mesh(arm, RuinGen.tube_mesh(path, rr, 5, 0.25, seed_base + 200 + i, false, true), root_mat)
		if i % 3 == 0:
			var tip_mat := StandardMaterial3D.new()
			tip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			tip_mat.albedo_color = Color(0.3, 0.7, 1.0)
			var bead := SphereMesh.new()
			bead.radius = 0.008
			bead.height = 0.016
			bead.radial_segments = 6
			bead.rings = 3
			_mesh(arm, bead, tip_mat, p)
			_tip_mats.append(tip_mat)

	# Skin label: white-voice lines written on the forearm
	_skin_label = Label3D.new()
	_skin_label.font_size = 48
	_skin_label.pixel_size = 0.0011
	_skin_label.outline_size = 8
	_skin_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	_skin_label.modulate = Color(0.72, 0.88, 1.0, 0.0)
	_skin_label.shaded = false
	_skin_label.width = 420.0
	_skin_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skin_label.position = pts[int(n * 0.30)] + Vector3(0.0, 0.085, 0.0)
	_skin_label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	arm.add_child(_skin_label)

# ── public API ──────────────────────────────────────────────────────────────
func set_drag(pulse: float, phase: float, moving: bool) -> void:
	_drag_pulse = pulse
	_drag_phase = phase
	_moving = moving

## Writes a short white-voice line onto the skin of the forearm.
func show_skin_text(text: String, seconds: float = 4.0) -> void:
	if _skin_label == null:
		return
	if _skin_tween and _skin_tween.is_valid():
		_skin_tween.kill()
	_skin_label.text = text
	_skin_tween = create_tween()
	_skin_tween.tween_property(_skin_label, "modulate:a", 0.95, 0.35)
	_skin_tween.tween_interval(seconds)
	_skin_tween.tween_property(_skin_label, "modulate:a", 0.0, 1.0)

# ── per-frame ───────────────────────────────────────────────────────────────
func _interference() -> float:
	return clampf(_ext_interference + GameManager.necrosis / 100.0 * 0.7, 0.0, 1.0)

func _arm_pose(arm: Node3D, shoulder: Vector3, u_in: float, amount: float, sway: float) -> void:
	# u in [0,1): [0,.5) = pull (planted hand drags the body forward), [.5,1) = recover (lifted, reaching)
	var u: float = fposmod(u_in, 1.0)
	var z_off: float = 0.0
	var lift: float = 0.0
	if u < 0.5:
		z_off = PULL_DISTANCE * (u / 0.5)
	else:
		var r: float = (u - 0.5) / 0.5
		z_off = PULL_DISTANCE * (1.0 - r)
		lift = LIFT_HEIGHT * sin(PI * r)
	arm.position = shoulder + Vector3(sway, lift * amount, z_off * amount * 0.8)
	arm.rotation_degrees = Vector3(lift * amount * 90.0, 0.0, 0.0)

func _process(delta: float) -> void:
	_t += delta
	var inter: float = _interference()
	_moving_blend = lerpf(_moving_blend, 1.0 if _moving else 0.0, clampf(delta * 5.0, 0.0, 1.0))
	var u: float = _drag_phase / TAU
	var breathe: float = sin(_t * 1.3) * 0.004
	_arm_pose(_left, SHOULDER_L, u, _moving_blend, breathe)
	_arm_pose(_right, SHOULDER_R, u + 0.5, _moving_blend, -breathe)

	if _needle_pivot == null:
		return

	# Which way does the needle point? 70% the nearest shard, 30% the nearest lair (a lie)
	_lie_timer -= delta
	if _lie_timer <= 0.0:
		_lie_timer = randf_range(4.0, 8.0)
		_lying = randf() < LIE_CHANCE
	var cam := get_parent() as Camera3D
	var target_node: Node3D = _nearest("lair" if _lying else "memory_shard")
	var target_yaw: float = _needle_yaw + delta * 0.8
	if cam and target_node:
		var local: Vector3 = cam.global_transform.affine_inverse() * target_node.global_position
		target_yaw = atan2(-local.x, -local.z)
	if _active and not _blind:
		target_yaw += sin(_t * 3.7) * 1.2 * inter + randf_range(-1.0, 1.0) * 0.5 * inter
		_needle_yaw = lerp_angle(_needle_yaw, target_yaw, clampf(delta * 6.0, 0.0, 1.0))
	elif not _blind:
		_needle_yaw = lerp_angle(_needle_yaw, target_yaw, clampf(delta * 1.0, 0.0, 1.0))
	_needle_pivot.rotation.y = _needle_yaw

	# Light + shader (dark when the eyes are closed: the bio-light is cut)
	var flick: float = 1.0
	if inter > 0.05:
		flick = 1.0 - inter * randf_range(0.0, 0.8) * (1.0 if randf() < 0.3 else 0.0)
	var lit: float = 0.0 if _blind else 1.0
	var glow: float = (1.3 if _active else 0.55) * flick * lit
	var lc: Color = Color(0.1, 0.55, 1.0).lerp(Color(1.0, 0.08, 0.05), inter)
	_light.light_color = lc
	_light.light_energy = ((0.9 if _active else 0.35) * flick + beat * 0.6) * lit
	_needle_mat.albedo_color = (lc.lightened(0.3) if not _blind else Color(0.02, 0.02, 0.03))
	for tm in _tip_mats:
		tm.albedo_color = lc.lightened(0.2) if not _blind else Color(0.01, 0.01, 0.015)
	_mat_l.set_shader_parameter("interference", inter)
	_mat_l.set_shader_parameter("glow", glow)
	_mat_l.set_shader_parameter("beat", beat * lit)

func _nearest(group: String) -> Node3D:
	var best: Node3D = null
	var best_d: float = INF
	for node in get_tree().get_nodes_in_group(group):
		if node is Node3D:
			var d: float = (node as Node3D).global_position.distance_squared_to(global_position)
			if d < best_d:
				best_d = d
				best = node as Node3D
	return best
