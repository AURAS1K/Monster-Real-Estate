extends Node3D
## Grid-based prop placement/removal/rotation for the single prototype room.
## Attached to the Room scene root.
##
## Two explicit, non-overlapping interaction modes. This replaces the old
## "guess whether the cursor is hovering a prop via a distance-threshold
## raycast on every keypress" approach, which was the actual cause of Q/E
## being inconsistent -- there was no real state, just a hopeful re-raycast.
##
##  PLACING (active_prop_id != ""): a prop button is toggled on in the HUD.
##    A translucent, non-colliding preview follows the mouse every frame
##    (see _process). Q/E rotate the preview/pending rotation. Left click
##    commits it as a real prop. Right click cancels placement.
##
##  SELECTED (selected_prop != null): left-clicking an already-placed prop
##    selects it (highlighted via Prop.set_selected). Q/E rotate that exact
##    node's rotation_degrees.y -- position is never touched. Right click on
##    a placed prop always deletes it, regardless of mode.

signal placement_cancelled

const GRID_SIZE: float = 0.5
const PROP_SCENE := preload("res://scenes/props/prop.tscn")

## Per-room data: node names (siblings of this Room root) for the dressing
## instance/floor/wall-collider group/entrance marker, plus placement bounds
## that leave a small margin from each room's actual floor edge/walls so
## props don't clip through geometry while still covering almost the whole
## floor. Sourced from RoomProfiles.PROFILES (scripts/data/room_profiles.gd)
## -- the single data-driven definition of every room -- rather than a
## second hardcoded dict here. Add a new entry to RoomProfiles (+ matching
## nodes in room.tscn) to support another room without touching the
## placement/selection/rotation code below.
const ROOM_DEFS := RoomProfiles.PROFILES
const DEFAULT_ROOM_ID := RoomProfiles.DEFAULT_ROOM_ID

@onready var props_container: Node3D = $PropsContainer

var current_room_id: String = DEFAULT_ROOM_ID
var _half_extent_x: float = 6.8
var _half_extent_z: float = 5.8

var active_prop_id: String = ""
var placed_props: Array[Node3D] = []
var selected_prop: Node3D = null

## Rotation (Y, degrees) applied to the preview / the next placed prop.
var pending_rotation_deg: int = 0

var _preview: Node3D = null


func _ready() -> void:
	# The preview already stops rendering itself once state != BUILD (see
	# _process below), but the SELECTED highlight has no per-frame guard --
	# without this, a prop clicked right before TEST ROOM would stay visibly
	# "selected" through the whole simulation.
	GameManager.state_changed.connect(_on_game_state_changed)
	# GR_Beams is a nested node inside the GoblinMapDressing GLB instance --
	# scene-file property overrides on it don't persist (no "editable
	# children" for that instance), so hide it here at runtime instead.
	var beams := get_node_or_null("GoblinMapDressing/GoblinRoom/GR_Beams")
	if beams:
		beams.visible = false
	_setup_ambience()
	_setup_menu_materials()
	_apply_room_state(current_room_id)


func _on_game_state_changed(new_state) -> void:
	if new_state != GameManager.State.BUILD:
		_select_prop(null)


func _process(_delta: float) -> void:
	_update_ambience(_delta)
	if GameManager.current_state != GameManager.State.BUILD or active_prop_id == "":
		_clear_preview()
		return
	var raycast := _raycast_floor(get_viewport().get_mouse_position())
	if not raycast.get("hit", false):
		if _preview:
			_preview.visible = false
		return
	_ensure_preview()
	_preview.visible = true
	_preview.global_position = raycast["pos"]
	_preview.rotation_degrees.y = pending_rotation_deg


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_state != GameManager.State.BUILD:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			_rotate_step(-90)
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_E:
			_rotate_step(90)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
			return  # leave middle-click/wheel to the camera controller
		var raycast := _raycast_floor(event.position)
		var hit_pos: Vector3 = raycast.get("pos", Vector3.ZERO)
		var hit_prop: Node3D = null
		if raycast.get("hit", false):
			hit_prop = _prop_from_collider(raycast.get("collider"))
			if hit_prop == null:
				hit_prop = _find_prop_near(hit_pos)  # fallback for non-collider hits

		if event.button_index == MOUSE_BUTTON_LEFT:
			if active_prop_id != "":
				if raycast.get("hit", false):
					_try_place(hit_pos)
			else:
				_select_prop(hit_prop)
			get_viewport().set_input_as_handled()

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if hit_prop != null:
				_delete_prop(hit_prop)
			elif active_prop_id != "":
				_cancel_placement()
			# else: empty floor, not placing -- deliberately a no-op
			get_viewport().set_input_as_handled()


## PLACING mode rotates the pending/preview rotation only. SELECTED mode
## rotates that exact node's Y rotation only -- position untouched.
func _rotate_step(delta_deg: int) -> void:
	if active_prop_id != "":
		pending_rotation_deg = wrapi(pending_rotation_deg + delta_deg, 0, 360)
	elif selected_prop != null and is_instance_valid(selected_prop):
		selected_prop.rotation_degrees.y = wrapi(int(selected_prop.rotation_degrees.y) + delta_deg, 0, 360)


func _find_prop_near(pos: Vector3) -> Node3D:
	for p in placed_props:
		if is_instance_valid(p) and p.global_position.distance_to(pos) < 0.35:
			return p
	return null


## Walks up from a raycast collider (e.g. a Prop's StaticBody3D) to find the
## placed Prop root that owns it. Preferred over _find_prop_near's snapped-
## floor-position proximity search, which can miss tall props: the ray can
## land on top of a prop's collision box at an XZ far enough from the prop's
## base that snapping it to the grid puts it outside the selection threshold.
## Going straight from collider -> owning Prop sidesteps that entirely and
## works identically for placeholder and real-GLB props of any size.
func _prop_from_collider(collider: Object) -> Node3D:
	if collider == null:
		return null
	var node: Node = collider as Node
	# Guard with `is Node3D` before the membership test: placed_props is a
	# typed Array[Node3D], and walking past the Prop root eventually reaches
	# non-Node3D ancestors (this Room's own parents, up to the Window root) --
	# testing those against the typed array throws a validation error rather
	# than just failing the check. Stopping at `self` (this Room node, the
	# scene root this script is attached to) also avoids walking past the
	# room into the rest of the tree at all.
	while node != null and node != self:
		if node is Node3D and placed_props.has(node):
			return node
		node = node.get_parent()
	return null


func _select_prop(prop: Node3D) -> void:
	if selected_prop == prop:
		return
	if selected_prop and is_instance_valid(selected_prop):
		selected_prop.call("set_selected", false)
	selected_prop = prop
	if selected_prop:
		selected_prop.call("set_selected", true)


func _delete_prop(prop: Node3D) -> void:
	if selected_prop == prop:
		selected_prop = null
	placed_props.erase(prop)
	prop.queue_free()


func _cancel_placement() -> void:
	active_prop_id = ""
	pending_rotation_deg = 0
	_clear_preview()
	placement_cancelled.emit()


## Raycasts from a screen-space mouse position onto the floor and returns
## {"hit": true, "pos": Vector3} on success or {"hit": false} on a miss.
## (A Dictionary instead of a nullable Vector3 so callers can use `:=`
## without tripping the project's "inferred from Variant" error.)
func _raycast_floor(screen_pos: Vector2) -> Dictionary:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return {"hit": false}
	var from: Vector3 = cam.project_ray_origin(screen_pos)
	var dir: Vector3 = cam.project_ray_normal(screen_pos)
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 100.0)
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return {"hit": false}
	return {"hit": true, "pos": _snap(result.position), "collider": result.get("collider")}


func _snap(pos: Vector3) -> Vector3:
	var x: float = clamp(round(pos.x / GRID_SIZE) * GRID_SIZE, -_half_extent_x, _half_extent_x)
	var z: float = clamp(round(pos.z / GRID_SIZE) * GRID_SIZE, -_half_extent_z, _half_extent_z)
	return Vector3(x, 0.0, z)


## Switches the active playable room: swaps which dressing/floor/wall-
## collider group is visible+collidable, resets placement bounds, clears
## any props placed in the previous room, and re-syncs the camera's pan
## bound to the new room's size. Unknown room_id is a no-op.
func switch_room(room_id: String) -> void:
	if not ROOM_DEFS.has(room_id) or room_id == current_room_id:
		return
	_select_prop(null)
	clear_all_props()
	current_room_id = room_id
	_apply_room_state(room_id)


func _apply_room_state(room_id: String) -> void:
	var def: Dictionary = ROOM_DEFS.get(room_id, ROOM_DEFS[DEFAULT_ROOM_ID])
	_half_extent_x = def["half_x"]
	_half_extent_z = def["half_z"]
	for id in ROOM_DEFS.keys():
		var d: Dictionary = ROOM_DEFS[id]
		var active: bool = id == room_id
		_set_room_group_active(d["dressing"], active)
		_set_room_group_active(d["floor"], active, 1)
		_set_room_group_active(d["walls"], active, 2)
	var cam := get_node_or_null("../Camera3D")
	if cam == null:
		cam = get_viewport().get_camera_3d()
	if cam and cam.has_method("set_room_bounds"):
		cam.call("set_room_bounds", _half_extent_x, _half_extent_z)
	# Per-room camera framing overrides (RoomProfiles.PROFILES[room_id]["camera"]).
	# Empty for every room today, so this is a no-op until a room profile
	# actually supplies build/presentation/top overrides.
	if cam and cam.has_method("apply_room_profile"):
		cam.call("apply_room_profile", def)


## Toggles visibility for a dressing group, and visibility + collision_layer
## for a floor/wall-collider group (layer_when_active 0 means "not a
## collider group, just toggle visibility").
func _set_room_group_active(node_name: String, active: bool, layer_when_active: int = 0) -> void:
	var n := get_node_or_null(node_name)
	if n == null:
		return
	n.visible = active
	if layer_when_active == 0:
		return
	if n is StaticBody3D:
		(n as StaticBody3D).collision_layer = layer_when_active if active else 0
	for child in n.get_children():
		if child is StaticBody3D:
			(child as StaticBody3D).collision_layer = layer_when_active if active else 0


## Used by RoomSimulator (TEST ROOM) instead of a hardcoded $Entrance --
## each room defines its own entrance marker name in ROOM_DEFS.
func get_active_entrance() -> Marker3D:
	var def: Dictionary = ROOM_DEFS.get(current_room_id, ROOM_DEFS[DEFAULT_ROOM_ID])
	return get_node_or_null(def["entrance"]) as Marker3D


## Called by the HUD when a prop button is toggled. Entering placement mode
## always clears any existing selection -- the two modes never overlap.
func set_active_prop(prop_id: String) -> void:
	_select_prop(null)
	if prop_id != active_prop_id:
		pending_rotation_deg = 0  # new prop type starts facing default
	active_prop_id = prop_id
	if prop_id == "":
		_clear_preview()


func _ensure_preview() -> void:
	if _preview and is_instance_valid(_preview) and String(_preview.get("prop_id")) == active_prop_id:
		return
	_clear_preview()
	_preview = PROP_SCENE.instantiate() as Node3D
	props_container.add_child(_preview)
	_preview.call("setup", active_prop_id)
	_preview.call("set_preview", true)


func _clear_preview() -> void:
	if _preview and is_instance_valid(_preview):
		_preview.queue_free()
	_preview = null


func _try_place(pos: Vector3) -> void:
	if active_prop_id == "":
		return
	var max_props: int = int(GameManager.current_monster.get("max_props", 10))
	if placed_props.size() >= max_props:
		return
	var per_prop_max := PropDatabase.get_max_count(active_prop_id)
	if per_prop_max >= 0 and count_placed(active_prop_id) >= per_prop_max:
		return  # hit this prop's placement cap (e.g. Bed 1/1) -- HUD already reflects this
	if _find_prop_near(pos) != null:
		return  # occupied
	var inst := PROP_SCENE.instantiate() as Node3D
	props_container.add_child(inst)
	inst.global_position = pos
	inst.rotation_degrees.y = pending_rotation_deg
	inst.call("setup", active_prop_id)
	placed_props.append(inst)
	pending_rotation_deg = 0  # each new placement starts facing default again


## Count of currently-placed props matching prop_id -- used to enforce
## per-prop placement caps (PropDatabase.get_max_count) and to drive the
## HUD's "BED 1/1" style availability labels.
func count_placed(prop_id: String) -> int:
	var n := 0
	for p in get_placed_props():
		if String(p.get("prop_id")) == prop_id:
			n += 1
	return n


func clear_all_props() -> void:
	_select_prop(null)
	for p in placed_props:
		if is_instance_valid(p):
			p.queue_free()
	placed_props.clear()


func get_placed_props() -> Array[Node3D]:
	var valid: Array[Node3D] = []
	for p in placed_props:
		if is_instance_valid(p):
			valid.append(p)
	placed_props = valid  # self-heal: drop refs freed by the simulator (e.g. traps)
	return valid


func remaining_budget() -> int:
	return int(GameManager.current_monster.get("max_props", 10)) - placed_props.size()


# ---------------------------------------------------------------------------
# Ambience: cheap, purely cosmetic idle animation for a few existing pieces
# of the GoblinRoom dressing (torch flames flicker, cobwebs/chain sway).
# No new geometry, no materials touched, no camera/placement logic touched.
# Nodes are looked up once and cached; if a name is missing (e.g. dressing
# changes later) it's just skipped, never an error.
# ---------------------------------------------------------------------------
## GoblinMapDressing is an instanced GLB ("Goblin Room.glb") without
## "editable children" enabled, which means material_override / added-child
## edits saved to room.tscn on nested GR_* nodes get silently discarded the
## moment the scene reloads -- Godot just re-collapses the instance back to
## exactly what the packed GLB scene contains. GR_Beams' visibility above
## already worked around this by setting it at runtime instead of in the
## scene file; this does the same for materials + torch light sources so
## the room isn't flat untextured gray blockout every time the game runs.
func _setup_menu_materials() -> void:
	var stone := _mat(Color(0.38, 0.34, 0.30), 0.0, 0.9)
	var floor_mat := _mat(Color(0.26, 0.22, 0.19), 0.0, 0.85)
	var wood := _mat(Color(0.32, 0.19, 0.11), 0.0, 0.8)
	var wood_dark := _mat(Color(0.26, 0.15, 0.08), 0.0, 0.75)
	var metal := _mat(Color(0.09, 0.08, 0.08), 0.6, 0.5)
	var charred := _mat(Color(0.04, 0.03, 0.03), 0.0, 0.95)
	var bone := _mat(Color(0.78, 0.73, 0.6), 0.0, 0.7)
	var gold := _mat(Color(0.65, 0.42, 0.1), 0.7, 0.3)
	var chain_mat := _mat(Color(0.14, 0.13, 0.13), 0.7, 0.4)
	var moss := _mat(Color(0.22, 0.32, 0.14), 0.0, 0.9)
	var stain := _mat(Color(0.09, 0.06, 0.04), 0.0, 0.8)
	var clutter := _mat(Color(0.33, 0.24, 0.15), 0.0, 0.8)
	var flame := StandardMaterial3D.new()
	flame.albedo_color = Color(1.0, 0.28, 0.06)
	flame.emission_enabled = true
	flame.emission = Color(1.0, 0.35, 0.05)
	flame.emission_energy_multiplier = 4.0

	var assignments := {
		"GoblinMapDressing/GoblinRoom/GR_Wall_N": stone,
		"GoblinMapDressing/GoblinRoom/GR_Wall_S": stone,
		"GoblinMapDressing/GoblinRoom/GR_Wall_E": stone,
		"GoblinMapDressing/GoblinRoom/GR_Wall_W": stone,
		"GoblinMapDressing/GoblinRoom/GR_Floor": floor_mat,
		"GoblinMapDressing/GoblinRoom/GR_Door/GR_Door_Panel_J": wood_dark,
		"GoblinMapDressing/GoblinRoom/GR_GoblinDoor/GR_GoblinDoor_Panel_J": wood_dark,
		"GoblinMapDressing/GoblinRoom/GR_Chain": chain_mat,
		"GoblinMapDressing/GoblinRoom/GR_Bones_Corner/GR_Bones_M": bone,
		"GoblinMapDressing/GoblinRoom/GR_ExtraDressing": clutter,
		"GoblinMapDressing/GoblinRoom/GR_FoodMess/GR_FoodMess_M": _mat(Color(0.42, 0.2, 0.14), 0.0, 0.7),
		"GoblinMapDressing/GoblinRoom/GR_Moss": moss,
		"GoblinMapDressing/GoblinRoom/GR_Repairs": wood,
		"GoblinMapDressing/GoblinRoom/GR_Scratches": _mat(Color(0.16, 0.08, 0.05), 0.0, 0.85),
		"GoblinMapDressing/GoblinRoom/GR_Shelf_E": wood,
		"GoblinMapDressing/GoblinRoom/GR_Stains": stain,
		"GoblinMapDressing/GoblinRoom/GR_Treasure_Shrine/GR_Treasure_M": gold,
		"GoblinMapDressing/GoblinRoom/GR_Torch_Crooked/GR_Torch_Crooked_Arm": metal,
		"GoblinMapDressing/GoblinRoom/GR_Torch_Crooked/GR_Torch_Crooked_Char": charred,
		"GoblinMapDressing/GoblinRoom/GR_Torch_Crooked/GR_Torch_Crooked_Cup": metal,
		"GoblinMapDressing/GoblinRoom/GR_Torch_Crooked/GR_Torch_Crooked_Flame": flame,
		"GoblinMapDressing/GoblinRoom/GR_Torch_Crooked/GR_Torch_Crooked_Plate": metal,
		"GoblinMapDressing/GoblinRoom/GR_Torch_Crooked/GR_Torch_Crooked_Wood": wood,
		"GoblinMapDressing/GoblinRoom/GR_Torch_Door/GR_Torch_Door_Arm": metal,
		"GoblinMapDressing/GoblinRoom/GR_Torch_Door/GR_Torch_Door_Char": charred,
		"GoblinMapDressing/GoblinRoom/GR_Torch_Door/GR_Torch_Door_Cup": metal,
		"GoblinMapDressing/GoblinRoom/GR_Torch_Door/GR_Torch_Door_Flame": flame,
		"GoblinMapDressing/GoblinRoom/GR_Torch_Door/GR_Torch_Door_Plate": metal,
		"GoblinMapDressing/GoblinRoom/GR_Torch_Door/GR_Torch_Door_Wood": wood,
		"Floor/MeshInstance3D": floor_mat,
	}
	for path in assignments.keys():
		var n := get_node_or_null(path)
		if n and n is GeometryInstance3D:
			(n as GeometryInstance3D).material_override = assignments[path]

	for torch_path in [
		"GoblinMapDressing/GoblinRoom/GR_Torch_Crooked",
		"GoblinMapDressing/GoblinRoom/GR_Torch_Door",
	]:
		var torch := get_node_or_null(torch_path)
		if torch:
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.55, 0.2)
			light.light_energy = 4.5
			light.omni_range = 4.0
			light.position = Vector3(0, 0.45, 0.21)
			torch.add_child(light)


func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m


var _ambience_time: float = 0.0
var _flame_nodes: Array[Node3D] = []
var _sway_nodes: Array[Node3D] = []

func _setup_ambience() -> void:
	for path in [
		"GoblinMapDressing/GoblinRoom/GR_Torch_Crooked/GR_Torch_Crooked_Flame",
		"GoblinMapDressing/GoblinRoom/GR_Torch_Door/GR_Torch_Door_Flame",
	]:
		var n := get_node_or_null(path) as Node3D
		if n:
			_flame_nodes.append(n)
	for path in [
		"GoblinMapDressing/GoblinRoom/GR_Cobwebs",
		"GoblinMapDressing/GoblinRoom/GR_Chain",
	]:
		var n := get_node_or_null(path) as Node3D
		if n:
			_sway_nodes.append(n)


func _update_ambience(delta: float) -> void:
	if _flame_nodes.is_empty() and _sway_nodes.is_empty():
		return
	_ambience_time += delta
	# Flicker: small, slightly-offset scale pulses so the two torches don't
	# flicker in lockstep. Cheap -- one sin() per flame per frame.
	for i in _flame_nodes.size():
		var n := _flame_nodes[i]
		if not is_instance_valid(n):
			continue
		var t := _ambience_time * 6.0 + float(i) * 2.4
		var pulse := 1.0 + 0.08 * sin(t) + 0.04 * sin(t * 2.7 + 1.0)
		n.scale = Vector3.ONE * pulse
	# Sway: a very small rotational wobble for cobwebs/chain.
	for i in _sway_nodes.size():
		var n := _sway_nodes[i]
		if not is_instance_valid(n):
			continue
		var t := _ambience_time * 1.1 + float(i) * 1.7
		n.rotation.z = deg_to_rad(2.0) * sin(t)
