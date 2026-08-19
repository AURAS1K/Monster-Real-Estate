extends Node
## Autoload. Builds the game's single shared Theme resource and exposes the
## color palette as constants, so every UI screen looks consistent without
## hand-authoring StyleBoxFlat sub-resources inside every .tscn file.
##
## Screens use it as: `theme = UITheme.theme` in _ready(), then apply
## per-node "type variations" via `node.theme_type_variation = &"PrimaryButton"`
## etc. See the variation names built below.

# ---- Palette (warm dungeon: stone + parchment + gold) --------------------
const STONE_DARK  := Color(0.098, 0.086, 0.094)
const STONE       := Color(0.161, 0.137, 0.129)
const STONE_LIGHT := Color(0.267, 0.220, 0.192)
const STONE_EDGE  := Color(0.361, 0.290, 0.235)
const PARCHMENT      := Color(0.933, 0.886, 0.792)
const PARCHMENT_DIM  := Color(0.702, 0.651, 0.573)
const GOLD        := Color(0.851, 0.651, 0.161)
const GOLD_BRIGHT := Color(1.0, 0.804, 0.278)
const GREEN       := Color(0.463, 0.694, 0.384)
const RED         := Color(0.788, 0.271, 0.235)
const PURPLE      := Color(0.549, 0.427, 0.690)

var theme: Theme


func _ready() -> void:
	theme = _build_theme()


func _box(bg: Color, border: Color, radius: int, border_w: int, h_margin: int = 14, v_margin: int = 10, shadow_size: int = 0, shadow_color: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = h_margin
	s.content_margin_right = h_margin
	s.content_margin_top = v_margin
	s.content_margin_bottom = v_margin
	s.anti_aliasing = true
	if shadow_size > 0:
		s.shadow_size = shadow_size
		s.shadow_color = shadow_color
		s.shadow_offset = Vector2(0, 3)
	return s


func _plaque(wood: Color, border: Color, bevel: Color, rivet: Color, border_w: float, h_margin: float, v_margin: float) -> PlaqueStyleBox:
	var s := PlaqueStyleBox.new()
	s.wood_color = wood
	s.border_color = border
	s.bevel_color = bevel
	s.rivet_color = rivet
	s.border_width = border_w
	s.content_margin_h = h_margin
	s.content_margin_v = v_margin
	return s


func _poster(parchment: Color, border: Color, pin: Color, glow: Color, border_w: float, pins: int, h_margin: float, v_margin: float) -> PosterStyleBox:
	var s := PosterStyleBox.new()
	s.parchment_color = parchment
	s.border_color = border
	s.pin_color = pin
	s.glow_color = glow
	s.border_width = border_w
	s.pin_count = pins
	s.content_margin_h = h_margin
	s.content_margin_v = v_margin
	return s


func _build_theme() -> Theme:
	var t := Theme.new()

	var bold := FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 0.7

	# ---- Labels ----
	t.set_default_font_size(18)
	t.set_font_size(&"font_size", &"Label", 18)
	t.set_color(&"font_color", &"Label", PARCHMENT)

	t.set_type_variation(&"TitleLabel", &"Label")
	t.set_font(&"font", &"TitleLabel", bold)
	t.set_font_size(&"font_size", &"TitleLabel", 58)
	t.set_color(&"font_color", &"TitleLabel", PARCHMENT)

	t.set_type_variation(&"SectionLabel", &"Label")
	t.set_font(&"font", &"SectionLabel", bold)
	t.set_font_size(&"font_size", &"SectionLabel", 24)
	t.set_color(&"font_color", &"SectionLabel", GOLD_BRIGHT)

	t.set_type_variation(&"SecondaryLabel", &"Label")
	t.set_font_size(&"font_size", &"SecondaryLabel", 14)
	t.set_color(&"font_color", &"SecondaryLabel", PARCHMENT_DIM)

	t.set_type_variation(&"GoldLabel", &"Label")
	t.set_font(&"font", &"GoldLabel", bold)
	t.set_font_size(&"font_size", &"GoldLabel", 22)
	t.set_color(&"font_color", &"GoldLabel", GOLD_BRIGHT)

	t.set_type_variation(&"SuccessLabel", &"Label")
	t.set_font(&"font", &"SuccessLabel", bold)
	t.set_font_size(&"font_size", &"SuccessLabel", 34)
	t.set_color(&"font_color", &"SuccessLabel", GREEN)

	t.set_type_variation(&"DangerLabel", &"Label")
	t.set_font(&"font", &"DangerLabel", bold)
	t.set_font_size(&"font_size", &"DangerLabel", 34)
	t.set_color(&"font_color", &"DangerLabel", RED)

	t.set_type_variation(&"BodyBoldLabel", &"Label")
	t.set_font(&"font", &"BodyBoldLabel", bold)
	t.set_font_size(&"font_size", &"BodyBoldLabel", 18)
	t.set_color(&"font_color", &"BodyBoldLabel", PARCHMENT)

	# ---- Panels ----
	t.set_stylebox(&"panel", &"PanelContainer", _box(STONE, STONE_EDGE, 10, 2))

	t.set_type_variation(&"CardPanel", &"PanelContainer")
	t.set_stylebox(&"panel", &"CardPanel", _box(STONE, GOLD, 14, 2, 22, 20))

	t.set_type_variation(&"TitlePlaque", &"PanelContainer")
	# Carved wood/stone sign, not a translucent modern UI card: low corner
	# radius, a thick gold frame, and near-opaque so it reads as a physical
	# plaque hanging in the room rather than a floating glass panel.
	var plaque_box := _box(STONE_DARK, GOLD, 10, 4, 52, 26, 10, Color(0, 0, 0, 0.55))
	plaque_box.bg_color.a = 0.93
	t.set_stylebox(&"panel", &"TitlePlaque", plaque_box)

	t.set_type_variation(&"FlatPanel", &"PanelContainer")
	t.set_stylebox(&"panel", &"FlatPanel", _box(STONE_DARK, STONE_EDGE, 8, 1, 10, 6))

	t.set_type_variation(&"HintPanel", &"PanelContainer")
	var hint_box := _box(STONE_DARK, STONE_EDGE, 8, 1, 10, 8)
	hint_box.bg_color.a = 0.55
	t.set_stylebox(&"panel", &"HintPanel", hint_box)

	# ---- Buttons ----
	t.set_stylebox(&"normal", &"Button", _box(STONE_LIGHT, STONE_EDGE, 8, 2, 14, 10, 4, Color(0, 0, 0, 0.35)))
	t.set_stylebox(&"hover", &"Button", _box(STONE_LIGHT.lightened(0.15), GOLD, 8, 2, 14, 10, 5, Color(0, 0, 0, 0.4)))
	t.set_stylebox(&"pressed", &"Button", _box(STONE_DARK, GOLD, 8, 2, 14, 10, 2, Color(0, 0, 0, 0.3)))
	t.set_stylebox(&"disabled", &"Button", _box(STONE.darkened(0.2), STONE, 8, 1))
	t.set_color(&"font_disabled_color", &"Button", PARCHMENT_DIM.darkened(0.3))
	# Focus ring intentionally fully transparent: Godot buttons grab keyboard
	# focus on mouse click by default, which left a persistent bright
	# GOLD_BRIGHT-bordered rectangle around the last-clicked button (visible
	# as stray light horizontal/vertical edges on every menu screen). This is
	# a mouse-first fantasy UI with no keyboard nav, so the ring is pure
	# visual noise -- removing it removes the artifact at its source.
	t.set_stylebox(&"focus", &"Button", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 8, 0))
	t.set_color(&"font_color", &"Button", PARCHMENT)
	t.set_color(&"font_hover_color", &"Button", PARCHMENT)
	t.set_color(&"font_pressed_color", &"Button", GOLD_BRIGHT)
	t.set_color(&"font_disabled_color", &"Button", PARCHMENT_DIM)
	t.set_font_size(&"font_size", &"Button", 18)
	t.set_font(&"font", &"Button", bold)

	t.set_type_variation(&"PrimaryButton", &"Button")
	# Squarer corners than a typical web button (8 vs 12) so it reads as a
	# carved plaque rather than a rounded pill, with a thicker frame and
	# bigger label so it's unmistakably the dominant CTA.
	var wood_primary := Color(0.169, 0.106, 0.055)
	var bronze := Color(0.62, 0.44, 0.16)
	var bronze_dark := Color(0.4, 0.27, 0.09)
	t.set_stylebox(&"normal", &"PrimaryButton", _plaque(wood_primary, bronze, bronze_dark, bronze_dark, 6.0, 34, 18))
	t.set_stylebox(&"hover", &"PrimaryButton", _plaque(wood_primary.lightened(0.06), GOLD, bronze, bronze_dark, 6.0, 34, 18))
	t.set_stylebox(&"pressed", &"PrimaryButton", _plaque(wood_primary.darkened(0.2), bronze.darkened(0.15), bronze_dark.darkened(0.2), bronze_dark, 6.0, 34, 18))
	t.set_stylebox(&"disabled", &"PrimaryButton", _plaque(STONE.darkened(0.1), STONE_EDGE, STONE_EDGE, STONE_EDGE, 5.0, 34, 18))
	t.set_font_size(&"font_size", &"PrimaryButton", 30)
	t.set_font(&"font", &"PrimaryButton", bold)
	t.set_color(&"font_color", &"PrimaryButton", GOLD_BRIGHT)
	t.set_color(&"font_hover_color", &"PrimaryButton", GOLD_BRIGHT)
	t.set_color(&"font_pressed_color", &"PrimaryButton", GOLD)
	t.set_color(&"font_disabled_color", &"PrimaryButton", PARCHMENT_DIM)

	t.set_type_variation(&"SecondaryButton", &"Button")
	# Same carved-panel family as PrimaryButton -- a dim gold frame even at
	# rest -- just smaller/darker, so all four buttons visibly belong
	# together instead of Start Renting looking like the only "themed" one.
	var wood_dark := Color(0.169, 0.114, 0.078)
	var wood := Color(0.235, 0.161, 0.106)
	t.set_stylebox(&"normal", &"SecondaryButton", _plaque(wood, bronze, bronze_dark, bronze_dark, 4.0, 18, 10))
	t.set_stylebox(&"hover", &"SecondaryButton", _plaque(wood.lightened(0.08), GOLD, bronze, bronze_dark, 4.0, 18, 10))
	t.set_stylebox(&"pressed", &"SecondaryButton", _plaque(wood_dark, bronze.darkened(0.15), bronze_dark.darkened(0.2), bronze_dark, 4.0, 18, 10))
	t.set_stylebox(&"disabled", &"SecondaryButton", _plaque(STONE.darkened(0.2), STONE, STONE, STONE, 3.0, 18, 10))
	t.set_font_size(&"font_size", &"SecondaryButton", 19)
	t.set_color(&"font_color", &"SecondaryButton", PARCHMENT_DIM)
	t.set_color(&"font_hover_color", &"SecondaryButton", PARCHMENT)
	t.set_color(&"font_pressed_color", &"SecondaryButton", GOLD_BRIGHT)

	t.set_type_variation(&"PosterButton", &"Button")
	# Request Board poster-card buttons: the PNG background already IS the
	# poster (parchment, borders, pins, texture) -- this control exists
	# ONLY to provide a clickable hit area + selection feedback over that
	# existing artwork. It must never draw its own fill/border/parchment;
	# normal/hover/disabled are fully invisible, and "pressed" (which
	# doubles as *selected*, via toggle_mode + a shared ButtonGroup) draws
	# nothing but a thin gold outline -- no fill, no pins, no shadow.
	var invisible := StyleBoxEmpty.new()
	invisible.content_margin_left = 16
	invisible.content_margin_right = 16
	invisible.content_margin_top = 12
	invisible.content_margin_bottom = 12
	var selected_outline := StyleBoxFlat.new()
	selected_outline.bg_color = Color(0, 0, 0, 0)
	selected_outline.border_color = GOLD_BRIGHT
	selected_outline.set_border_width_all(2)
	selected_outline.set_corner_radius_all(6)
	selected_outline.content_margin_left = 16
	selected_outline.content_margin_right = 16
	selected_outline.content_margin_top = 12
	selected_outline.content_margin_bottom = 12
	selected_outline.shadow_size = 6
	selected_outline.shadow_color = Color(1.0, 0.82, 0.4, 0.35)
	t.set_stylebox(&"normal", &"PosterButton", invisible)
	t.set_stylebox(&"hover", &"PosterButton", invisible)
	t.set_stylebox(&"pressed", &"PosterButton", selected_outline)
	t.set_stylebox(&"disabled", &"PosterButton", invisible)
	t.set_stylebox(&"focus", &"PosterButton", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))
	t.set_font_size(&"font_size", &"PosterButton", 16)
	var poster_ink := Color(0.329, 0.212, 0.129)
	t.set_color(&"font_color", &"PosterButton", poster_ink)
	t.set_color(&"font_hover_color", &"PosterButton", poster_ink)
	t.set_color(&"font_pressed_color", &"PosterButton", poster_ink)
	t.set_color(&"font_disabled_color", &"PosterButton", poster_ink.lightened(0.15))

	t.set_type_variation(&"MenuHitboxButton", &"Button")
	# Used only on the Title Screen: the artwork's background image already
	# contains the final button plaques/text, so this variation draws
	# nothing of its own -- it exists purely to give Godot's real Button
	# nodes a clickable area over the baked-in button art. A faint warm
	# glow on hover/press gives pointer feedback without drawing a second
	# button on top of the artwork.
	var hitbox_normal := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 8, 0, 0, 0)
	var hitbox_hover := _box(Color(1.0, 0.85, 0.5, 0.05), Color(1.0, 0.85, 0.5, 0.22), 8, 2, 0, 0)
	var hitbox_pressed := _box(Color(1.0, 0.85, 0.5, 0.09), Color(1.0, 0.85, 0.5, 0.3), 8, 2, 0, 0)
	t.set_stylebox(&"normal", &"MenuHitboxButton", hitbox_normal)
	t.set_stylebox(&"hover", &"MenuHitboxButton", hitbox_hover)
	t.set_stylebox(&"pressed", &"MenuHitboxButton", hitbox_pressed)
	t.set_stylebox(&"disabled", &"MenuHitboxButton", hitbox_normal)
	t.set_stylebox(&"focus", &"MenuHitboxButton", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 8, 0))
	t.set_color(&"font_color", &"MenuHitboxButton", Color(0, 0, 0, 0))
	t.set_color(&"font_hover_color", &"MenuHitboxButton", Color(0, 0, 0, 0))
	t.set_color(&"font_pressed_color", &"MenuHitboxButton", Color(0, 0, 0, 0))
	t.set_color(&"font_disabled_color", &"MenuHitboxButton", Color(0, 0, 0, 0))

	t.set_type_variation(&"CloseButton", &"Button")
	# Small flat X used in the top-right corner of modal cards (Settings,
	# Credits/Terms, How To Play). Deliberately minimal -- no border/bg at
	# rest, just a faint gold glow on hover -- so it reads as a dismiss
	# affordance, not a fourth action competing with the primary button.
	var close_normal := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 8, 0, 0, 0)
	var close_hover := _box(Color(1.0, 0.85, 0.5, 0.08), GOLD, 8, 1, 0, 0)
	var close_pressed := _box(Color(1.0, 0.85, 0.5, 0.14), GOLD_BRIGHT, 8, 1, 0, 0)
	t.set_stylebox(&"normal", &"CloseButton", close_normal)
	t.set_stylebox(&"hover", &"CloseButton", close_hover)
	t.set_stylebox(&"pressed", &"CloseButton", close_pressed)
	t.set_stylebox(&"disabled", &"CloseButton", close_normal)
	t.set_stylebox(&"focus", &"CloseButton", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 8, 0))
	t.set_font_size(&"font_size", &"CloseButton", 22)
	t.set_color(&"font_color", &"CloseButton", PARCHMENT_DIM)
	t.set_color(&"font_hover_color", &"CloseButton", GOLD_BRIGHT)
	t.set_color(&"font_pressed_color", &"CloseButton", GOLD_BRIGHT)

	# ---- Progress / stat bars ----
	t.set_stylebox(&"background", &"ProgressBar", _box(STONE_DARK, STONE_EDGE, 6, 1, 0, 0))
	t.set_stylebox(&"fill", &"ProgressBar", _box(GOLD, GOLD, 6, 0, 0, 0))
	t.set_font_size(&"font_size", &"ProgressBar", 13)
	t.set_color(&"font_color", &"ProgressBar", PARCHMENT)

	t.set_type_variation(&"DangerBar", &"ProgressBar")
	t.set_stylebox(&"background", &"DangerBar", _box(STONE_DARK, STONE_EDGE, 6, 1, 0, 0))
	t.set_stylebox(&"fill", &"DangerBar", _box(RED, RED, 6, 0, 0, 0))
	t.set_font_size(&"font_size", &"DangerBar", 13)
	t.set_color(&"font_color", &"DangerBar", PARCHMENT)

	# ---- Scroll containers: keep transparent, no default panel look ----
	t.set_stylebox(&"panel", &"ScrollContainer", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 0, 0))

	return t
