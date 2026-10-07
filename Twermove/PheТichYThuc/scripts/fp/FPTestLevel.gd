# FPTestLevel.gd — brutalist test corridor, built entirely from code (boxes + shaders).
# Run scenes/fp/FP_TestRoom.tscn (F6). Everything here is primitives: concrete slabs, rusted
# plate walls, a wire-mesh divider, a coolant pool, flickering red neon, and an Erasure void
# that eats the far end of the corridor. A memory shard (compass target) sits in an alcove.
extends Node3D

const TEX_CONCRETE: String = "res://assets/textures/fp/concrete.png"
const TEX_RUST: String = "res://assets/textures/fp/rust.png"
const TEX_MESH: String = "res://assets/textures/fp/mesh.png"
const SURFACE_SHADER: String = "res://shaders/fp/brutalist_surface.gdshader"

var _mat_concrete: ShaderMaterial
var _mat_rust: ShaderMaterial
var _mat_mesh: ShaderMaterial
var _player: FPController
var _thud_timer: Timer

func _ready() -> void:
	_build_materials()
	_build_environment()
	_build_geometry()
	_build_lights()
	_build_coolant_and_shard()
	_build_void()
	_spawn_player()
	_build_audio()
	_script_the_walls()

# ── materials ───────────────────────────────────────────────────────────────
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
	_mat_rust = _surface(TEX_RUST, Color(1.1, 1.0, 0.95), 0.35, 0.6, 0.35)
	_mat_mesh = _surface(TEX_MESH, Color(1.3, 1.2, 1.1), 0.7, 0.5, 0.4)

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.07, 0.05, 0.08)
	env.ambient_light_energy = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.015, 0.025)
	env.fog_density = 0.045
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

# ── geometry ────────────────────────────────────────────────────────────────
func _box(pos: Vector3, size: Vector3, mat: Material, solid: bool = true) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = pos
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		body.add_child(cs)
		add_child(body)

func _build_geometry() -> void:
	var length: float = 36.0
	var cz: float = -length * 0.5
	_box(Vector3(0, -0.1, cz), Vector3(4.2, 0.2, length), _mat_concrete)            # floor
	_box(Vector3(0, 3.1, cz), Vector3(4.2, 0.2, length), _mat_concrete)             # ceiling
	_box(Vector3(-2.2, 1.5, cz), Vector3(0.2, 3.0, length), _mat_concrete)          # left wall
	_box(Vector3(2.2, 1.5, cz), Vector3(0.2, 3.0, length), _mat_rust)               # right wall: plates
	_box(Vector3(0, 1.5, -36.1), Vector3(4.6, 3.2, 0.2), _mat_concrete)             # far wall
	_box(Vector3(0, 1.5, 0.6), Vector3(4.6, 3.2, 0.2), _mat_concrete)               # back wall
	# Slabs and pillars to crawl around
	_box(Vector3(-1.2, 1.5, -8.0), Vector3(0.6, 3.0, 0.6), _mat_concrete)
	_box(Vector3(1.2, 1.5, -14.0), Vector3(0.6, 3.0, 0.6), _mat_concrete)
	_box(Vector3(-0.9, 1.5, -22.0), Vector3(0.6, 3.0, 0.6), _mat_concrete)
	_box(Vector3(-0.9, 0.25, -11.0), Vector3(2.2, 0.5, 0.3), _mat_rust)             # low barrier
	_box(Vector3(1.0, 1.2, -18.0), Vector3(2.0, 2.4, 0.08), _mat_mesh)              # wire-mesh divider
	_box(Vector3(-0.6, 2.6, -16.0), Vector3(2.4, 0.8, 0.5), _mat_concrete)          # hanging slab (ceiling chunk)

func _build_lights() -> void:
	for z in [-4.0, -12.0, -20.0, -28.0]:
		var tube_mat := StandardMaterial3D.new()
		tube_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tube_mat.albedo_color = Color(1.0, 0.1, 0.06)
		tube_mat.emission_enabled = true
		tube_mat.emission = Color(1.0, 0.08, 0.05)
		tube_mat.emission_energy_multiplier = 3.0
		var tube := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(0.12, 0.06, 1.3)
		tube.mesh = tb
		tube.material_override = tube_mat
		tube.position = Vector3(0, 2.95, z)
		add_child(tube)
		var l := FlickerLight.new()
		l.position = Vector3(0, 2.6, z)
		l.light_color = Color(1.0, 0.1, 0.06)
		l.omni_range = 9.0
		l.base_energy = 2.4
		l.dropout_chance = randf_range(0.15, 0.5)
		l.tube_material = tube_mat
		add_child(l)

func _build_coolant_and_shard() -> void:
	# Coolant pool: shallow cyan emissive plane
	var pool := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3.0, 6.0)
	pool.mesh = pm
	pool.position = Vector3(0.2, 0.012, -25.0)
	var sh := Shader.new()
	sh.code = _COOLANT_SHADER
	var cm := ShaderMaterial.new()
	cm.shader = sh
	pool.material_override = cm
	add_child(pool)
	var pl := OmniLight3D.new()
	pl.position = Vector3(0.2, 0.4, -25.0)
	pl.light_color = Color(0.1, 0.9, 0.8)
	pl.light_energy = 0.7
	pl.omni_range = 4.5
	add_child(pl)

	# Memory shard in a side alcove: the compass target
	var shard := Node3D.new()
	shard.name = "MemoryShard"
	shard.position = Vector3(-1.6, 0.5, -27.0)
	shard.add_to_group("memory_shard")
	var sm := MeshInstance3D.new()
	var sphere := PrismMesh.new()
	sphere.size = Vector3(0.18, 0.3, 0.18)
	sm.mesh = sphere
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

func _build_void() -> void:
	var v := ErasureVoid3D.new()
	v.position = Vector3(0.6, 1.3, -32.0)
	v.radius = 1.3
	v.affected.assign([_mat_concrete, _mat_rust, _mat_mesh])
	add_child(v)

# ── player / UI / audio ────────────────────────────────────────────────────
func _spawn_player() -> void:
	var scene := load("res://scenes/fp/FP_Player.tscn") as PackedScene
	_player = scene.instantiate() as FPController
	_player.position = Vector3(0, 0.05, -1.0)
	add_child(_player)
	var pt := PsychText3D.new()
	add_child(pt)
	pt.setup(_player.camera)
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
	p.position = Vector3(randf_range(-2.0, 2.0), 1.5, randf_range(-30.0, -2.0))
	p.unit_size = 6.0
	p.finished.connect(p.queue_free)
	add_child(p)
	if p.stream:
		p.play()
	_thud_timer.start(randf_range(9.0, 22.0))

# ── the walls speak ────────────────────────────────────────────────────────
func _script_the_walls() -> void:
	await get_tree().create_timer(2.5).timeout
	EventBus.firewall_speak.emit("Kéo thân: W A S D. Nhắm mắt: Space. La bàn: Q. Hãy tránh khoảng đen.")
	await get_tree().create_timer(14.0).timeout
	EventBus.memory_leak_speak.emit("Nằm xuống đi. Bức tường này sắp sập rồi.", 0.8)

const _COOLANT_SHADER: String = """
shader_type spatial;
render_mode blend_mix, cull_back;
float h21(vec2 p){ p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vn(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
  return mix(mix(h21(i), h21(i+vec2(1,0)), f.x), mix(h21(i+vec2(0,1)), h21(i+vec2(1,1)), f.x), f.y); }
void fragment() {
	float r = vn(UV * 14.0 + vec2(TIME * 0.15, -TIME * 0.1)) * 0.6 + vn(UV * 31.0 - TIME * 0.2) * 0.4;
	ALBEDO = vec3(0.02, 0.1, 0.1);
	EMISSION = vec3(0.05, 0.9, 0.8) * (0.25 + 0.6 * r);
	ROUGHNESS = 0.05;
	METALLIC = 0.7;
	ALPHA = 0.88;
}
"""
