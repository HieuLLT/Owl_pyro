# AudioManager.gd — Autoload singleton: tập trung quản lý Audio Routing.
#
# ── Hạng mục A (Audio UX Pass) ─────────────────────────────────────────────
# A1 – Bus Routing:
#   Đảm bảo mọi AudioStreamPlayer đều được gán đúng bus. Cung cấp API tiện lợi
#   để các hệ thống khác không cần biết tên bus cụ thể.
#
# A2 – Spatial Audio (AudioStreamPlayer3D):
#   Cung cấp factory method tạo sẵn AudioStreamPlayer3D với thông số
#   Attenuation chuẩn cho từng loại âm thanh (Ambient vs Threat).
#
# BUS MAP:
#   "Ambient"    → âm nền: quạt, nhiễu, môi trường liên tục    (-18 dB)
#   "SFX"        → va đập kim loại, tương tác vật lý             (0 dB)
#   "UI_Mental"  → Giao diện Tâm lý, Firewall/MemoryLeak voice   (0 dB)
#   "Heartbeat"  → nhịp tim cơ học của мрак                      (0 dB)
#   "Spatial"    → AudioStreamPlayer3D trong môi trường          (-3 dB)
#   "Music"      → nhạc nền / stinger                            (-6 dB)

extends Node

# ── Bus name constants ────────────────────────────────────────────────────────

const BUS_MASTER    := "Master"
const BUS_AMBIENT   := "Ambient"
const BUS_SFX       := "SFX"
const BUS_MENTAL    := "UI_Mental"
const BUS_HEARTBEAT := "Heartbeat"
const BUS_SPATIAL   := "Spatial"
const BUS_MUSIC     := "Music"

# ── A2: Spatial Audio presets ─────────────────────────────────────────────────

## Loại âm thanh không gian — xác định Attenuation Curve và Max Distance.
enum SpatialType {
	## Tiếng máy móc, Xác Máy Đói Khát: suy giảm nhanh → hiểm họa rõ rệt khi gần.
	THREAT,
	## Tiếng môi trường lan rộng: gió, rỉ sét, drip — suy giảm chậm.
	AMBIENT_WIDE,
	## Tiếng va đập, sự kiện ngắn: suy giảm trung bình.
	IMPACT,
}

# ── A1: Bus assignment helpers ────────────────────────────────────────────────

## Gán bus cho một AudioStreamPlayer hoặc AudioStreamPlayer2D.
static func assign_bus(player: Node, bus_name: String) -> void:
	if player == null:
		return
	if player.has_method("get") and "bus" in player:
		player.bus = bus_name
	else:
		push_warning("AudioManager.assign_bus: node '%s' không có thuộc tính 'bus'." % player.name)

# ── A2: Spatial Audio factory ─────────────────────────────────────────────────

## Tạo một AudioStreamPlayer3D đã được cấu hình chuẩn cho loại âm thanh `type`.
## Người gọi chịu trách nhiệm add_child và set .stream.
##
## Ví dụ:
##   var p = AudioManager.make_spatial(SpatialType.THREAT)
##   p.stream = FPUtil.load_sound("res://assets/audio/fp/scavenger_scan.wav")
##   p.position = enemy.global_position
##   add_child(p)
##   p.play()
static func make_spatial(type: SpatialType = SpatialType.THREAT) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = BUS_SPATIAL

	match type:
		SpatialType.THREAT:
			# Suy giảm Inverse Square → âm lượng giảm mạnh theo khoảng cách.
			# Người chơi định vị được hiểm họa bằng tai.
			p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
			p.max_distance       = 14.0
			p.unit_size          = 3.0

		SpatialType.AMBIENT_WIDE:
			# Logarithmic → suy giảm nhẹ, âm thanh "bao phủ" rộng hơn.
			p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
			p.max_distance       = 28.0
			p.unit_size          = 8.0
			p.bus                = BUS_AMBIENT   # tiếng môi trường → Bus Ambient

		SpatialType.IMPACT:
			p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
			p.max_distance       = 20.0
			p.unit_size          = 5.0

	return p

## Phiên bản tiện lợi: tạo, gán stream, thêm vào parent, và play ngay.
## Player sẽ tự xóa sau khi phát xong (`finished → queue_free`).
static func play_spatial_once(
		parent: Node,
		stream_path: String,
		world_position: Vector3,
		type: SpatialType = SpatialType.IMPACT,
		volume_db: float = 0.0
) -> AudioStreamPlayer3D:
	var p := make_spatial(type)
	p.stream     = FPUtil.load_sound(stream_path)
	p.position   = world_position
	p.volume_db  = volume_db
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	if p.stream:
		p.play()
	return p

# ── Bus volume runtime control ────────────────────────────────────────────────

## Thay đổi volume của một bus theo tên (dB). Hữu ích cho fade-in/out.
static func set_bus_volume(bus_name: String, db: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)
	else:
		push_warning("AudioManager.set_bus_volume: không tìm thấy bus '%s'." % bus_name)

## Mute / unmute một bus theo tên.
static func set_bus_mute(bus_name: String, muted: bool) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)
