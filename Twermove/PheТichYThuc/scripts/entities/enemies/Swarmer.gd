# Swarmer.gd — Tier 3 Scavenger
# Moves in packs of 3-5. Primary detection: THERMAL.
# Weakness: Cool the Heat Core (stay still) before entering Swarmer territory.

extends BaseEnemy

## Pack identity — Swarmers coordinate via shared alarm
@export var pack_id: String = "pack_default"

func _ready() -> void:
	vision_range      = 250.0
	audio_sensitivity = 0.8
	thermal_range     = 220.0   # Very wide thermal range
	patrol_speed      = 50.0
	hunt_speed        = 90.0    # Faster than Crawlers
	suspicion_timeout = 2.5
	super._ready()
	# Listen for pack alarms
	EventBus.scavenger_alarm_triggered.connect(_on_pack_alarm)

func _check_detection() -> void:
	# Swarmers prioritize thermal above all
	var mrak := _get_mrak()
	if not mrak:
		return
	var dist: float = global_position.distance_to(mrak.global_position)

	# Thermal check first — even through walls (heat signature)
	if dist <= thermal_range and GameManager.thermal >= 55.0:  # Lower threshold
		_last_known_pos = mrak.global_position
		_escalate_state()
		return

	super._check_detection()

func _on_pack_alarm(alarm_pos: Vector2) -> void:
	# If alarm is within pack coordination range, join the hunt
	if global_position.distance_to(alarm_pos) <= 400.0:
		if current_state == State.IDLE or current_state == State.PATROL:
			_last_known_pos = alarm_pos
			_set_state(State.HUNT)

func _on_state_entered(state: State) -> void:
	match state:
		State.IDLE:       sprite.play("idle")
		State.PATROL:     sprite.play("swarm_patrol")
		State.SUSPICIOUS: sprite.play("alert")
		State.HUNT, State.FRENZY: sprite.play("swarm_chase")
