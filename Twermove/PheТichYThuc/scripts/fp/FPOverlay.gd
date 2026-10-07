# FPOverlay.gd — screen-space layer over the 3D view (built in code).
#  * fp_noise_overlay shader: edge static, tearing, RGB split ("Intrusion")
#  * eyes closed -> the whole view drops to pitch black (only sound remains)
#  * death card (The Erasure / necrosis 100%), E to restart
class_name FPOverlay
extends CanvasLayer

var _noise_mat: ShaderMaterial
var _black: ColorRect
var _death: Label
var _dead: bool = false
var _intrusion_tween: Tween

func _ready() -> void:
	layer = 20

	var noise := ColorRect.new()
	noise.set_anchors_preset(Control.PRESET_FULL_RECT)
	noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_noise_mat = FPUtil.make_shader_material("res://shaders/fp/fp_noise_overlay.gdshader")
	noise.material = _noise_mat
	add_child(noise)

	_black = ColorRect.new()
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.color = Color(0.0, 0.0, 0.0, 1.0)
	_black.modulate.a = 0.0
	add_child(_black)

	_death = Label.new()
	_death.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death.add_theme_color_override("font_color", Color(0.9, 0.1, 0.08))
	_death.add_theme_font_size_override("font_size", 22)
	_death.text = "MÃ NGUỒN BỊ XÓA\n\n[ E — khởi động lại ]"
	_death.modulate.a = 0.0
	add_child(_death)

	EventBus.ui_chaos_level_changed.connect(func(level: float) -> void: _noise_mat.set_shader_parameter("necrosis", level))
	EventBus.memory_leak_speak.connect(_on_leak)
	EventBus.mrak_blink_toggled.connect(_on_blink)
	EventBus.mrak_died.connect(_on_died)

## Red-voice intrusion: the picture tears for a moment.
func intrude(strength: float, seconds: float) -> void:
	if _intrusion_tween and _intrusion_tween.is_valid():
		_intrusion_tween.kill()
	_intrusion_tween = create_tween()
	_intrusion_tween.tween_method(_set_intrusion, 0.0, clampf(strength, 0.0, 1.0), seconds * 0.25)
	_intrusion_tween.tween_method(_set_intrusion, clampf(strength, 0.0, 1.0), 0.0, seconds * 0.75)

func _set_intrusion(v: float) -> void:
	_noise_mat.set_shader_parameter("intrusion", v)

func _on_leak(_msg: String, intensity: float) -> void:
	if GameManager.is_blind:
		return
	intrude(0.4 + 0.5 * intensity, 0.45)

func _on_blink(blind: bool) -> void:
	if _dead:
		return
	var tw := create_tween()
	tw.tween_property(_black, "modulate:a", 1.0 if blind else 0.0, 0.25 if blind else 0.18)

func _on_died() -> void:
	_dead = true
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
