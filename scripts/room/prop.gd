extends Node3D
## Attached to the root of prop.tscn. Builds its own placeholder mesh/collision
## from PropDatabase at runtime based on prop_id, so a single template scene
## covers every prop type.

@export var prop_id: String = ""

var _is_selected: bool = false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var visual_container: Node3D = $Visual
@onready var collision_shape: CollisionShape3D = $StaticBody3D/CollisionShape3D
@onready var static_body: StaticBody3D = $StaticBody3D

## All MeshInstance3D nodes currently showing this prop's visual (the single
## placeholder mesh, OR every mesh inside an instanced real-asset scene).
## Selection/preview effects apply uniformly to whichever is active.
var _mesh_instances: Array[MeshInstance3D] = []
var _selection_mat: StandardMaterial3D = null
var _preview_mat: StandardMaterial3D = null
var _selection_ring: MeshInstance3D = null


func _ready() -> void:
	if prop_id != "":
		setup(prop_id)


func setup(id: String) -> void:
	prop_id = id
	var def := PropDatabase.get_def(id)
	if def.is_empty():
		push_warning("Unknown prop_id: %s" % id)
		return

	var size: Vector3 = def.get("size", Vector3.ONE)
	var color: Color = def.get("color", Color.WHITE)
	var shape: String = def.get("shape", "box")
	var asset_scene: String = def.get("asset_scene", "")

	# --- VISUAL: real asset if one is configured, else the placeholder primitive ---
	for c in visual_container.get_children():
		c.queue_free()
	mesh_instance.mesh = null

	if asset_scene != "" and ResourceLoader.exists(asset_scene):
		var packed: PackedScene = load(asset_scene)
		var inst: Node3D = packed.instantiate()
		visual_container.add_child(inst)
		_mesh_instances = _collect_mesh_instances(inst)
	else:
		var mesh: Mesh
		match shape:
			"cylinder":
				var cyl := CylinderMesh.new()
				cyl.top_radius = size.x
				cyl.bottom_radius = size.x
				cyl.height = size.y
				mesh = cyl
			_:
				var box := BoxMesh.new()
				box.size = Vector3(size.x * 2.0, size.y * 2.0, size.z * 2.0)
				mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		if mesh.get_surface_count() > 0:
			mesh.surface_set_material(0, mat)
		mesh_instance.mesh = mesh
		mesh_instance.material_override = mat
		mesh_instance.position.y = size.y
		_mesh_instances = [mesh_instance]

	# --- COLLISION: always generated from size/shape, regardless of visual source. ---
	# Real assets can carry their own collision later; until then this keeps
	# placement/selection/raycasts working identically for every prop.
	var col_shape: Shape3D
	match shape:
		"cylinder":
			var ccol := CylinderShape3D.new()
			ccol.radius = size.x
			ccol.height = size.y
			col_shape = ccol
		_:
			var bcol := BoxShape3D.new()
			bcol.size = Vector3(size.x * 2.0, size.y * 2.0, size.z * 2.0)
			col_shape = bcol
	collision_shape.shape = col_shape
	collision_shape.position.y = size.y

	# Half-height, used by other systems (movement targets, destruction FX).
	set_meta("half_height", size.y)


## Recursively collects every MeshInstance3D under a node (used for instanced
## real-asset scenes, which may have several parts e.g. LeftJaw/RightJaw).
func _collect_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_collect_mesh_instances(child))
	return result


func get_display_name() -> String:
	return PropDatabase.get_def(prop_id).get("name", prop_id)


func has_tag(tag: String) -> bool:
	return PropDatabase.has_tag(prop_id, tag)


func set_selected(selected: bool) -> void:
	_is_selected = selected
	if selected and not _selection_mat:
		_selection_mat = StandardMaterial3D.new()
		_selection_mat.emission_enabled = true
		_selection_mat.emission = UITheme.GOLD_BRIGHT
		_selection_mat.emission_energy_multiplier = 0.9
		_selection_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	for mi in _mesh_instances:
		if is_instance_valid(mi):
			mi.material_overlay = _selection_mat if selected else null
	# Ground ring: a small, tasteful "this is what Q/E rotates" indicator that
	# works identically for placeholder primitives and multi-part real GLBs,
	# since it's parented to the prop root rather than any specific mesh.
	if selected:
		_ensure_selection_ring().visible = true
	elif _selection_ring and is_instance_valid(_selection_ring):
		_selection_ring.visible = false


## Lazily builds a thin gold ring on the floor under the prop, used only
## while selected. Unshaded so it reads clearly regardless of room lighting.
func _ensure_selection_ring() -> MeshInstance3D:
	if _selection_ring and is_instance_valid(_selection_ring):
		return _selection_ring
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.46
	mesh.outer_radius = 0.56
	ring.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(UITheme.GOLD_BRIGHT, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	ring.position.y = 0.02
	add_child(ring)
	_selection_ring = ring
	return ring


## Ghost mode for the room-editor placement preview: non-colliding (so it
## never intercepts the room editor's own floor/prop raycasts), translucent,
## and gold-tinted so it reads clearly as "not placed yet" rather than a
## dim copy of the final object.
func set_preview(is_preview: bool) -> void:
	_set_collision_enabled(not is_preview)
	if is_preview and not _preview_mat:
		_preview_mat = StandardMaterial3D.new()
		_preview_mat.emission_enabled = true
		_preview_mat.emission = UITheme.GOLD
		_preview_mat.emission_energy_multiplier = 0.35
		_preview_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	# GeometryInstance3D.transparency fades any mesh uniformly, regardless of
	# its own material -- works for the placeholder AND real assets.
	for mi in _mesh_instances:
		if is_instance_valid(mi):
			mi.transparency = 0.55 if is_preview else 0.0
			mi.material_overlay = _preview_mat if is_preview else null


func _set_collision_enabled(enabled: bool) -> void:
	var mask_value: int = 1 if enabled else 0
	static_body.set_deferred("collision_layer", mask_value)
	static_body.set_deferred("collision_mask", mask_value)


## Simple "destroyed" reaction used by the simulator (goblin smashing things).
## Scales only the mesh (not the root) so the StaticBody3D under this node
## never receives a zero-scale transform -- Jolt Physics rejects singular
## bases and logs an error otherwise (same class of issue as the goblin
## squash/stretch fix).
func play_destroyed() -> void:
	_set_collision_enabled(false)
	var tw := create_tween()
	# Scale BOTH visual sources in parallel, not the StaticBody3D/root: only
	# one is ever populated (placeholder mesh_instance OR an instanced
	# real-asset scene under visual_container), but scaling the empty one
	# is harmless and keeps this correct for either case.
	tw.set_parallel(true)
	tw.tween_property(mesh_instance, "scale", Vector3.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(visual_container, "scale", Vector3.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)
