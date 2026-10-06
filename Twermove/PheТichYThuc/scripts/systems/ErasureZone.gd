# ErasureZone.gd
# "Sự Xâm Thực" (The Erasure) hazard. Attach to an Area2D whose collision_mask
# includes мрак's layer (4). Touching it deletes мрак permanently:
# necrosis jumps to 100 -> GameManager emits mrak_died + ending A_FRAGMENTATION.
#
# Sensory Deprivation does NOT protect against this — the Erasure is not a sense.

extends Area2D

## Warning text shown by the white voice the first time мрак gets close.
@export var warning_text: String = "Lỗi không gian cách 0.4 mét. Rút chân lại trước khi mã nguồn bị nuốt."
## Last words of the red voice when мрак is erased.
@export var erase_text: String = "Một bước thôi. Im lặng thật sự."

var _triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _triggered or not body.is_in_group("mrak"):
		return
	_triggered = true
	EventBus.firewall_speak.emit(warning_text)
	EventBus.memory_leak_speak.emit(erase_text, 1.0)
	# Hard erase: 100% necrosis triggers death/ending in GameManager
	GameManager.add_necrosis(100.0)
