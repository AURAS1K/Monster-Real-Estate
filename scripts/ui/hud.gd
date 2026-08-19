extends Control
## Build/simulation/results UI for the prototype. Talks to GameManager
## (autoload) and to the RoomEditor script on the Room instance (passed in
## via setup()). Rewritten for the UI/UX polish pass: top status bar with a
## live requirements checklist, restyled prop picker, a simulation status
## banner, and a proper report screen (stat bars + sanitized event log)
## instead of one big Label of formatted text.

@onready var tenant_name_label: Label = $TopBar/Margin/Row/TenantInfo/TenantNameLabel
@onready var checklist_row: HBoxContainer = $TopBar/Margin/Row/TenantInfo/ChecklistRow
@onready var state_label: Label = $TopBar/Margin/Row/StateLabel
@onready var money_label: Label = $TopBar/Margin/Row/MoneyLabel
@onready var sim_status_label: Label = $SimStatusLabel
@onready var test_button: Button = $TestButton
@onready var prop_buttons: HBoxContainer = $PropPanel/PropScroll/PropButtons

@onready var results_panel: CenterContainer = $ResultsPanel
@onready var result_title: Label = $ResultsPanel/Card/ResultsBox/ResultTitle
@onready var result_subtitle: Label = $ResultsPanel/Card/ResultsBox/ResultSubtitle
@onready var rent_value: Label = $ResultsPanel/Card/ResultsBox/RentRow/RentValue
@onready var stats_box: VBoxContainer = $ResultsPanel/Card/ResultsBox/ScrollArea/ScrollBox/StatsBox
@onready var cause_box: VBoxContainer = $ResultsPanel/Card/ResultsBox/ScrollArea/ScrollBox/CauseBox
@onready var cause_text: Label = $ResultsPanel/Card/ResultsBox/ScrollArea/ScrollBox/CauseBox/CauseText
@onready var why_text: Label = $ResultsPanel/Card/ResultsBox/ScrollArea/ScrollBox/CauseBox/WhyText
@onready var events_box: VBoxContainer = $ResultsPanel/Card/ResultsBox/ScrollArea/ScrollBox/EventsBox
@onready var try_again_button: Button = $ResultsPanel/Card/ResultsBox/TryAgainButton

var _room_editor: Node = null
var _buttons_by_id: Dictionary = {}
var _prop_base_names: Dictionary = {}  # id -> display name, for capped props whose button text becomes "NAME n/max"
var _active_button: Button = null
var _checklist_labels: Dictionary = {}  # requirement id -> Label
var _last_money: int = -1

const STAT_ROWS: Array = [
	{"key": "survival", "label": "SURVIVAL"},
	{"key": "comfort", "label": "COMFORT"},
	{"key": "food", "label": "FOOD"},
	{"key": "safety", "label": "SAFETY"},
	{"key": "decoration", "label": "DECORATION"},
	{"key": "personality_match", "label": "PERSONALITY MATCH"},
	{"key": "happiness", "label": "HAPPINESS"},
]


func setup(room_editor: Node) -> void:
	_room_editor = room_editor
	if _room_editor.has_signal("placement_cancelled"):
		_room_editor.placement_cancelled.connect(_on_placement_cancelled)
	GameManager.room_changed.connect(_on_room_changed)


## Player switched rooms off the Request Board. Tenant header/checklist and
## the prop toolbar both depend on which room/tenant is active (see
## PropDatabase.is_allowed_in_room), so both rebuild from scratch here
## instead of only at _ready() -- previously this HUD only ever populated
## once, hardcoded to the goblin.
func _on_room_changed(_room_id: String) -> void:
	_populate_tenant_header()
	_rebuild_prop_buttons()


func _ready() -> void:
	theme = UITheme.theme

	_populate_tenant_header()
	_populate_prop_buttons()
	_update_money(true)
	_update_checklist()

	test_button.pressed.connect(_on_test_pressed)
	try_again_button.pressed.connect(_on_try_again_pressed)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.simulation_finished.connect(_on_simulation_finished)

	results_panel.visible = false
	results_panel.modulate.a = 0.0
	sim_status_label.visible = false

	var poll := Timer.new()
	poll.wait_time = 0.3
	poll.autostart = true
	poll.timeout.connect(_on_poll_tick)
	add_child(poll)


## Tenant-profile-driven (GameManager.current_monster) rather than a
## direct GoblinData.DATA read, so this rebuilds correctly for whichever
## tenant the active room's profile names. Called again on room_changed
## (see setup()) since a fresh room can bring a different tenant.
func _populate_tenant_header() -> void:
	for c in checklist_row.get_children():
		c.queue_free()
	_checklist_labels.clear()

	var d: Dictionary = GameManager.current_monster
	tenant_name_label.text = String(d.get("name", "Tenant")).to_upper()

	for req in (d.get("requirements", []) as Array):
		var lbl := Label.new()
		lbl.theme_type_variation = &"SecondaryLabel"
		lbl.text = "%s: --" % String(req).capitalize()
		checklist_row.add_child(lbl)
		_checklist_labels[req] = lbl


## Polls placed props (via the room editor's public getter) and updates the
## live requirements checklist + primary-button pulse. Polling avoids
## needing a new "prop placed" signal on room_editor.gd.
func _on_poll_tick() -> void:
	_update_checklist()
	_update_prop_availability()


## Keeps capped prop buttons (Bed/Chest/Torch) labeled with a live
## "NAME n/max" count and disables them once the cap is hit, so the player
## sees WHY a button is unavailable instead of clicking a silent no-op.
## If the currently-active placement button just hit its cap, placement
## mode is cleared too (matches _try_place's own silent-block behavior,
## but also stops the now-pointless placement preview from lingering).
func _update_prop_availability() -> void:
	if not _room_editor:
		return
	for id: String in _prop_base_names.keys():
		if not _buttons_by_id.has(id):
			continue
		var btn: Button = _buttons_by_id[id]
		if not is_instance_valid(btn):
			continue
		var max_count := PropDatabase.get_max_count(id)
		var count: int = _room_editor.count_placed(id)
		btn.text = "%s %d/%d" % [String(_prop_base_names[id]).to_upper(), count, max_count]
		var at_cap := count >= max_count
		btn.disabled = at_cap
		if at_cap and btn.button_pressed:
			btn.button_pressed = false
			if _active_button == btn:
				_active_button = null
				_room_editor.set_active_prop("")


func _update_checklist() -> void:
	if not _room_editor:
		return
	var placed: Array = _room_editor.get_placed_props()
	var have_tags: Dictionary = {}
	for p in placed:
		if not is_instance_valid(p):
			continue
		var tags: Array = PropDatabase.get_def(p.prop_id).get("tags", [])
		for t in tags:
			have_tags[t] = true

	var all_met := true
	for req in _checklist_labels.keys():
		var met: bool = have_tags.has(req)
		var lbl: Label = _checklist_labels[req]
		lbl.text = "%s: %s" % [String(req).capitalize(), ("READY" if met else "NEEDED")]
		lbl.add_theme_color_override("font_color", UITheme.GREEN if met else UITheme.PARCHMENT_DIM)
		if not met:
			all_met = false

	if GameManager.current_state == GameManager.State.BUILD:
		var target_scale := 1.03 if (all_met and placed.size() > 0) else 1.0
		if absf(test_button.scale.x - target_scale) > 0.005 and test_button.scale.x <= 1.001:
			var tw := create_tween().set_loops(1)
			tw.tween_property(test_button, "scale", Vector2(target_scale, target_scale), 0.25).set_trans(Tween.TRANS_SINE)


## Fixed display order for category clusters. A category is only ever
## rendered if at least one prop in PropDatabase actually resolves to it
## (see loop below) -- this list is just the preferred left-to-right order,
## not a promise that all of these appear.
const CATEGORY_ORDER: Array[String] = ["furniture", "storage", "food", "hazard", "light", "environment"]

## Clears and rebuilds the whole prop toolbar -- used on room_changed so a
## room whose profile restricts allowed props (PropDatabase.is_allowed_in_room)
## never shows a button for a prop it can't place. No prop today declares
## allowed_room_ids, so this currently rebuilds the exact same full set for
## every room -- the filtering hook exists without changing behavior yet.
func _rebuild_prop_buttons() -> void:
	for c in prop_buttons.get_children():
		c.queue_free()
	_buttons_by_id.clear()
	_prop_base_names.clear()
	_active_button = null
	_group = null
	_populate_prop_buttons()


func _populate_prop_buttons() -> void:
	# Group prop ids by category first (rather than clustering contiguous
	# runs of PLACEMENT_ORDER) so every category gets exactly one labeled
	# column, even if its props aren't adjacent in PLACEMENT_ORDER.
	var room_id: String = GameManager.current_room_id
	var by_category: Dictionary = {}
	for id in PropDatabase.PLACEMENT_ORDER:
		if not PropDatabase.is_allowed_in_room(id, room_id):
			continue
		var tags: Array = PropDatabase.get_def(id).get("tags", [])
		var category := _category_for_tags(tags)
		if not by_category.has(category):
			by_category[category] = []
		(by_category[category] as Array).append(id)

	var first_cluster := true
	for category in CATEGORY_ORDER:
		if not by_category.has(category):
			continue
		if not first_cluster:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(14, 0)
			prop_buttons.add_child(gap)
		first_cluster = false

		var cluster_row := _make_category_cluster(category)
		for id in (by_category[category] as Array):
			var def := PropDatabase.get_def(id)
			var tags: Array = def.get("tags", [])
			var btn := Button.new()
			btn.text = def.get("name", id)
			if PropDatabase.get_max_count(id) >= 0:
				_prop_base_names[id] = def.get("name", id)
			btn.toggle_mode = true
			btn.button_group = _shared_group()
			btn.custom_minimum_size = Vector2(0, 30)
			btn.set_script(load("res://scripts/ui/button_juice.gd"))
			btn.pressed.connect(_on_prop_button_pressed.bind(id, btn))

			# Selected state: a stronger gold fill + thicker bright border so the
			# active placement button is unmistakable at a glance, distinct from
			# the thinner gold-bordered hover state. Godot falls back to this
			# "pressed" style when hovering an already-selected button too (no
			# "hover_pressed" override set), so selected/hover never fight.
			btn.add_theme_stylebox_override("pressed", _selected_prop_stylebox())

			if tags.has("hazard"):
				# Hazard props get a consistent red border accent (not a full red
				# fill) so the cue reads as "caution" rather than "broken/disabled".
				# Text stays red-tinted too, matching danger coloring used elsewhere.
				btn.add_theme_color_override("font_color", UITheme.RED)
				btn.add_theme_color_override("font_hover_color", UITheme.RED)
				btn.add_theme_stylebox_override("normal", _hazard_prop_stylebox(false))
				btn.add_theme_stylebox_override("hover", _hazard_prop_stylebox(true))

			cluster_row.add_child(btn)
			_buttons_by_id[id] = btn


## Stronger "selected" look for a toggled-on prop button: warm gold fill +
## bright thick border. Reuses UITheme's own margins/radius so the button
## doesn't resize/jump when it becomes selected.
func _selected_prop_stylebox() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = UITheme.GOLD.darkened(0.05)
	s.border_color = UITheme.GOLD_BRIGHT
	s.set_border_width_all(3)
	s.set_corner_radius_all(8)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.anti_aliasing = true
	return s


## Hazard-button accent: same stone fill as a normal prop button, just with
## a red border instead of the default one, so hazard props stand out
## without turning the whole toolbar red.
func _hazard_prop_stylebox(hovered: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = UITheme.STONE_LIGHT.lightened(0.15) if hovered else UITheme.STONE_LIGHT
	s.border_color = UITheme.RED.lightened(0.15) if hovered else UITheme.RED
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.anti_aliasing = true
	return s


## Builds one labeled cluster (small caption Label above a row of buttons)
## and appends it to the toolbar. Returns the inner HBoxContainer that
## individual prop buttons for this category should be added to.
func _make_category_cluster(category: String) -> HBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)

	var caption := Label.new()
	caption.text = _category_display_name(category)
	caption.theme_type_variation = &"SecondaryLabel"
	caption.add_theme_font_size_override("font_size", 11)
	caption.add_theme_color_override("font_color", UITheme.PARCHMENT_DIM.darkened(0.1))
	column.add_child(caption)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)

	prop_buttons.add_child(column)
	return row


func _category_display_name(category: String) -> String:
	match category:
		"hazard":
			return "HAZARDS"
		"food":
			return "FOOD"
		"storage":
			return "STORAGE"
		"light":
			return "LIGHTING"
		"environment":
			return "ENVIRONMENT"
		_:
			return "FURNITURE"


func _category_for_tags(tags: Array) -> String:
	if tags.has("hazard"):
		return "hazard"
	if tags.has("food"):
		return "food"
	if tags.has("storage"):
		return "storage"
	if tags.has("light"):
		return "light"
	return "furniture"


var _group: ButtonGroup = null

func _shared_group() -> ButtonGroup:
	if _group == null:
		_group = ButtonGroup.new()
	return _group


func _on_prop_button_pressed(id: String, _btn: Button) -> void:
	_active_button = _btn
	if _room_editor:
		_room_editor.set_active_prop(id)


func _on_placement_cancelled() -> void:
	if _active_button and is_instance_valid(_active_button):
		_active_button.button_pressed = false
	_active_button = null


func _on_test_pressed() -> void:
	if GameManager.current_state == GameManager.State.BUILD:
		GameManager.begin_test()


func _on_try_again_pressed() -> void:
	if _room_editor:
		_room_editor.clear_all_props()
	var tw := create_tween()
	tw.tween_property(results_panel, "modulate:a", 0.0, 0.18)
	tw.tween_property(results_panel, "scale", Vector2(0.96, 0.96), 0.18).set_trans(Tween.TRANS_QUAD)
	tw.parallel()
	tw.tween_callback(func():
		results_panel.visible = false
		results_panel.scale = Vector2.ONE
		GameManager.reset_for_retry()
	)


func _on_state_changed(new_state) -> void:
	_update_money()
	match new_state:
		GameManager.State.BUILD:
			results_panel.visible = false
			test_button.disabled = false
			sim_status_label.visible = false
			state_label.text = "BUILD MODE"
		GameManager.State.SIMULATING:
			test_button.disabled = true
			test_button.scale = Vector2.ONE
			state_label.text = "TESTING ROOM"
			_show_sim_status()
		GameManager.State.RESULTS:
			test_button.disabled = true
			sim_status_label.visible = false
			state_label.text = "INSPECTION REPORT"


func _show_sim_status() -> void:
	sim_status_label.visible = true
	sim_status_label.modulate.a = 0.0
	sim_status_label.text = "TESTING ROOM..."
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(sim_status_label, "modulate:a", 1.0, 0.5)
	tw.tween_property(sim_status_label, "modulate:a", 0.55, 0.5)


func _on_simulation_finished(result: Dictionary) -> void:
	_update_money()
	var success: bool = result.get("success", false)
	var scores: Dictionary = result.get("scores", {})
	var events: Array = result.get("events", [])
	var rent: int = int(result.get("rent", 0))

	var grade := String(result.get("grade", ""))
	var grade_prefix := "GRADE %s -- " % grade if not grade.is_empty() else ""
	var tenant_outcome := String(result.get("tenant_outcome", ""))

	if success:
		# Rejected/complaint outcomes (D/F) still mean the goblin survived,
		# but they shouldn't read as an unqualified win -- flag those with
		# the danger styling while keeping everything else the same label.
		result_title.theme_type_variation = &"DangerLabel" if grade == "F" else &"SuccessLabel"
		result_title.text = tenant_outcome if not tenant_outcome.is_empty() else "TENANT APPROVED"
		result_subtitle.text = grade_prefix + _grade_replay_message(grade)
		rent_value.text = "+%d GOLD" % rent
		cause_box.visible = false
		try_again_button.text = "FURNISH AGAIN" if grade == "S" else "FURNISH AGAIN -- GO FOR AN S"
	else:
		result_title.theme_type_variation = &"DangerLabel"
		result_title.text = "TENANT DECEASED"
		result_subtitle.text = grade_prefix + "The goblin did not survive the room you built."
		try_again_button.text = "FURNISH AGAIN -- KEEP THEM ALIVE"
		rent_value.text = "+0 GOLD"
		cause_box.visible = true
		cause_text.text = String(result.get("cause", "Unknown mishap."))
		var why := String(result.get("why", "Something went wrong and nobody knows what."))
		var note := String(GameManager.current_monster.get("danger_note", ""))
		if not note.is_empty():
			# Surface the same fairness note shown on the tenant application, so
			# a death caused by something the goblin "liked" (e.g. a trap) never
			# reads as the game lying to the player -- it was a known risk.
			why_text.text = "%s\n\n%s" % [why, note]
		else:
			why_text.text = why

	_rebuild_stats(scores, success)
	_rebuild_events(events)

	results_panel.visible = true
	results_panel.modulate.a = 0.0
	results_panel.scale = Vector2(0.95, 0.95)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(results_panel, "modulate:a", 1.0, 0.22)
	tw.tween_property(results_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Replay-motivation blurb tied to grade, per the grade-outcome design --
## separate from the win/loss subtitle text above it.
func _grade_replay_message(grade: String) -> String:
	match grade:
		"S":
			return "Perfect room."
		"A":
			return "The goblin survived. Rent collected."
		"B":
			return "A solid room, but not quite an S."
		"C":
			return "Room could be improved."
		"D":
			return "Improve the room to earn full rent."
		"E":
			return "The room barely worked. Big changes needed."
		"F":
			return "Tenant rejected the room."
		_:
			return "The goblin survived. Rent collected."


func _rebuild_stats(scores: Dictionary, success: bool) -> void:
	for c in stats_box.get_children():
		c.queue_free()
	for row_def in STAT_ROWS:
		var key: String = row_def["key"]
		if not success and (key == "personality_match" or key == "happiness"):
			continue  # keep the death report focused on the "almost had it" stats
		if not scores.has(key):
			continue
		var value: int = int(scores[key])

		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 22)

		var name_label := Label.new()
		name_label.text = row_def["label"]
		name_label.theme_type_variation = &"SecondaryLabel"
		name_label.custom_minimum_size = Vector2(150, 0)

		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 100
		bar.value = 0
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.theme_type_variation = &"ProgressBar" if value >= 50 else &"DangerBar"
		var bar_tween := create_tween()
		bar_tween.tween_property(bar, "value", value, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		var value_label := Label.new()
		value_label.text = str(value)
		value_label.theme_type_variation = &"SecondaryLabel"
		value_label.custom_minimum_size = Vector2(30, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		row.add_child(name_label)
		row.add_child(bar)
		row.add_child(value_label)
		stats_box.add_child(row)


## room_simulator.gd's event strings are hand-written with leading Unicode
## glyphs (checkmark / warning / skull) that may not render in every font.
## Per the "no emoji dependency" rule, translate the known prefixes to plain
## text here at the UI layer -- gameplay code (room_simulator.gd) is left
## untouched.
func _sanitize_event(raw: String) -> Dictionary:
	var text := raw
	var kind := "ok"
	if text.begins_with("\u2713"):
		text = text.substr(1).strip_edges()
		kind = "ok"
	elif text.begins_with("\u26a0"):
		text = text.substr(1).strip_edges()
		kind = "warn"
	elif text.begins_with("\U0001F480"):
		text = text.substr(1).strip_edges()
		kind = "dead"
	return {"text": text, "kind": kind}


func _rebuild_events(events: Array) -> void:
	for c in events_box.get_children():
		c.queue_free()
	for i in events.size():
		var parsed := _sanitize_event(String(events[i]))
		var kind: String = parsed["kind"]

		var accent := UITheme.GREEN
		var tag_text := "OK"
		match kind:
			"ok":
				accent = UITheme.GREEN
				tag_text = "OK"
			"warn":
				accent = UITheme.GOLD_BRIGHT
				tag_text = "WARN"
			"dead":
				accent = UITheme.RED
				tag_text = "DIED"

		# Each entry is its own small carved-stone chip -- a colored left
		# accent bar plus a faint zebra tint -- instead of bare text in a
		# list, so a long log reads as scannable rows rather than a wall of
		# text. Kept purely additive on top of the existing tag/text data.
		var row_panel := PanelContainer.new()
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = UITheme.STONE_DARK.lightened(0.03 if i % 2 == 0 else 0.0)
		row_style.set_corner_radius_all(5)
		row_style.set_border_width_all(0)
		row_style.border_width_left = 3
		row_style.border_color = accent
		row_style.content_margin_left = 10
		row_style.content_margin_right = 10
		row_style.content_margin_top = 5
		row_style.content_margin_bottom = 5
		row_panel.add_theme_stylebox_override("panel", row_style)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var tag_chip := PanelContainer.new()
		var tag_style := StyleBoxFlat.new()
		tag_style.bg_color = Color(accent.r, accent.g, accent.b, 0.16)
		tag_style.set_corner_radius_all(4)
		tag_style.content_margin_left = 6
		tag_style.content_margin_right = 6
		tag_style.content_margin_top = 1
		tag_style.content_margin_bottom = 1
		tag_chip.add_theme_stylebox_override("panel", tag_style)
		tag_chip.custom_minimum_size = Vector2(46, 0)

		var tag := Label.new()
		tag.text = tag_text
		tag.theme_type_variation = &"SecondaryLabel"
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_color_override("font_color", accent)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag_chip.add_child(tag)

		var text_label := Label.new()
		text_label.theme_type_variation = &"SecondaryLabel"
		text_label.text = parsed["text"]
		text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		row.add_child(tag_chip)
		row.add_child(text_label)
		row_panel.add_child(row)
		events_box.add_child(row_panel)


func _update_money(force: bool = false) -> void:
	var m := GameManager.money
	if not force and m == _last_money:
		return
	money_label.text = "%d GOLD" % m
	if _last_money >= 0 and m != _last_money:
		var tw := create_tween()
		money_label.scale = Vector2(1.25, 1.25)
		tw.tween_property(money_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_last_money = m
