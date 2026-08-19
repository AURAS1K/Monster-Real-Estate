extends CharacterBody3D
## The one tenant in the prototype. Movement is deliberately simple:
## straight-line seeking toward a target, no navmesh/avoidance (LAW #5).
## room_simulator.gd drives this via the async helpers below.

class_name Goblin

signal died

@export var move_speed: float = 2.6
@export var turn_speed: float = 8.0

@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var label: Label3D = $ReactionLabel

var _base_scale: Vector3


func _ready() -> void:
	_base_scale = scale
	label.text = ""


## Moves in a straight line on the XZ plane toward target_pos. Resolves when arrived
## (or after a generous timeout, so a bad setup can never soft-lock the simulation).
func move_to(target_pos: Vector3, arrive_dist: float = 0.15) -> void:
	var timeout := 6.0
	var t := 0.0
	while true:
		var to_target := target_pos - global_position
		to_target.y = 0.0
		var dist := to_target.length()
		if dist <= arrive_dist or t >= timeout:
			break
		var dir := to_target.normalized()
		var desired_yaw := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, desired_yaw, get_process_delta_time() * turn_speed)
		global_position += dir * move_speed * get_process_delta_time()
		t += get_process_delta_time()
		await get_tree().process_frame
	global_position.x = target_pos.x
	global_position.z = target_pos.z


func face_towards(target_pos: Vector3) -> void:
	var dir := target_pos - global_position
	dir.y = 0.0
	if dir.length() > 0.01:
		rotation.y = atan2(dir.x, dir.z)


func say(text: String, duration: float = 1.1) -> void:
	label.text = text
	label.modulate.a = 1.0
	await get_tree().create_timer(duration).timeout
	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 0.0, 0.25)
	await tw.finished
	label.text = ""


func play_eat() -> void:
	await say("YUM.")
	await _squish_bounce()


func play_sleep() -> void:
	await say("zzz...")
	var tw := create_tween()
	tw.tween_property(self, "rotation:x", deg_to_rad(-88), 0.3)
	await tw.finished
	await get_tree().create_timer(0.6).timeout
	var tw2 := create_tween()
	tw2.tween_property(self, "rotation:x", 0.0, 0.3)
	await tw2.finished


func play_squint_and_declare_sun() -> void:
	await say("UGH.")
	await say("THIS IS THE SUN.", 1.3)


func play_angry() -> void:
	await say("GRR.")
	await _shake()


func play_death(cause_direction: Vector3 = Vector3.ZERO) -> void:
	label.text = "X_X"
	label.modulate.a = 1.0
	var tw := create_tween()
	tw.set_parallel(true)
	var launch_dir := cause_direction.normalized() if cause_direction.length() > 0.01 else Vector3(0, 1, 0)
	tw.tween_property(self, "global_position", global_position + launch_dir * 1.5 + Vector3(0, 2.5, 0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation:z", deg_to_rad(540), 0.35)
	await tw.finished
	died.emit()


func play_happy_dance() -> void:
	await say("YAY!")
	for i in range(2):
		var tw := create_tween()
		tw.tween_property(self, "position:y", position.y + 0.35, 0.15).set_trans(Tween.TRANS_SINE)
		tw.tween_property(self, "position:y", position.y, 0.15).set_trans(Tween.TRANS_SINE)
		await tw.finished


func _squish_bounce() -> void:
	var tw := create_tween()
	tw.tween_property(body_mesh, "scale", Vector3(1.25, 0.75, 1.25), 0.12)
	tw.tween_property(body_mesh, "scale", Vector3.ONE, 0.18)
	await tw.finished


func _shake() -> void:
	var start_x := position.x
	var tw := create_tween()
	for i in range(4):
		tw.tween_property(self, "position:x", start_x + (0.12 if i % 2 == 0 else -0.12), 0.06)
	tw.tween_property(self, "position:x", start_x, 0.06)
	await tw.finished
