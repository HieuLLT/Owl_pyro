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
	_set_alert_visual(state)
	if not sprite:
		return
	match state:
		State.IDLE:       sprite.play("idle")
		State.PATROL:     sprite.play("crawl")
		State.SUSPICIOUS: sprite.play("alert")
		State.HUNT, State.FRENZY: sprite.play("chase")

## Drives scavenger_glitch.gdshader: 0 dormant ... 1 hunting.
func _set_alert_visual(state: State) -> void:
	var target: CanvasItem = sprite if sprite else get_node_or_null("PlaceholderSprite")
	if target == null or not (target.material is ShaderMaterial):
		return
	var value: float = 0.0
	match state:
		State.SUSPICIOUS: value = 0.35
		State.HUNT:       value = 0.8
		State.FRENZY:     value = 1.0
	(target.material as ShaderMaterial).set_shader_parameter("alert", value)
