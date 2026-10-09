# VoiceTextPool.gd
# Pooled RichTextLabels for the two inner voices (Diegetic UI).
#   WHITE = Firewall (cold, survival)   -> [wave]
#   RED   = Memory Leak (guilt, glitch) -> [shake] (+ [tornado] when intense)
#
# Why a pool: labels are created ONCE in setup() and recycled. Nothing is
# queue_free()'d at runtime, no SceneTreeTimers are created, and every Tween is
# killed before a label is reused -> no leaks even under a boss-fight text flood.
# If every label is busy, the OLDEST active one is recycled (never grows).
#
# Usage (from SchizophrenicUI):
#   _pool = VoiceTextPool.new()
#   add_child(_pool)
#   _pool.setup($MemoryLeakLayer, glitch_font)
#   _pool.show_text("...", VoiceTextPool.Voice.RED, Vector2(300, 200), 0.8)
#   _pool.show_world_text("...", VoiceTextPool.Voice.WHITE, phantom.global_position)

class_name VoiceTextPool
extends Node

enum Voice { WHITE, RED }

const POOL_SIZE: int = 12
const LABEL_WIDTH: float = 420.0

const WHITE_COLOR: String = "#c8d8e8"
const RED_COLOR: String = "#d01414"

const WHITE_LIFETIME: float = 3.6
const RED_LIFETIME: float = 3.0

var _host: Node = null
var _font: Font = null
var _free: Array[RichTextLabel] = []
var _active: Array[RichTextLabel] = []            # oldest first
var _tweens: Dictionary = {}                      # RichTextLabel -> Array[Tween]

# ─────────────────────────────────────────────
# SETUP
# ─────────────────────────────────────────────

func setup(host: Node, font: Font = null) -> void:
	_host = host
	_font = font
	for i in range(POOL_SIZE):
		var label := _make_label()
		_host.add_child(label)
		_free.append(label)

func _make_label() -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(LABEL_WIDTH, 0.0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible = false
	l.modulate.a = 0.0
	if _font:
		l.add_theme_font_override("normal_font", _font)
	return l

# ─────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────

## Show text at a position in the host's local space (screen space under a CanvasLayer).
## intensity: 0.0 whisper … 1.0 screaming (affects size, shake, tornado).
func show_text(text: String, voice: Voice, pos: Vector2, intensity: float = 0.5, lifetime: float = -1.0, emotion: String = "") -> RichTextLabel:
	if _host == null:
		push_warning("[VoiceTextPool] setup() was not called.")
		return null
	intensity = clampf(intensity, 0.0, 1.0)
	var label := _acquire()
	var life: float = lifetime if lifetime > 0.0 else (RED_LIFETIME if voice == Voice.RED else WHITE_LIFETIME) * (1.0 + intensity * 0.4)

	# Optional emotion font (FPFonts): swaps the face and colour of the red voice
	var col_hex: String = RED_COLOR
	if emotion != "":
		var ef: Font = FPFonts.get_font(emotion)
		if ef:
			label.add_theme_font_override("normal_font", ef)
		col_hex = "#" + FPFonts.color_of(emotion).to_html(false)
	elif _font:
		label.add_theme_font_override("normal_font", _font)
	label.text = _build_bbcode(text, voice, intensity, col_hex)
	label.add_theme_font_size_override("normal_font_size", _font_size(voice, intensity))
	label.position = _clamp_to_screen(pos)
	label.rotation = deg_to_rad(randf_range(-4.0, 4.0)) if voice == Voice.RED else 0.0
	label.modulate.a = 0.0
	label.self_modulate = Color.WHITE
	label.visible = true
	label.set_meta("voice", voice)

	_active.append(label)
	var list: Array = []
	_tweens[label] = list

	# Fade in → hold → fade out → release
	var t := label.create_tween()
	list.append(t)
	var fade_in: float = 0.06 if voice == Voice.RED else 0.5   # red appears abruptly
	var fade_out: float = 0.35 if voice == Voice.RED else 0.8
	t.tween_property(label, "modulate:a", 1.0, fade_in)
	t.tween_interval(maxf(life - fade_in - fade_out, 0.05))
	t.tween_property(label, "modulate:a", 0.0, fade_out)
	t.tween_callback(_release.bind(label))

	# Positional jitter for loud red text (finite loops -> always terminates)
	if voice == Voice.RED and intensity > 0.6:
		var j := label.create_tween()
		list.append(j)
		j.set_loops(int(life / 0.05))
		j.tween_property(label, "position:x", label.position.x + randf_range(-4.0, 4.0), 0.05)

	return label

## Show text at a WORLD position (e.g. over a phantom, a data station, a wall).
## Converts through the active camera so it works under a CanvasLayer.
func show_world_text(text: String, voice: Voice, world_pos: Vector2, intensity: float = 0.5, lifetime: float = -1.0) -> RichTextLabel:
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * world_pos
	return show_text(text, voice, screen_pos, intensity, lifetime)

## Instantly hide all red text (call when мрак closes his eyes, if desired).
func clear_red(fade: float = 0.12) -> void:
	for label in _active.duplicate():
		if label.has_meta("voice") and label.get_meta("voice") == Voice.RED:
			_kill_tweens(label)
			var t: Tween = label.create_tween()
			_tweens[label] = [t]
			t.tween_property(label, "modulate:a", 0.0, fade)
			t.tween_callback(_release.bind(label))

## Release everything (scene change, ending…).
func clear_all() -> void:
	for label in _active.duplicate():
		_release(label)

# ─────────────────────────────────────────────
# INTERNALS
# ─────────────────────────────────────────────

func _acquire() -> RichTextLabel:
	var label: RichTextLabel
	if not _free.is_empty():
		label = _free.pop_back()
	else:
		# Pool exhausted: recycle the oldest active label
		label = _active.pop_front()
		_kill_tweens(label)
	return label

func _release(label: RichTextLabel) -> void:
	_kill_tweens(label)
	label.visible = false
	label.modulate.a = 0.0
	label.text = ""
	if label.has_meta("voice"):
		label.remove_meta("voice")
	_active.erase(label)
	if not _free.has(label):
		_free.append(label)

func _kill_tweens(label: RichTextLabel) -> void:
	if _tweens.has(label):
		for t in _tweens[label]:
			if t and t.is_valid():
				t.kill()
		_tweens.erase(label)

func _build_bbcode(text: String, voice: Voice, intensity: float, red_hex: String = RED_COLOR) -> String:
	# Escape user text so stray "[" cannot inject or break tags
	var safe: String = text.replace("[", "[lb]")
	match voice:
		Voice.WHITE:
			return "[wave amp=%d freq=%.1f connected=0][color=%s]%s[/color][/wave]" % [
				int(lerpf(6.0, 14.0, intensity)), lerpf(1.5, 3.0, intensity), WHITE_COLOR, safe]
		_:
			var inner: String = "[color=%s]%s[/color]" % [red_hex, safe]
			var s: String = "[shake rate=%d level=%d connected=0]%s[/shake]" % [
				int(lerpf(12.0, 30.0, intensity)), int(lerpf(3.0, 12.0, intensity)), inner]
			if intensity > 0.75:
				s = "[tornado radius=%.1f freq=%.1f connected=0]%s[/tornado]" % [
					lerpf(1.0, 3.0, intensity), lerpf(2.0, 6.0, intensity), s]
			return s

func _font_size(voice: Voice, intensity: float) -> int:
	if voice == Voice.RED:
		return int(lerpf(14.0, 24.0, intensity))
	return int(lerpf(11.0, 14.0, intensity))

func _clamp_to_screen(pos: Vector2) -> Vector2:
	var size: Vector2 = get_viewport().get_visible_rect().size
	return Vector2(
		clampf(pos.x, 8.0, maxf(size.x - LABEL_WIDTH - 8.0, 8.0)),
		clampf(pos.y, 8.0, maxf(size.y - 48.0, 8.0))
	)
