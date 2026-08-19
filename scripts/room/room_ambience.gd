extends Node
## Adds the room's ambient lighting setup (WorldEnvironment + a soft warm
## fill light) at runtime. The project previously had no WorldEnvironment
## at all, which is why the dressed room rendered as flat, high-contrast
## gray/black shapes ("build-mode blockout" look) instead of a warm lit
## dungeon: with no ambient light source, every surface facing away from
## the single DirectionalLight3D falls to pure black and the lit side
## reads as flat unlit gray.
##
## Purely cosmetic and additive -- creates new nodes only, never touches
## room_editor.gd, the GLB dressing, props, camera controls, or any
## gameplay/placement/economy logic. Safe to leave active in both the
## Main Menu and BUILD mode since it only affects how the existing room
## is lit, not anything about how it plays.

func _ready() -> void:
	var room := get_parent()

	var world_env := WorldEnvironment.new()
	world_env.name = "RoomEnvironment"

	var env := Environment.new()
	_apply_baseline(env)

	world_env.environment = env
	room.add_child.call_deferred(world_env)

	# Let the Settings panel's Brightness/Contrast sliders affect this
	# Environment live (purely additive -- adjustment_enabled defaults off
	# so this is a no-op until the player actually touches those sliders).
	GameSettings.register_environment(env)

	_env = env

	# Soft fill light opposite the key DirectionalLight3D so the room's
	# far/shadowed side (where the title UI sits, and where the goblin's
	# bed corner is) isn't a flat black wall. Color is room-profile
	# overridable (see EnvironmentProfiles "fill_light_color") -- the
	# literal Color(0.72, 0.6, 0.5) below is only the safe default that
	# matches today's Goblin baseline exactly (also DEFAULT_FILL_LIGHT_COLOR
	# below), used whenever a room's profile doesn't set fill_light_color
	# (every room except Wizard today). Created before the first
	# _apply_room_profile call below so that call can already reach it.
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.light_color = DEFAULT_FILL_LIGHT_COLOR
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-35.0, 150.0, 0.0)
	room.add_child.call_deferred(fill)
	_fill_light = fill

	# Apply whichever room is already active (goblin at boot) -- a
	# visual no-op for goblin (empty "environment" profile matches
	# baseline exactly), but Wizard now gets its own cooler fill/ambient
	# via EnvironmentProfiles. Also listen for room switches so a
	# previous room's overrides never linger after switching back.
	_apply_room_profile(GameManager.current_room_id)
	GameManager.room_changed.connect(_apply_room_profile)


## The exact hardcoded baseline this file always used, factored out so
## room switching can reset to it before applying the new room's profile
## overrides -- otherwise a previous room's override would linger.
func _apply_baseline(env: Environment) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.035, 0.03)

	# Warm amber ambient fill so shadowed faces read as dim warm stone
	# instead of crushed black -- this is the single biggest fix for the
	# "gray blockout" look.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.32, 0.24)
	env.ambient_light_energy = 0.85

	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.3

	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.05

	env.fog_enabled = true
	env.fog_light_color = Color(0.5, 0.36, 0.26)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.0

	# SSAO adds cheap contact shadow depth in the corners/under furniture,
	# which reads as "handcrafted" rather than flat.
	env.ssao_enabled = true
	env.ssao_intensity = 1.2
	env.ssao_radius = 1.0


## Resets to the shared baseline, then layers on this room's "environment"
## overrides (see RoomProfiles.PROFILES / EnvironmentProfiles). Goblin's
## profile is still empty, so this stays a visual no-op for Goblin -- the
## opt-in only takes effect once a profile actually sets a key (Wizard,
## now). Also resets+overrides FillLight's color the same way, so a
## previous room's fill-light override never lingers after switching
## back (matches the existing Environment reset-then-override pattern).
func _apply_room_profile(room_id: String) -> void:
	if _env == null:
		return
	_apply_baseline(_env)
	EnvironmentProfiles.apply_overrides(_env, room_id)
	if _fill_light != null:
		_fill_light.light_color = EnvironmentProfiles.get_profile(room_id).get("fill_light_color", DEFAULT_FILL_LIGHT_COLOR)


## Safe default fill-light color -- matches today's Goblin baseline
## exactly, used whenever a room's profile doesn't set fill_light_color.
const DEFAULT_FILL_LIGHT_COLOR: Color = Color(0.72, 0.6, 0.5)

var _env: Environment = null
var _fill_light: DirectionalLight3D = null
