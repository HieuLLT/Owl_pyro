# FPFonts.gd — the six emotion fonts (SRC/*.ttf, docs: dialogue_voice_and_floating_typography_report)
# mapped to the two voices. Static helper, no autoload needed.
#   Firewall (white)  : monospace system font (Share Tech Mono / Space Mono / Courier)
#   Memory Leak (red) : shame=MTOGrungeSans  despair=SkippySharpi (eyes closed)
#                       envy=HundredWatt (overheat)  angry=MTOGettingAngry  rage=KillCrazy
#   monster           : MTOMonsterTalking (Phantoms / echoes)
class_name FPFonts
extends RefCounted

const FILES: Dictionary = {
	"shame": "res://assets/fonts/MTOGrungeSans.ttf",
	"despair": "res://assets/fonts/SkippySharpi.ttf",
	"angry": "res://assets/fonts/MTOGettingAngry.ttf",
	"envy": "res://assets/fonts/HundredWatt.ttf",
	"rage": "res://assets/fonts/KillCrazy.ttf",
	"monster": "res://assets/fonts/MTOMonsterTalking.ttf",
}
## Voice colours per emotion (dark, wine-toned: the world is dim, the red must not glow cheerfully).
const COLORS: Dictionary = {
	"shame": Color(0.62, 0.16, 0.17),
	"despair": Color(0.85, 0.30, 0.30),
	"angry": Color(0.90, 0.06, 0.06),
	"envy": Color(1.0, 0.40, 0.10),
	"rage": Color(1.0, 0.0, 0.0),
	"monster": Color(0.45, 0.0, 0.0),
}
const CORRUPTION: String = "̸̵̴̷̶̡̢̨̧̛"

static var _cache: Dictionary = {}
static var _mono: Font = null

static func get_font(emotion: String) -> Font:
	if _cache.has(emotion):
		return _cache[emotion]
	var f: Font = null
	if FILES.has(emotion) and ResourceLoader.exists(FILES[emotion]):
		f = load(FILES[emotion]) as Font
		if f is FontFile:
			(f as FontFile).multichannel_signed_distance_field = true   # sharp when scaled (report §6.2)
			(f as FontFile).msdf_pixel_range = 12
	_cache[emotion] = f
	return f

static func mono() -> Font:
	if _mono == null:
		var s := SystemFont.new()
		s.font_names = PackedStringArray(["Share Tech Mono", "Space Mono", "Consolas", "Courier New", "monospace"])
		_mono = s
	return _mono

static func color_of(emotion: String) -> Color:
	return COLORS.get(emotion, COLORS["shame"])

## Which red-voice emotion fits the body's state right now (report §3.2).
static func pick_emotion(intensity: float, necrosis01: float, thermal: float, blind: bool, monster: bool = false) -> String:
	if monster:
		return "monster"
	if necrosis01 > 0.85 or intensity > 0.85:
		return "rage"
	if intensity > 0.6 or necrosis01 > 0.7:
		return "angry"
	if blind:
		return "despair"
	if thermal > 70.0:
		return "envy"
	return "shame"

## Red voice eating into a white line: inserts combining marks at `rate` (0..1) per character.
static func corrupt(text: String, rate: float) -> String:
	if rate <= 0.0:
		return text
	var out: String = ""
	for c in text:
		if randf() < rate:
			out += CORRUPTION[randi() % CORRUPTION.length()]
		out += c
	return out
