extends Control
## Opening screen. Emits `start_pressed` when the player wants to jump into
## the tenant application. Owns its own tiny "How To Play" / "Settings"
## sub-states so main.gd doesn't need to know about them.

signal start_pressed

@onready var title_content: VBoxContainer = $TitleArea/TitlePlaque/TitleContent
@onready var button_content: VBoxContainer = $ButtonArea/ButtonContent
@onready var start_button: Button = $ButtonArea/ButtonContent/StartButton
@onready var how_to_button: Button = $ButtonArea/ButtonContent/HowToButton
@onready var settings_button: Button = $ButtonArea/ButtonContent/SettingsButton
@onready var settings_panel: Control = $SettingsPanel
@onready var settings_backdrop: ColorRect = $SettingsBackdrop
@onready var scroll_box: VBoxContainer = $SettingsPanel/Card/ContentRoot/Box/ScrollArea/ScrollBox
@onready var fullscreen_toggle: CheckButton = $SettingsPanel/Card/ContentRoot/Box/ScrollArea/ScrollBox/FullscreenRow/FullscreenToggle
@onready var volume_slider: HSlider = $SettingsPanel/Card/ContentRoot/Box/ScrollArea/ScrollBox/VolumeRow/VolumeSlider
@onready var volume_value_label: Label = $SettingsPanel/Card/ContentRoot/Box/ScrollArea/ScrollBox/VolumeRow/ValueLabel
@onready var sensitivity_slider: HSlider = $SettingsPanel/Card/ContentRoot/Box/ScrollArea/ScrollBox/SensitivityRow/SensitivitySlider
@onready var sensitivity_value_label: Label = $SettingsPanel/Card/ContentRoot/Box/ScrollArea/ScrollBox/SensitivityRow/ValueLabel
@onready var brightness_slider: HSlider = $SettingsPanel/Card/ContentRoot/Box/ScrollArea/ScrollBox/BrightnessRow/BrightnessSlider
@onready var brightness_value_label: Label = $SettingsPanel/Card/ContentRoot/Box/ScrollArea/ScrollBox/BrightnessRow/ValueLabel
@onready var contrast_slider: HSlider = $SettingsPanel/Card/ContentRoot/Box/ScrollArea/ScrollBox/ContrastRow/ContrastSlider
@onready var contrast_value_label: Label = $SettingsPanel/Card/ContentRoot/Box/ScrollArea/ScrollBox/ContrastRow/ValueLabel
@onready var reset_camera_keybind: Button = $SettingsPanel/Card/ContentRoot/Box/ScrollArea/ScrollBox/ResetCameraRow/KeybindButton
@onready var toggle_view_keybind: Button = $SettingsPanel/Card/ContentRoot/Box/ScrollArea/ScrollBox/ToggleViewRow/KeybindButton
@onready var toggle_top_keybind: Button = $SettingsPanel/Card/ContentRoot/Box/ScrollArea/ScrollBox/ToggleTopRow/KeybindButton
@onready var reset_defaults_button: Button = $SettingsPanel/Card/ContentRoot/Box/ResetDefaultsButton
@onready var settings_back_button: Button = $SettingsPanel/Card/ContentRoot/Box/BackButton
@onready var settings_close_button: Button = $SettingsPanel/Card/ContentRoot/CloseButton

@onready var credits_button: Button = $ButtonArea/ButtonContent/CreditsButton
@onready var menu_background: VideoStreamPlayer = $MenuBackground

var how_to_play_scene: Control = null
var credits_scene: Control = null


func _ready() -> void:
	theme = UITheme.theme

	menu_background.stream = load("res://assets/UI Assets/looped_final.ogv")
	menu_background.material = _make_sharpen_material()
	menu_background.play()

	start_button.pressed.connect(func(): start_pressed.emit())
	how_to_button.pressed.connect(_on_how_to_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	settings_button.pressed.connect(_open_settings)
	settings_back_button.pressed.connect(_close_settings)
	settings_close_button.theme_type_variation = &"CloseButton"
	settings_close_button.pressed.connect(_close_settings)
	reset_defaults_button.pressed.connect(_on_reset_defaults_pressed)

	reset_camera_keybind.setup("reset_camera")
	toggle_view_keybind.setup("toggle_cinematic_view")
	toggle_top_keybind.setup("toggle_top_view")

	volume_slider.value_changed.connect(_on_volume_changed)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	brightness_slider.value_changed.connect(_on_brightness_changed)
	contrast_slider.value_changed.connect(_on_contrast_changed)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	_sync_settings_ui()

	menu_background.finished.connect(menu_background.play)

	_play_intro()


## Cheap unsharp-mask style shader to counter the softness introduced by
## re-compressing the menu background video (Clipchamp export -> Theora).
func _make_sharpen_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float sharpen_amount : hint_range(0.0, 2.0) = 0.6;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec3 center = texture(TEXTURE, UV).rgb;
	vec3 blur = texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb
		+ texture(TEXTURE, UV - vec2(px.x, 0.0)).rgb
		+ texture(TEXTURE, UV + vec2(0.0, px.y)).rgb
		+ texture(TEXTURE, UV - vec2(0.0, px.y)).rgb;
	blur *= 0.25;
	vec3 sharpened = center + (center - blur) * sharpen_amount;
	COLOR = vec4(clamp(sharpened, 0.0, 1.0), texture(TEXTURE, UV).a);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat
func set_how_to_play(screen: Control) -> void:
	how_to_play_scene = screen
	how_to_play_scene.hide()
	if how_to_play_scene.has_signal("closed"):
		how_to_play_scene.closed.connect(func(): visible = true)


## Called by main.gd once, so the title screen can show its own
## Credits screen without main.gd owning that flow.
func set_credits(screen: Control) -> void:
	credits_scene = screen
	credits_scene.hide()
	if credits_scene.has_signal("closed"):
		credits_scene.closed.connect(func(): visible = true)


func _on_how_to_pressed() -> void:
	if how_to_play_scene:
		how_to_play_scene.show_screen()


func _on_credits_pressed() -> void:
	if credits_scene:
		credits_scene.show_screen()


func _open_settings() -> void:
	settings_backdrop.visible = true
	settings_backdrop.modulate.a = 0.0
	settings_panel.visible = true
	settings_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(settings_panel, "modulate:a", 1.0, 0.15)
	tw.tween_property(settings_backdrop, "modulate:a", 1.0, 0.15)


func _close_settings() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(settings_panel, "modulate:a", 0.0, 0.12)
	tw.tween_property(settings_backdrop, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback(func():
		settings_panel.visible = false
		settings_backdrop.visible = false
	)


func _on_fullscreen_toggled(pressed: bool) -> void:
	GameSettings.set_fullscreen(pressed)


func _on_volume_changed(value: float) -> void:
	GameSettings.set_master_volume(value)
	volume_value_label.text = "%d%%" % roundi(value * 100.0)


func _on_sensitivity_changed(value: float) -> void:
	GameSettings.set_camera_sensitivity(value)
	sensitivity_value_label.text = "%.2fx" % value


func _on_brightness_changed(value: float) -> void:
	GameSettings.set_brightness(value)
	brightness_value_label.text = "%.2f" % value


func _on_contrast_changed(value: float) -> void:
	GameSettings.set_contrast(value)
	contrast_value_label.text = "%.2f" % value


func _on_reset_defaults_pressed() -> void:
	GameSettings.reset_to_defaults()
	_sync_settings_ui()


## Pulls current GameSettings values into every Settings control -- used on
## first open and after Reset To Defaults, so the UI never drifts from the
## actual applied state (including whatever was loaded from disk).
func _sync_settings_ui() -> void:
	fullscreen_toggle.button_pressed = GameSettings.fullscreen
	volume_slider.value = GameSettings.master_volume
	volume_value_label.text = "%d%%" % roundi(GameSettings.master_volume * 100.0)
	sensitivity_slider.value = GameSettings.camera_sensitivity
	sensitivity_value_label.text = "%.2fx" % GameSettings.camera_sensitivity
	brightness_slider.value = GameSettings.brightness
	brightness_value_label.text = "%.2f" % GameSettings.brightness
	contrast_slider.value = GameSettings.contrast
	contrast_value_label.text = "%.2f" % GameSettings.contrast
	reset_camera_keybind._refresh_label()
	toggle_view_keybind._refresh_label()
	toggle_top_keybind._refresh_label()


## Subtle staggered fade/slide-in, ~0.8s total -- kept short per the design doc.
func _play_intro() -> void:
	var title1: Label = title_content.get_node("TitleLine1")
	var title2: Label = title_content.get_node("TitleLine2")
	var subtitle: Label = title_content.get_node("Subtitle")

	for n: Control in [title1, title2, subtitle, start_button, how_to_button, settings_button]:
		n.modulate.a = 0.0

	# NOTE: only ever animate `modulate`/`scale` here, never `position`.
	# title1/title2/subtitle are children of a VBoxContainer, which drives
	# their position every layout pass -- animating .position directly
	# fights the container and is what caused MONSTER/REAL ESTATE to
	# visibly overlap. pivot_offset centers the scale pulse instead of
	# growing from the top-left corner.
	title1.pivot_offset = title1.size / 2.0
	title2.pivot_offset = title2.size / 2.0
	title1.scale = Vector2(0.92, 0.92)
	title2.scale = Vector2(0.92, 0.92)

	var tw := create_tween()
	tw.set_parallel(false)
	tw.tween_property(title1, "modulate:a", 1.0, 0.28)
	tw.parallel().tween_property(title1, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(title2, "modulate:a", 1.0, 0.24)
	tw.parallel().tween_property(title2, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(subtitle, "modulate:a", 1.0, 0.22)
	tw.tween_property(start_button, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(how_to_button, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(settings_button, "modulate:a", 1.0, 0.18)


## Called by main.gd whenever the screen is shown again (e.g. returning
## from How To Play) so it doesn't replay the whole intro every time.
func show_screen() -> void:
	visible = true
	modulate.a = 1.0
