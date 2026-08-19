extends Node
## Foundation for the future Tenant Request Board. A "request" (contract)
## binds a tenant profile to a room and a specific set of requirements/
## likes/hates/rent for that particular job -- so the same tenant_id can
## later have several different requests (Hungry Goblin vs Sleepy Goblin)
## without duplicating rooms or the simulator.
##
## Only one seed entry exists today (goblin_default), matching the current
## single-scenario prototype exactly. Do not add more requests until the
## variant content itself (new likes/hates/rules) actually exists --
## this file is the data model, not the content.
class_name RequestData

## request_id -> {
##   request_id, tenant_id, room_id, title, description,
##   requirements, likes, hates, rent, difficulty, reward_modifier,
##   unlock_level, variant_id, special_rule,
## }
const REQUESTS: Dictionary = {
	"goblin_default": {
		"request_id": "goblin_default",
		"tenant_id": "goblin",
		"room_id": "goblin",
		"title": "GOBLIN REQUEST",
		"description": "\"I need a place to live.\"",
		"requirements": ["food", "bed", "storage"],
		"likes": ["food", "junk", "trap"],
		"hates": ["bright_light", "expensive"],
		"rent": 120,
		"difficulty": 1,
		"reward_modifier": 1.0,
		"unlock_level": 0,
		"variant_id": "",
		"special_rule": "",
	},
	"goblin_sleepy": {
		"request_id": "goblin_sleepy",
		"tenant_id": "goblin",
		"room_id": "goblin",
		"title": "SLEEPY GOBLIN REQUEST",
		"description": "\"Just... let me sleep.\"",
		"requirements": ["bed", "storage"],
		"likes": ["bed", "quiet"],
		"hates": ["bright_light", "noise"],
		"rent": 100,
		"difficulty": 1,
		"reward_modifier": 1.0,
		"unlock_level": 0,
		"variant_id": "sleepy",
		"special_rule": "",
	},
}
const DEFAULT_REQUEST_ID := "goblin_default"

## Merges a request's overrides onto its base tenant profile so the same
## tenant_id can produce different runtime configs per request, without
## duplicating the tenant profile. Only fields a request meaningfully
## overrides (requirements/likes/hates/rent/special_rule/name context) are
## replaced; everything else (max_props, allowed/forbidden_props, etc.)
## is inherited from TenantProfiles as-is.
static func resolve_tenant(request_id: String) -> Dictionary:
	var request := get_request(request_id)
	var tenant_id: String = request.get("tenant_id", "")
	if not TenantProfiles.has_profile(tenant_id):
		return {}
	var base := TenantProfiles.get_profile(tenant_id)
	var resolved := base.duplicate(true)
	resolved["requirements"] = request.get("requirements", base.get("requirements", []))
	resolved["likes"] = request.get("likes", base.get("likes", []))
	resolved["hates"] = request.get("hates", base.get("hates", []))
	resolved["rent"] = request.get("rent", base.get("rent", 0))
	resolved["special_room_rule"] = request.get("special_rule", base.get("special_room_rule", ""))
	resolved["request_id"] = request.get("request_id", "")
	resolved["request_title"] = request.get("title", "")
	resolved["request_description"] = request.get("description", "")
	resolved["difficulty"] = request.get("difficulty", 1)
	return resolved

## True only if the request's tenant_id and room_id both resolve to real
## data. Used to reject a bad request instead of silently falling back.
static func is_valid_request(request_id: String) -> bool:
	if not REQUESTS.has(request_id):
		return false
	var request: Dictionary = REQUESTS[request_id]
	if not TenantProfiles.has_profile(request.get("tenant_id", "")):
		return false
	if not RoomProfiles.has_profile(request.get("room_id", "")):
		return false
	return true

static func get_request(request_id: String) -> Dictionary:
	return REQUESTS.get(request_id, REQUESTS[DEFAULT_REQUEST_ID])

## All request ids available for a given room, in insertion order.
static func requests_for_room(room_id: String) -> Array:
	var ids: Array = []
	for id in REQUESTS.keys():
		if REQUESTS[id].get("room_id", "") == room_id:
			ids.append(id)
	return ids

## True if this room has at least one real request registered. The
## single source of truth for the Request Board's "request entry" vs
## "room-only entry" distinction (see job_board.gd) -- driven by actual
## REQUESTS data rather than a hand-maintained room-id list, so adding a
## future wizard_organized/wizard_alchemist/etc. request is a pure data
## change: the room's card upgrades itself from room-only to a real
## request list with no UI code to update.
static func room_has_requests(room_id: String) -> bool:
	return not requests_for_room(room_id).is_empty()

static func requests_for_tenant(tenant_id: String) -> Array:
	var ids: Array = []
	for id in REQUESTS.keys():
		if REQUESTS[id].get("tenant_id", "") == tenant_id:
			ids.append(id)
	return ids
