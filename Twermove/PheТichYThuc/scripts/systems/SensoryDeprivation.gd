# SensoryDeprivation.gd
# Manages the Nhắm Mắt (Blink) system — мрак's most powerful stealth tool.
# When active: screen goes dark, heat core deactivates, heartbeat plays.
# Enemies cannot detect мрак visually or thermally, but AUDIO still works.

extends Node

@export var darkness_overlay_path: NodePath
@export var heartbeat_player_path: NodePath

@onready var darkness_overlay: ColorRect       = get_node_or_null(darkness_overlay_path)
@onready var heartbeat_player: AudioStreamPlayer = get_node_or_null(heartbeat_player_path)

var is_active: bool = false

# Heartbeat BPM range — faster when enemy is close
const BPM_CALM: float    = 60.0
const BPM_DANGER: float  = 140.0

var _current_bpm: float = BPM_CALM
var _beat_timer: float  = 0.0

func _ready() -> void:
	EventBus.mrak_blink_toggled.connect(_on_blink)
	EventBus.mrak_detected.connect(_on_detected)
	EventBus.mrak_hidden.connect(_on_hidden)

func _process(delta: float) -> void:
	if not is_active:
		return
	_update_heartbeat(delta)

# ─────────────────────────────────────────────
# BLINK TOGGLE
# ─────────────────────────────────────────────

func _on_blink(blind: bool) -> void:
	is_active = blind
	if blind:
		_enter_darkness()
	else:
		_exit_darkness()

func _enter_darkness() -> void:
	# Overlay: fade to near-black (leave tiny amount so text is visible)
	var tween := create_tween()
	tween.tween_property(darkness_overlay, "color:a", 0.96, 0.3)

	# Heartbeat starts
	if heartbeat_player and not heartbeat_player.playing:
		heartbeat_player.play()

	# Audio bus manipulation: mute SFX bus, keep Spatial bus active
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("SFX"), -80.0
	)

func _exit_darkness() -> void:
	var tween := create_tween()
	tween.tween_property(darkness_overlay, "color:a", 0.0, 0.2)

	# Restore SFX bus
	var sfx_tween := create_tween()
	sfx_tween.tween_method(
		func(db: float): AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), db),
		-80.0, 0.0, 0.4
	)

	# Fade out heartbeat
	if heartbeat_player:
		var stop_tween := create_tween()
		stop_tween.tween_property(heartbeat_player, "volume_db", -40.0, 0.5)
		stop_tween.tween_callback(heartbeat_player.stop)
		stop_tween.tween_callback(func(): heartbeat_player.volume_db = 0.0)

# ─────────────────────────────────────────────
# HEARTBEAT RATE (proximity-driven)
# ─────────────────────────────────────────────

func _update_heartbeat(delta: float) -> void:
	_beat_timer += delta
	var beat_interval: float = 60.0 / _current_bpm
	if _beat_timer >= beat_interval:
		_beat_timer = 0.0
		if heartbeat_player and is_active:
			heartbeat_player.pitch_scale = _current_bpm / BPM_CALM

## Called by enemy AI when it gets close to мрак
func set_danger_proximity(normalized_proximity: float) -> void:
	# 0.0 = far away, 1.0 = touching
	_current_bpm = lerpf(BPM_CALM, BPM_DANGER, normalized_proximity)

func _on_detected(_enemy: Node) -> void:
	_current_bpm = BPM_DANGER

func _on_hidden() -> void:
	_current_bpm = BPM_CALM
