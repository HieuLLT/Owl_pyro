# FlickerLight.gd — failing red neon. Mostly steady, with random dropouts and buzz.
class_name FlickerLight
extends OmniLight3D

@export var base_energy: float = 2.4
@export var dropout_chance: float = 0.35   # chance per second of starting a dropout
## Optional emissive tube material kept in sync with the light.
@export var tube_material: StandardMaterial3D

var _drop_left: float = 0.0
var _phase: float = randf() * 10.0

func _ready() -> void:
	light_energy = base_energy

func _process(delta: float) -> void:
	_phase += delta
	var e: float = base_energy * (0.92 + 0.08 * sin(_phase * 55.0))   # mains buzz
	if _drop_left > 0.0:
		_drop_left -= delta
		e = base_energy * (0.04 if fmod(_drop_left, 0.07) < 0.035 else 0.5)
	elif randf() < dropout_chance * delta:
		_drop_left = randf_range(0.08, 0.5)
	light_energy = e
	if tube_material:
		tube_material.emission_energy_multiplier = 0.2 + 3.0 * (e / base_energy)
