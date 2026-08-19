extends Button
## Small "click to rebind" button used in the Settings > Controls section.
## Shows the current key for `action_name`; on press, waits for the next
## key the player presses and rebinds the action to it via GameSettings.

var action_name: String = ""
var _listening: bool = false


func setup(bound_action: String) -> void:
	action_name = bound_action
	_refresh_label()
	pressed.connect(_start_listening)


func _refresh_label() -> void:
	if _listening:
		text = "PRESS A KEY…"
	else:
		text = GameSettings.get_keybind_label(action_name)


func _start_listening() -> void:
	if _listening or action_name.is_empty():
		return
	_listening = true
	_refresh_label()
	set_process_unhandled_key_input(true)


func _unhandled_key_input(event: InputEvent) -> void:
	if not _listening:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		# Escape cancels the rebind instead of binding to Escape itself.
		if event.keycode != KEY_ESCAPE:
			GameSettings.rebind_action(action_name, event.keycode)
		_listening = false
		set_process_unhandled_key_input(false)
		_refresh_label()
		get_viewport().set_input_as_handled()
