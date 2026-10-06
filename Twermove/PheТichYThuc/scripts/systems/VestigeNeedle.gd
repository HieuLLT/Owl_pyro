# VestigeNeedle.gd
# La Bàn Dối Trái — The Lying Compass.
# A compass needle driven through мрак's left hand.
# Points toward the nearest Memory Shard — but lies when corrupted.
# Hold [Q] to activate. Release to dismiss.

extends Node2D

# ─────────────────────────────────────────────
# NODE REFS
# ─────────────────────────────────────────────

# ── NODE REFS ──────────────────────────────────────
# All null-safe — VestigeNeedle works as pure logic even without child nodes
var compass_overlay: Control           = null
var needle_sprite: Sprite2D            = null
var compass_ring: Sprite2D             = null
var interference_label: Label          = null
var blood_particles: GPUParticles2D    = null

# ─────────────────────────────────────────────
# STATE
# ─────────────────────────────────────────────

var is_active: bool      = false
var nearest_shard: Node2D = null
var interference: float  = 0.0    # 0.0 clean → 1.0 fully corrupted

# When interference > 0.85 on floor 3+, needle may point completely wrong
const FULL_LIE_THRESHOLD: float  = 0.85
const FULL_LIE_FLOOR: int        = 3
var _lie_active: bool = false
var _lie_angle_offset: float = 0.0  # radians — when lying

# Needle noise
var _noise_angle: float = 0.0
var _noise_velocity: float = 0.0
const NOISE_SPRING: float = 8.0
const NOISE_DAMPING: float = 0.3

# ─────────────────────────────────────────────
# INIT
# ─────────────────────────────────────────────

func _ready() -> void:
	EventBus.vestige_needle_toggled.connect(_on_toggle)
	EventBus.memory_shard_collected.connect(_on_shard_collected)
	# Resolve child nodes if they exist
	compass_overlay   = get_node_or_null("CompassOverlay")
	if compass_overlay:
		needle_sprite     = compass_overlay.get_node_or_null("NeedleSprite")
		compass_ring      = compass_overlay.get_node_or_null("CompassRing")
		interference_label = compass_overlay.get_node_or_null("InterferenceLabel")
		blood_particles   = compass_overlay.get_node_or_null("BloodParticles")
		compass_overlay.visible = false

func _process(delta: float) -> void:
	if not is_active:
		return
	_find_nearest_shard()
	_calculate_interference()
	_update_needle(delta)
	_update_display()

# ─────────────────────────────────────────────
# ACTIVATION
# ─────────────────────────────────────────────

func _on_toggle(active: bool) -> void:
	is_active = active
	if compass_overlay:
		compass_overlay.visible = active
	if active:
		if blood_particles:
			blood_particles.emitting = true
		EventBus.vestige_needle_interference.emit(interference)
	else:
		if blood_particles:
			blood_particles.emitting = false

# ─────────────────────────────────────────────
# SHARD FINDING
# ─────────────────────────────────────────────

func _find_nearest_shard() -> void:
	var shards := get_tree().get_nodes_in_group("memory_shard")
	var min_dist: float = INF
	nearest_shard = null
	for s in shards:
		var d: float = global_position.distance_to((s as Node2D).global_position)
		if d < min_dist:
			min_dist = d
			nearest_shard = s as Node2D

func _on_shard_collected(_id: String) -> void:
	# Refresh after collection
	_find_nearest_shard()

# ─────────────────────────────────────────────
# INTERFERENCE CALCULATION
# ─────────────────────────────────────────────

func _calculate_interference() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	interference = 0.0
	for e in enemies:
		var d: float = global_position.distance_to((e as Node2D).global_position)
		if d < 350.0:
			interference += (350.0 - d) / 350.0

	interference = clampf(interference, 0.0, 1.0)
	EventBus.vestige_needle_interference.emit(interference)

	# Decide if needle enters full-lie mode
	var on_high_floor: bool = GameManager.current_floor >= FULL_LIE_FLOOR
	if on_high_floor and interference > FULL_LIE_THRESHOLD and not _lie_active:
		if randf() < 0.08:  # 8% chance per frame when conditions met
			_lie_active = true
			_lie_angle_offset = randf_range(PI * 0.7, PI * 1.3)  # near-opposite direction
	elif interference < 0.5:
		_lie_active = false

# ─────────────────────────────────────────────
# NEEDLE UPDATE
# ─────────────────────────────────────────────

func _update_needle(delta: float) -> void:
	if not nearest_shard:
		if needle_sprite:
			needle_sprite.rotation += delta * 1.2
		return

	var true_angle: float = global_position.angle_to_point(nearest_shard.global_position)

	var noise_target: float = randf_range(-PI, PI) * interference * 0.6
	_noise_velocity += (noise_target - _noise_angle) * NOISE_SPRING * delta
	_noise_velocity *= (1.0 - NOISE_DAMPING)
	_noise_angle += _noise_velocity * delta

	var final_angle: float
	if _lie_active:
		final_angle = true_angle + _lie_angle_offset + _noise_angle
	else:
		final_angle = true_angle + _noise_angle

	if needle_sprite:
		needle_sprite.rotation = lerp_angle(needle_sprite.rotation, final_angle, 8.0 * delta)

# ─────────────────────────────────────────────
# DISPLAY
# ─────────────────────────────────────────────

func _update_display() -> void:
	var ring_color: Color = Color(0.0, 1.0, 0.8).lerp(Color(0.8, 0.0, 0.0), interference)
	if compass_ring:
		compass_ring.modulate = ring_color
	if needle_sprite:
		needle_sprite.modulate = Color(1.0, 1.0 - interference * 0.9, 1.0 - interference * 0.9)
	if interference_label:
		var pct: int = int(interference * 100.0)
		if _lie_active:
			interference_label.text = "SIGNAL: [CORRUPTED]"
			interference_label.add_theme_color_override("font_color", Color(0.8, 0.0, 0.0))
		else:
			interference_label.text = "SIGNAL: %d%%" % (100 - pct)
			interference_label.add_theme_color_override("font_color",
				Color(0.78, 0.78, 0.83).lerp(Color(0.8, 0.0, 0.0), interference)
			)
