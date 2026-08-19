extends Node
## Reusable per-room/world data profile. This is the single source of truth
## for "what is this room, what does it look like, what can be built in it" --
## replacing hardcoded per-room branches scattered through room_editor.gd,
## camera_controller.gd, and the HUD.
##
## Architecture note: scene-node NAMES (dressing/floor/walls/entrance) are
## kept here rather than resolved dynamically because they're siblings of
## the Room root in room.tscn -- a real "one room per .tscn" structure would
## let this be pure gameplay data with no scene-tree knowledge at all, but
## the prototype's single-scene-many-rooms layout means RoomEditor still
## needs a node-name lookup table. Everything else (bounds, camera,
## environment, prop filtering, unlock requirement) is pure data.
class_name RoomProfiles

## camera / environment sub-dicts are OPTIONAL overrides. Any key you omit
## falls back to camera_controller.gd's existing BUILD/PRESENTATION/TOP
## consts (goblin) or to the auto-derived-from-bounds behavior (wizard) --
## see CameraController.apply_room_profile(). An empty {} means "use
## defaults", so adding a room without camera tuning never breaks anything.
##
## allowed_prop_categories / allowed_prop_ids: OPTIONAL prop filters.
## Both empty means "no restriction, all props allowed" (current behavior
## for goblin + wizard). See PropDatabase.is_allowed_in_room().
const PROFILES: Dictionary = {
	"goblin": {
		"room_id": "goblin",
		"display_name": "Goblin Den",
		"tenant_type": "goblin",
		"scene": "res://assets/rooms/Goblin Room.glb",
		"dressing": "GoblinMapDressing", "floor": "Floor", "walls": "WallColliders",
		"entrance": "Entrance", "half_x": 6.8, "half_z": 5.8,
		"camera": {},
		"environment": {},
		"allowed_prop_categories": [],
		"allowed_prop_ids": [],
		"permanent_dressing_zones": [],
		"gameplay_modifiers": {},
		"special_room_rule": "",
		"unlock_level": 0,
	},
	"wizard": {
		"room_id": "wizard",
		"display_name": "Wizard's Tower",
		"tenant_type": "wizard",
		"scene": "res://assets/props/environment/wizard_apartment.glb",
		"dressing": "WizardMapDressing", "floor": "WizardFloor", "walls": "WizardWallColliders",
		# 5-room cross layout (center + Library/Lab/Bathroom/Captive Room wings).
		# half_x/half_z cover the whole footprint, not just the center room --
		# safe to widen because the floor raycast (room_editor._raycast_floor)
		# already gates placement to real floor colliders; these only clamp an
		# already-successful hit, so the empty space between wings never
		# becomes placeable just because the bounding box now covers it.
		"entrance": "WizardEntrance", "half_x": 15.6, "half_z": 16.0,
		"camera": {},
		# Cooler/arcane counter to the shared amber baseline (see
		# EnvironmentProfiles + RoomAmbience) -- guided by the room's own
		# glowing blue/purple rune circle rather than invented from
		# scratch. Only the 4 color keys needed to de-yellow the room are
		# set; energy/fog density/tonemap stay at RoomAmbience's baseline
		# so brightness and readability don't shift, just hue.
		"environment": {
			"background_color": Color(0.03, 0.035, 0.06),
			"ambient_light_color": Color(0.28, 0.3, 0.42),
			"fog_color": Color(0.32, 0.3, 0.48),
			"fill_light_color": Color(0.55, 0.58, 0.75),
		},
		"allowed_prop_categories": [],
		"allowed_prop_ids": [],
		"permanent_dressing_zones": ["Arcane", "Bed", "Library", "Study", "Artifact", "WallDress"],
		"gameplay_modifiers": {},
		"special_room_rule": "",
		"unlock_level": 0,
	},
}
const DEFAULT_ROOM_ID := "goblin"

static func get_profile(room_id: String) -> Dictionary:
	return PROFILES.get(room_id, PROFILES[DEFAULT_ROOM_ID])

static func has_profile(room_id: String) -> bool:
	return PROFILES.has(room_id)

static func all_room_ids() -> Array:
	return PROFILES.keys()

## Rooms whose unlock_level is <= the given lender level.
static func unlocked_room_ids(level: int) -> Array:
	var ids: Array = []
	for id in PROFILES.keys():
		if int(PROFILES[id].get("unlock_level", 0)) <= level:
			ids.append(id)
	return ids
