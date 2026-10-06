# Crawler.gd — Tier 1 Scavenger
# Crawls along walls and ceilings. Primary detection: AUDIO.
# Weakness: Nhắm Mắt + Khom người (blind + crouched) makes it completely unaware.

extends BaseEnemy

func _ready() -> void:
	vision_range      = 200.0
	audio_sensitivity = 1.2   # Slightly more sensitive to sound than base
	thermal_range     = 80.0  # Short thermal range
	patrol_speed      = 32.0
	hunt_speed        = 58.0
	suspicion_timeout = 3.5
	super._ready()

func _on_state_entered(state: State) -> void:
	if not sprite:
		return
	match state:
		State.IDLE:       sprite.play("idle")
		State.PATROL:     sprite.play("crawl")
		State.SUSPICIOUS: sprite.play("alert")
		State.HUNT, State.FRENZY: sprite.play("chase")
