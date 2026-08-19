extends Node
## Reusable registry of room "condition" problems -- dust, trash, broken
## furniture, spills, etc. (brief Phase 9/10, pulled forward as the data
## TaskGenerator/Phase 2 needs to turn a room+tenant+request into tasks).
##
## This is DATA ONLY: it describes what a problem is and what a task for
## it should look like. It does NOT track which problems are currently
## "active" in a specific room instance -- that's a future runtime concern
## once world furniture with per-instance condition state exists (Phase 6,
## furniture-condition system). Today TaskGenerator treats "applicable to
## this tenant+room" as "currently present", which matches the brief's
## examples (a Goblin room always has the same handful of default
## problems) until real per-instance state exists to drive Phase 10's
## randomized subset selection.
##
## Deliberately a flat, tag-filtered registry rather than a per-tenant
## switch statement (hard rule: no giant hardcoded tenant switches) --
## adding a future Dragon's "ash" condition is a new dictionary entry, not
## a new branch anywhere in code.
class_name ConditionData

## condition_id -> {
##   display_name, description,
##   category            -- one of TaskData.CATEGORY_*
##   target_type           -- see TaskData.make_task doc
##   valid_tools             -- Array[String] of future Tool ids (Phase B)
##                            this condition can be resolved with; empty
##                            means "not tool-driven yet" (e.g. decoration)
##   mandatory_default        -- required unless a request overrides it
##   reward_xp                  -- Phase 13 XP awarded on completion
##   applicable_tenant_types      -- Array[String], empty = any tenant
##   applicable_room_ids            -- Array[String], empty = any room
## }
const CONDITIONS: Dictionary = {
	# --- Goblin (brief's own example checklist) --------------------------
	"dirty_bedding": {
		"display_name": "Clean bedding",
		"description": "The bedding is filthy.",
		"category": "cleaning", "target_type": "furniture",
		"valid_tools": ["broom", "water_tool"],
		"mandatory_default": true, "reward_xp": 10,
		"applicable_tenant_types": ["goblin"], "applicable_room_ids": [],
	},
	"trash_pile": {
		"display_name": "Remove trash",
		"description": "Loose trash is scattered around the room.",
		"category": "cleaning", "target_type": "floor",
		"valid_tools": ["broom", "trash_bag"],
		"mandatory_default": true, "reward_xp": 10,
		"applicable_tenant_types": ["goblin"], "applicable_room_ids": [],
	},
	"dirty_bathroom": {
		"display_name": "Clean bathroom",
		"description": "The bathroom fixtures need a scrub.",
		"category": "cleaning", "target_type": "bathroom",
		"valid_tools": ["water_tool", "mop"],
		"mandatory_default": true, "reward_xp": 10,
		"applicable_tenant_types": ["goblin"], "applicable_room_ids": [],
	},
	"broken_chair": {
		"display_name": "Repair broken chair",
		"description": "A chair in the room is broken.",
		"category": "repair", "target_type": "furniture",
		"valid_tools": ["repair_kit"],
		"mandatory_default": true, "reward_xp": 15,
		"applicable_tenant_types": ["goblin"], "applicable_room_ids": [],
	},
	"scattered_junk": {
		"display_name": "Organize junk",
		"description": "Junk is strewn around instead of stored.",
		"category": "organization", "target_type": "floor",
		"valid_tools": ["trash_bag"],
		"mandatory_default": false, "reward_xp": 8,
		"applicable_tenant_types": ["goblin"], "applicable_room_ids": [],
	},
	"add_flowers": {
		"display_name": "Add flowers",
		"description": "A nice touch the goblin didn't ask for.",
		"category": "optional", "target_type": "decoration",
		"valid_tools": [],
		"mandatory_default": false, "reward_xp": 8,
		"applicable_tenant_types": ["goblin"], "applicable_room_ids": [],
	},
	"polish_furniture": {
		"display_name": "Polish furniture",
		"description": "Give the existing furniture a shine.",
		"category": "optional", "target_type": "furniture",
		"valid_tools": ["mop"],
		"mandatory_default": false, "reward_xp": 8,
		"applicable_tenant_types": ["goblin"], "applicable_room_ids": [],
	},
	# --- Wizard (data only -- no wizard TenantProfile/request exists yet;
	# harmless to define ahead of time. Generates zero tasks until both a
	# TenantProfiles wizard entry AND a RequestData wizard request exist,
	# since TaskGenerator.generate_tasks bails out on an invalid request
	# before ever consulting this table -- see PHASE 21 note there.) ------
	"potion_spill": {
		"display_name": "Clean potion spill",
		"description": "A spilled potion left a sticky residue.",
		"category": "cleaning", "target_type": "floor",
		"valid_tools": ["mop", "water_tool"],
		"mandatory_default": true, "reward_xp": 10,
		"applicable_tenant_types": ["wizard"], "applicable_room_ids": [],
	},
	"disorganized_books": {
		"display_name": "Organize books",
		"description": "Books are piled up instead of shelved.",
		"category": "organization", "target_type": "furniture",
		"valid_tools": [],
		"mandatory_default": true, "reward_xp": 10,
		"applicable_tenant_types": ["wizard"], "applicable_room_ids": [],
	},
	"broken_desk": {
		"display_name": "Repair desk",
		"description": "The study desk is broken.",
		"category": "repair", "target_type": "furniture",
		"valid_tools": ["repair_kit"],
		"mandatory_default": true, "reward_xp": 15,
		"applicable_tenant_types": ["wizard"], "applicable_room_ids": [],
	},
	"magical_residue": {
		"display_name": "Clean magical residue",
		"description": "Arcane residue clings to nearby surfaces.",
		"category": "cleaning", "target_type": "furniture",
		"valid_tools": ["water_tool"],
		"mandatory_default": true, "reward_xp": 10,
		"applicable_tenant_types": ["wizard"], "applicable_room_ids": [],
	},
	# --- Any tenant --------------------------------------------------------
	"dust": {
		"display_name": "Dust the room",
		"description": "A light layer of dust on everything.",
		"category": "optional", "target_type": "furniture",
		"valid_tools": ["broom"],
		"mandatory_default": false, "reward_xp": 5,
		"applicable_tenant_types": [], "applicable_room_ids": [],
	},
}

static func get_def(condition_id: String) -> Dictionary:
	return CONDITIONS.get(condition_id, {})

static func has_def(condition_id: String) -> bool:
	return CONDITIONS.has(condition_id)

## True if this condition may spawn for the given tenant_type/room_id.
## Empty applicable_* lists mean "any" -- same convention as
## PropDatabase.is_allowed_in_room.
static func is_applicable(condition_id: String, tenant_type: String, room_id: String) -> bool:
	var def := get_def(condition_id)
	if def.is_empty():
		return false
	var tenants: Array = def.get("applicable_tenant_types", [])
	var rooms: Array = def.get("applicable_room_ids", [])
	if not tenants.is_empty() and not tenants.has(tenant_type):
		return false
	if not rooms.is_empty() and not rooms.has(room_id):
		return false
	return true

## All condition ids applicable to a tenant_type/room_id pair, in registry
## order (deterministic -- Phase 10 asks for "deterministic/randomized
## data safely", not chaos; a future seeded-random subset selector can
## sample from this list without changing this function's contract).
static func conditions_for_tenant_room(tenant_type: String, room_id: String) -> Array:
	var ids: Array = []
	for id in CONDITIONS.keys():
		if is_applicable(id, tenant_type, room_id):
			ids.append(id)
	return ids
