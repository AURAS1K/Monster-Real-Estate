extends Control
## Short, static "How To Play" screen. Not a tutorial system -- just four
## steps and a "GOT IT" button. Emits `closed` so whichever screen opened
## it (currently just the title screen) can show itself again.

signal closed

@onready var got_it_button: Button = $CenterArea/Card/ContentRoot/Box/GotItButton
@onready var close_button: Button = $CenterArea/Card/ContentRoot/CloseButton


func _ready() -> void:
	theme = UITheme.theme
	visible = false
	got_it_button.pressed.connect(_on_got_it_pressed)
	close_button.theme_type_variation = &"CloseButton"
	close_button.pressed.connect(_on_got_it_pressed)


func show_screen() -> void:
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.97, 0.97)
	pivot_offset = size / 2.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_got_it_pressed() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func():
		visible = false
		closed.emit()
	)
