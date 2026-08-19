extends Node
## Data model + applier for per-room WorldEnvironment overrides.
##
## The live WorldEnvironment already exists (see room/room_ambience.gd,
## which builds the shared amber-dungeon baseline both Goblin and Wizard
## currently render with). This class does NOT own a second copy of
## per-room data -- it reads the "environment" dict RoomProfiles.PROFILES
## already reserves per room (see room_profiles.gd) and applies only the
## keys present there onto that shared Environment resource, leaving
## every other property at room_ambience.gd's baseline untouched.
##
## Empty {} (true for goblin + wizard today) means "use the baseline
## exactly as-is" -- this is what keeps today's visuals unchanged until a
## room profile actually opts into an override.
class_name EnvironmentProfiles

## Recognized override keys and how they map onto Environment properties.
## Intentionally a small, safe subset -- brightness/contrast are already
## owned by GameSettings (user-facing sliders) and are NOT duplicated
## here; a profile should never fight the player's own settings.
##
## One additional recognized key, "fill_light_color", is NOT applied by
## apply_overrides() below since it targets FillLight (a DirectionalLight3D
## sibling of the WorldEnvironment, not an Environment property) --
## RoomAmbience._apply_room_profile reads it directly via get_profile().
## Documented here so both the profile schema and its two appliers stay
## in one place.
static func get_profile(room_id: String) -> Dictionary:
	return RoomProfiles.get_profile(room_id).get("environment", {})


## Applies only the keys present in this room's profile onto `env`.
## Caller is responsible for having already reset `env` to the shared
## baseline first (see RoomAmbience._apply_room_profile) so switching
## rooms never leaves a previous room's overrides behind.
static func apply_overrides(env: Environment, room_id: String) -> void:
	if env == null:
		return
	var profile := get_profile(room_id)
	if profile.is_empty():
		return
	if profile.has("background_color"):
		env.background_color = profile["background_color"]
	if profile.has("ambient_light_color"):
		env.ambient_light_color = profile["ambient_light_color"]
	if profile.has("ambient_light_energy"):
		env.ambient_light_energy = profile["ambient_light_energy"]
	if profile.has("fog_enabled"):
		env.fog_enabled = profile["fog_enabled"]
	if profile.has("fog_color"):
		env.fog_light_color = profile["fog_color"]
	if profile.has("fog_density"):
		env.fog_density = profile["fog_density"]
	if profile.has("glow_enabled"):
		env.glow_enabled = profile["glow_enabled"]
	if profile.has("glow_intensity"):
		env.glow_intensity = profile["glow_intensity"]
