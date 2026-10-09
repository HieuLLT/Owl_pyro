# ArmSway.gd — procedural weapon sway for the CompassArm (B2b).
#
# WHY THIS EXISTS:
#   In the previous setup CompassArm was hard-parented to Camera3D, so any
#   camera movement was instantly mirrored to the arm — zero lag, zero weight.
#   мрак's body is described as "70% necrotic" and "dragging itself along".
#   The arm must feel HEAVY and SLOW to respond, not bolted to the eyeball.
#
# HOW IT WORKS:
#   Each frame we read the raw mouse delta (via _input) and build a TARGET
#   rotation offset.  We then LERP the arm's current rotation toward that
#   target, producing the characteristic lag / inertia feel.
#   The sway is applied as a local rotation offset on the CompassArm node,
#   which lives inside ArmViewport in camera-local space.
#
# INTEGRATION:
#   Instantiated and owned by FPController.  FPController also feeds
#   beat / drag data to compass_arm directly (same API as before).

class_name ArmSway
extends Node

# ── exported tunables ────────────────────────────────────────────────────────

## How far the arm rotates in response to mouse movement (radians per pixel).
## Higher → more exaggerated sway.
@export var sway_amount: float = 0.045

## How quickly the arm catches up to the target rotation (higher = snappier).
## At 5.0 the arm takes ~0.2 s to settle — feels "heavy body, slow response".
@export var sway_speed: float = 5.0

## Maximum angular deviation in either axis (radians).
@export var max_sway: float = 0.085

# ── private ──────────────────────────────────────────────────────────────────

var _arm_node: Node3D        # the CompassArm (or any Node3D) to sway
var _mouse_delta: Vector2 = Vector2.ZERO
var _current_rot: Vector2 = Vector2.ZERO   # actual smoothed value (x=pitch, y=yaw)

# ── public API ────────────────────────────────────────────────────────────────

## Call once after the arm node is ready.
func setup(arm: Node3D) -> void:
	_arm_node = arm

# ── input & update ────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Accumulate raw delta; consumed each _process frame.
		_mouse_delta += (event as InputEventMouseMotion).relative

func _process(delta: float) -> void:
	if _arm_node == null:
		return

	# Build target from accumulated mouse movement this frame.
	# Negative signs: mouse right → arm tilts LEFT (opposite → sells the lag).
	var target := Vector2(
		clamp(-_mouse_delta.y * sway_amount, -max_sway, max_sway),  # pitch (look up/down)
		clamp(-_mouse_delta.x * sway_amount, -max_sway, max_sway)   # yaw   (look left/right)
	)

	# Lerp toward target — the core of the "heavy body" feel.
	var t: float = clamp(sway_speed * delta, 0.0, 1.0)
	_current_rot = _current_rot.lerp(target, t)

	# Apply as a LOCAL rotation OFFSET on top of whatever _arm_pose set.
	# We write rotation.x and .y directly; .z is owned by drag/breathe in
	# CompassArm._arm_pose, so we leave it alone.
	_arm_node.rotation.x += _current_rot.x
	_arm_node.rotation.y += _current_rot.y

	# Reset accumulator — ensures we don't double-count across frames.
	_mouse_delta = Vector2.ZERO
