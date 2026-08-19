extends Camera3D
## Simple orbit/pan/zoom editor camera for the room prototype.
## Deliberately dumb: spherical coords around a pan target, no smoothing,
## no cinematic behavior. Attached directly to the existing Camera3D node.

const ROOM_HALF_EXTENT: float = 7.25

const MIN_PITCH: float = 0.15
const MAX_PITCH: float = 1.4
## Base rates at GameSettings.camera_sensitivity == 1.0 (Settings > Camera).
const BASE_ORBIT_SENSITIVITY: float = 0.008
const BASE_PAN_SENSITIVITY: float = 0.0025

const DEFAULT_YAW: float = 0.0
const DEFAULT_PITCH: float = 1.0
const DEFAULT_DISTANCE: float = 10.5
const DEFAULT_TARGET: Vector3 = Vector3(0.0, 1.0, 0.0)

const PAN_BOUND: float = 6.0
const MIN_DISTANCE: float = 6.0
const MAX_DISTANCE: float = 16.0
const BASE_ZOOM_STEP: float = 0.8

## Two hand-authored framings, toggled with C. BUILD is the existing
## default editor angle; PRESENTATION is a closer, tighter-FOV look meant
## for showing off a finished room rather than placing props in it.
enum ViewMode { BUILD, PRESENTATION, TOP }

const BUILD_FOV: float = 60.0
const PRESENTATION_FOV: float = 34.0
const PRESENTATION_YAW: float = 0.62
const PRESENTATION_PITCH: float = 0.30
const PRESENTATION_DISTANCE: float = 6.0
## Presentation looks toward the goblin's corner of the room rather than
## dead-center, so the Main Menu framing actually includes the goblin and
## the dressed back wall instead of empty mid-floor. Tightened yaw/FOV so
## the ladder (far left) and the undressed side of the room (far right)
## fall outside the frame -- the whole point of a dedicated menu framing.
const PRESENTATION_TARGET: Vector3 = Vector3(1.2, 1.0, -1.8)
const TOP_FOV: float = 50.0
const TOP_YAW: float = 0.0
const TOP_PITCH: float = 1.4
const TOP_DISTANCE: float = 14.5
const VIEW_TRANSITION_TIME: float = 0.5

var _target: Vector3 = DEFAULT_TARGET
var _yaw: float = DEFAULT_YAW
var _pitch: float = DEFAULT_PITCH
var _distance: float = DEFAULT_DISTANCE

var _input_enabled: bool = true
var _orbiting: bool = false
var _panning: bool = false

## Room-specific pan bound + default zoom-out distance, applied by
## RoomEditor.switch_room so a larger room (e.g. Wizard) isn't stuck with
## Goblin's tight pan/zoom limits. Reuses the existing BUILD framing --
## no second camera or view mode needed.
func set_room_bounds(half_x: float, half_z: float) -> void:
	_room_pan_bound = max(half_x, half_z)
	_room_max_distance = max(MAX_DISTANCE, _room_pan_bound * 2.2)
	if _view_mode == ViewMode.BUILD:
		_apply_view_mode()

var _room_pan_bound: float = PAN_BOUND
var _room_max_distance: float = MAX_DISTANCE

## Per-room camera overrides (see RoomProfiles.PROFILES[room_id]["camera"]),
## set by RoomEditor._apply_room_state via apply_room_profile(). Keyed by
## view mode ("build"/"presentation"/"top"), each an optional dict of
## {yaw, pitch, distance, fov, target}. See _apply_view_mode() for how
## missing keys fall back to this script's own consts.
var _camera_profile: Dictionary = {}

## Applies a room's camera profile and re-renders the current view mode
## with it. Called alongside set_room_bounds() whenever the active room
## changes. An empty/missing "camera" key (every room today) is a no-op --
## same framing as before this hook existed.
func apply_room_profile(profile: Dictionary) -> void:
	_camera_profile = profile.get("camera", {})
	_apply_view_mode()

var _view_mode: ViewMode = ViewMode.BUILD
var _tween: Tween = null


func _ready() -> void:
	fov = BUILD_FOV
	_apply_transform()


## Lets external systems (e.g. the title-screen menu dressing) temporarily
## freeze free-cam orbit/pan/zoom without touching the underlying state.
func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	if not enabled:
		_orbiting = false
		_panning = false


## Public wrapper around the R-key reset, so other systems (e.g. menu
## dressing cleanup) can restore the default editor framing without faking
## a key event.
func reset_view() -> void:
	_reset()


## Switches straight to the cinematic PRESENTATION framing. Used by the
## Main Menu instead of a second camera node -- reuses the same orbit/
## transition machinery build mode already relies on.
func show_presentation_view() -> void:
	_view_mode = ViewMode.PRESENTATION
	_apply_view_mode()


## Switches back to the default BUILD framing (used when leaving the Main
## Menu for the tenant application / build mode).
func show_build_view() -> void:
	_view_mode = ViewMode.BUILD
	_apply_view_mode()


func _unhandled_input(event: InputEvent) -> void:
	if not _input_enabled:
		return
	# Reads through GameSettings-managed InputMap actions rather than hardcoded
	# keycodes so the Settings panel's keybind rebinding actually takes effect.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action(&"toggle_cinematic_view"):
			_toggle_view()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action(&"reset_camera"):
			_reset()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action(&"toggle_top_view"):
			_toggle_top()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				if event.pressed:
					_panning = Input.is_key_pressed(KEY_SHIFT)
					_orbiting = not _panning
				else:
					_orbiting = false
					_panning = false
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom(-BASE_ZOOM_STEP * GameSettings.camera_sensitivity)
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom(BASE_ZOOM_STEP * GameSettings.camera_sensitivity)
					get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _orbiting:
			_orbit(event.relative)
			get_viewport().set_input_as_handled()
		elif _panning:
			_pan(event.relative)
			get_viewport().set_input_as_handled()



func _orbit(rel: Vector2) -> void:
	var sens: float = BASE_ORBIT_SENSITIVITY * GameSettings.camera_sensitivity
	_yaw -= rel.x * sens
	_pitch = clampf(_pitch + rel.y * sens, MIN_PITCH, MAX_PITCH)
	_apply_transform()


func _pan(rel: Vector2) -> void:
	var right: Vector3 = global_transform.basis.x
	var forward_flat: Vector3 = -global_transform.basis.z
	forward_flat.y = 0.0
	forward_flat = forward_flat.normalized() if forward_flat.length() > 0.001 else Vector3.FORWARD
	var pan_scale: float = BASE_PAN_SENSITIVITY * GameSettings.camera_sensitivity * _distance
	_target -= right * rel.x * pan_scale
	_target += forward_flat * rel.y * pan_scale
	_target.x = clampf(_target.x, -_room_pan_bound, _room_pan_bound)
	_target.z = clampf(_target.z, -_room_pan_bound, _room_pan_bound)
	_target.y = clampf(_target.y, 0.0, 3.0)
	_apply_transform()


func _zoom(delta: float) -> void:
	_distance = clampf(_distance + delta, MIN_DISTANCE, _room_max_distance)
	_apply_transform()





func _apply_transform() -> void:
	var horiz: float = _distance * cos(_pitch)
	var offset := Vector3(
		horiz * sin(_yaw),
		_distance * sin(_pitch),
		horiz * cos(_yaw)
	)
	global_transform.origin = _target + offset
	look_at(_target, Vector3.UP)


## Switches _view_mode and smoothly animates to that mode's framing.
func _toggle_view() -> void:
	_view_mode = ViewMode.PRESENTATION if _view_mode == ViewMode.BUILD else ViewMode.BUILD
	_apply_view_mode()


## T key: snap to/from the top-down overview. Toggles back to BUILD if
## already in TOP, same pattern as C's BUILD<->PRESENTATION toggle.
func _toggle_top() -> void:
	_view_mode = ViewMode.BUILD if _view_mode == ViewMode.TOP else ViewMode.TOP
	_apply_view_mode()


## Animates the camera to the hand-authored framing for the current view
## mode, layering any per-room override from _camera_profile on top of
## this script's own BUILD_*/PRESENTATION_*/TOP_* consts. Every override
## key is optional -- a room with no "camera" profile (every room today)
## resolves every .get() to the same const this always used, so behavior
## is byte-for-byte unchanged until a room actually supplies overrides.
func _apply_view_mode() -> void:
	var target_yaw: float
	var target_pitch: float
	var target_distance: float
	var target_fov: float
	if _view_mode == ViewMode.BUILD:
		var o: Dictionary = _camera_profile.get("build", {})
		var default_distance: float = max(DEFAULT_DISTANCE, min(_room_max_distance, _room_pan_bound * 1.7))
		target_yaw = o.get("yaw", DEFAULT_YAW)
		target_pitch = o.get("pitch", DEFAULT_PITCH)
		target_distance = o.get("distance", default_distance)
		target_fov = o.get("fov", BUILD_FOV)
		_start_transition(target_yaw, target_pitch, target_distance, o.get("target", DEFAULT_TARGET), target_fov)
		return
	elif _view_mode == ViewMode.PRESENTATION:
		var o: Dictionary = _camera_profile.get("presentation", {})
		target_yaw = o.get("yaw", PRESENTATION_YAW)
		target_pitch = o.get("pitch", PRESENTATION_PITCH)
		target_distance = o.get("distance", PRESENTATION_DISTANCE)
		target_fov = o.get("fov", PRESENTATION_FOV)
		_start_transition(target_yaw, target_pitch, target_distance, o.get("target", PRESENTATION_TARGET), target_fov)
		return
	else:
		var o: Dictionary = _camera_profile.get("top", {})
		target_yaw = o.get("yaw", TOP_YAW)
		target_pitch = o.get("pitch", TOP_PITCH)
		target_distance = o.get("distance", TOP_DISTANCE)
		target_fov = o.get("fov", TOP_FOV)
		_start_transition(target_yaw, target_pitch, target_distance, o.get("target", DEFAULT_TARGET), target_fov)
		return


## R key: reset the current view mode back to its default framing.
func _reset() -> void:
	_apply_view_mode()


## Smoothly tweens yaw/pitch/distance/target/fov toward the given values,
## re-applying the camera transform every step so orbit math stays in sync.
func _start_transition(target_yaw: float, target_pitch: float, target_distance: float, target_target: Vector3, target_fov: float) -> void:
	if _tween:
		_tween.kill()
	var start_yaw: float = _yaw
	var start_pitch: float = _pitch
	var start_distance: float = _distance
	var start_target: Vector3 = _target
	var start_fov: float = fov
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(
		func(t: float) -> void:
			_yaw = lerp_angle(start_yaw, target_yaw, t)
			_pitch = lerpf(start_pitch, target_pitch, t)
			_distance = lerpf(start_distance, target_distance, t)
			_target = start_target.lerp(target_target, t)
			fov = lerpf(start_fov, target_fov, t)
			_apply_transform(),
		0.0, 1.0, VIEW_TRANSITION_TIME
	)

