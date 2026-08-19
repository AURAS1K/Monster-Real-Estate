extends Node3D
## Attached to the root of each per-prop "visual wrapper" scene
## (res://assets/props/*_visual.tscn). These wrappers instance a shared,
## combined GLB (Assets.glb) that Blender exports with several top-level
## objects as siblings (e.g. Bed, Barrel, BearTrap, WallTorch all in one
## file). prop.gd's asset_scene expects a scene containing exactly ONE
## visual prop, so this script prunes the unwanted siblings at instance
## time, keeping only `keep_node_name` and re-centering it on the wrapper
## origin.
##
## This runs synchronously in _ready(), which fires before prop.gd (the
## caller that instances this wrapper) collects mesh instances -- so the
## pruned result is what prop.gd actually sees.
##
## Convention for future assets: point `keep_node_name` at the exact
## top-level node name Blender/QWEN gives the object inside the combined
## GLB. If a GLB only ever contains one object, leave this blank and
## nothing is pruned.

@export var asset_container_name: String = "Assets"
@export var keep_node_name: String = ""
@export var recenter: bool = true


func _ready() -> void:
	if keep_node_name == "":
		return
	var container := get_node_or_null(NodePath(asset_container_name))
	if container == null:
		push_warning("asset_wrapper: no '%s' container found under %s" % [asset_container_name, name])
		return

	var kept: Node = null
	for child in container.get_children():
		if child.name == keep_node_name:
			kept = child
		else:
			container.remove_child(child)
			child.free()

	if kept == null:
		push_warning("asset_wrapper: '%s' not found in %s (check GLB top-level object names)" % [keep_node_name, asset_container_name])
		return

	if recenter and kept is Node3D:
		(kept as Node3D).position = Vector3.ZERO
		(kept as Node3D).rotation = Vector3.ZERO
