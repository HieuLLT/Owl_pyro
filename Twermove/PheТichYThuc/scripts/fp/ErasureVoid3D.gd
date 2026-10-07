# ErasureVoid3D.gd — "Sự Xâm Thực" (The Erasure) as a 3D hazard.
# A shredded black sphere with TV static on its rim. While it exists it also EATS the
# surrounding level geometry: every ShaderMaterial in `affected` (brutalist_surface) has its
# erase_center / erase_radius driven here, so walls dissolve into black around it.
# Touching the core = 100% necrosis = death. Closing your eyes does not help.
class_name ErasureVoid3D
extends Node3D

@export var radius: float = 1.4
## How far beyond the core the surrounding geometry is eaten.
@export var eat_extra: float = 1.8
## Slow creep (metres per second) — set > 0 for a pursuing void.
@export var grow_per_second: float = 0.0
@export var warning_text: String = "Lỗi không gian cách 1.5 mét. Rút lại trước khi mã nguồn bị nuốt."
@export var erase_text: String = "Một bước thôi. Im lặng thật sự."

var affected: Array[ShaderMaterial] = []

var _t: float = 0.0
var _extra_growth: float = 0.0
var _warned: bool = false
var _killed: bool = false
var _mesh: MeshInstance3D

func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	_mesh = MeshInstance3D.new()
	_mesh.mesh = sphere
	_mesh.scale = Vector3.ONE * radius
	_mesh.material_override = FPUtil.make_shader_material("res://shaders/fp/erasure_void.gdshader")
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)

	var core := Area3D.new()
	core.collision_layer = 0
	core.collision_mask = 2
	var cs := CollisionShape3D.new()
	var ss := SphereShape3D.new()
	ss.radius = radius * 1.05
	cs.shape = ss
	core.add_child(cs)
	core.body_entered.connect(_on_core_entered)
	add_child(core)

	var warn := Area3D.new()
	warn.collision_layer = 0
	warn.collision_mask = 2
	var ws := CollisionShape3D.new()
	var wss := SphereShape3D.new()
	wss.radius = radius * 2.6
	ws.shape = wss
	warn.add_child(ws)
	warn.body_entered.connect(_on_warn_entered)
	add_child(warn)

	var crackle := AudioStreamPlayer3D.new()
	crackle.stream = FPUtil.load_sound("res://assets/audio/fp/erasure_crackle.wav", true)
	crackle.unit_size = 5.0
	crackle.max_distance = 40.0
	crackle.volume_db = -2.0
	crackle.autoplay = true
	add_child(crackle)

func _process(delta: float) -> void:
	_t += delta
	_extra_growth += grow_per_second * delta
	var pulse: float = 0.5 + 0.5 * sin(_t * 1.3)
	var eat: float = radius * 0.9 + _extra_growth + eat_extra * (0.55 + 0.45 * pulse)
	for m in affected:
		m.set_shader_parameter("erase_center", global_position)
		m.set_shader_parameter("erase_radius", eat)
	_mesh.scale = Vector3.ONE * (radius + _extra_growth * 0.5) * (1.0 + 0.04 * sin(_t * 9.0))

func _exit_tree() -> void:
	for m in affected:
		m.set_shader_parameter("erase_radius", 0.0)

func _on_warn_entered(body: Node3D) -> void:
	if _warned or not body.is_in_group("mrak"):
		return
	_warned = true
	EventBus.firewall_speak.emit(warning_text)

func _on_core_entered(body: Node3D) -> void:
	if _killed or not body.is_in_group("mrak"):
		return
	_killed = true
	EventBus.memory_leak_speak.emit(erase_text, 1.0)
	GameManager.add_necrosis(100.0)
