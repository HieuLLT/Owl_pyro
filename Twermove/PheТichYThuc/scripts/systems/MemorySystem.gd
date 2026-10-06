# MemorySystem.gd
# Manages all Memory Shard collection and puzzle gating.
# Memory Shards are the key collectibles that unlock the true ending.

extends Node

# All shard data defined here — expandable
const SHARD_DATA: Dictionary = {
	"shard_01": {
		"floor": 1,
		"type": "SIGNAL_TUNING",
		"firewall_text": "FRAGMENT RETRIEVED — MEMORY INTEGRITY: 12%",
		"leak_text": "...em đã chờ bạn suốt ba tiếng...",
		"leak_intensity": 0.6,
		"puzzle_config": {
			"target_frequency": 440.0,
			"noise_level": 0.4,
			"interference_text": "...bạn có nhớ bàn tay em không... t̵ạ̸i̷ ̷s̵a̸o̴...",
		}
	},
	"shard_02": {
		"floor": 1,
		"type": "FRAGMENT_ASSEMBLY",
		"firewall_text": "FRAGMENT RETRIEVED — MEMORY INTEGRITY: 24%",
		"leak_text": "ký ức này... bạn đã cố tình xóa nó đi...",
		"leak_intensity": 0.75,
		"puzzle_config": {
			"fragment_count": 4,
			"correct_order": [2, 0, 3, 1],
			"wrong_order_text": "không... không phải vậy... bạn đang nói dối bản thân mình",
		}
	},
	"shard_03": {
		"floor": 2,
		"type": "LIE_LABYRINTH",
		"firewall_text": "FRAGMENT RETRIEVED — MEMORY INTEGRITY: 36%",
		"leak_text": "b̷â̸y̷ ̸g̵i̸ờ̸ ̴b̷ạ̵n̸ ̸s̶ẽ̴ ̷p̷h̵ả̸i̴ ̷c̷h̷ọ̸n̴...",
		"leak_intensity": 0.9,
		"puzzle_config": {
			"sentence": "Tôi đã {ở lại / bỏ đi} vì {yêu / sợ hãi} cô ấy.",
			"words": [
				{"text": "ở lại",  "is_truth": false},
				{"text": "bỏ đi",  "is_truth": true},
				{"text": "yêu",    "is_truth": false},
				{"text": "sợ hãi", "is_truth": true},
			]
		}
	},
	"shard_04": {
		"floor": 2,
		"type": "SIGNAL_TUNING",
		"firewall_text": "FRAGMENT RETRIEVED — MEMORY INTEGRITY: 48%",
		"leak_text": "...tiếng cô ấy khóc... bạn vẫn nghe thấy không...",
		"leak_intensity": 0.7,
		"puzzle_config": {
			"target_frequency": 528.0,
			"noise_level": 0.65,
			"interference_text": "c̵ô̶ ̵ấ̸y̸ ̴đ̷ã̴ ̸g̴ọ̷i̸ ̸t̷ê̷n̴ ̸b̵ạ̶n̸...",
		}
	},
	"shard_05": {
		"floor": 3,
		"type": "LIE_LABYRINTH",
		"firewall_text": "FRAGMENT RETRIEVED — MEMORY INTEGRITY: 62%",
		"leak_text": "đây là mảnh cuối... trước khi bạn gặp nó...",
		"leak_intensity": 1.0,
		"puzzle_config": {
			"sentence": "Tôi {muốn / không muốn} nhớ. Sự thật là tôi {có tội / vô tội}.",
			"words": [
				{"text": "muốn",       "is_truth": true},
				{"text": "không muốn", "is_truth": false},
				{"text": "có tội",     "is_truth": true},
				{"text": "vô tội",     "is_truth": false},
			]
		}
	},
}

func _ready() -> void:
	EventBus.memory_shard_collected.connect(_on_shard_collected)

func _on_shard_collected(shard_id: String) -> void:
	if not SHARD_DATA.has(shard_id):
		return
	var data: Dictionary = SHARD_DATA[shard_id]

	# FIREWALL acknowledgment
	EventBus.firewall_speak.emit(data.get("firewall_text", "FRAGMENT RETRIEVED"))

	# MEMORY LEAK eruption
	EventBus.memory_leak_speak.emit(
		data.get("leak_text", "..."),
		data.get("leak_intensity", 0.5)
	)

	# Necrosis spike from confronting memory
	GameManager.add_necrosis(2.0)

func get_shard_data(shard_id: String) -> Dictionary:
	return SHARD_DATA.get(shard_id, {})

func get_puzzle_config(shard_id: String) -> Dictionary:
	return SHARD_DATA.get(shard_id, {}).get("puzzle_config", {})
