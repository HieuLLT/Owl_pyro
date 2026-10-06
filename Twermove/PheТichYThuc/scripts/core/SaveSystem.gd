# SaveSystem.gd
# Autoload singleton — Handles save/load via JSON to user:// directory.

extends Node

const SAVE_PATH: String = "user://mrak_save.json"

func save_game() -> void:
	var data: Dictionary = GameManager.get_save_data()
	var json_str: String = JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		print("[SaveSystem] Game saved.")
	else:
		push_error("[SaveSystem] Failed to open save file for writing.")

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var json_str: String = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(json_str)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_error("[SaveSystem] Corrupted save file.")
		return false
	GameManager.load_save_data(parsed)
	print("[SaveSystem] Game loaded.")
	return true

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("[SaveSystem] Save deleted.")

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
