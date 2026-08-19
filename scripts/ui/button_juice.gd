extends Button
## Small tactile hover-lift / press-squash animation layered on top of the
## shared UITheme stylebox states. Attach to any Button node (in a .tscn,
## or via `btn.set_script(load(...))` on a button created in code) that
## should feel a bit more alive -- primary CTAs, prop picker buttons, etc.
## Purely cosmetic: never touches disabled/toggle logic.

@export var hover_scale: float = 1.035
@export var press_scale: float = 0.94

var _tween: Tween
var _hovered: bool = false


func _ready() -> void:
	pivot_offset = size / 2.0
	resized.connect(_on_resized)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)


func _on_resized() -> void:
	pivot_offset = size / 2.0


func _on_mouse_entered() -> void:
	_hovered = true
	if not disabled:
		_animate(hover_scale)


func _on_mouse_exited() -> void:
	_hovered = false
	if not disabled:
		_animate(1.0)


func _on_button_down() -> void:
	if not disabled:
		_animate(press_scale)


func _on_button_up() -> void:
	if not disabled:
		_animate(hover_scale if _hovered else 1.0)


func _animate(target: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2(target, target), 0.12)
