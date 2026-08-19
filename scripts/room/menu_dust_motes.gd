extends Node3D
## Faint, slow-drifting dust motes for the room. The only ambience piece
## room_editor.gd's existing _setup_ambience()/_update_ambience() doesn't
## already cover (torch flicker + cobweb/chain sway are handled there --
## this deliberately does NOT duplicate them). Built entirely in code so
## it doesn't depend on any external texture asset. Purely cosmetic and
## additive: touches nothing in room_editor.gd, GameManager, props, or
## the simulator.


func _ready() -> void:
	var particles := CPUParticles3D.new()
	particles.name = "DustMotes"
	particles.amount = 22
	particles.lifetime = 7.0
	particles.emitting = true
	particles.local_coords = false
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 180.0
	particles.gravity = Vector3(0, 0.02, 0)
	particles.initial_velocity_min = 0.02
	particles.initial_velocity_max = 0.07
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.4
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(3.2, 1.1, 3.2)
	particles.position = Vector3(0, 1.3, 0)

	var quad := QuadMesh.new()
	quad.size = Vector2(0.02, 0.02)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.92, 0.78, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	particles.mesh = quad

	add_child(particles)
