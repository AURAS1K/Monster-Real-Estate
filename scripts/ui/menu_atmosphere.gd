extends Control
## Subtle, code-generated "living illustration" layer for the Main Menu.
##
## Sits directly above the baked MenuBackground artwork (never modifies or
## replaces it) and adds small, precisely-positioned animated accents on
## top of it: fireplace flicker, candle/lantern flicker, thin rising smoke,
## drifting dust motes, and a faint goblin "breathing" cue. Every visual
## here is generated at runtime from code (gradients/particles) -- no new
## image assets are added, matching how menu_dust_motes.gd/room_ambience.gd
## build their effects for the 3D room.
##
## Purely additive/cosmetic. Never touches the MenuBackground texture,
## button nodes or signals, the Room/MenuGoblin/MenuDressing 3D dressing
## (a separate, Main-Menu-only system already wired up in main.gd), or
## Build Mode. This node is 2D/Control-only and has nothing to do with
## that 3D dressing -- it does not duplicate or replace it.
##
## Positions below are fractions (0..1) of the full-screen artwork,
## matched by eye to res://assets/Image Assets/Main Menu.png. The design
## canvas is locked at 1920x1080 by the project's canvas_items stretch
## mode, so fractional placement stays correct across window sizes.

const DESIGN_SIZE := Vector2(1920.0, 1080.0)

@onready var _bg: TextureRect = get_parent().get_node("MenuBackground")

var _rng := RandomNumberGenerator.new()
var _glow_tex: GradientTexture2D
var _soft_dot_tex: GradientTexture2D

# Each entry: sprite, base_pos, base_scale, base_alpha, noise, speed,
# amp_scale, amp_alpha, amp_y -- driven every frame in _process().
var _flickers: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = -1
	_rng.randomize()

	_glow_tex = _make_radial_texture(96, 0.15)
	_soft_dot_tex = _make_radial_texture(24, 0.05)

	_add_fireplace_glow()

	# Candle / lantern flicker points.
	_add_flicker(Vector2(0.288, 0.365), 24.0, Color(1.0, 0.8, 0.5), 0.5)     # mantel candle pair
	_add_flicker(Vector2(0.277, 0.585), 13.0, Color(1.0, 0.76, 0.42), 0.36)  # table candle
	_add_flicker(Vector2(0.196, 0.255), 18.0, Color(1.0, 0.74, 0.4), 0.4)    # left lantern
	_add_flicker(Vector2(0.897, 0.255), 18.0, Color(1.0, 0.74, 0.4), 0.4)    # right lantern

	_add_smoke(Vector2(0.335, 0.455), 1.1, 6)    # fireplace smoke
	_add_smoke(Vector2(0.288, 0.335), 0.55, 4)   # candle smoke

	_add_dust_motes()
	_add_goblin_breath()


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for f in _flickers:
		var n: float = f.noise.get_noise_1d(t * f.speed)
		var n2: float = f.noise.get_noise_1d(t * f.speed * 2.1 + 50.0)
		f.sprite.modulate.a = clamp(f.base_alpha * (1.0 + n * f.amp_alpha), 0.0, 1.0)
		var s: float = f.base_scale * (1.0 + n2 * f.amp_scale)
		f.sprite.scale = Vector2(s, s)
		f.sprite.position = f.base_pos - Vector2(0.0, f.amp_y * max(n, 0.0))


# ---------------------------------------------------------------------------
# Generated textures
# ---------------------------------------------------------------------------

func _make_radial_texture(tex_size: int, hardness: float) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	grad.offsets = PackedFloat32Array([hardness, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = tex_size
	tex.height = tex_size
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


func _make_soft_box_mask() -> ImageTexture:
	var res := 48
	var feather := 0.22
	var img := Image.create(res, res, false, Image.FORMAT_RGBA8)
	for y in res:
		for x in res:
			var u := float(x) / float(res - 1)
			var v := float(y) / float(res - 1)
			var d: float = min(min(u, 1.0 - u), min(v, 1.0 - v))
			var a := smoothstep(0.0, feather, d)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _feather_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;

uniform sampler2D mask_tex : filter_linear;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float m = texture(mask_tex, UV).a;
	COLOR = vec4(c.rgb, c.a * m);
}
"""
	return sh


# ---------------------------------------------------------------------------
# Fire / candle / lantern flicker
# ---------------------------------------------------------------------------

func _add_fireplace_glow() -> void:
	# Bigger radius + stronger amplitude than the candles, but still a
	# small, carefully positioned accent -- not a full-fireplace particle
	# blast.
	_add_flicker(Vector2(0.335, 0.535), 58.0, Color(1.0, 0.55, 0.2), 0.4, 0.06, 0.22, 3.0)


func _add_flicker(pos_frac: Vector2, radius_px: float, color: Color, base_alpha: float,
		amp_scale: float = 0.03, amp_alpha: float = 0.14, amp_y: float = 1.5) -> void:
	var spr := Sprite2D.new()
	spr.texture = _glow_tex
	spr.centered = true
	spr.modulate = Color(color.r, color.g, color.b, base_alpha)

	var base_pos: Vector2 = pos_frac * DESIGN_SIZE
	var base_scale: float = radius_px / (float(_glow_tex.width) * 0.5)
	spr.position = base_pos
	spr.scale = Vector2(base_scale, base_scale)
	add_child(spr)

	var noise := FastNoiseLite.new()
	noise.seed = _rng.randi()
	noise.frequency = 1.0

	_flickers.append({
		"sprite": spr,
		"base_pos": base_pos,
		"base_scale": base_scale,
		"base_alpha": base_alpha,
		"noise": noise,
		"speed": _rng.randf_range(0.35, 0.55),
		"amp_scale": amp_scale,
		"amp_alpha": amp_alpha,
		"amp_y": amp_y,
	})


# ---------------------------------------------------------------------------
# Smoke / dust
# ---------------------------------------------------------------------------

func _add_smoke(pos_frac: Vector2, scale_mult: float, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.position = pos_frac * DESIGN_SIZE
	p.texture = _soft_dot_tex
	p.amount = amount
	p.lifetime = 7.0 * scale_mult
	p.preprocess = 2.0
	p.emitting = true
	p.direction = Vector2(0, -1)
	p.spread = 12.0
	p.gravity = Vector2(0, -2.0)
	p.initial_velocity_min = 3.0 * scale_mult
	p.initial_velocity_max = 7.0 * scale_mult
	p.angular_velocity_min = -4.0
	p.angular_velocity_max = 4.0
	p.tangential_accel_min = -1.5
	p.tangential_accel_max = 1.5
	p.scale_amount_min = 1.2 * scale_mult
	p.scale_amount_max = 2.6 * scale_mult
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 3.0

	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([
		Color(0.85, 0.8, 0.75, 0.0),
		Color(0.85, 0.8, 0.75, 0.16),
		Color(0.85, 0.8, 0.75, 0.0),
	])
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	p.color_ramp = ramp

	add_child(p)


func _add_dust_motes() -> void:
	var p := CPUParticles2D.new()
	# Roughly the warm-lit lower-left half of the room (table, fireplace,
	# rug) where firelight would catch floating dust.
	p.position = Vector2(0.34, 0.62) * DESIGN_SIZE
	p.texture = _soft_dot_tex
	p.amount = 26
	p.lifetime = 9.0
	p.preprocess = 4.0
	p.emitting = true
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, -1.0)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 4.0
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(0.30, 0.28) * DESIGN_SIZE * 0.5

	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([
		Color(1.0, 0.92, 0.78, 0.0),
		Color(1.0, 0.92, 0.78, 0.35),
		Color(1.0, 0.92, 0.78, 0.0),
	])
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	p.color_ramp = ramp

	add_child(p)


# ---------------------------------------------------------------------------
# Goblin breathing cue
# ---------------------------------------------------------------------------
#
# The goblin is baked into the artwork, so there's no separate cutout to
# move. Instead this crops a small region of the SAME background texture
# (an AtlasTexture region -- no new image asset), overlays it in the exact
# same spot with a soft feathered-edge mask so the crop seam is invisible
# at rest, and applies a tiny, slow breathing scale pulse plus an
# occasional barely-there posture shift -- deliberately much smaller than
# menu_goblin_idle.gd's 3D version, since this is a flat-image illusion,
# not an actual rig.

func _add_goblin_breath() -> void:
	if not (_bg and _bg.texture):
		return
	var tex_size: Vector2 = _bg.texture.get_size()

	# Bounding box around the goblin + clipboard, as a fraction of the
	# source artwork.
	var box_min := Vector2(0.655, 0.42)
	var box_max := Vector2(0.795, 0.72)
	var region := Rect2(box_min * tex_size, (box_max - box_min) * tex_size)

	var atlas := AtlasTexture.new()
	atlas.atlas = _bg.texture
	atlas.region = region

	var spr := TextureRect.new()
	spr.texture = atlas
	spr.stretch_mode = TextureRect.STRETCH_SCALE
	spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spr.position = box_min * DESIGN_SIZE
	spr.size = (box_max - box_min) * DESIGN_SIZE
	spr.pivot_offset = spr.size * Vector2(0.5, 1.0)  # breathe from the base, not center

	var mat := ShaderMaterial.new()
	mat.shader = _feather_shader()
	mat.set_shader_parameter("mask_tex", _make_soft_box_mask())
	spr.material = mat

	add_child(spr)
	_start_goblin_breathing(spr)


func _start_goblin_breathing(spr: TextureRect) -> void:
	var base_scale: Vector2 = spr.scale
	var tw := create_tween().set_loops()
	tw.tween_property(spr, "scale:y", base_scale.y * 1.012, 1.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(spr, "scale:y", base_scale.y, 1.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_schedule_goblin_beat(spr)


func _schedule_goblin_beat(spr: TextureRect) -> void:
	await get_tree().create_timer(_rng.randf_range(9.0, 17.0)).timeout
	if not is_instance_valid(spr):
		return
	var start_rot: float = spr.rotation
	var tw := create_tween()
	tw.tween_property(spr, "rotation", start_rot + deg_to_rad(_rng.randf_range(-0.6, 0.6)), 0.5) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_property(spr, "rotation", start_rot, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	_schedule_goblin_beat(spr)
