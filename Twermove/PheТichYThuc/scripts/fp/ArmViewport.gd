# ArmViewport.gd — SubViewport isolator for the CompassArm.
#
# WHY THIS EXISTS (B1 – Render Layer fix):
#   CompassArm was a direct child of Camera3D, sharing the same depth buffer as the
#   world geometry.  When мрак looks down, the arm geometry clips through the floor
#   because the world's depth test wins.  Moving the arm into its own SubViewport
#   gives it a completely separate depth buffer, so it is ALWAYS drawn on top,
#   regardless of the camera pitch or proximity to surfaces.
#
# ARCHITECTURE:
#   FPPlayer (CharacterBody3D)
#   ├── Head / Camera3D              ← main world camera (unchanged)
#   ├── ArmViewport (SubViewport)    ← this node, added by FPController._ready()
#   │   ├── ArmCamera (Camera3D)     ← mirrors main camera every frame
#   │   └── CompassArm              ← moved here; rendered in isolation
#   └── UI (CanvasLayer)
#       └── ArmRect (TextureRect)    ← composites the arm on top of the world
#
# USAGE:
#   Call ArmViewport.setup(main_camera) once after adding to the scene tree.
#   The node handles its own per-frame sync.  No other code needs to change.

class_name ArmViewport
extends SubViewport

# ── public ──────────────────────────────────────────────────────────────────

## The CompassArm instance living inside this viewport.
var compass_arm: CompassArm

# ── private ─────────────────────────────────────────────────────────────────

var _main_cam: Camera3D
var _arm_cam: Camera3D

# ── setup ────────────────────────────────────────────────────────────────────

func setup(main_camera: Camera3D) -> void:
	_main_cam = main_camera

	# SubViewport config ─────────────────────────────────────────────────────
	# transparent_bg = true → only the arm pixels are opaque; everything else
	# is alpha-0 so the world shows through when we composite with a TextureRect.
	transparent_bg = true

	# use_own_world_3d = true → arm lives in a blank world with no environment
	# geometry, so there is nothing for its depth buffer to fight against.
	use_own_world_3d = true

	# Disable audio listener: the arm viewport must never steal 3D audio focus.
	audio_listener_enable_3d = false

	# Match the main window size (updated on resize via signal).
	_sync_size()
	get_tree().root.size_changed.connect(_sync_size)

	# ArmCamera ──────────────────────────────────────────────────────────────
	_arm_cam = Camera3D.new()
	_arm_cam.name = "ArmCamera"
	# Near plane pushed slightly in so the arm geometry (close to camera origin)
	# is never clipped by the near plane.
	_arm_cam.near = 0.01
	_arm_cam.far = 10.0   # arm only; no need for the full world far plane
	_arm_cam.current = true
	add_child(_arm_cam)

	# CompassArm ─────────────────────────────────────────────────────────────
	compass_arm = CompassArm.new()
	# PIVOT CORRECTION (B2a): offset the arm root so it originates from the
	# virtual shoulder position rather than the camera origin.
	# Values tuned to match мрак's proportions: arm enters from lower-left,
	# reaching forward and down, as if the shoulder is behind and below the eye.
	compass_arm.position = Vector3(0.0, -0.18, 0.08)
	add_child(compass_arm)
	# Inject ArmCamera so the compass needle can calculate world-space angles
	# correctly (CompassArm.get_parent() is now SubViewport, not Camera3D).
	compass_arm.arm_camera = _arm_cam

# ── per-frame ─────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _main_cam == null or _arm_cam == null:
		return
	# Mirror the main camera's world transform exactly.
	# The arm geometry is in LOCAL space relative to this transform, so sway
	# (applied in ArmSway.gd) will always move correctly in camera-space.
	_arm_cam.global_transform = _main_cam.global_transform
	_arm_cam.fov               = _main_cam.fov

# ── helpers ──────────────────────────────────────────────────────────────────

func _sync_size() -> void:
	if get_tree() == null:
		return
	var vp_size: Vector2i = Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width",  1280),
		ProjectSettings.get_setting("display/window/size/viewport_height", 720)
	)
	size = vp_size
