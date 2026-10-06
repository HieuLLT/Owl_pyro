# MrakBody.gd
# Handles all DIEGETIC UI — stats displayed directly on мрак's body.
# No HUD bars. No fixed UI. Everything is projected onto the corpse and the ground.
# Attached as a child of Mrak scene.

extends Node2D

# ─────────────────────────────────────────────
# NODE REFS
# ─────────────────────────────────────────────

@onready var pin_glow: PointLight2D         = $PinGlow         # Chest bone glow
@onready var thermal_core: Sprite2D         = $ThermalCore     # Heat core color
@onready var necrosis_overlay: Sprite2D     = $NecrosisOverlay # Fracture projection
@onready var necrosis_label: Label          = $NecrosisLabel   # "70%" projected on ground
@onready var spine_shards: Node2D           = $SpineShards     # Gai xương sống (memory shards)
@onready var flicker_timer: Timer           = $FlickerTimer

# ─────────────────────────────────────────────
# PALETTE CONSTANTS
# ─────────────────────────────────────────────

# Thermal core color: cold cyan → warning yellow → critical red
const THERMAL_COLD:     Color = Color(0.0,  1.0,  0.8,  1.0)   # #00FFCC
const THERMAL_WARM:     Color = Color(1.0,  0.65, 0.0,  1.0)   # #FF6600 ish
const THERMAL_CRITICAL: Color = Color(0.9,  0.05, 0.05, 1.0)   # #E50D0D

# Pin glow colors
const PIN_NORMAL:   Color = Color(0.0, 1.0, 0.8,  0.7)
const PIN_WARNING:  Color = Color(1.0, 1.0, 0.0,  0.9)   # Yellow flash

var _flicker_state: bool = false

# ─────────────────────────────────────────────
# INIT
# ─────────────────────────────────────────────

func _ready() -> void:
	EventBus.mrak_pin_changed.connect(_on_pin_changed)
	EventBus.mrak_thermal_changed.connect(_on_thermal_changed)
	EventBus.mrak_necrosis_changed.connect(_on_necrosis_changed)
	EventBus.memory_shard_collected.connect(_on_shard_collected)

	flicker_timer.timeout.connect(_on_flicker_timeout)
	flicker_timer.wait_time = 0.18
	flicker_timer.autostart = false

	# Initial state
	_on_pin_changed(GameManager.pin)
	_on_thermal_changed(GameManager.thermal)
	_on_necrosis_changed(GameManager.necrosis)
	_refresh_spine_shards()

# ─────────────────────────────────────────────
# PIN (BATTERY) — Chest glow
# ─────────────────────────────────────────────

func _on_pin_changed(value: float) -> void:
	if value < 15.0:
		pin_glow.color = PIN_WARNING
		if not flicker_timer.is_stopped():
			return
		flicker_timer.start()
	elif value < 35.0:
		# Dim pulse
		pin_glow.color = PIN_NORMAL.lerp(PIN_WARNING, (35.0 - value) / 20.0)
		flicker_timer.stop()
		pin_glow.enabled = true
	else:
		pin_glow.color = PIN_NORMAL
		flicker_timer.stop()
		pin_glow.enabled = true

func _on_flicker_timeout() -> void:
	_flicker_state = !_flicker_state
	pin_glow.enabled = _flicker_state

# ─────────────────────────────────────────────
# THERMAL — Core color shift
# ─────────────────────────────────────────────

func _on_thermal_changed(temp: float) -> void:
	# Remap 20°C–100°C → 0.0–1.0
	var t: float = clampf((temp - 20.0) / 80.0, 0.0, 1.0)

	var core_color: Color
	if t < 0.5:
		core_color = THERMAL_COLD.lerp(THERMAL_WARM, t * 2.0)
	else:
		core_color = THERMAL_WARM.lerp(THERMAL_CRITICAL, (t - 0.5) * 2.0)

	thermal_core.modulate = core_color

	# Energy haze: PointLight2D energy correlates with heat
	# (requires a second PointLight on ThermalCore)

# ─────────────────────────────────────────────
# NECROSIS — Fracture projection
# ─────────────────────────────────────────────

func _on_necrosis_changed(value: float) -> void:
	# Show necrosis % projected onto ground near мрак's feet
	necrosis_label.text = "%.0f%%" % value
	necrosis_label.modulate.a = remap(value, 0.0, 100.0, 0.0, 1.0)

	# Overlay cracks: opacity and shader intensity scale with necrosis
	var shader_mat := necrosis_overlay.material as ShaderMaterial
	if shader_mat:
		shader_mat.set_shader_parameter("crack_intensity", value / 100.0)

	# Screen vignette
	var vignette_mat := get_node_or_null("/root/SchizophrenicUI/VignetteOverlay") as ColorRect
	if vignette_mat and vignette_mat.material is ShaderMaterial:
		(vignette_mat.material as ShaderMaterial).set_shader_parameter(
			"necrosis_level", value / 100.0
		)

# ─────────────────────────────────────────────
# SPINE SHARDS — Memory Shard counter on spine
# ─────────────────────────────────────────────

func _on_shard_collected(_shard_id: String) -> void:
	_refresh_spine_shards()

func _refresh_spine_shards() -> void:
	var count: int = GameManager.memory_shards_collected.size()
	# Show 'count' spine gai as visible
	for i in range(spine_shards.get_child_count()):
		spine_shards.get_child(i).visible = i < count
