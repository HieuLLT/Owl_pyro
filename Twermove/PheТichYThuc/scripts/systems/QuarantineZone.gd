# QuarantineZone.gd — Khu Vực Cách Ly (Hồi 1, Phân cảnh 3)
# Flooded server hall. While мрак is inside:
#   * the White voice teaches the "close your eyes" stealth loop on entry;
#   * Scavengers that turn SUSPICIOUS inside the zone trigger near_scavenger lines;
#   * glowing (eyes open) мрак is bright prey — enemy detection is handled by BaseEnemy.
# Attach to an Area2D (collision_mask 4).

extends Area2D

var _inside: bool = false
var _entered_once: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	EventBus.enemy_state_changed.connect(_on_enemy_state_changed)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("mrak"):
		return
	_inside = true
	if not _entered_once:
		_entered_once = true
		DialogueSystem.trigger("quarantine_stealth", true)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("mrak"):
		_inside = false

func _on_enemy_state_changed(enemy: Node, new_state: String) -> void:
	if not _inside:
		return
	if new_state == "SUSPICIOUS" or new_state == "HUNT":
		DialogueSystem.trigger("near_scavenger", new_state == "HUNT")
