# Watcher.gd — Tier 2 Scavenger
# Stationary sentinel. Sweeps a laser-eye arc. Primary detection: VISUAL.
# Weakness: Stay out of its vision cone. Nhắm Mắt makes you invisible to it.

extends BaseEnemy

@export var sweep_angle: float   = 120.0   # degrees total arc
@export var sweep_speed: float   = 30.0    # degrees/second
@export var vision_cone: float   = 60.0    # half-angle of vision cone

var _sweep_dir: float = 1.0
var _current_angle: float = 0.0  # relative to base rotation

@onready var laser_ray: RayCast2D = $LaserRay
@onready var laser_sprite: Sprite2D = $LaserSprite

func _ready() -> void:
	vision_range      = 400.0   # Long range but narrow
	audio_sensitivity = 0.4     # Nearly deaf — compensated by visual dominance
	thermal_range     = 60.0
	patrol_speed      = 0.0     # Stationary
	hunt_speed        = 0.0     # Cannot chase — triggers alarm instead
	suspicion_timeout = 2.0
	super._ready()
	_set_state(State.IDLE)      # Watchers never patrol

func _physics_process(delta: float) -> void:
	_sweep_laser(delta)
	super._physics_process(delta)

func _sweep_laser(delta: float) -> void:
	_current_angle += sweep_speed * _sweep_dir * delta
	if abs(_current_angle) >= sweep_angle / 2.0:
		_sweep_dir *= -1.0
		_current_angle = clampf(_current_angle, -sweep_angle / 2.0, sweep_angle / 2.0)

	# Rotate laser ray to current sweep angle
	if laser_ray:
		laser_ray.rotation_degrees = _current_angle

func _has_line_of_sight(target: Node2D) -> bool:
	# Watcher uses cone check + raycast
	var to_target: Vector2 = target.global_position - global_position
	var angle_to: float = rad_to_deg(laser_ray.global_rotation) - rad_to_deg(to_target.angle())
	angle_to = fmod(angle_to + 360.0, 360.0)
	if angle_to > 180.0: angle_to -= 360.0

	if abs(angle_to) > vision_cone:
		return false  # Outside cone
	return super._has_line_of_sight(target)

func _on_state_entered(state: State) -> void:
	match state:
		State.SUSPICIOUS:
			if laser_sprite:
				laser_sprite.modulate = Color(1.0, 0.7, 0.0)  # Orange alert
		State.HUNT:
			if laser_sprite:
				laser_sprite.modulate = Color(1.0, 0.1, 0.1)  # Red alarm
			# Watcher can't chase — it screams and alerts nearby Crawlers
			EventBus.scavenger_alarm_triggered.emit(global_position)
		State.IDLE, State.PATROL:
			if laser_sprite:
				laser_sprite.modulate = Color(0.2, 0.8, 1.0)  # Cyan normal
