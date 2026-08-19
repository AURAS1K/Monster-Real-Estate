extends Node
## Autoload singleton. Owns the CURRENT room/request's generated task set
## (see TaskGenerator) the same way GameManager owns current_request --
## one live copy that other systems (future checklist UI, tool
## interactions, Final Inspection) read and mutate through this API rather
## than regenerating or duplicating task state themselves.
##
## Regenerates automatically whenever GameManager.current_request_id
## actually changes (see GameManager.request_changed), so nothing else has
## to remember to call generate_for_current_request() -- mirroring how
## GameManager itself reacts to its own state changes internally. Also
## generates once on _ready() so the very first room (loaded before any
## signal fires) already has a task set.

signal tasks_generated
signal task_completed(task: Dictionary)
## Emitted the moment every mandatory task becomes complete -- the future
## Final Inspection screen (Phase D) can light up "ready" off this instead
## of polling is_ready_for_inspection() every frame.
signal all_required_complete

var current_tasks: Dictionary = {"required": [], "optional": []}


func _ready() -> void:
	GameManager.request_changed.connect(_on_request_changed)
	generate_for_current_request()


func _on_request_changed(_request_id: String) -> void:
	generate_for_current_request()


func generate_for_current_request() -> void:
	current_tasks = TaskGenerator.generate_tasks(GameManager.current_request_id)
	tasks_generated.emit()


func get_required_tasks() -> Array:
	return current_tasks.get("required", [])


func get_optional_tasks() -> Array:
	return current_tasks.get("optional", [])


func get_all_tasks() -> Array:
	return get_required_tasks() + get_optional_tasks()


## Marks the first matching, not-yet-completed task done and emits
## task_completed. Returns false if no such task exists (already done, or
## no task with that id in the current set) so callers (future tool
## interaction handlers) can tell a real completion from a redundant one
## before awarding XP/gold.
func complete_task(task_id: String) -> bool:
	for task in get_all_tasks():
		if task.get("task_id", "") == task_id and not TaskData.is_completed(task):
			TaskData.mark_complete(task)
			task_completed.emit(task)
			if is_ready_for_inspection():
				all_required_complete.emit()
			return true
	return false


## True once every REQUIRED task (mandatory furnishing + mandatory
## condition tasks) is complete -- the single gate the Final Inspection
## phase will check before letting the property proceed to the tenant
## simulation (brief Phase 11: "Do NOT immediately start the tenant
## simulation when mandatory tasks are incomplete").
func is_ready_for_inspection() -> bool:
	var summary := TaskData.summarize(get_required_tasks())
	return bool(summary.get("all_required_done", false))


func get_summary() -> Dictionary:
	return TaskData.summarize(get_all_tasks())


## Clears the current task set without regenerating -- mirrors
## RoomEditor.clear_all_props' "wipe state, caller decides what happens
## next" shape, for any future caller that needs an empty state briefly
## (e.g. mid room-transition) rather than an immediately-regenerated one.
func clear() -> void:
	current_tasks = {"required": [], "optional": []}
