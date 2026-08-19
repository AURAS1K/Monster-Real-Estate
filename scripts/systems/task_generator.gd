extends Node
## Data-driven task generation (brief Phase 2). Turns CURRENT ROOM +
## CURRENT TENANT + CURRENT REQUEST into REQUIRED/OPTIONAL task lists,
## using ConditionData as the source of possible cleaning/repair/
## organization/optional problems, plus the request's EXISTING
## `requirements` array (food/bed/storage -- the current prop-placement
## loop) turned into FURNISHING tasks. This means the new task system
## represents the whole property-prep loop without duplicating either the
## existing requirement data (RequestData) or the prop system
## (PropDatabase) -- it just describes them as tasks too.
##
## No per-tenant switch statement: which conditions apply comes from
## ConditionData's tag filters (Phase 9/10), and a request MAY narrow that
## set explicitly via an optional "condition_ids" key -- a Phase 10/22
## request-variant hook. Neither existing request (goblin_default /
## goblin_sleepy) sets this key, so both fall back to "every condition
## ConditionData says applies to this tenant+room", which is today's only
## real content and is exactly what the brief's Goblin example checklist
## describes.
class_name TaskGenerator

## Builds {"required": Array[Dictionary], "optional": Array[Dictionary]}
## for a request_id. Empty arrays (not an error) for an invalid/room-only
## request_id -- matches RequestData's own "no crash, just nothing here"
## style (e.g. wizard today, which has no registered request).
static func generate_tasks(request_id: String) -> Dictionary:
	var required: Array = []
	var optional: Array = []

	if not RequestData.is_valid_request(request_id):
		return {"required": required, "optional": optional}

	var request := RequestData.get_request(request_id)
	var room_id: String = request.get("room_id", "")
	var tenant_id: String = request.get("tenant_id", "")

	# --- Existing requirement tags (food/bed/storage) become FURNISHING
	# tasks so they show up in the same checklist as the new cleaning/
	# repair work instead of living in a totally separate, invisible
	# system. Completion for these is driven by prop placement -- wiring
	# that up to TaskManager.complete_task belongs to a later phase (the
	# checklist/tool-interaction phases), not this generator.
	var requirements: Array = request.get("requirements", [])
	for req_tag in requirements:
		required.append(TaskData.make_task({
			"task_id": "furnish_%s_%s" % [request_id, req_tag],
			"display_name": "Provide: %s" % String(req_tag).capitalize(),
			"description": "The tenant needs %s in the room." % req_tag,
			"mandatory": true,
			"category": TaskData.CATEGORY_FURNISHING,
			"target_type": "prop_tag",
			"target_id": req_tag,
			"room_id": room_id,
			"request_id": request_id,
			"reward_xp": 5,
		}))

	# --- Condition-driven cleaning/repair/organization/optional tasks. ---
	var condition_ids := _condition_ids_for_request(request_id, tenant_id, room_id)
	for condition_id in condition_ids:
		var def := ConditionData.get_def(condition_id)
		if def.is_empty():
			continue
		var mandatory: bool = bool(def.get("mandatory_default", true))
		var task := TaskData.make_task({
			"task_id": "%s_%s" % [request_id, condition_id],
			"display_name": def.get("display_name", condition_id),
			"description": def.get("description", ""),
			"mandatory": mandatory,
			"category": def.get("category", TaskData.CATEGORY_CLEANING),
			"target_type": def.get("target_type", ""),
			"target_id": condition_id,
			"room_id": room_id,
			"request_id": request_id,
			"reward_xp": def.get("reward_xp", 0),
			"condition_id": condition_id,
		})
		if mandatory:
			required.append(task)
		else:
			optional.append(task)

	return {"required": required, "optional": optional}


## A request may pin its own condition set via an optional "condition_ids"
## key (not present on any request today -- this is the hook, not new
## content). Falls back to every condition ConditionData says applies to
## this tenant+room, in registry order.
static func _condition_ids_for_request(request_id: String, tenant_id: String, room_id: String) -> Array:
	var request := RequestData.get_request(request_id)
	var explicit: Array = request.get("condition_ids", [])
	if not explicit.is_empty():
		return explicit
	return ConditionData.conditions_for_tenant_room(tenant_id, room_id)
