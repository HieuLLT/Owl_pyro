# Echo.gd — Special Scavenger (Invisible)
# Invisible to the player visually. Detection: AUDIO ONLY.
# Weakness: The ONLY counter is Nhắm Mắt (Sensory Deprivation).
# When мрак is blind, Echo cannot find them AT ALL — perfect counter.
# Echo can only be perceived through spatial audio (footstep sounds).

extends BaseEnemy

var _is_visible_to_player: bool = false

func _ready() -> void:
	vision_range      = 0.0     # Cannot see — it IS the unseen
	audio_sensitivity = 2.5     # Extremely sensitive to sound
	thermal_range     = 0.0     # No thermal detection
	patrol_speed      = 55.0
	hunt_speed        = 80.0
	suspicion_timeout = 6.0     # Longer search — very persistent
	super._ready()
	# Echo is always invisible except on special reveals
	modulate.a = 0.0

func _check_detection() -> void:
	# Echo ONLY detects by audio
	var mrak := _get_mrak()
	if not mrak:
		return
	var dist: float = global_position.distance_to(mrak.global_position)

	# Blind мрак = completely undetectable by Echo
	if GameManager.is_blind:
		_de_escalate_state()
		return

	if dist <= GameManager.current_sound_radius * audio_sensitivity:
		_last_known_pos = mrak.global_position
		_escalate_state()
	else:
		_de_escalate_state()

func _on_state_entered(state: State) -> void:
	match state:
		State.HUNT, State.FRENZY:
			# Brief "shimmer" reveal when Echo is hunting — unsettling
			var tween := create_tween()
			tween.tween_property(self, "modulate:a", 0.15, 0.2)
			tween.tween_property(self, "modulate:a", 0.0, 0.2)
		State.IDLE, State.PATROL, State.SUSPICIOUS:
			modulate.a = 0.0
