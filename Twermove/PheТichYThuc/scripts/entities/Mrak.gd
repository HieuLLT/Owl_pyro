# Mrak.gd
# Player controller for мрак — The Residual.
# мрак does not walk. мрак CRAWLS. This is the core movement philosophy.
# All input, movement, and state changes are handled here.
# Diegetic stats are handled by MrakBody.gd (child node).

extends CharacterBody2D

# ─────────────────────────────────────────────
# MOVEMENT CONSTANTS
# ─────────────────────────────────────────────

const CRAWL_SPEED: float        = 80.0   # px/s — deliberately slow
const CRAWL_SPEED_CROUCHED: float = 42.0
const CRAWL_SPEED_CLIMB: float  = 35.0
const GRAVITY: float            = 980.0

## Sound emission radii (px) — read by enemy SoundDetectionArea
const SOUND_RADIUS_NORMAL: float   = 190.0
const SOUND_RADIUS_CROUCHED: float = 75.0
const SOUND_RADIUS_STILL: float    = 30.0
## Eyes closed: footsteps nearly silent (GDD: footstepVolume 0.1)
const SOUND_RADIUS_BLIND: float = 45.0

## Heat generated per second of movement
const MOVE_HEAT_RATE: float = 1.5

# ─────────────────────────────────────────────
# NODE REFERENCES (set in scene)
# ─────────────────────────────────────────────

# All node refs are null-safe — game works with placeholder nodes
var sprite: AnimatedSprite2D         = null   # set in _ready if present
var placeholder_sprite: ColorRect    = null   # placeholder until art ready
@onready var heat_core: PointLight2D = get_node_or_null("HeatCore")
@onready var collision_shape: CollisionShape2D  = $CollisionShape2D
@onready var crouch_shape: CollisionShape2D     = get_node_or_null("CrouchShape")
@onready var sound_area: Area2D      = get_node_or_null("SoundEmissionArea")
@onready var sound_collision: CollisionShape2D  = get_node_or_null("SoundEmissionArea/SoundShape")
@onready var interact_area: Area2D   = get_node_or_null("InteractArea")
@onready var blink_overlay: ColorRect = get_node_or_null("UILayer/BlinkOverlay")
@onready var heartbeat_player: AudioStreamPlayer = get_node_or_null("HeartbeatPlayer")
@onready var footstep_player: AudioStreamPlayer  = get_node_or_null("FootstepPlayer")
@onready var mrak_body: Node2D = get_node_or_null("MrakBody")

# ─────────────────────────────────────────────
# STATE
# ─────────────────────────────────────────────

## External slowdown (Phantom proximity etc). 1.0 = normal, 0.0 = rooted.
var speed_multiplier: float = 1.0

var is_crouched: bool = false
var is_blind: bool    = false
var is_on_ladder: bool = false
var is_moving: bool   = false
var facing_right: bool = true

var _footstep_timer: float = 0.0
const FOOTSTEP_INTERVAL_NORMAL: float  = 0.55
const FOOTSTEP_INTERVAL_CROUCHED: float = 0.9

# ─────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────

func _ready() -> void:
	add_to_group("mrak")
	GameManager.game_started = true
	EventBus.mrak_blink_toggled.connect(_on_blink_changed)
	# Detect sprite type (art or placeholder)
	if has_node("AnimatedSprite2D"):
		sprite = $AnimatedSprite2D
	if has_node("PlaceholderSprite"):
		placeholder_sprite = $PlaceholderSprite
	# Initial state
	if crouch_shape:
		crouch_shape.disabled = true
	_update_sound_radius()
	# Drive the glitch body shader (mrak_glitch_body.gdshader)
	_body_material = _find_body_material()
	EventBus.mrak_necrosis_changed.connect(_on_necrosis_for_shader)
	EventBus.mrak_pin_changed.connect(_on_pin_for_shader)
	_on_necrosis_for_shader(GameManager.necrosis)
	_on_pin_for_shader(GameManager.pin)
	EventBus.firewall_speak.emit("мрак — SYSTEM BOOT. NECROSIS: %.1f%%" % GameManager.necrosis)

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_movement(delta)
	_update_heat(delta)
	_update_footstep_sounds(delta)
	_update_sound_radius()
	move_and_slide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("blink"):
		_toggle_sensory_deprivation()
	if event.is_action_pressed("crouch"):
		_toggle_crouch()
	if event.is_action_pressed("vestige_needle"):
		EventBus.vestige_needle_toggled.emit(true)
	if event.is_action_released("vestige_needle"):
		EventBus.vestige_needle_toggled.emit(false)
	if event.is_action_pressed("interact"):
		_try_interact()

# ─────────────────────────────────────────────
# MOVEMENT
# ─────────────────────────────────────────────

func _apply_gravity(delta: float) -> void:
	if not is_on_floor() and not is_on_ladder:
		velocity.y += GRAVITY * delta
	elif is_on_floor() and not is_on_ladder:
		velocity.y = 0.0

func _handle_movement(_delta: float) -> void:
	var dir: float = Input.get_axis("move_left", "move_right")

	if is_on_ladder:
		var vert: float = Input.get_axis("move_up", "crouch")
		velocity.y = vert * CRAWL_SPEED_CLIMB
		velocity.x = 0.0
		is_moving = vert != 0.0
	else:
		var speed: float = CRAWL_SPEED_CROUCHED if is_crouched else CRAWL_SPEED
		velocity.x = dir * speed * speed_multiplier
		is_moving = dir != 0.0

	# Sprite direction (sprite is null while the ColorRect placeholder is used)
	if dir > 0.0:
		if sprite:
			sprite.flip_h = false
		facing_right = true
	elif dir < 0.0:
		if sprite:
			sprite.flip_h = true
		facing_right = false

	# Animation
	_update_animation()

func _update_animation() -> void:
	if sprite:
		if not is_on_floor() and not is_on_ladder:
			sprite.play("fall")
		elif is_crouched:
			sprite.play("crawl_low" if is_moving else "crouch_idle")
		elif is_moving:
			sprite.play("crawl")
		else:
			sprite.play("idle")
	# Placeholder: tint cyan when still, green when moving
	if placeholder_sprite:
		placeholder_sprite.color = Color(0.0, 0.9, 0.7) if is_moving else Color(0.0, 1.0, 0.8)

# ─────────────────────────────────────────────
# SENSORY DEPRIVATION (NHẮM MẮT)
# ─────────────────────────────────────────────

func _toggle_sensory_deprivation() -> void:
	if not is_blind and GameManager.pin < 5.0:
		EventBus.firewall_speak.emit("WARNING — INSUFFICIENT POWER FOR SENSORY DEPRIVATION.")
		return
	is_blind = !is_blind
	GameManager.is_blind = is_blind
	EventBus.mrak_blink_toggled.emit(is_blind)

func _on_blink_changed(blind: bool) -> void:
	is_blind = blind
	if blink_overlay:
		var target_alpha: float = 0.96 if blind else 0.0
		var fade_time: float    = 0.3  if blind else 0.2
		var tween := create_tween()
		tween.tween_property(blink_overlay, "modulate:a", target_alpha, fade_time)
	if heat_core:
		heat_core.visible = !blind
	if heartbeat_player:
		if blind:
			heartbeat_player.play()
		else:
			var stop_tween := create_tween()
			stop_tween.tween_interval(0.5)
			stop_tween.tween_callback(heartbeat_player.stop)

# ─────────────────────────────────────────────
# GLITCH BODY SHADER BRIDGE
# ─────────────────────────────────────────────

var _body_material: ShaderMaterial = null

func _find_body_material() -> ShaderMaterial:
	var target: CanvasItem = sprite if sprite else placeholder_sprite
	if target and target.material is ShaderMaterial:
		return target.material as ShaderMaterial
	return null

func _on_necrosis_for_shader(value: float) -> void:
	if _body_material:
		_body_material.set_shader_parameter("necrosis", clampf(value / 100.0, 0.0, 1.0))
		# Heart beats faster the more decayed мрак is: 60 -> 110 BPM
		_body_material.set_shader_parameter("heartbeat_bpm", lerpf(60.0, 110.0, value / 100.0))

func _on_pin_for_shader(value: float) -> void:
	if _body_material:
		_body_material.set_shader_parameter("pin_level", clampf(value / 100.0, 0.0, 1.0))

# ─────────────────────────────────────────────
# CROUCH
# ─────────────────────────────────────────────

func _toggle_crouch() -> void:
	is_crouched = !is_crouched
	collision_shape.disabled = is_crouched
	if crouch_shape:
		crouch_shape.disabled = !is_crouched

# ─────────────────────────────────────────────
# INTERACTION
# ─────────────────────────────────────────────

func _try_interact() -> void:
	var overlaps: Array = interact_area.get_overlapping_areas()
	for area in overlaps:
		if area.is_in_group("memory_shard"):
			area.collect()
			return
		if area.is_in_group("interactable"):
			area.interact()
			return

# ─────────────────────────────────────────────
# HEAT MANAGEMENT
# ─────────────────────────────────────────────

func _update_heat(delta: float) -> void:
	if is_moving:
		GameManager.add_heat(MOVE_HEAT_RATE * delta)

# ─────────────────────────────────────────────
# SOUND RADIUS
# ─────────────────────────────────────────────

func _update_sound_radius() -> void:
	var radius: float
	if is_blind:
		radius = SOUND_RADIUS_BLIND
	elif not is_moving:
		radius = SOUND_RADIUS_STILL
	elif is_crouched:
		radius = SOUND_RADIUS_CROUCHED
	else:
		radius = SOUND_RADIUS_NORMAL
	if sound_collision and sound_collision.shape is CircleShape2D:
		(sound_collision.shape as CircleShape2D).radius = radius
	GameManager.set_sound_radius(radius)

# ─────────────────────────────────────────────
# FOOTSTEP SOUNDS
# ─────────────────────────────────────────────

func _update_footstep_sounds(delta: float) -> void:
	if not is_moving or not is_on_floor():
		_footstep_timer = 0.0
		return
	_footstep_timer += delta
	var interval: float = FOOTSTEP_INTERVAL_CROUCHED if is_crouched else FOOTSTEP_INTERVAL_NORMAL
	if _footstep_timer >= interval:
		_footstep_timer = 0.0
		if footstep_player:
			footstep_player.play()
		EventBus.mrak_collision_sound.emit(global_position, 0.3 if is_crouched else 1.0)

# ─────────────────────────────────────────────
# EXTERNAL EVENTS
# ─────────────────────────────────────────────

## Called by ladder Area2D on_body_entered
func enter_ladder() -> void:
	is_on_ladder = true
	velocity.y = 0.0

## Called by ladder Area2D on_body_exited
func exit_ladder() -> void:
	is_on_ladder = false
