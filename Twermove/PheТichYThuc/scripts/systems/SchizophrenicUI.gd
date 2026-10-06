# SchizophrenicUI.gd
# The UI IS a character. It fights itself. It lies.
# FIREWALL (White) and MEMORY LEAK (Red) compete for screen real estate.
# No health bars. No minimaps. The game world IS the interface.

extends CanvasLayer

# ─────────────────────────────────────────────
# NODE REFS
# ─────────────────────────────────────────────

@onready var firewall_log: RichTextLabel   = $FirewallLayer/FirewallLog
@onready var leak_container: Node2D        = $MemoryLeakLayer
@onready var vignette_overlay: ColorRect   = $VignetteOverlay
@onready var crt_overlay: ColorRect        = $CRTOverlay
@onready var glitch_overlay: ColorRect     = $GlitchOverlay
@onready var chaos_shake_timer: Timer      = $ChaosShakeTimer

# ─────────────────────────────────────────────
# FONTS (set via @export or loaded in _ready)
# ─────────────────────────────────────────────

@export var mono_font: Font       # FIREWALL — cold monospace
@export var glitch_font: Font     # MEMORY LEAK — broken serif

# ─────────────────────────────────────────────
# STATE
# ─────────────────────────────────────────────

var chaos_level: float = 0.0       # 0.0 calm → 1.0 full chaos
var _firewall_lines: Array[String] = []
const MAX_FIREWALL_LINES: int = 8
const LEAK_TEXT_LIFETIME: float = 4.5

# ─────────────────────────────────────────────
# GLITCH SHADER MATERIAL (shared)
# ─────────────────────────────────────────────

var _glitch_mat: ShaderMaterial
var _vignette_mat: ShaderMaterial

# ─────────────────────────────────────────────
# INIT
# ─────────────────────────────────────────────

func _ready() -> void:
	# Connect signals
	EventBus.firewall_speak.connect(_on_firewall_speak)
	EventBus.memory_leak_speak.connect(_on_leak_speak)
	EventBus.ui_chaos_level_changed.connect(_on_chaos_changed)
	EventBus.mrak_blink_toggled.connect(_on_blink)

	# Setup shader materials
	if glitch_overlay.material is ShaderMaterial:
		_glitch_mat = glitch_overlay.material as ShaderMaterial
	if vignette_overlay.material is ShaderMaterial:
		_vignette_mat = vignette_overlay.material as ShaderMaterial

	chaos_shake_timer.timeout.connect(_chaos_shake_tick)

	# Initial FIREWALL boot message
	await get_tree().process_frame
	_on_firewall_speak("SYSTEM BOOT SEQUENCE INITIATED")
	_on_firewall_speak("мрак — NECROSIS: %.1f%% — STATUS: OPERATIONAL" % GameManager.necrosis)

# ─────────────────────────────────────────────
# FIREWALL (WHITE VOICE)
# ─────────────────────────────────────────────

func _on_firewall_speak(msg: String) -> void:
	_firewall_lines.append("FIREWALL > " + msg)
	if _firewall_lines.size() > MAX_FIREWALL_LINES:
		_firewall_lines.pop_front()
	_rebuild_firewall_display()

func _rebuild_firewall_display() -> void:
	var text: String = ""
	for i in range(_firewall_lines.size()):
		# Older lines fade
		var alpha_hex: String = "%02X" % int(remap(i, 0, _firewall_lines.size() - 1, 80, 220))
		# At chaos > 0.7, some FIREWALL characters get corrupted by MEMORY LEAK
		var line: String = _firewall_lines[i]
		if chaos_level > 0.7 and i < 2:
			line = _corrupt_text(line, 0.15)
		text += "[color=#C8C8D4" + alpha_hex + "]" + line + "[/color]\n"
	firewall_log.text = text  # RichTextLabel with bbcode

# ─────────────────────────────────────────────
# MEMORY LEAK (RED VOICE)
# ─────────────────────────────────────────────

func _on_leak_speak(msg: String, intensity: float) -> void:
	var label := _create_leak_label(msg, intensity)
	leak_container.add_child(label)
	# Auto-destroy
	var timer := get_tree().create_timer(LEAK_TEXT_LIFETIME * (1.0 + intensity * 0.5))
	timer.timeout.connect(label.queue_free)

func _create_leak_label(text: String, intensity: float) -> Label:
	var label := Label.new()
	label.text = text
	if glitch_font:
		label.add_theme_font_override("font", glitch_font)

	# Color: deep red, slightly transparent
	var r: float = 0.75 + intensity * 0.2
	label.add_theme_color_override("font_color", Color(r, 0.05, 0.05, 0.85))
	label.add_theme_font_size_override("font_size", int(lerp(14, 22, intensity)))

	# Random floating position — avoiding dead center
	label.position = Vector2(
		randf_range(40.0, 1200.0),
		randf_range(40.0, 650.0)
	)

	# Float upward and fade out
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - randf_range(30.0, 80.0),
		LEAK_TEXT_LIFETIME)
	tween.tween_property(label, "modulate:a", 0.0, LEAK_TEXT_LIFETIME * 0.7).set_delay(
		LEAK_TEXT_LIFETIME * 0.3
	)

	# Glitch jitter for high-intensity messages
	if intensity > 0.6:
		var glitch_tween := label.create_tween()
		glitch_tween.set_loops(int(LEAK_TEXT_LIFETIME * 8))
		glitch_tween.tween_property(label, "position:x",
			label.position.x + randf_range(-4.0, 4.0), 0.05)

	return label

# ─────────────────────────────────────────────
# CHAOS SYSTEM
# ─────────────────────────────────────────────

func _on_chaos_changed(level: float) -> void:
	chaos_level = level

	# Vignette tightens with necrosis
	if _vignette_mat:
		_vignette_mat.set_shader_parameter("necrosis_level", level)

	# Glitch intensity scales with chaos
	if _glitch_mat:
		_glitch_mat.set_shader_parameter("glitch_intensity", level * 0.6)

	# Screen shake at high chaos
	if level > 0.7:
		if chaos_shake_timer.is_stopped():
			chaos_shake_timer.wait_time = 0.08
			chaos_shake_timer.start()
	else:
		chaos_shake_timer.stop()

	# Rebuild FIREWALL to apply corruption
	_rebuild_firewall_display()

var _shake_offset: Vector2 = Vector2.ZERO

func _chaos_shake_tick() -> void:
	var intensity: float = (chaos_level - 0.7) / 0.3 * 4.0
	_shake_offset = Vector2(
		randf_range(-intensity, intensity),
		randf_range(-intensity, intensity)
	)
	# Apply to canvas layer offset
	offset = _shake_offset

# ─────────────────────────────────────────────
# BLINK OVERLAY
# ─────────────────────────────────────────────

func _on_blink(is_blind: bool) -> void:
	# When blind: FIREWALL dims, MEMORY LEAK becomes more prominent
	var fw_target_alpha: float = 0.3 if is_blind else 1.0
	var tween := create_tween()
	tween.tween_property(firewall_log, "modulate:a", fw_target_alpha, 0.4)

# ─────────────────────────────────────────────
# TEXT CORRUPTION HELPER
# ─────────────────────────────────────────────

## Randomly corrupts a percentage of characters in text
func _corrupt_text(text: String, corruption_rate: float) -> String:
	const CORRUPTION_CHARS: String = "̸̵̴̷̶̡̢̨̧̛͠͡"
	var result: String = ""
	for c in text:
		if randf() < corruption_rate:
			result += CORRUPTION_CHARS[randi() % CORRUPTION_CHARS.length()]
		result += c
	return result
