extends Node
## Autoload. Centralizes every user-configurable setting behind one place:
## persists to user://settings.cfg, applies the real side effects
## (fullscreen, master volume, camera orbit/pan/zoom sensitivity, screen
## brightness/contrast via the room's Environment, and rebindable camera
## keybinds), and is what the Settings panel UI reads from / writes to.

signal settings_applied

const SAVE_PATH := "user://settings.cfg"

const DEFAULT_CAMERA_SENSITIVITY := 1.0
const DEFAULT_MASTER_VOLUME := 1.0
const DEFAULT_BRIGHTNESS := 1.0
const DEFAULT_CONTRAST := 1.0

const MIN_SENSITIVITY := 0.25
const MAX_SENSITIVITY := 3.0
const MIN_ADJUST := 0.5
const MAX_ADJUST := 1.5

## Rebindable camera actions and their built-in default key. Display order
## for the Settings panel follows this dictionary's insertion order.
const DEFAULT_KEYBINDS := {
	"reset_camera": KEY_R,
	"toggle_cinematic_view": KEY_C,
	"toggle_top_view": KEY_T,
}

const ACTION_LABELS := {
	"reset_camera": "Reset Camera",
	"toggle_cinematic_view": "Toggle Cinematic View",
	"toggle_top_view": "Toggle Top View",
}

var fullscreen: bool = false
var master_volume: float = DEFAULT_MASTER_VOLUME
var camera_sensitivity: float = DEFAULT_CAMERA_SENSITIVITY
var brightness: float = DEFAULT_BRIGHTNESS
var contrast: float = DEFAULT_CONTRAST
var keybinds: Dictionary = DEFAULT_KEYBINDS.duplicate()

## Set once by whatever creates the room's Environment (room_ambience.gd) so
## brightness/contrast sliders have something to actually affect.
var _environment: Environment = null


func _ready() -> void:
	_register_input_actions()
	_load()
	_apply_all()


func _register_input_actions() -> void:
	for action_name: String in DEFAULT_KEYBINDS:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	)
	_save()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	_save()


func set_camera_sensitivity(value: float) -> void:
	camera_sensitivity = clampf(value, MIN_SENSITIVITY, MAX_SENSITIVITY)
	_save()


func set_brightness(value: float) -> void:
	brightness = clampf(value, MIN_ADJUST, MAX_ADJUST)
	_apply_environment()
	_save()


func set_contrast(value: float) -> void:
	contrast = clampf(value, MIN_ADJUST, MAX_ADJUST)
	_apply_environment()
	_save()


## Called by the Settings UI once the player presses a new key while
## rebinding `action_name`. Replaces any previous binding for that action.
func rebind_action(action_name: String, keycode: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	InputMap.action_erase_events(action_name)
	var ev := InputEventKey.new()
	ev.keycode = keycode as Key
	InputMap.action_add_event(action_name, ev)
	keybinds[action_name] = keycode
	_save()


func get_keybind_label(action_name: String) -> String:
	var keycode: int = keybinds.get(action_name, KEY_NONE)
	if keycode == KEY_NONE:
		return "—"
	return OS.get_keycode_string(keycode)


func reset_to_defaults() -> void:
	fullscreen = false
	master_volume = DEFAULT_MASTER_VOLUME
	camera_sensitivity = DEFAULT_CAMERA_SENSITIVITY
	brightness = DEFAULT_BRIGHTNESS
	contrast = DEFAULT_CONTRAST
	keybinds = DEFAULT_KEYBINDS.duplicate()
	for action_name: String in keybinds:
		rebind_action(action_name, keybinds[action_name])
	_apply_all()
	_save()


## Lets the scene that owns the room's Environment resource (room_ambience.gd)
## register it once so brightness/contrast sliders can affect it live.
func register_environment(env: Environment) -> void:
	_environment = env
	_apply_environment()


func _apply_environment() -> void:
	if _environment == null:
		return
	_environment.adjustment_enabled = true
	_environment.adjustment_brightness = brightness
	_environment.adjustment_contrast = contrast


func _apply_volume() -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx < 0:
		return
	AudioServer.set_bus_mute(bus_idx, master_volume <= 0.0001)
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(max(master_volume, 0.0001)))


func _apply_all() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	_apply_volume()
	for action_name: String in keybinds:
		rebind_action(action_name, keybinds[action_name])
	_apply_environment()
	settings_applied.emit()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("camera", "sensitivity", camera_sensitivity)
	cfg.set_value("graphics", "brightness", brightness)
	cfg.set_value("graphics", "contrast", contrast)
	cfg.set_value("keybinds", "map", keybinds)
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
	master_volume = cfg.get_value("audio", "master_volume", master_volume)
	camera_sensitivity = cfg.get_value("camera", "sensitivity", camera_sensitivity)
	brightness = cfg.get_value("graphics", "brightness", brightness)
	contrast = cfg.get_value("graphics", "contrast", contrast)
	var loaded_binds = cfg.get_value("keybinds", "map", keybinds)
	if loaded_binds is Dictionary:
		keybinds = loaded_binds
