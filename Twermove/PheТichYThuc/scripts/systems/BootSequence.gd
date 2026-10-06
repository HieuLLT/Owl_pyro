# BootSequence.gd
# Attached to BootSequenceTrigger node in Floor_0.tscn
# Runs the opening sequence: FIREWALL messages, atmospheric setup, tutorial hints.

extends Node

# Boot sequence lines — delivered in order with delays
const BOOT_LINES: Array[Dictionary] = [
	{"voice": "firewall", "text": "RESIDUUM — SECTOR 0 — BOOT SEQUENCE INITIATED", "delay": 1.5},
	{"voice": "firewall", "text": "мрак — NECROSIS: 0.0% — THERMAL: 20°C — PIN: 100%", "delay": 2.5},
	{"voice": "firewall", "text": "OBJECTIVE: REACH DEPTH THRESHOLD. AVOID DETECTION.", "delay": 2.0},
	{"voice": "leak",     "text": "...bạn thực sự nghĩ rằng đây là về sinh tồn sao...", "delay": 3.0},
	{"voice": "firewall", "text": "[SPACE] = SENSORY DEPRIVATION. [Q] = VESTIGE NEEDLE. [E] = INTERACT.", "delay": 2.5},
	{"voice": "leak",     "text": "tìm mảnh ký ức đi... tôi đang đợi...", "delay": 4.0},
]

var _sequence_index: int = 0

func _ready() -> void:
	# Wait a moment after scene loads before starting sequence
	await get_tree().create_timer(0.8).timeout
	_deliver_next()

func _deliver_next() -> void:
	if _sequence_index >= BOOT_LINES.size():
		return
	var line: Dictionary = BOOT_LINES[_sequence_index]
	_sequence_index += 1

	if line["voice"] == "firewall":
		EventBus.firewall_speak.emit(line["text"])
	else:
		EventBus.memory_leak_speak.emit(line["text"], 0.5)

	await get_tree().create_timer(line["delay"]).timeout
	_deliver_next()
