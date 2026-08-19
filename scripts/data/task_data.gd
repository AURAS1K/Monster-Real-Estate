extends Node
## Shared Task model (Architecture Pass Phase A / brief Phase 1). A "task"
## is a plain Dictionary rather than a custom Resource/class -- consistent
## with every other data model in this project (RoomProfiles, RequestData,
## PropDatabase all read/write Dictionaries, and room_simulator.gd already
## builds its `result`/`scores` payloads the same way) and avoids "a
## separate script per task type", which the brief explicitly rules out.
##
## This file is the single place that knows a task's shape and how to
## build/mutate one. TaskGenerator (Phase 2) decides WHICH tasks to build
## for a request; TaskManager (autoload) owns the currently-live set;
## future tool/interaction handlers (Phase B+) call mark_complete/
## is_completed instead of poking the Dictionary directly.
class_name TaskData

## Task categories (Phase 1). Plain strings, not an enum, so they
## serialize cleanly into ConfigFile save data later (Phase 23) without a
## separate int<->name lookup table.
const CATEGORY_CLEANING := "cleaning"
const CATEGORY_REPAIR := "repair"
const CATEGORY_REPLACEMENT := "replacement"
const CATEGORY_ORGANIZATION := "organization"
const CATEGORY_FURNISHING := "furnishing"
const CATEGORY_OPTIONAL := "optional"
const CATEGORY_INSPECTION := "inspection"

const ALL_CATEGORIES: Array[String] = [
	CATEGORY_CLEANING, CATEGORY_REPAIR, CATEGORY_REPLACEMENT, CATEGORY_ORGANIZATION,
	CATEGORY_FURNISHING, CATEGORY_OPTIONAL, CATEGORY_INSPECTION,
]


## Builds one task Dictionary with every field defaulted, so every caller
## gets the same shape regardless of how much it fills in. Keys in
## `overrides` win over the defaults below.
##
## Fields:
##   task_id            -- unique within the current task set (not global)
##   display_name        -- shown in the checklist UI (Phase 3)
##   description           -- optional flavor/detail text
##   mandatory              -- required for FINAL INSPECTION to pass
##   category                -- one of the CATEGORY_* consts above
##   target_type               -- what kind of thing this task acts on
##                             (e.g. "furniture", "floor", "bathroom") --
##                             read by the future Tool validation layer
##                             (tool.can_interact, Phase B)
##   target_id                  -- optional specific target reference (a
##                             prop tag, a condition_id, a furniture slot id)
##   room_id / request_id        -- applicability, so a stale task from a
##                             previous room/request is never mistaken
##                             for a current one
##   reward_xp / reward_gold      -- awarded once, on completion (Phase 13/14)
##   completed                     -- current completion state
##   visible                        -- whether the checklist UI should show
##                             it (a task can exist but stay hidden)
##   special_rule                    -- optional world-specific rule hook
##                             (Phase 21), empty string = none
##   condition_id                     -- back-reference to the
##                             ConditionData entry this task was generated
##                             from, if any (empty for furnishing tasks)
static func make_task(overrides: Dictionary) -> Dictionary:
	var task := {
		"task_id": "",
		"display_name": "",
		"description": "",
		"mandatory": true,
		"category": CATEGORY_CLEANING,
		"target_type": "",
		"target_id": "",
		"room_id": "",
		"request_id": "",
		"reward_xp": 0,
		"reward_gold": 0,
		"completed": false,
		"visible": true,
		"special_rule": "",
		"condition_id": "",
	}
	for key in overrides.keys():
		task[key] = overrides[key]
	return task


static func is_required(task: Dictionary) -> bool:
	return bool(task.get("mandatory", false))


static func is_completed(task: Dictionary) -> bool:
	return bool(task.get("completed", false))


## Mutates `task` in place -- Dictionaries are reference types in GDScript,
## so this affects whatever Array the caller's task set holds -- and
## returns whether it actually changed anything, so callers (TaskManager)
## can decide whether to award XP / emit signals rather than doing so on
## every redundant completion attempt.
static func mark_complete(task: Dictionary) -> bool:
	if task.get("completed", false):
		return false
	task["completed"] = true
	return true


static func mark_incomplete(task: Dictionary) -> bool:
	if not task.get("completed", false):
		return false
	task["completed"] = false
	return true


## Aggregate progress for a list of tasks -- used by the checklist UI
## (Phase 3) and the inspection gate (Phase 11) alike so they never
## compute "how much is left" differently from each other.
static func summarize(tasks: Array) -> Dictionary:
	var required_total := 0
	var required_done := 0
	var optional_total := 0
	var optional_done := 0
	for t in tasks:
		if is_required(t):
			required_total += 1
			if is_completed(t):
				required_done += 1
		else:
			optional_total += 1
			if is_completed(t):
				optional_done += 1
	return {
		"required_total": required_total,
		"required_done": required_done,
		"optional_total": optional_total,
		"optional_done": optional_done,
		"all_required_done": required_done == required_total,
	}
