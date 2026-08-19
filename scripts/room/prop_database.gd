extends Node
## Static-ish database of all placeable props for the prototype.
## Not an autoload -- accessed as PropDatabase.DEFS via the class_name below.
class_name PropDatabase

## Each entry:
##   name        -> display name
##   color       -> placeholder primitive color
##   shape       -> "box" | "capsule" | "cylinder"
##   size        -> Vector3 half-extent-ish visual size (for the mesh, and always for collision)
##   tags        -> array of strings describing what this prop IS (used for likes/hates/requirements)
##   asset_scene -> OPTIONAL res:// path to a real .glb/.tscn visual. Leave unset to keep
##                  using the placeholder primitive. When set, Prop.setup() instances this
##                  scene instead of building a primitive mesh; collision still comes from
##                  size/shape, so gameplay/simulation code never needs to change.
##                  Convention: res://assets/props/<category>/<prop_id>.glb
##   allowed_room_ids -> OPTIONAL Array[String] of RoomProfiles room_ids this prop may be
##                  placed in. Omitted or empty means "allowed in every room" (the default,
##                  and current behavior for every prop below). A future prop can restrict
##                  itself with e.g. ["dragon"] without any per-room if/else in room_editor.gd
##                  or hud.gd -- see is_allowed_in_room() below.
const DEFS: Dictionary = {
	"bed": {
		"name": "Bed",
		"color": Color(0.55, 0.27, 0.68),
		"shape": "box",
		"size": Vector3(0.9, 0.35, 1.6),
		"tags": ["bed", "furniture", "junk"],
		"asset_scene": "res://assets/props/bed_visual.tscn",
		"max_count": 1,
	},
	"food": {
		"name": "Food Scraps",
		"color": Color(0.65, 0.45, 0.15),
		"shape": "box",
		"size": Vector3(0.5, 0.25, 0.5),
		"tags": ["food", "junk"],
	},
	"chest": {
		"name": "Storage Chest",
		"color": Color(0.4, 0.3, 0.15),
		"shape": "box",
		"size": Vector3(0.8, 0.6, 0.5),
		"tags": ["storage", "junk"],
		"asset_scene": "res://assets/props/chest_visual.tscn",
		"max_count": 1,
	},
	"torch": {
		"name": "Torch",
		"color": Color(1.0, 0.55, 0.05),
		"shape": "cylinder",
		"size": Vector3(0.15, 1.2, 0.15),
		"tags": ["light", "bright_light"],
		"asset_scene": "res://assets/props/torch_visual.tscn",
		"max_count": 5,
		"wall_mount": true,
	},
	"window": {
		"name": "Window",
		"color": Color(0.65, 0.85, 1.0),
		"shape": "box",
		"size": Vector3(1.0, 1.2, 0.1),
		"tags": ["light", "bright_light", "window"],
	},
	"trap": {
		"name": "Spike Trap",
		"color": Color(0.75, 0.05, 0.05),
		"shape": "box",
		"size": Vector3(0.8, 0.1, 0.8),
		"tags": ["trap", "hazard"],
		"asset_scene": "res://assets/props/beartrap_visual.tscn",
	},
	"table": {
		"name": "Fancy Table",
		"color": Color(0.65, 0.5, 0.2),
		"shape": "box",
		"size": Vector3(1.2, 0.5, 0.7),
		"tags": ["furniture", "expensive"],
		"asset_scene": "res://assets/props/table_visual.tscn",
	},
	"chair": {
		"name": "Fancy Chair",
		"color": Color(0.7, 0.55, 0.25),
		"shape": "box",
		"size": Vector3(0.5, 0.8, 0.5),
		"tags": ["furniture", "expensive"],
		"asset_scene": "res://assets/props/chair_visual.tscn",
	},
	"barrel": {
		"name": "Barrel",
		"color": Color(0.45, 0.32, 0.12),
		"shape": "cylinder",
		"size": Vector3(0.4, 0.7, 0.4),
		"tags": ["junk", "storage"],
		"asset_scene": "res://assets/props/barrel_visual.tscn",
	},
	"treasure": {
		"name": "Treasure Pile",
		"color": Color(1.0, 0.84, 0.0),
		"shape": "box",
		"size": Vector3(0.7, 0.5, 0.7),
		"tags": ["expensive", "shiny"],
	},
	"basket": {
		"name": "Basket", "color": Color(0.6, 0.45, 0.25), "shape": "box",
		"size": Vector3(0.4, 0.35, 0.4), "tags": ["storage", "junk"],
		"asset_scene": "res://assets/props/basket_visual.tscn",
	},
	"bone_pile": {
		"name": "Bone Pile", "color": Color(0.85, 0.82, 0.7), "shape": "box",
		"size": Vector3(0.5, 0.2, 0.5), "tags": ["junk", "decor"],
		"asset_scene": "res://assets/props/bonepile_visual.tscn",
	},
	"bookshelf": {
		"name": "Bookshelf", "color": Color(0.5, 0.35, 0.2), "shape": "box",
		"size": Vector3(0.4, 1.4, 0.9), "tags": ["furniture", "storage"],
		"asset_scene": "res://assets/props/bookshelf_visual.tscn",
	},
	"bread": {
		"name": "Bread", "color": Color(0.75, 0.55, 0.3), "shape": "box",
		"size": Vector3(0.3, 0.2, 0.2), "tags": ["food", "junk"],
		"asset_scene": "res://assets/props/bread_visual.tscn",
	},
	"bucket": {
		"name": "Bucket", "color": Color(0.5, 0.5, 0.55), "shape": "cylinder",
		"size": Vector3(0.3, 0.35, 0.3), "tags": ["storage", "junk"],
		"asset_scene": "res://assets/props/bucket_visual.tscn",
	},
	"cheese": {
		"name": "Cheese", "color": Color(0.95, 0.8, 0.3), "shape": "box",
		"size": Vector3(0.25, 0.2, 0.25), "tags": ["food", "junk"],
		"asset_scene": "res://assets/props/cheese_visual.tscn",
	},
	"crate": {
		"name": "Crate", "color": Color(0.55, 0.4, 0.22), "shape": "box",
		"size": Vector3(0.6, 0.6, 0.6), "tags": ["storage", "junk"],
		"asset_scene": "res://assets/props/crate_visual.tscn",
	},
	"cupboard": {
		"name": "Cupboard", "color": Color(0.45, 0.3, 0.18), "shape": "box",
		"size": Vector3(0.5, 1.3, 0.5), "tags": ["furniture", "storage"],
		"asset_scene": "res://assets/props/cupboard_visual.tscn",
	},
	"plate_scraps": {
		"name": "Plate Scraps", "color": Color(0.8, 0.75, 0.7), "shape": "box",
		"size": Vector3(0.35, 0.1, 0.35), "tags": ["food", "junk"],
		"asset_scene": "res://assets/props/platescraps_visual.tscn",
	},
	"sack": {
		"name": "Sack", "color": Color(0.65, 0.55, 0.4), "shape": "box",
		"size": Vector3(0.4, 0.5, 0.4), "tags": ["storage", "junk"],
		"asset_scene": "res://assets/props/sack_visual.tscn",
	},
	"stew_bowl": {
		"name": "Stew Bowl", "color": Color(0.7, 0.4, 0.2), "shape": "box",
		"size": Vector3(0.3, 0.2, 0.3), "tags": ["food", "junk"],
		"asset_scene": "res://assets/props/stewbowl_visual.tscn",
	},
	"stool": {
		"name": "Stool", "color": Color(0.6, 0.45, 0.28), "shape": "box",
		"size": Vector3(0.4, 0.5, 0.4), "tags": ["furniture"],
		"asset_scene": "res://assets/props/stool_visual.tscn",
	},
}

const PLACEMENT_ORDER: Array[String] = [
	"bed", "food", "chest", "torch", "window", "trap", "table", "chair", "barrel", "treasure",
	"basket", "bone_pile", "bookshelf", "bread", "bucket", "cheese", "crate", "cupboard",
	"plate_scraps", "sack", "stew_bowl", "stool"
]

static func get_def(prop_id: String) -> Dictionary:
	return DEFS.get(prop_id, {})

static func has_tag(prop_id: String, tag: String) -> bool:
	var def := get_def(prop_id)
	if def.is_empty():
		return false
	var tags: Array = def.get("tags", [])
	return tags.has(tag)

## -1 means unlimited (the default for any prop without an explicit cap).
static func get_max_count(prop_id: String) -> int:
	return int(get_def(prop_id).get("max_count", -1))

static func is_wall_mount(prop_id: String) -> bool:
	return bool(get_def(prop_id).get("wall_mount", false))

## True if prop_id may be placed in room_id. A prop with no
## "allowed_room_ids" entry (or an empty one) is allowed everywhere --
## every prop defined above resolves true for both existing rooms today.
## Room-specific prop packs (e.g. Dragon Treasure) opt into a restriction
## by listing the room ids they're allowed in.
static func is_allowed_in_room(prop_id: String, room_id: String) -> bool:
	var allowed: Array = get_def(prop_id).get("allowed_room_ids", [])
	if allowed.is_empty():
		return true
	return allowed.has(room_id)

## Placement family for the future placement/wall-mounting framework
## (#9 in the architecture pass): today only "floor" and "wall" exist,
## driven by the same wall_mount flag Torch already uses.
static func get_placement_type(prop_id: String) -> String:
	return "wall" if is_wall_mount(prop_id) else "floor"
