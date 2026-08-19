extends Node3D
## Purely cosmetic "menu room" dressing. Spawns a handful of furniture props,
## a lit torch, a goblin doing something dumb, and a few floating dust motes
## into the (otherwise empty, pre-game) Room, and gives the camera a fixed
## flattering angle -- all tagged with the "menu_dressing" group so a single
## call to cleanup() strips it back out before real gameplay/build-mode
## starts. Never touches PropDatabase/room_editor state, so it can't corrupt
## an actual save or placement.

const PropScene: PackedScene = preload("res://scenes/props/prop.tscn")
const GoblinScene: PackedScene = preload("res://scenes/monsters/goblin.tscn")

const MENU_CAMERA_POS := Vector3(3.6, 3.4, 5.6)
const MENU_CAMERA_LOOK := Vector3(-0.3, 0.6, -0.2)

var _room: Node3D
var _camera: Camera3D
var _torch_light: OmniLight3D
var _goblin: Node
var _flicker_seed: float = 0.0
var _cam_time: float = 0.0
var _cam_base_pos: Vector3
var _active: bool = false


func setup(room: Node3D) -> void:
	_room = room
	_camera = room.get_node("Camera3D")
	if _camera.has_method("set_input_enabled"):
		_camera.set_input_enabled(false)

	_cam_base_pos = MENU_CAMERA_POS
	_camera.global_position = MENU_CAMERA_POS
	_camera.look_at(MENU_CAMERA_LOOK, Vector3.UP)

	_spawn_environment()

	_spawn_prop("table", Vector3(-1.6, 0, -0.6), 0.3)
	_spawn_prop("chair", Vector3(-1.6, 0, 0.4), 2.6)
	_spawn_prop("chest", Vector3(1.9, 0, -1.4), -0.5)
	_spawn_prop("barrel", Vector3(2.1, 0, 0.6), 0.0)
	_spawn_prop("bed", Vector3(0.6, 0, -2.4), 0.0)
	_spawn_prop("bookshelf", Vector3(-2.3, 0, -2.2), 0.4)
	_spawn_prop("bread", Vector3(-1.75, 0.5, -0.55), 0.0)

	var torch: Node3D = _spawn_prop("torch", Vector3(-2.6, 0, -0.4), 0.0)
	_torch_light = OmniLight3D.new()
	_torch_light.light_color = Color(1.0, 0.65, 0.28)
	_torch_light.light_energy = 2.2
	_torch_light.omni_range = 4.5
	_torch_light.position = Vector3(0, 1.3, 0)
	torch.add_child(_torch_light)
	torch.add_to_group("menu_dressing")

	_spawn_dust()

	_goblin = GoblinScene.instantiate()
	_goblin.add_to_group("menu_dressing")
	_room.add_child(_goblin)
	_goblin.global_position = Vector3(-1.4, 0, 0.55)
	_goblin.rotation.y = deg_to_rad(-40)
	_loop_goblin_idle()

	_active = true
	set_process(true)


func cleanup() -> void:
	_active = false
	set_process(false)
	if is_instance_valid(_camera) and _camera.has_method("set_input_enabled"):
		_camera.set_input_enabled(true)
	if is_instance_valid(_camera) and _camera.has_method("reset_view"):
		_camera.reset_view()
	for n in get_tree().get_nodes_in_group("menu_dressing"):
		if is_instance_valid(n):
			n.queue_free()

	# The menu's own Environment is about to be freed -- hand Brightness/
	# Contrast control back to the room's persistent Environment so the
	# Settings sliders keep working once gameplay/build-mode starts.
	if is_instance_valid(_room):
		var room_env: WorldEnvironment = _room.get_node_or_null("RoomEnvironment")
		if room_env and room_env.environment:
			GameSettings.register_environment(room_env.environment)


## Warm, cozy dungeon mood for the menu specifically -- tagged into the
## menu_dressing group like everything else so cleanup() removes it and
## gameplay/build-mode gets the room's plain default environment back.
func _spawn_environment() -> void:
	var world_env := WorldEnvironment.new()
	world_env.add_to_group("menu_dressing")

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.04, 0.035)

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.3, 0.22)
	env.ambient_light_energy = 0.55

	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.2

	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0

	env.fog_enabled = true
	env.fog_light_color = Color(0.55, 0.4, 0.28)
	env.fog_density = 0.02
	env.fog_sky_affect = 0.0

	world_env.environment = env
	_room.add_child(world_env)

	# Let the Settings panel's Brightness/Contrast sliders affect the menu's
	# mood too while it's the active Environment.
	GameSettings.register_environment(env)


func _spawn_prop(prop_id: String, pos: Vector3, yaw: float) -> Node3D:
	var p: Node3D = PropScene.instantiate()
	p.add_to_group("menu_dressing")
	_room.add_child(p)
	p.setup(prop_id)
	p.position = pos
	p.rotation.y = yaw
	return p


func _spawn_dust() -> void:
	var particles := GPUParticles3D.new()
	particles.add_to_group("menu_dressing")
	particles.amount = 18
	particles.lifetime = 6.0
	particles.position = Vector3(-1.0, 1.4, -0.6)

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 40.0
	mat.gravity = Vector3(0, 0.05, 0)
	mat.initial_velocity_min = 0.03
	mat.initial_velocity_max = 0.1
	mat.scale_min = 0.01
	mat.scale_max = 0.025
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(1.6, 0.9, 1.2)
	particles.process_material = mat

	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.03, 0.03)
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.albedo_color = Color(1.0, 0.9, 0.7, 0.35)
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mesh_mat
	particles.draw_pass_1 = mesh

	_room.add_child(particles)


func _loop_goblin_idle() -> void:
	if not is_instance_valid(_goblin):
		return
	await get_tree().create_timer(1.2).timeout
	if not _active or not is_instance_valid(_goblin):
		return
	if _goblin.has_method("play_eat"):
		await _goblin.play_eat()
	if not _active or not is_instance_valid(_goblin):
		return
	await get_tree().create_timer(2.0).timeout
	if not _active or not is_instance_valid(_goblin):
		return
	if _goblin.has_method("play_happy_dance"):
		await _goblin.play_happy_dance()
	if _active:
		_loop_goblin_idle()


func _process(delta: float) -> void:
	_flicker_seed += delta
	if is_instance_valid(_torch_light):
		_torch_light.light_energy = 2.0 + sin(_flicker_seed * 9.0) * 0.15 + sin(_flicker_seed * 23.0) * 0.08

	_cam_time += delta
	if is_instance_valid(_camera):
		var drift := Vector3(sin(_cam_time * 0.15) * 0.06, sin(_cam_time * 0.11) * 0.03, 0.0)
		_camera.global_position = _cam_base_pos + drift
		_camera.look_at(MENU_CAMERA_LOOK, Vector3.UP)
