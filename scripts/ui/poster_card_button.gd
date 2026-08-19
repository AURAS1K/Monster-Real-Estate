extends "res://scripts/ui/button_juice.gd"
class_name PosterCardButton
## Poster-card button for the Request Board. Adds "pinned poster"
## selection feedback on top of button_juice's hover/press juice: when
## toggled on (selected -- see job_board.gd's shared ButtonGroup, which
## keeps exactly one poster selected at a time) the poster settles at a
## slightly larger resting scale and a faint warm tint instead of
## snapping back to 1.0, so the selected poster visibly stands out
## without becoming a modern glowing "card". The PosterButton theme
## variation (see ui_theme.gd) handles the border/glow/parchment-tint
## side of the same feedback via the button's native pressed state.

@export var selected_scale: float = 1.045
@export var selected_tint: Color = Color(1.05, 1.015, 0.94)

var _base_scale: float = 1.0


func _ready() -> void:
	super._ready()
	toggled.connect(_on_selected_toggled)
	_apply_selected_visual(button_pressed)


func _on_selected_toggled(is_selected: bool) -> void:
	_apply_selected_visual(is_selected)
	_animate(hover_scale if _hovered else _base_scale)


func _apply_selected_visual(is_selected: bool) -> void:
	_base_scale = selected_scale if is_selected else 1.0
	var tw := create_tween()
	tw.tween_property(self, "self_modulate", selected_tint if is_selected else Color(1, 1, 1, 1), 0.15)


func _on_mouse_exited() -> void:
	_hovered = false
	if not disabled:
		_animate(_base_scale)


func _on_button_up() -> void:
	if not disabled:
		_animate(hover_scale if _hovered else _base_scale)
