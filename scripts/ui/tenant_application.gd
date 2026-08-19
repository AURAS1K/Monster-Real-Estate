extends Control
## The rental-application screen shown before build mode. Reads
## GameManager.current_monster (the active room's tenant profile -- see
## TenantProfiles) so this works for any tenant, not just the goblin.
## Emits `accepted` when the player clicks ACCEPT TENANT.

signal accepted

const FLAVOR_LINES: Array[String] = [
	"I need a place.",
	"I don't care if it's clean.",
	"Do NOT put me near windows.",
	"I have very reasonable expectations.",
]

@onready var quote_label: Label = $CenterArea/Card/Box/Quote
@onready var requirements_box: VBoxContainer = $CenterArea/Card/Box/RequirementsBox
@onready var likes_label: Label = $CenterArea/Card/Box/LikesRow/LikesValue
@onready var hates_label: Label = $CenterArea/Card/Box/HatesRow/HatesValue
@onready var rent_label: Label = $CenterArea/Card/Box/RentRow/RentValue
@onready var personality_label: Label = $CenterArea/Card/Box/PersonalityLabel
@onready var accept_button: Button = $CenterArea/Card/Box/AcceptButton


func _ready() -> void:
	theme = UITheme.theme
	accept_button.pressed.connect(func(): accepted.emit())
	_populate()


func _populate() -> void:
	var d: Dictionary = GameManager.current_monster
	quote_label.text = "\u201c%s\u201d" % FLAVOR_LINES[randi() % FLAVOR_LINES.size()]

	for child in requirements_box.get_children():
		child.queue_free()

	var reqs: Array = d.get("requirements", [])
	for req in reqs:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = String(req).capitalize()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tag_label := Label.new()
		tag_label.text = "REQUIRED"
		tag_label.theme_type_variation = &"SecondaryLabel"
		tag_label.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
		row.add_child(name_label)
		row.add_child(tag_label)
		requirements_box.add_child(row)

	likes_label.text = ", ".join(d.get("likes", []) as Array).capitalize()
	hates_label.text = ", ".join(d.get("hates", []) as Array).capitalize()
	rent_label.text = "%d GOLD" % int(d.get("rent", 0))

	var note: String = String(d.get("danger_note", ""))
	if note.is_empty():
		personality_label.visible = false
	else:
		personality_label.visible = true
		personality_label.text = "\u26a0 %s Some likes are risky." % note


## Called by main.gd every time the screen is (re)shown so the flavor
## line and layout are fresh, with a small fade/scale-in.
func show_screen() -> void:
	_populate()
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.97, 0.97)
	pivot_offset = size / 2.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
