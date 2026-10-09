# FPOverlay.gd — screen-space layer over the 3D view (built in code), bottom to top:
#   1. fp_noise_overlay  edge static, tearing, RGB split (Intrusion)
#   2. fp_visor          the BROKEN, BLACKENED DIVING-HELMET glass: black corners, cracks
#   3. Red-voice text    glitchy red/black lines pasted ON THE VIEW. They block sight (the
#                        louder the voice, the more of the screen they cover — up to ~80% when
#                        a Phantom screams). Cleared instantly by closing the eyes.
#   4. black             eyes closed -> pitch black, only sound remains
#   5. death card        The Erasure / necrosis 100%, E to restart
# Story rule (SRC/cot-truyen...): the Red voice "che khuất tầm nhìn"; the White voice lives on
# skin and ground in the world (see PsychText3D / CompassArm), never over the view.
class_name FPOverlay
extends CanvasLayer

var _noise_mat: ShaderMaterial
var _visor_mat: ShaderMaterial
var _black: ColorRect
var _death: Label
var _red_host: Control
var _red_pool: VoiceTextPool
var _mem_host: Control
var _mem_pool: VoiceTextPool
var _dead: bool = false
var _t: float = 0.0
var _intrusion_tween: Tween

func _ready() -> void:
	layer = 20

	var noise := _full_rect()
	_noise_mat = FPUtil.make_shader_material("res://shaders/fp/fp_noise_overlay.gdshader")
	noise.material = _noise_mat
	add_child(noise)

	var visor := _full_rect()
	_visor_mat = FPUtil.make_shader_material("res://shaders/fp/fp_visor.gdshader")
	visor.material = _visor_mat
	add_child(visor)

	_red_host = Control.new()
	_red_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_red_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_red_host)
	_red_pool = VoiceTextPool.new()
	add_child(_red_pool)
	_red_pool.setup(_red_host, null)

	_black = _full_rect()
	_black.color = Color(0.0, 0.0, 0.0, 1.0)
	_black.modulate.a = 0.0
	add_child(_black)

	# Eyes closed: only a faint childlike marker-pen memory (SkippySharpi) glows on the black (report §3.2.2)
	_mem_host = Control.new()
	_mem_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mem_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mem_host)
	_mem_pool = VoiceTextPool.new()
	add_child(_mem_pool)
	_mem_pool.setup(_mem_host, null)

	_death = Label.new()
	_death.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death.add_theme_color_override("font_color", Color(0.9, 0.1, 0.08))
	_death.add_theme_font_size_override("font_size", 22)
	_death.text = "MÃ NGUỒN BỊ XÓA\n\n[ E — khởi động lại ]"
	_death.modulate.a = 0.0
	add_child(_death)

	EventBus.ui_chaos_level_changed.connect(_on_chaos)
	EventBus.memory_leak_speak.connect(_on_leak)
	EventBus.mrak_blink_toggled.connect(_on_blink)
	EventBus.mrak_died.connect(_on_died)
	_on_chaos(GameManager.necrosis / 100.0)

func _full_rect() -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _process(delta: float) -> void:
	_t += delta
	_visor_mat.set_shader_parameter("breath", 0.5 + 0.5 * sin(_t * 0.9))

func _on_chaos(level: float) -> void:
	_noise_mat.set_shader_parameter("necrosis", level)
	_visor_mat.set_shader_parameter("damage", clampf(0.2 + level * 0.8, 0.0, 1.0))

## Red-voice intrusion: the picture tears for a moment.
func intrude(strength: float, seconds: float) -> void:
	if _intrusion_tween and _intrusion_tween.is_valid():
		_intrusion_tween.kill()
	_intrusion_tween = create_tween()
	_intrusion_tween.tween_method(_set_intrusion, 0.0, clampf(strength, 0.0, 1.0), seconds * 0.25)
	_intrusion_tween.tween_method(_set_intrusion, clampf(strength, 0.0, 1.0), 0.0, seconds * 0.75)

func _set_intrusion(v: float) -> void:
	_noise_mat.set_shader_parameter("intrusion", v)

func _on_leak(msg: String, intensity: float) -> void:
	if _dead:
		return
	if GameManager.is_blind:
		var sz: Vector2 = get_viewport().get_visible_rect().size
		var lb: RichTextLabel = _mem_pool.show_text(msg, VoiceTextPool.Voice.RED, Vector2(randf_range(0.15, 0.5) * sz.x, randf_range(0.3, 0.65) * sz.y), 0.25, 3.0, "despair")
		if lb:
			lb.modulate.a = 0.0
		return
	intrude(0.4 + 0.5 * intensity, 0.45)
	_flood_red(msg, intensity)

## Pastes the line (and, when loud, fragments of it) at random places over the view.
## Intensity 0 = one small whisper; 1 = ten huge lines that blot out most of the screen.
func _flood_red(msg: String, intensity: float) -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var count: int = clampi(1 + roundi(intensity * 9.0), 1, 10)
	var words: PackedStringArray = msg.split(" ", false)
	for i in count:
		var text: String = msg
		if i > 0 and words.size() > 3:
			var a: int = randi_range(0, words.size() - 3)
			var b: int = randi_range(a + 2, mini(a + 5, words.size()))
			text = " ".join(words.slice(a, b))
		var pos := Vector2(randf_range(0.0, 0.62) * size.x, randf_range(0.04, 0.78) * size.y)
		var inten: float = clampf(intensity + randf_range(-0.15, 0.15), 0.0, 1.0)
		var emo: String = FPFonts.pick_emotion(inten, GameManager.necrosis / 100.0, GameManager.thermal, GameManager.is_blind)
		var label: RichTextLabel = _red_pool.show_text(text, VoiceTextPool.Voice.RED, pos, inten, 2.2 + intensity * 1.8, emo)
		if label:
			# Red on black: a thick dark outline, scaled up with the voice's volume
			label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
			label.add_theme_constant_override("outline_size", 6 + roundi(intensity * 8.0))
			label.scale = Vector2.ONE * (1.45 + intensity * 1.2)
			if emo == "envy":                       # overheat: constant flicker (report 3.2)
				var fl := label.create_tween().set_loops(30)
				fl.tween_property(label, "self_modulate:a", 0.25, 0.06)
				fl.tween_property(label, "self_modulate:a", 1.0, 0.06)

func _on_blink(blind: bool) -> void:
	if blind:
		_red_pool.clear_red(0.05)
	else:
		_mem_pool.clear_all()
	if _dead:
		return
	var tw := create_tween()
	tw.tween_property(_black, "modulate:a", 1.0 if blind else 0.0, 0.25 if blind else 0.18)

func _on_died() -> void:
	_dead = true
	_red_pool.clear_all()
	var tw := create_tween()
	tw.tween_property(_black, "modulate:a", 1.0, 0.35)
	tw.tween_property(_death, "modulate:a", 1.0, 0.8)

func _unhandled_input(event: InputEvent) -> void:
	if _dead and event.is_action_pressed("interact"):
		GameManager.necrosis = 0.0
		GameManager.pin = 100.0
		GameManager.thermal = 20.0
		GameManager.is_blind = false
		get_tree().reload_current_scene()
