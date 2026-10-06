# ElevatorCCTV.gd — Kết Hồi 1 (Thang Máy Lõi + góc máy CCTV)
# Attach to an Area2D (collision_mask 4). When мрак steps in:
#   control is taken, the camera pulls back into a cold CCTV frame under flashing
#   emergency light, the Vestige Needle points at the ceiling, then the floor changes.
# If `next_scene` does not exist yet, an end-of-chapter card is shown instead.

extends Area2D

@export_file("*.tscn") var next_scene: String = "res://scenes/world/Floor_1.tscn"
@export var hold_seconds: float = 7.0

var _started: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _started or not body.is_in_group("mrak"):
		return
	_started = true
	_run_sequence(body)

func _run_sequence(mrak: Node2D) -> void:
	# Take control away
	mrak.set_physics_process(false)
	mrak.set_process_input(false)
	if "velocity" in mrak:
		mrak.velocity = Vector2.ZERO
	GameManager.is_paused = false

	# --- CCTV overlay (built in code: no extra scene needed) ---
	var layer := CanvasLayer.new()
	layer.layer = 30
	get_tree().root.add_child(layer)

	var alarm := ColorRect.new()
	alarm.set_anchors_preset(Control.PRESET_FULL_RECT)
	alarm.color = Color(0.8, 0.0, 0.0, 0.0)
	alarm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(alarm)

	var label := Label.new()
	label.text = "CAM_04 // THANG MÁY LÕI\n● REC"
	label.position = Vector2(24, 20)
	label.add_theme_color_override("font_color", Color(0.85, 0.1, 0.1, 0.9))
	label.add_theme_font_size_override("font_size", 14)
	label.modulate.a = 0.0
	layer.add_child(label)

	var fade := ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)

	# Emergency light: flashing red
	var flash := create_tween().set_loops()
	flash.tween_property(alarm, "color:a", 0.28, 0.45)
	flash.tween_property(alarm, "color:a", 0.0, 0.45)

	# REC dot blink + label in
	create_tween().tween_property(label, "modulate:a", 1.0, 0.6)

	# Camera pulls back like a ceiling security lens
	var cam := mrak.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.limit_left = -100000
		cam.limit_right = 100000
		cam.limit_top = -100000
		cam.limit_bottom = 100000
		var ct := create_tween().set_parallel(true)
		ct.tween_property(cam, "zoom", Vector2(1.1, 1.1), 2.5).set_trans(Tween.TRANS_SINE)
		ct.tween_property(cam, "offset", Vector2(0, -90), 2.5).set_trans(Tween.TRANS_SINE)

	EventBus.firewall_speak.emit("Cửa thép đóng. Thang máy đang kéo lên. Nhịp tim cơ học: không ổn định.")
	await get_tree().create_timer(2.6).timeout
	EventBus.firewall_speak.emit("La bàn chỉ lên trần nhà. Trạm Ký Ức Trung Tâm.")
	EventBus.vestige_needle_toggled.emit(true)
	await get_tree().create_timer(maxf(hold_seconds - 2.6, 1.0)).timeout

	# Fade to black, then change floor
	var ft := create_tween()
	ft.tween_property(fade, "color:a", 1.0, 1.2)
	await ft.finished

	EventBus.vestige_needle_toggled.emit(false)
	GameManager.set_floor(1)

	if ResourceLoader.exists(next_scene):
		layer.queue_free()
		get_tree().change_scene_to_file(next_scene)
	else:
		_show_end_card(layer)

func _show_end_card(layer: CanvasLayer) -> void:
	var card := Label.new()
	card.text = "HỒI 1 — HÀNH LANG CỦA SỰ TÀN NHẪN\nKẾT THÚC\n\n[ HỒI 2: CÁC TẦNG KHUYẾT THIẾU — ĐANG ĐƯỢC XÂY DỰNG ]"
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_theme_color_override("font_color", Color(0.85, 0.1, 0.1, 1.0))
	card.add_theme_font_size_override("font_size", 18)
	card.modulate.a = 0.0
	layer.add_child(card)
	create_tween().tween_property(card, "modulate:a", 1.0, 1.5)
