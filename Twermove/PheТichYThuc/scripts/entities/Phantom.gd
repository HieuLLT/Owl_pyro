# Phantom.gd — Bóng Đen Quá Khứ ("Lá chắn")
# Hồi 1, Phân cảnh 2 (see lore). Behaviour:
#   * Entering its radius roots мрак almost completely (speed_multiplier -> slow_factor).
#   * Eyes OPEN  -> the Red voice screams and necrosis rises.
#   * Eyes CLOSED -> the Red voice is silenced; the Vestige Needle drains the data.
#     After `extraction_time` seconds of blind contact the Phantom dissolves,
#     the memory shard is collected and the last audio fragment plays.
# Leaving the radius resets the slowdown; progress decays.

extends Area2D

@export var slow_factor: float = 0.15
@export var extraction_time: float = 3.0
@export var shard_id: String = "shard_01"
## Necrosis per second while мрак stares at it with open eyes.
@export var gaze_necrosis_per_sec: float = 1.5
## Seconds between Red-voice outbursts while eyes are open.
@export var taunt_interval: float = 2.4

var _mrak: Node = null
var _progress: float = 0.0
var _taunt_timer: float = 0.0
var _done: bool = false
var _hint_given: bool = false

@onready var _body: ColorRect = $Body
var _mat: ShaderMaterial = null

func _ready() -> void:
	add_to_group("memory_shard")      # the Vestige Needle points at it
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _body.material is ShaderMaterial:
		_mat = _body.material as ShaderMaterial

func _on_body_entered(body: Node2D) -> void:
	if _done or not body.is_in_group("mrak"):
		return
	_mrak = body
	_taunt_timer = 0.0
	_hint_given = false
	DialogueSystem.trigger("near_phantom", true)

func _on_body_exited(body: Node2D) -> void:
	if body != _mrak:
		return
	_release_mrak()
	_mrak = null

func _release_mrak() -> void:
	if _mrak and "speed_multiplier" in _mrak:
		_mrak.speed_multiplier = 1.0

func _process(delta: float) -> void:
	if _done:
		return
	if _mrak == null:
		_progress = maxf(_progress - delta * 0.5, 0.0)
		_apply_visual()
		return

	_mrak.speed_multiplier = slow_factor

	if GameManager.is_blind:
		_progress += delta
		if not _hint_given:
			_hint_given = true
			EventBus.firewall_speak.emit("Rễ la bàn đang cắm vào khối dữ liệu. Giữ nguyên bóng tối.")
		if _progress >= extraction_time:
			_complete()
			return
	else:
		# Eyes open: the Memory Leak erupts
		GameManager.add_necrosis(gaze_necrosis_per_sec * delta)
		_taunt_timer += delta
		if _taunt_timer >= taunt_interval:
			_taunt_timer = 0.0
			DialogueSystem.trigger("near_phantom", true)
		# Open eyes interrupt the extraction
		_progress = maxf(_progress - delta * 0.3, 0.0)
	_apply_visual()

func _apply_visual() -> void:
	if _mat:
		_mat.set_shader_parameter("dissolve", clampf(_progress / extraction_time, 0.0, 1.0) * 0.6)

func _complete() -> void:
	_done = true
	_release_mrak()
	remove_from_group("memory_shard")
	EventBus.firewall_speak.emit("[ÂM THANH ĐỨT QUÃNG] Lá chắn đã sập. Cứu lấy lõi trung tâm... Bỏ tôi lại...")
	EventBus.memory_shard_collected.emit(shard_id)

	var t := create_tween()
	t.tween_method(_set_dissolve, 0.6, 1.0, 1.4)
	t.tween_callback(queue_free)

func _set_dissolve(v: float) -> void:
	if _mat:
		_mat.set_shader_parameter("dissolve", v)
