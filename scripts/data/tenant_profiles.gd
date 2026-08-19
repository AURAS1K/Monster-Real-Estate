extends Node
## Reusable registry of tenant profiles, keyed by tenant_id. A tenant
## profile is the data GameManager/RoomSimulator/HUD need to run a tenant
## through the existing simulation pipeline without any of those scripts
## knowing which specific monster it is.
##
## Fields (mirrors GoblinData.DATA's existing shape so the goblin migrates
## with zero behavior change -- "rent" is kept as the key name, not
## "base_rent", so existing consumers (tenant_application.gd,
## room_simulator.gd) don't need a rename on top of the source change):
##   tenant_id, name, room_id, rent, requirements, likes, hates,
##   flavor, danger_note, max_props, allowed_props, forbidden_props,
##   special_behavior_flags, special_room_rule, unlock_level
##
## Only "goblin" is populated for real -- it's a thin wrapper around the
## existing GoblinData.DATA const (not a duplicate copy) so GoblinData
## stays the single source of truth and nothing has to migrate at once.
## New tenants (wizard, dragon, vampire, ...) get added here later as their
## own DATA consts, same pattern as GoblinData.
class_name TenantProfiles

static func _goblin_profile() -> Dictionary:
	var d: Dictionary = GoblinData.DATA
	return {
		"tenant_id": d.get("id", "goblin"),
		"name": d.get("name", "Goblin"),
		"room_id": "goblin",
		"rent": d.get("rent", 0),
		"requirements": d.get("requirements", []),
		"likes": d.get("likes", []),
		"hates": d.get("hates", []),
		"flavor": d.get("flavor", ""),
		"danger_note": d.get("danger_note", ""),
		"max_props": d.get("max_props", 10),
		"allowed_props": [],
		"forbidden_props": [],
		"special_behavior_flags": [],
		"special_room_rule": "",
		"unlock_level": 0,
	}

## Built lazily (not a const) since it wraps GoblinData.DATA rather than
## duplicating it -- keeps a single source of truth if GoblinData.DATA ever
## changes at runtime (it doesn't yet, but the indirection is free).
static func get_profile(tenant_id: String) -> Dictionary:
	match tenant_id:
		"goblin":
			return _goblin_profile()
		_:
			return {}

static func has_profile(tenant_id: String) -> bool:
	return tenant_id == "goblin"
