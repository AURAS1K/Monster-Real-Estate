extends Node
## Subtle idle behavior for the decorative goblin that sits in the Main
## Menu's 3D room. Purely cosmetic -- lives as a child of a menu-only
## Goblin instance (MenuGoblin) and never touches goblin.gd or gameplay
## AI. This node has nothing to do with the separate Goblin instance
## room_simulator.gd drives during an actual test run.

@onready var goblin: Node3D = get_parent()
@onready var body_mesh: MeshInstance3D = goblin.get_node("BodyMesh")

var _base_mesh_scale: Vector3
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_base_mesh_scale = body_mesh.scale
	_breathe_loop()
	_schedule_next_beat()


## Slow, continuous breathing -- a gentle vertical scale pulse on the body.
func _breathe_loop() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(body_mesh, "scale:y", _base_mesh_scale.y * 1.035, 1.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(body_mesh, "scale:y", _base_mesh_scale.y, 1.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Alternates between a small posture shift and a rare "glance" reaction,
## on a long, randomized interval -- kept calm and premium rather than a
## rigid, frequent loop. Most beats are the subtle shift; the surprised
## glance is the occasional exception, not the norm.
func _schedule_next_beat() -> void:
	await get_tree().create_timer(_rng.randf_range(9.0, 17.0)).timeout
	if not is_instance_valid(goblin):
		return
	if _rng.randf() < 0.3:
		await _glance()
	else:
		await _shift_posture()
	_schedule_next_beat()


## Something catches its eye: a small head/body turn plus a tiny "!" beat,
## then it settles back. Deliberately restrained -- no dancing.
func _glance() -> void:
	var start_yaw := goblin.rotation.y
	var tw := create_tween()
	tw.tween_property(goblin, "rotation:y", start_yaw + deg_to_rad(_rng.randf_range(-16.0, 16.0)), 0.3).set_trans(Tween.TRANS_SINE)
	await tw.finished
	if goblin.has_method("say"):
		await goblin.say("!", 0.7)
	var tw2 := create_tween()
	tw2.tween_property(goblin, "rotation:y", start_yaw, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw2.finished


## Tiny sitting-posture adjustment -- a slight lean and settle, not a jump.
func _shift_posture() -> void:
	var start_z := goblin.rotation.z
	var tw := create_tween()
	tw.tween_property(goblin, "rotation:z", start_z + deg_to_rad(_rng.randf_range(-3.0, 3.0)), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(goblin, "rotation:z", start_z, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
