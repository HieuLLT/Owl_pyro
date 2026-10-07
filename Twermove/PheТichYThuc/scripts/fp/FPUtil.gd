# FPUtil.gd — small static helpers for the first-person build.
class_name FPUtil
extends RefCounted

## Loads an AudioStream if the file exists (it may not, before assets are generated/imported).
## With loop = true, a WAV is duplicated and set to loop forward over its whole length.
static func load_sound(path: String, loop: bool = false) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var s := load(path) as AudioStream
	if s == null:
		return null
	if loop and s is AudioStreamWAV:
		var w := s.duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() >> 1  # 16-bit mono -> frame count
		return w
	return s

static func load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

static func make_shader_material(shader_path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	if ResourceLoader.exists(shader_path):
		m.shader = load(shader_path) as Shader
	return m

## Registers the first-person input actions (WASD / arrows) if the project lacks them.
## Existing actions are reused: blink (Space), vestige_needle (Q), interact (E).
static func ensure_actions() -> void:
	var map := {
		"fp_forward": [KEY_W, KEY_UP],
		"fp_back": [KEY_S, KEY_DOWN],
		"fp_left": [KEY_A, KEY_LEFT],
		"fp_right": [KEY_D, KEY_RIGHT],
	}
	for action in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
