# FPTestLevel.gd — "Bãi Phế Liệu Ký Ức" (the Memory Junkyard), built entirely from code.
# Story (SRC/cot-truyen...): a dark, suffocating space of collapsed concrete, ragged edges eaten by
# The Erasure; a narrow corridor of ruined walls; and (Hồi 2) a sky of floating concrete islands
# over a bottomless static abyss. Per the brief, NOTHING here is a straight box:
#   * faceted ground made of tilting, faulted plates with ragged, cliff-skirted edges and rubble heaps
#   * leaning walls with gaps where they have collapsed and jagged tops
#   * snapped columns with rebar, broken slabs hanging from the ceiling on cables
#   * floating islands with jagged cone undersides, drifting slowly
# The route (ROUTE) winds, climbs over heaps and is verified walkable by tools/ checks.
# Run scenes/fp/FP_TestRoom.tscn (F6).
extends Node3D

const TEX_CONCRETE: String = "res://assets/textures/fp/concrete.png"
const TEX_RUST: String = "res://assets/textures/fp/rust.png"
const TEX_MESH: String = "res://assets/textures/fp/mesh.png"
const SURFACE_SHADER: String = "res://shaders/fp/brutalist_surface.gdshader"

const CELL: float = 0.6
const GX0: float = -9.0
const GZ0: float = -46.0
const NX: int = 30
const NZ: int = 82
const CLIFF_Z: float = -42.5

## The crawl route (x, z). Terrain, walls and the compass shard follow it.
const ROUTE: Array[Vector2] = [
	Vector2(0.0, 2.0), Vector2(0.0, -1.0), Vector2(-1.2, -7.0), Vector2(1.5, -13.0), Vector2(0.5, -19.0),
	Vector2(-2.0, -25.0), Vector2(-0.5, -31.0), Vector2(1.0, -37.0), Vector2(0.5, -41.0),
]
## Rubble heaps: x, z, height, sigma
const HEAPS: Array[Vector4] = [
	Vector4(-0.2, -10.2, 0.55, 1.1), Vector4(1.9, -17.0, 0.70, 1.2), Vector4(-3.0, -13.0, 0.90, 1.4),
	Vector4(3.2, -9.0, 0.60, 1.2), Vector4(-1.0, -22.5, 0.50, 1.0), Vector4(2.5, -28.0, 0.80, 1.3),
	Vector4(-3.2, -31.0, 0.70, 1.2), Vector4(-0.3, -35.0, 0.45, 1.0),
]
const POOL_CENTER: Vector2 = Vector2(0.8, -19.5)

var _noise := FastNoiseLite.new()
var _mat_concrete: ShaderMaterial
var _mat_ground: ShaderMaterial
var _mat_rust: ShaderMaterial
var _mat_mesh: ShaderMaterial
var _eaten: Array[ShaderMaterial] = []
var _player: FPController
var _psych: PsychText3D
var _thud_timer: Timer
var _voids: Array[ErasureVoid3D] = []
var _islands: Array = []          # [{node, base, phase}]
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_noise.seed = 66
	_noise.frequency = 1.0
	_rng.seed = 6606
	_build_materials()
	_build_environment()
	_build_ground()
	_build_walls()
	_build_columns()
	_build_rubble()
	_build_ceiling()
	_build_coolant_and_shard()
	_build_islands_and_abyss()
	_build_voids()
	_spawn_player()
	_build_audio()
	_script_the_walls()

func _process(delta: float) -> void:
	_t += delta
	for isl in _islands:
		var n: Node3D = isl["node"]
		var base: Vector3 = isl["base"]
		var ph: float = isl["phase"]
		n.position = base + Vector3(0.0, sin(_t * 0.28 + ph) * 0.3, 0.0)
		n.rotation.z = isl["tilt"] + sin(_t * 0.17 + ph) * 0.02
	# The Erasure can only eat with one centre at a time: let the nearest void do it
	if _player and not _voids.is_empty():
		var best: ErasureVoid3D = _voids[0]
		for v in _voids:
			if v.global_position.distance_to(_player.global_position) < best.global_position.distance_to(_player.global_position):
				best = v
		for v in _voids:
			v.affected.assign(_eaten if v == best else [])

# ── materials / environment ────────────────────────────────────────────────
func _surface(tex_path: String, tint: Color, uv_scale: float, rough: float, metal: float) -> ShaderMaterial:
	var m := FPUtil.make_shader_material(SURFACE_SHADER)
	var tex := FPUtil.load_texture(tex_path)
	if tex:
		m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("uv_scale", uv_scale)
	m.set_shader_parameter("roughness_val", rough)
	m.set_shader_parameter("metallic_val", metal)
	return m

func _build_materials() -> void:
	_mat_concrete = _surface(TEX_CONCRETE, Color(1.0, 0.98, 1.0), 0.40, 0.95, 0.0)
	_mat_ground = _surface(TEX_CONCRETE, Color(0.8, 0.78, 0.82), 0.45, 0.95, 0.0)
	_mat_rust = _surface(TEX_RUST, Color(1.1, 1.0, 0.95), 0.35, 0.6, 0.35)
	_mat_mesh = _surface(TEX_MESH, Color(1.3, 1.2, 1.1), 0.7, 0.5, 0.4)
	_eaten = [_mat_concrete, _mat_ground, _mat_rust, _mat_mesh]

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.07, 0.05, 0.08)
	env.ambient_light_energy = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.015, 0.025)
	env.fog_density = 0.03
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# A faint cold glow from the dead system itself: just enough to read the silhouettes of the
	# ruins and the floating islands against the black (the red neon still dominates).
	var cold := DirectionalLight3D.new()
	cold.light_color = Color(0.45, 0.52, 0.75)
	cold.light_energy = 0.28
	cold.shadow_enabled = false
	cold.rotation_degrees = Vector3(-35.0, 40.0, 0.0)
	add_child(cold)

# ── helpers ────────────────────────────────────────────────────────────────
func _hash2(a: int, b: int) -> float:
	return fposmod(sin(float(a) * 127.1 + float(b) * 311.7) * 43758.5453, 1.0)

## Distance from (x, z) to the route polyline.
func _route_dist(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best: float = INF
	for i in ROUTE.size() - 1:
		var a: Vector2 = ROUTE[i]
		var b: Vector2 = ROUTE[i + 1]
		var ab: Vector2 = b - a
		var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best

func _width_at(z: float) -> float:
	var w: float = 3.0 + 0.7 * _noise.get_noise_1d(z * 0.35)
	w += 1.8 * exp(-pow((z + 13.0) / 3.0, 2.0))     # heap plaza
	w += 1.4 * exp(-pow((z + 25.0) / 3.0, 2.0))     # shard clearing
	w += 1.2 * exp(-pow((z + 19.5) / 2.5, 2.0))     # pool basin
	return w

func _cell_solid(ix: int, iz: int) -> bool:
	var x: float = GX0 + (float(ix) + 0.5) * CELL
	var z: float = GZ0 + (float(iz) + 0.5) * CELL
	if z < CLIFF_Z:
		return false
	var ragged: float = _noise.get_noise_2d(x * 0.9, z * 0.9) * 1.1
	return _route_dist(x, z) < _width_at(z) + ragged

func _voro(x: float, z: float, s: float) -> Array:
	var px: float = x / s
	var pz: float = z / s
	var ix: int = floori(px)
	var iz: int = floori(pz)
	var d1: float = 9.0
	var d2: float = 9.0
	var id: float = 0.0
	var fx: float = 0.0
	var fz: float = 0.0
	for j in range(-1, 2):
		for i in range(-1, 2):
			var cx: int = ix + i
			var cz: int = iz + j
			var dx: float = float(cx) + _hash2(cx, cz) - px
			var dz: float = float(cz) + _hash2(cx + 31, cz + 17) - pz
			var d: float = sqrt(dx * dx + dz * dz)
			if d < d1:
				d2 = d1
				d1 = d
				id = _hash2(cx + 7, cz + 3)
				fx = dx
				fz = dz
			elif d < d2:
				d2 = d
	return [d1 * s, d2 * s, id, fx * s, fz * s]

## Ground height: tilting plates + fault grooves + rubble heaps + the pool basin.
func _ground_y(x: float, z: float) -> float:
	var v: Array = _voro(x, z, 3.4)
	var h: float = (float(v[2]) - 0.5) * 0.16
	h += (float(v[3]) * ((float(v[2]) - 0.5) * 0.05)) + (float(v[4]) * ((fposmod(float(v[2]) * 7.31, 1.0) - 0.5) * 0.05))
	var gap: float = float(v[1]) - float(v[0])
	if gap < 0.14:
		h -= 0.10 * (1.0 - gap / 0.14)               # a fault groove between plates
	h += _noise.get_noise_2d(x * 2.3, z * 2.3) * 0.015
	for hp in HEAPS:
		var d2: float = (x - hp.x) * (x - hp.x) + (z - hp.y) * (z - hp.y)
		h += hp.z * exp(-d2 / (2.0 * hp.w * hp.w))
	var pd: float = Vector2(x, z).distance_to(POOL_CENTER)
	h -= 0.18 * exp(-pow(pd / 1.6, 2.0))
	return h

func _add_mesh(mesh: Mesh, mat: Material, collide: bool, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, convex: bool = false) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees = rot_deg
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	holder.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_convex_shape() if convex else mesh.create_trimesh_shape()
		body.add_child(cs)
		holder.add_child(body)
	add_child(holder)
	return holder

# ── ground ─────────────────────────────────────────────────────────────────
func _build_ground() -> void:
	var hfn := func(ix: int, iz: int) -> float:
		return _ground_y(GX0 + float(ix) * CELL, GZ0 + float(iz) * CELL)
	var sfn := func(ix: int, iz: int) -> bool:
		return _cell_solid(ix, iz)
	var mesh: ArrayMesh = RuinGen.grid_mesh(hfn, sfn, GX0, GZ0, CELL, NX, NZ, 6606, 1.3)
	if mesh:
		_add_mesh(mesh, _mat_ground, true)

# ── walls ──────────────────────────────────────────────────────────────────
func _route_points() -> PackedVector3Array:
	var ctrl: Array = []
	for r in ROUTE:
		ctrl.append(Vector3(r.x, 0.0, r.y))
	return RuinGen.spline(ctrl, 80)

func _build_walls() -> void:
	var pts: PackedVector3Array = _route_points()
	for side in [-1, 1]:
		var path := PackedVector3Array()
		var heights := PackedFloat32Array()
		for i in pts.size():
			var a: Vector3 = pts[maxi(i - 1, 0)]
			var b: Vector3 = pts[mini(i + 1, pts.size() - 1)]
			var tan: Vector3 = (b - a)
			tan.y = 0.0
			tan = tan.normalized()
			var normal := Vector3(-tan.z, 0.0, tan.x) * float(side)
			var off: float = _width_at(pts[i].z) * 0.82 + _noise.get_noise_2d(float(i) * 0.6, float(side) * 9.0) * 0.5
			var p: Vector3 = pts[i] + normal * off
			p.y = _ground_y(p.x, p.z)
			path.append(p)
			var h: float = 1.1 + 2.1 * (0.5 + 0.5 * _noise.get_noise_2d(float(i) * 0.33, float(side) * 5.0 + 20.0))
			var collapse: float = _noise.get_noise_2d(float(i) * 0.21, float(side) * 13.0 + 50.0)
			if collapse > 0.30:
				h = 0.05                                         # collapsed: a gap in the wall
			elif pts[i].z > -2.0 and side == -1:
				h = maxf(h, 2.2)                                 # the start is more enclosed
			heights.append(h)
		var mesh: ArrayMesh = RuinGen.wall_mesh(path, heights, 0.5, 0.05 * float(side), 700 + side)
		if mesh:
			_add_mesh(mesh, _mat_rust if side == 1 else _mat_concrete, true)

# ── columns ────────────────────────────────────────────────────────────────
func _rebar(parent_pos: Vector3, count: int, seed_val: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.17, 0.1)
	mat.roughness = 0.85
	mat.metallic = 0.4
	for i in count:
		var p: Vector3 = parent_pos + Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25))
		var dir := Vector3(rng.randf_range(-0.4, 0.4), 1.0, rng.randf_range(-0.4, 0.4)).normalized()
		var path := PackedVector3Array([p])
		for s in 3:
			dir = (dir + Vector3(rng.randf_range(-0.35, 0.35), 0.0, rng.randf_range(-0.35, 0.35))).normalized()
			p += dir * rng.randf_range(0.18, 0.32)
			path.append(p)
		var m: ArrayMesh = RuinGen.tube_mesh(path, PackedFloat32Array([0.013]), 5, 0.1, seed_val + i, false, true)
		if m:
			_add_mesh(m, mat, false)

func _build_columns() -> void:
	var spots: Array[Vector2] = [Vector2(-2.4, -5.0), Vector2(2.6, -11.0), Vector2(-2.9, -17.0), Vector2(2.3, -23.0), Vector2(-3.1, -29.0), Vector2(2.7, -34.0)]
	var k: int = 0
	for s in spots:
		k += 1
		var h: float = _rng.randf_range(0.9, 2.9)
		var gy: float = _ground_y(s.x, s.y)
		var poly: PackedVector2Array = RuinGen.irregular_polygon(0.36, 0.3, 7, 0.22, 900 + k, 1)
		var mesh: ArrayMesh = RuinGen.extrude_polygon(poly, h, h + 0.5, 910 + k, 0.0, 0.22)
		if mesh:
			_add_mesh(mesh, _mat_concrete, true, Vector3(s.x, gy, s.y), Vector3(_rng.randf_range(-6, 6), _rng.randf_range(0, 360), _rng.randf_range(-6, 6)))
			_rebar(Vector3(s.x, gy + h, s.y), 4, 930 + k)

# ── rubble ─────────────────────────────────────────────────────────────────
func _build_rubble() -> void:
	var placed: int = 0
	var tries: int = 0
	while placed < 46 and tries < 400:
		tries += 1
		var x: float = _rng.randf_range(-6.5, 6.5)
		var z: float = _rng.randf_range(-40.0, 1.0)
		if not _cell_solid(floori((x - GX0) / CELL), floori((z - GZ0) / CELL)):
			continue
		var rd: float = _route_dist(x, z)
		if rd < 0.9:
			continue                                   # never block the crawl line
		var sz: float = _rng.randf_range(0.22, 0.85)
		var chunk: ArrayMesh = RuinGen.chunk_mesh(Vector3(sz, sz * _rng.randf_range(0.5, 1.0), sz * _rng.randf_range(0.6, 1.2)), 400 + placed)
		var big: bool = sz > 0.5
		_add_mesh(chunk, _mat_concrete if _rng.randf() < 0.75 else _mat_rust, big, Vector3(x, _ground_y(x, z) + 0.02, z), Vector3(_rng.randf_range(-25, 25), _rng.randf_range(0, 360), _rng.randf_range(-25, 25)), true)
		placed += 1

# ── ceiling: broken slabs on cables, tilted neon ───────────────────────────
func _build_ceiling() -> void:
	var cable_mat := StandardMaterial3D.new()
	cable_mat.albedo_color = Color(0.015, 0.015, 0.02)
	cable_mat.roughness = 0.9
	var slab_z: Array[float] = [-3.0, -8.5, -14.0, -19.5, -24.0, -29.5, -34.0, -38.5]
	var lit: int = 0
	for i in slab_z.size():
		var z: float = slab_z[i]
		var rp: Vector3 = _route_at_z(z)
		var cx: float = rp.x + _rng.randf_range(-1.2, 1.2)
		var y: float = _rng.randf_range(3.1, 4.2)
		var poly: PackedVector2Array = RuinGen.irregular_polygon(_rng.randf_range(1.5, 2.7), _rng.randf_range(1.4, 2.4), 10, 0.3, 1200 + i, 2)
		var mesh: ArrayMesh = RuinGen.extrude_polygon(poly, 0.0, 0.35, 1220 + i, 0.0, 0.06)
		if mesh == null:
			continue
		var tilt := Vector3(_rng.randf_range(-12, 12), _rng.randf_range(0, 360), _rng.randf_range(-14, 14))
		_add_mesh(mesh, _mat_concrete, false, Vector3(cx, y, z), tilt)
		# Hanging rebar tufts and cables at the slab rim
		for c in 3:
			var ang: float = _rng.randf_range(0.0, TAU)
			var rim := Vector3(cx + cos(ang) * 1.3, y - 0.2, z + sin(ang) * 1.1)
			var drop: float = _rng.randf_range(0.8, 2.2)
			var sway := Vector3(_rng.randf_range(-0.3, 0.3), 0.0, _rng.randf_range(-0.3, 0.3))
			var ctrl: Array = [rim, rim + Vector3(0.0, -drop * 0.45, 0.0) + sway * 0.4, rim + Vector3(0.0, -drop * 0.8, 0.0) + sway, rim + Vector3(0.0, -drop, 0.0) + sway * 1.2]
			var cm: ArrayMesh = RuinGen.tube_mesh(RuinGen.spline(ctrl, 10), PackedFloat32Array([0.018, 0.016, 0.014]), 6, 0.2, 1300 + i * 7 + c, false, true)
			if cm:
				_add_mesh(cm, cable_mat, false)
		# Some slabs carry a failing red neon, hung crooked
		if i % 2 == 0 and lit < 4:
			lit += 1
			_neon(Vector3(cx, y - 0.45, z), _rng.randf_range(-25, 25))

func _route_at_z(z: float) -> Vector3:
	for i in ROUTE.size() - 1:
		var a: Vector2 = ROUTE[i]
		var b: Vector2 = ROUTE[i + 1]
		if (z <= a.y and z >= b.y):
			var t: float = (z - a.y) / (b.y - a.y)
			return Vector3(lerpf(a.x, b.x, t), 0.0, z)
	return Vector3(ROUTE[0].x, 0.0, z)

func _neon(pos: Vector3, roll_deg: float) -> void:
	var tube_mat := StandardMaterial3D.new()
	tube_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tube_mat.albedo_color = Color(1.0, 0.1, 0.06)
	tube_mat.emission_enabled = true
	tube_mat.emission = Color(1.0, 0.08, 0.05)
	tube_mat.emission_energy_multiplier = 3.0
	var path := PackedVector3Array([Vector3(-0.6, 0.0, 0.0), Vector3(0.0, 0.02, 0.0), Vector3(0.6, -0.03, 0.0)])
	var tube: ArrayMesh = RuinGen.tube_mesh(path, PackedFloat32Array([0.035]), 6, 0.0, 5, true, true)
	var holder := _add_mesh(tube, tube_mat, false, pos, Vector3(0.0, _rng.randf_range(0, 180), roll_deg))
	var l := FlickerLight.new()
	l.position = Vector3(0.0, -0.3, 0.0)
	l.light_color = Color(1.0, 0.1, 0.06)
	l.omni_range = 9.0
	l.base_energy = 2.4
	l.dropout_chance = _rng.randf_range(0.15, 0.5)
	l.tube_material = tube_mat
	holder.add_child(l)

# ── coolant pool and the compass target ────────────────────────────────────
func _build_coolant_and_shard() -> void:
	var py: float = _ground_y(POOL_CENTER.x, POOL_CENTER.y) + 0.13
	var poly: PackedVector2Array = RuinGen.irregular_polygon(2.2, 1.7, 13, 0.25, 77, 2)
	var mesh: ArrayMesh = RuinGen.extrude_polygon(poly, 0.0, 0.01, 78, 0.0, 0.0)
	var sh := Shader.new()
	sh.code = _COOLANT_SHADER
	var cm := ShaderMaterial.new()
	cm.shader = sh
	if mesh:
		_add_mesh(mesh, cm, false, Vector3(POOL_CENTER.x, py, POOL_CENTER.y))
	var pl := OmniLight3D.new()
	pl.position = Vector3(POOL_CENTER.x, py + 0.5, POOL_CENTER.y)
	pl.light_color = Color(0.1, 0.9, 0.8)
	pl.light_energy = 0.7
	pl.omni_range = 4.5
	add_child(pl)

	# Memory shard: the compass target (clearing at z -25)
	var shard := Node3D.new()
	shard.name = "MemoryShard"
	var sx: float = -2.3
	var sz: float = -25.0
	shard.position = Vector3(sx, _ground_y(sx, sz) + 0.45, sz)
	shard.add_to_group("memory_shard")
	var prism := PrismMesh.new()
	prism.size = Vector3(0.18, 0.32, 0.18)
	var sm := MeshInstance3D.new()
	sm.mesh = prism
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(0.3, 1.0, 0.9)
	sm.material_override = smat
	shard.add_child(sm)
	var sl := OmniLight3D.new()
	sl.light_color = Color(0.2, 1.0, 0.9)
	sl.light_energy = 0.8
	sl.omni_range = 3.0
	shard.add_child(sl)
	add_child(shard)

# ── Hồi 2 vista: floating islands over the static abyss ────────────────────
func _build_islands_and_abyss() -> void:
	var specs: Array[Vector4] = [
		Vector4(-9.0, 0.5, -50.0, 3.4), Vector4(8.0, 2.5, -53.0, 4.2), Vector4(0.0, -1.5, -59.0, 5.5),
		Vector4(-14.0, 5.0, -63.0, 3.0), Vector4(13.0, -2.0, -67.0, 4.8), Vector4(3.0, 6.0, -73.0, 3.6),
		Vector4(-7.0, -4.0, -78.0, 5.0), Vector4(-16.0, -1.0, -44.0, 2.6), Vector4(15.0, 1.0, -45.0, 2.9),
	]
	var k: int = 0
	for sp in specs:
		k += 1
		var poly: PackedVector2Array = RuinGen.irregular_polygon(sp.w, sp.w * _rng.randf_range(0.7, 1.1), 11, 0.28, 2000 + k, 2)
		var mesh: ArrayMesh = RuinGen.extrude_polygon(poly, 0.0, 0.6, 2100 + k, _rng.randf_range(2.5, 5.5), 0.1)
		if mesh == null:
			continue
		var tilt: float = deg_to_rad(_rng.randf_range(-14, 14))
		var holder := _add_mesh(mesh, _mat_concrete, false, Vector3(sp.x, sp.y, sp.z), Vector3(_rng.randf_range(-5, 5), _rng.randf_range(0, 360), rad_to_deg(tilt)))
		_islands.append({"node": holder, "base": holder.position, "phase": _rng.randf_range(0.0, TAU), "tilt": tilt})
		# A snapped column or two on the bigger islands
		if sp.w > 3.5:
			var cp: PackedVector2Array = RuinGen.irregular_polygon(0.4, 0.35, 7, 0.2, 2200 + k, 1)
			var ch: float = _rng.randf_range(0.8, 2.0)
			var cm: ArrayMesh = RuinGen.extrude_polygon(cp, ch, ch + 0.2, 2210 + k, 0.0, 0.2)
			if cm:
				var col := MeshInstance3D.new()
				col.mesh = cm
				col.material_override = _mat_concrete
				col.position = Vector3(_rng.randf_range(-sp.w * 0.4, sp.w * 0.4), 0.0, _rng.randf_range(-sp.w * 0.4, sp.w * 0.4))
				col.rotation_degrees = Vector3(_rng.randf_range(-8, 8), 0, _rng.randf_range(-8, 8))
				holder.add_child(col)

	# The abyss itself
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(500.0, 500.0)
	plane.mesh = pm
	plane.position = Vector3(0.0, -24.0, -40.0)
	plane.material_override = FPUtil.make_shader_material("res://shaders/fp/abyss_static.gdshader")
	add_child(plane)

# ── the Erasure ────────────────────────────────────────────────────────────
func _build_voids() -> void:
	var specs: Array[Vector4] = [
		Vector4(3.9, 1.3, -24.0, 1.2),     # hangs over the shard clearing
		Vector4(-4.6, 0.6, -9.5, 0.8),     # eats the left wall near the start
		Vector4(4.8, 0.8, -31.5, 1.0),
	]
	for sp in specs:
		var v := ErasureVoid3D.new()
		v.position = Vector3(sp.x, sp.y, sp.z)
		v.radius = sp.w
		add_child(v)
		_voids.append(v)

# ── player / UI / audio ────────────────────────────────────────────────────
func _spawn_player() -> void:
	var scene := load("res://scenes/fp/FP_Player.tscn") as PackedScene
	_player = scene.instantiate() as FPController
	_player.position = Vector3(0.0, _ground_y(0.0, -1.0) + 0.3, -1.0)
	add_child(_player)
	_psych = PsychText3D.new()
	add_child(_psych)
	_psych.setup(_player.camera)
	add_child(FPOverlay.new())

func _build_audio() -> void:
	var fan := AudioStreamPlayer.new()
	fan.stream = FPUtil.load_sound("res://assets/audio/fp/fan_hum.wav", true)
	fan.volume_db = -12.0
	fan.autoplay = true
	add_child(fan)
	_thud_timer = Timer.new()
	_thud_timer.one_shot = true
	_thud_timer.timeout.connect(_on_thud)
	add_child(_thud_timer)
	_thud_timer.start(randf_range(8.0, 16.0))

func _on_thud() -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = FPUtil.load_sound("res://assets/audio/fp/metal_thud.wav")
	p.position = Vector3(randf_range(-3.0, 3.0), 1.5, randf_range(-38.0, -2.0))
	p.unit_size = 6.0
	p.finished.connect(p.queue_free)
	add_child(p)
	if p.stream:
		p.play()
	_thud_timer.start(randf_range(9.0, 22.0))

# ── the world speaks ───────────────────────────────────────────────────────
func _script_the_walls() -> void:
	await get_tree().create_timer(2.5).timeout
	# Instructions: etched on a wall (white voice, tutorial)
	_psych.instruct("Kéo thân: W A S D. Giữ Space: nhắm mắt. La bàn: Q.")
	await get_tree().create_timer(5.0).timeout
	# White voice proper: short -> on your own arm; long -> on the ground
	EventBus.firewall_speak.emit("Bám theo ánh sáng xanh.")
	await get_tree().create_timer(4.0).timeout
	EventBus.firewall_speak.emit("Hãy tránh các khoảng đen. Chạm vào là bị xóa vĩnh viễn khỏi hệ thống.")
	await get_tree().create_timer(10.0).timeout
	EventBus.memory_leak_speak.emit("Nằm xuống đi. Bức tường này sắp sập rồi.", 0.8)

const _COOLANT_SHADER: String = """
shader_type spatial;
render_mode blend_mix, cull_back;
float h21(vec2 p){ p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vn(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
  return mix(mix(h21(i), h21(i+vec2(1,0)), f.x), mix(h21(i+vec2(0,1)), h21(i+vec2(1,1)), f.x), f.y); }
varying vec3 w_pos;
void vertex() { w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = w_pos.xz;
	float r = vn(uv * 3.0 + vec2(TIME * 0.15, -TIME * 0.1)) * 0.6 + vn(uv * 7.0 - TIME * 0.2) * 0.4;
	ALBEDO = vec3(0.02, 0.1, 0.1);
	EMISSION = vec3(0.05, 0.9, 0.8) * (0.25 + 0.6 * r);
	ROUGHNESS = 0.05;
	METALLIC = 0.7;
	ALPHA = 0.88;
}
"""
