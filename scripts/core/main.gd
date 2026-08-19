extends Node
## Root of main.tscn. Wires the HUD to the Room's editor script so prop
## buttons actually talk to placement logic, and drives the front-end
## screen flow (Title -> How To Play -> Tenant Application -> HUD).
##
## These are presentation states layered on top of GameManager's gameplay
## state machine (BUILD/SIMULATING/RESULTS) -- not new gameplay
## architecture. Only one tenant exists in this prototype, so there's no
## tenant-selection step: accepting always leads straight into build mode.

@onready var room: Node = $Room
@onready var room_camera: Camera3D = $Room/Camera3D
@onready var menu_goblin: Node3D = $Room/MenuGoblin
@onready var menu_dressing: Node3D = $Room/MenuDressing
@onready var hud: Control = $UILayer/HUD
@onready var title_screen: Control = $UILayer/TitleScreen
@onready var how_to_play: Control = $UILayer/HowToPlay
@onready var credits: Control = $UILayer/Credits
@onready var tenant_application: Control = $UILayer/TenantApplication
@onready var job_board: Control = $UILayer/JobBoard


func _ready() -> void:
	hud.setup(room)

	title_screen.set_how_to_play(how_to_play)
	title_screen.set_credits(credits)
	title_screen.start_pressed.connect(_on_start_pressed)
	job_board.visible = false
	job_board.room_selected.connect(_on_room_selected)
	job_board.back_pressed.connect(_on_job_board_back)
	tenant_application.accepted.connect(_on_tenant_accepted)

	# Cinematic framing for the Main Menu, reusing camera_controller.gd's
	# existing PRESENTATION view mode instead of a second camera node.
	# Free orbit/pan/zoom is frozen while the menu is up so the composition
	# holds; build mode gets its normal camera + controls back in
	# _on_start_pressed below.
	if room_camera:
		room_camera.call("show_presentation_view")
		room_camera.call("set_input_enabled", false)

	# The baked Main Menu video is now the menu background -- the 3D Room
	# (camera/goblin/dressing) is gameplay-only and must not render behind
	# it. Hidden here, restored in _on_start_pressed below.
	room.visible = false

	title_screen.show_screen()


func _on_start_pressed() -> void:
	room.visible = true
	# The decorative menu goblin is Main-Menu-only dressing -- take it (and
	# its collision shape) out of the way before build mode's floor raycasts
	# start firing, so it can never block prop placement.
	if menu_goblin:
		menu_goblin.visible = false
		menu_goblin.set_collision_layer_value(1, false)
		menu_goblin.set_collision_mask_value(1, false)
	# Menu-only furniture dressing (table/chairs/bed/etc.) -- same reasoning
	# as menu_goblin above: hide immediately and free it so its collision
	# shapes can never block build-mode floor raycasts/prop placement.
	if menu_dressing:
		menu_dressing.visible = false
		menu_dressing.queue_free()
	# Hand the camera back to normal build framing + free orbit/pan/zoom.
	if room_camera:
		room_camera.call("show_build_view")
		room_camera.call("set_input_enabled", true)
	var tw := create_tween()
	tw.tween_property(title_screen, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		title_screen.visible = false
		title_screen.modulate.a = 1.0
		job_board.show_screen()
	)


## Player accepted a card off the Request Board. GameManager.current_
## request/current_monster are ALREADY resolved by JobBoard (it calls
## select_request/select_room itself before emitting) -- calling
## select_room again here would re-run its default-request lookup and
## clobber an explicitly chosen non-default request (e.g. goblin_sleepy)
## back to goblin_default. This handler only does the physical room swap
## plus routing: a real request still goes through the rental-application
## screen, but a room-only entry (no RequestData for this room -- see
## GameManager.has_current_request/RequestData.room_has_requests) has no
## tenant to apply, so it skips straight to Build Mode via the same
## hud-reveal tween _on_tenant_accepted uses below.
func _on_room_selected(room_id: String) -> void:
	if room.has_method("switch_room"):
		room.call("switch_room", room_id)
	var is_real_request := GameManager.has_current_request()
	var tw := create_tween()
	tw.tween_property(job_board, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		job_board.visible = false
		job_board.modulate.a = 1.0
		if is_real_request:
			tenant_application.show_screen()
		else:
			_reveal_hud()
	)


## Player pressed BACK on the Request Board. Returns to the Title Screen
## and restores its presentation setup (frozen camera, 3D room hidden
## behind the menu video) -- the mirror image of _on_start_pressed above.
## Leaves current_request/current_room untouched: they'll simply be
## re-resolved the next time a card is picked, so nothing is left
## "half-selected" for gameplay to trip over.
func _on_job_board_back() -> void:
	if room_camera:
		room_camera.call("show_presentation_view")
		room_camera.call("set_input_enabled", false)
	room.visible = false
	var tw := create_tween()
	tw.tween_property(job_board, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		job_board.visible = false
		job_board.modulate.a = 1.0
		title_screen.show_screen()
	)


func _on_tenant_accepted() -> void:
	var tw := create_tween()
	tw.tween_property(tenant_application, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		tenant_application.visible = false
		tenant_application.modulate.a = 1.0
		_reveal_hud()
	)


## Shared HUD fade-in, used both after a real request's tenant-application
## screen is accepted and when a room-only entry skips straight to Build
## Mode from the Request Board (see _on_room_selected above).
func _reveal_hud() -> void:
	hud.visible = true
	hud.modulate.a = 0.0
	var tw2 := create_tween()
	tw2.tween_property(hud, "modulate:a", 1.0, 0.2)
