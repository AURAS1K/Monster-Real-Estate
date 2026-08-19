extends Control
## "Monster Guild Request Board": lets the player browse housing requests
## (one card per RequestData entry, grouped by room) and accept one to
## enter Build Mode. Pure UI layer over the existing architecture --
## reads RequestData/GameManager/LenderProgression, never duplicates their
## data. Selecting a card calls GameManager.select_request (or
## select_room for a room with no request registered yet, e.g. wizard
## today) so current_request/current_monster are already resolved by the
## time ACCEPT is pressed; main.gd's handler no longer needs to (and must
## not -- see its comment) call select_room again itself.
##
## REQUEST vs ROOM-ONLY entries: which one a room gets is derived purely
## from RequestData.room_has_requests(room_id) -- NOT a hardcoded id list.
## A room with zero registered requests (wizard, today) shows a room-only
## "preview" card instead of inventing fake request content for it. The
## moment real requests exist for that room (e.g. wizard_organized), it
## automatically becomes a normal request-card room with no UI change
## needed here. See _add_request_cards / _add_room_card below.
##
## Cards are built as PosterButton-themed Buttons (see ui_theme.gd +
## poster_stylebox.gd) with toggle_mode + a shared ButtonGroup, so
## exactly one poster is ever visually "selected" (its pressed stylebox)
## at a time -- the poster itself is the only selection control, per the
## board's interaction spec (no separate visible SELECT button).

signal room_selected(room_id: String)
signal back_pressed

@onready var list_box: Control = $RequestList
@onready var detail_label: RichTextLabel = $DetailLabel
@onready var accept_button: Button = $AcceptButton
@onready var back_button: Button = $BackButton
@onready var requirements_label: RichTextLabel = $RequirementsLabel
@onready var likes_label: RichTextLabel = $LikesLabel
@onready var hates_label: RichTextLabel = $HatesLabel

# --- Poster BBCode palette -- matches ui_theme.gd's warm dungeon palette,
# just as hex (RichTextLabel BBCode colors don't take Color consts
# directly). Kept local to this file since nothing else needs poster-ink
# colors specifically. Ink is near-black per the physical-poster spec --
# it must read clearly against the light parchment texture.
const _INK := "#1c1006"
const _INK_SOFT := "#3a2a18"
const _GREEN_HEADER := "#33591f"
const _RED_HEADER := "#8a2a20"
const _GOLD_TEXT := "#5c3a06"

# The reusable physical poster artwork (parchment, border, pins, texture
# -- see the checkpoint that imported it). One instance is placed per
# request/room-preview card; Godot only ever draws real data on top of
# it, never a second background. Preloaded once and reused across every
# card instead of load()-ing it per card.
const _POSTER_TEXTURE: Texture2D = preload("res://assets/UI Assets/Poster Request.png")

# 5-creature portrait sheet -- pixel regions measured directly against
# the 1536x1024 source (2 rows: goblin/wizard/dragon on top, vampire/
# witch below). One preload + one AtlasTexture per tenant, never a
# duplicated/cropped PNG. Rect coords are a first pass from visual
# inspection, not pixel-perfect -- flagged for a screenshot check.
const _PORTRAIT_SHEET: Texture2D = preload("res://assets/UI Assets/Fantasy Character Portrait Lineup.png")
const _PORTRAIT_REGIONS := {
	"goblin": Rect2(40, 0, 440, 520),
	"wizard": Rect2(540, 0, 440, 520),
	"dragon": Rect2(1040, 0, 440, 520),
	"vampire": Rect2(300, 560, 440, 460),
	"witch": Rect2(780, 560, 440, 460),
}

# Fractional box (within a card button) that the poster art's baked-in
# portrait frame occupies -- also a first pass from visual inspection.
const _PORTRAIT_BOX := Rect2(0.10, 0.17, 0.33, 0.28)

# --- Placement bounding boxes for each request/room-preview card, as
# fractions of the full board rect -- re-measured directly against a
# user screenshot (brightness-edge scan of the actual board artwork,
# not eyeballed). Originally these mapped 1:1 to blank parchment sheets
# baked into the board background; now that each card carries its own
# _POSTER_TEXTURE, these rects are the region that poster is fit inside
# (aspect preserved, never stretched -- see _make_poster_art), so a few
# px of letterboxing inside a box is expected and fine. 3 boxes match
# today's 3 live entries (goblin_default, goblin_sleepy, wizard
# preview); do not invent a 4th here.
const _POSTER_SLOTS: Array[Rect2] = [
	Rect2(0.20, 0.28, 0.20, 0.46),  # left poster
	Rect2(0.42, 0.32, 0.20, 0.46),  # center poster (slightly lower)
	Rect2(0.64, 0.30, 0.20, 0.46),  # right poster
]

# Subtle per-slot pin rotation (degrees) so the group reads as hand-pinned
# notices rather than a rigid grid. Kept tiny so text stays easy to read.
const _POSTER_ROTATIONS: Array[float] = [-1.0, 0.0, 1.0]

# Small glyph substitutes for the reference poster's hand-drawn icons.
# Plain punctuation/dingbat symbols only -- the game font has no emoji
# glyphs, so anything outside basic Latin-1/dingbat range renders as
# tofu boxes (confirmed via screenshot, not assumed).
const _TAG_ICONS := {
	"bed": "\u25C6",
	"food": "\u25C6",
	"storage": "\u25C6",
	"light": "\u25C6",
	"traps": "\u00D7",
	"loud noises": "\u00D7",
	"junk": "\u2665",
	"treasure": "\u2665",
}
const _TENANT_ICONS := {
	"goblin": "",
	"wizard": "",
}


func _icon_for_tag(tag: String) -> String:
	return _TAG_ICONS.get(tag.to_lower(), "\u2726")


func _icon_for_tenant(tenant_id: String) -> String:
	return _TENANT_ICONS.get(tenant_id.to_lower(), "\U0001F464")

var _selected_request_id: String = ""
var _selected_room_id: String = ""
var _card_group: ButtonGroup
var _next_slot: int = 0


func _set_accept_active(active: bool) -> void:
	accept_button.disabled = not active
	accept_button.mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	theme = UITheme.theme
	accept_button.pressed.connect(_on_accept_pressed)
	back_button.pressed.connect(func(): back_pressed.emit())
	_populate_list()


func _populate_list() -> void:
	for child in list_box.get_children():
		child.queue_free()
	_selected_request_id = ""
	_selected_room_id = ""
	detail_label.visible = false
	requirements_label.visible = false
	likes_label.visible = false
	hates_label.visible = false
	_set_accept_active(false)
	_card_group = ButtonGroup.new()
	_next_slot = 0

	for room_id in RoomProfiles.PROFILES.keys():
		if RequestData.room_has_requests(room_id):
			_add_request_cards(room_id)
		else:
			_add_room_card(room_id)


func _add_request_cards(room_id: String) -> void:
	for request_id in RequestData.requests_for_room(room_id):
		var request := RequestData.get_request(request_id)
		var unlocked: bool = GameManager.is_request_unlocked(request_id)
		_add_poster_card(request, unlocked, func(): _select_request(request_id))


## Room-only entry: a room with a RoomProfiles entry but zero registered
## RequestData rows (see RequestData.room_has_requests). Shown as a
## lighter "preview" poster instead of a request contract -- no fake
## rent/requirements/likes/hates are ever invented for it.
func _add_room_card(room_id: String) -> void:
	var profile := RoomProfiles.get_profile(room_id)
	var unlocked: bool = GameManager.is_room_unlocked(room_id)
	_add_room_only_card(room_id, profile, unlocked, func(): _select_room_only(room_id))


func _add_poster_card(request: Dictionary, unlocked: bool, on_selected: Callable) -> void:
	var slot = _take_slot()
	if slot == null:
		return  # all 3 wired boxes are already in use -- see _POSTER_SLOTS

	var tenant_id: String = request.get("tenant_id", "")
	var tenant_name: String = tenant_id.capitalize()
	var rent := int(request.get("rent", 0))
	var stars := "\u2605".repeat(int(request.get("difficulty", 1)))

	var btn := _make_card_button(unlocked)
	_apply_slot(btn, slot, _current_slot_rotation())
	btn.add_child(_make_poster_art())  # physical poster art, drawn first == behind the text below
	var portrait := _make_portrait_art(tenant_id)
	if portrait:
		btn.add_child(portrait)

	# Small physical poster -> compact contract summary only (tenant,
	# request title, rent + difficulty, a couple of tags if they fit).
	# Full detail lives on the large right parchment once selected -- see
	# _select_request. Centered VBox, no portrait/HBox: the posters are
	# narrow, so a single stacked column reads best.
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 5)
	btn.add_child(col)
	_anchor_full(col)

	col.add_child(_make_centered_label(tenant_name.to_upper(), 20, Color(0.133, 0.063, 0.024), true))
	col.add_child(_make_centered_label(String(request.get("title", "REQUEST")).to_upper(), 13, Color(_GREEN_HEADER), true))

	var teaser := String(request.get("request_description", ""))
	if not teaser.is_empty():
		var quote_lbl := _make_centered_label("\u201c%s\u201d" % teaser, 11, Color(_INK_SOFT))
		quote_lbl.add_theme_font_size_override("font_size", 11)
		col.add_child(quote_lbl)

	col.add_child(_make_centered_label("%d GOLD  %s" % [rent, stars], 16, Color(_GOLD_TEXT), true))

	var reqs := request.get("requirements", []) as Array
	if not reqs.is_empty():
		var shown: Array = reqs.slice(0, 2)
		var tag_names: Array = []
		for r in shown:
			tag_names.append("%s %s" % [_icon_for_tag(String(r)), String(r).capitalize()])
		col.add_child(_make_centered_label("   ".join(tag_names), 13, Color(_INK), true))

	if not unlocked:
		col.add_child(_make_locked_label(int(request.get("unlock_level", 1))))

	if unlocked:
		btn.pressed.connect(on_selected)
	list_box.add_child(btn)


## Called when a request poster is pressed. Delegates to GameManager so
## current_request/current_monster are resolved, then repaints the
## right-side parchment as a concise "guild contract" readout.
func _select_request(request_id: String) -> void:
	if not GameManager.select_request(request_id):
		return  # invalid/locked -- leave prior selection (if any) intact
	_selected_request_id = request_id
	_selected_room_id = ""
	var d: Dictionary = GameManager.current_monster
	var tenant_name := String(d.get("tenant_id", "")).capitalize()
	var stars := "\u2605".repeat(int(d.get("difficulty", 1)))
	var rent := int(d.get("rent", 0))

	# --- Big poster: title + quote + tenant/rent/difficulty "contract"
	# readout, styled like a real housing-request notice rather than a
	# dump of plain sentences.
	var poster := PackedStringArray()
	poster.append("[center][color=%s][b][font_size=26]%s[/font_size][/b][/color]" % [_INK, tenant_name.to_upper()])
	poster.append("[font_size=15]HOUSING REQUEST[/font_size]")
	poster.append("[font_size=12]- - - - - - - -[/font_size][/center]")
	var desc := String(d.get("request_description", ""))
	if not desc.is_empty():
		poster.append("")
		poster.append("[center][i][color=%s]\u201c%s\u201d[/color][/i][/center]" % [_INK_SOFT, desc])
	poster.append("")
	poster.append("[color=%s][b]TENANT[/b][/color]" % _GREEN_HEADER)
	poster.append(tenant_name)
	poster.append("")
	poster.append("[color=%s][b]MONTHLY RENT[/b][/color]" % _GREEN_HEADER)
	poster.append("[color=%s][b]%d GOLD[/b][/color]" % [_GOLD_TEXT, rent])
	poster.append("")
	poster.append("[color=%s][b]DIFFICULTY[/b][/color]" % _GREEN_HEADER)
	poster.append("[color=%s]%s[/color]" % [_GOLD_TEXT, stars])
	var special := String(d.get("special_room_rule", ""))
	if not special.is_empty():
		poster.append("")
		poster.append("[color=%s][b]SPECIAL RULE[/b][/color]" % _RED_HEADER)
		poster.append(special)
	detail_label.text = "\n".join(poster)
	detail_label.visible = true

	requirements_label.text = _bullet_section("REQUIREMENTS", _GREEN_HEADER, d.get("requirements", []) as Array, "\u2022")
	likes_label.text = _bullet_section("LIKES", _GREEN_HEADER, d.get("likes", []) as Array, "\u2665")
	hates_label.text = _bullet_section("HATES", _RED_HEADER, d.get("hates", []) as Array, "\u00d7")
	requirements_label.visible = true
	likes_label.visible = true
	hates_label.visible = true
	_set_accept_active(true)


## Shared builder for the three small poster panels (REQUIREMENTS/LIKES/
## HATES) -- a colored, centered header plus one bulleted line per tag,
## so all three panels read as matching "clauses" of the same contract
## instead of three differently-formatted lists.
func _bullet_section(title: String, header_color: String, tags: Array, bullet: String) -> String:
	var lines := PackedStringArray()
	lines.append("[center][color=%s][b]%s[/b][/color][/center]" % [header_color, title])
	if tags.is_empty():
		lines.append("[center][color=%s][i]none[/i][/color][/center]" % _INK_SOFT)
	else:
		for tag in tags:
			var glyph := _icon_for_tag(String(tag)) if bullet == "\u2022" else bullet
			lines.append("[color=%s]%s %s[/color]" % [_INK, glyph, String(tag).capitalize()])
	return "\n".join(lines)


## Room-only cards (e.g. wizard, which has no RequestData entry yet) --
## same accept flow, but the detail parchment reads as a plain room
## preview rather than a contract, and the requirement/likes/hates panels
## stay hidden since there's no request to describe. GameManager.
## select_room() clears current_request/current_request_id AND
## current_monster when the room has no registered tenant, so nothing
## from a previously-selected request (e.g. goblin) leaks through here.
func _select_room_only(room_id: String) -> void:
	if not GameManager.is_room_unlocked(room_id):
		return
	GameManager.select_room(room_id)
	_selected_request_id = ""
	_selected_room_id = room_id
	var profile := RoomProfiles.get_profile(room_id)
	var room_name := String(profile.get("name", room_id)).capitalize()
	var poster := PackedStringArray()
	poster.append("[center][color=%s][b][font_size=26]%s[/font_size][/b][/color]" % [_INK, room_name.to_upper()])
	poster.append("[font_size=15]ROOM PREVIEW[/font_size][/center]")
	poster.append("")
	poster.append("[center][i][color=%s]No formal request registered for this room yet.[/color][/i][/center]" % _INK_SOFT)
	poster.append("[center][i][color=%s]Entering will open Build Mode directly.[/color][/i][/center]" % _INK_SOFT)
	detail_label.text = "\n".join(poster)
	detail_label.visible = true
	requirements_label.visible = false
	likes_label.visible = false
	hates_label.visible = false
	_set_accept_active(true)


## Handler for both the (invisible) AcceptButton and, via it, clicks
## anywhere on the large right parchment (AcceptButton covers it -- see
## _set_accept_active). Re-validates at accept time rather than trusting
## selection-time state, in case unlock state changed underneath.
func _on_accept_pressed() -> void:
	if _selected_request_id.is_empty() and _selected_room_id.is_empty():
		return
	var room_id: String = GameManager.current_room_id
	if not RoomProfiles.has_profile(room_id) or not GameManager.is_room_unlocked(room_id):
		return
	room_selected.emit(room_id)


func show_screen() -> void:
	_populate_list()
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.97, 0.97)
	pivot_offset = size / 2.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Returns the next unused physical-parchment slot rect, or null once all
## 3 wired sheets (_POSTER_SLOTS) are taken. Callers must skip adding a
## card rather than falling back to any kind of stacking layout.
func _take_slot() -> Variant:
	if _next_slot >= _POSTER_SLOTS.size():
		return null
	var slot: Rect2 = _POSTER_SLOTS[_next_slot]
	_next_slot += 1
	return slot


## Rotation (degrees) paired with the slot just handed out by _take_slot,
## i.e. call immediately after _take_slot while _next_slot still lines up.
func _current_slot_rotation() -> float:
	var idx := _next_slot - 1
	if idx < 0 or idx >= _POSTER_ROTATIONS.size():
		return 0.0
	return _POSTER_ROTATIONS[idx]


## Anchors a card's button to exactly cover one physical parchment sheet.
## RequestList is a plain Control (not a Container), so size_flags/
## expand-fill on children do nothing -- every card previously defaulted
## to anchor (0,0) with zero size, which is why posters were landing on
## bare wood instead of on their parchment. Explicit anchors fix that.
func _apply_slot(btn: Control, slot: Rect2, slot_rotation_degrees: float = 0.0) -> void:
	btn.anchor_left = slot.position.x
	btn.anchor_top = slot.position.y
	btn.anchor_right = slot.end.x
	btn.anchor_bottom = slot.end.y
	btn.offset_left = 0
	btn.offset_top = 0
	btn.offset_right = 0
	btn.offset_bottom = 0
	btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	btn.grow_vertical = Control.GROW_DIRECTION_BOTH
	# Anchors give this Control its final size synchronously (RequestList
	# is a plain Control, not a Container, and its own size is already
	# resolved by the time cards are built), so pivoting around size/2 here
	# rotates the poster in place instead of swinging around its corner.
	btn.pivot_offset = btn.size / 2.0
	btn.rotation_degrees = slot_rotation_degrees


## The physical poster art itself (_POSTER_TEXTURE), fit inside whatever
## rect the card button ends up at -- aspect preserved, never stretched,
## per the checkpoint's "do not let the poster distort" requirement.
## KEEP_ASPECT_CENTERED does the containment math for us: if the box's
## aspect ratio doesn't match the art's, it letterboxes evenly instead
## of skewing. Non-interactive (MOUSE_FILTER_IGNORE) so clicks fall
## through to the button beneath it; added as the FIRST child of that
## button so text added afterward draws on top of it, never behind.
func _make_poster_art() -> TextureRect:
	var art := TextureRect.new()
	art.texture = _POSTER_TEXTURE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 0
	art.offset_top = 0
	art.offset_right = 0
	art.offset_bottom = 0
	return art


## Correct creature portrait for a tenant, cropped from the single shared
## sheet via AtlasTexture (no duplicated art). Returns null for tenants
## not yet on the sheet so callers can skip adding the node entirely.
func _make_portrait_art(tenant_id: String) -> TextureRect:
	var region: Rect2 = _PORTRAIT_REGIONS.get(tenant_id.to_lower(), Rect2())
	if region == Rect2():
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = _PORTRAIT_SHEET
	atlas.region = region
	var art := TextureRect.new()
	art.texture = atlas
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.anchor_left = _PORTRAIT_BOX.position.x
	art.anchor_top = _PORTRAIT_BOX.position.y
	art.anchor_right = _PORTRAIT_BOX.end.x
	art.anchor_bottom = _PORTRAIT_BOX.end.y
	art.offset_left = 0
	art.offset_top = 0
	art.offset_right = 0
	art.offset_bottom = 0
	return art


## Small centered ink label shared by the compact poster/room-preview
## slots -- keeps every line on a small parchment sheet using the same
## dark-ink-on-parchment styling instead of ad hoc Label setup per call.
func _make_centered_label(text: String, font_size: int, color: Color, bold: bool = false) -> Label:
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	if bold:
		lbl.theme_type_variation = &"BodyBoldLabel"
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _make_card_button(unlocked: bool) -> Button:
	var btn := Button.new()
	btn.text = ""
	btn.theme_type_variation = &"PosterButton"
	btn.toggle_mode = true
	btn.disabled = not unlocked
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.set_script(load("res://scripts/ui/poster_card_button.gd"))
	if unlocked:
		btn.button_group = _card_group
	return btn


func _make_locked_label(unlock_level: int) -> Label:
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text = "LOCKED \u2014 Lender Level %d" % unlock_level
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.2, 0.18))
	return lbl


func _anchor_full(c: Control) -> void:
	# Poster art has a decorative portrait box + divider line baked into
	# its top ~42%; text must sit clear below that instead of overlapping
	# it, which is what was reading as "misaligned".
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.anchor_top = 0.44
	c.offset_left = 10
	c.offset_top = 0
	c.offset_right = -10
	c.offset_bottom = -8


func _add_room_only_card(room_id: String, profile: Dictionary, unlocked: bool, on_selected: Callable) -> void:
	var slot = _take_slot()
	if slot == null:
		return  # all 3 wired boxes are already in use -- see _POSTER_SLOTS

	var btn := _make_card_button(unlocked)
	btn.self_modulate = Color(1, 1, 1, 0.82)
	_apply_slot(btn, slot, _current_slot_rotation())
	btn.add_child(_make_poster_art())  # physical poster art, drawn first == behind the text below
	var room_portrait := _make_portrait_art(room_id)
	if room_portrait:
		btn.add_child(room_portrait)

	var room_name: String = String(profile.get("name", room_id)).capitalize()
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 5)
	btn.add_child(col)
	_anchor_full(col)

	col.add_child(_make_centered_label(room_name.to_upper(), 20, Color(0.133, 0.063, 0.024), true))
	col.add_child(_make_centered_label("ROOM PREVIEW", 13, Color(_GOLD_TEXT), true))

	if not unlocked:
		col.add_child(_make_locked_label(int(profile.get("unlock_level", 1))))

	if unlocked:
		btn.pressed.connect(on_selected)
	list_box.add_child(btn)
