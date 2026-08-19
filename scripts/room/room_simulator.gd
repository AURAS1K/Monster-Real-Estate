extends Node3D
## Drives the scripted goblin test sequence once TEST ROOM is pressed.
## Deliberately dumb and deterministic (LAW: no pathfinding, no AI, no
## behavior trees) -- just a fixed list of beats driven by whichever props
## the player placed via RoomEditor (sibling script on the Room root).
##
## Also records a simple event log + per-category scores as it goes, so the
## results screen can always explain WHY the goblin lived or died instead of
## the outcome feeling random.

const GOBLIN_SCENE := preload("res://scenes/monsters/goblin.tscn")

var _goblin: Node3D = null


func _ready() -> void:
	GameManager.state_changed.connect(_on_state_changed)


func _on_state_changed(new_state) -> void:
	if new_state == GameManager.State.SIMULATING:
		_run_simulation()
	elif new_state == GameManager.State.BUILD:
		_cleanup_goblin()


func _cleanup_goblin() -> void:
	if is_instance_valid(_goblin):
		_goblin.queue_free()
	_goblin = null


func _run_simulation() -> void:
	_cleanup_goblin()

	var room := get_parent()
	var entrance: Marker3D = room.call("get_active_entrance")
	var placed: Array = room.get_placed_props()

	_goblin = GOBLIN_SCENE.instantiate()
	room.add_child(_goblin)
	_goblin.global_position = entrance.global_position

	var food_props: Array = []
	var bed_props: Array = []
	var storage_count: int = 0
	var other_props: Array = []

	for p in placed:
		if p.has_tag("storage"):
			storage_count += 1
		if p.has_tag("food"):
			food_props.append(p)
		elif p.has_tag("bed"):
			bed_props.append(p)
		else:
			other_props.append(p)

	var happiness := 50
	var ate := false
	var slept := false
	var died := false
	var cause := ""
	var why := ""
	var events: Array[String] = []
	var liked_hits := 0
	var hated_hits := 0
	# Reads the active tenant profile (WHO is renting -- see TenantProfiles /
	# GameManager._load_tenant_for_room) rather than GoblinData.DATA
	# directly, so this simulator isn't hardwired to one monster. The rest
	# of this function (WHAT they want, WHERE they live, WHAT the player
	# built) is deliberately left as-is -- LAW: no rewrite, only make it
	# tenant-profile-driven.
	var tenant: Dictionary = GameManager.current_monster
	var likes: Array = tenant.get("likes", [])
	var hates: Array = tenant.get("hates", [])

	events.append("\u2713 Entered the room")

	await get_tree().create_timer(0.3).timeout
	await _goblin.say("?", 0.6)

	# --- FOOD ---
	if food_props.size() > 0:
		var target = food_props[0]
		events.append("\u2713 Found food")
		await _goblin.say("HUNGRY!", 0.7)
		await _goblin.move_to(target.global_position)
		await _goblin.play_eat()
		await _goblin.say("YUM.", 0.6)
		ate = true
		happiness += 15
		events.append("\u2713 Ate food")

	# --- BED ---
	if bed_props.size() > 0:
		var target = bed_props[0]
		events.append("\u2713 Found the bed")
		await _goblin.move_to(target.global_position)
		await _goblin.play_sleep()
		slept = true
		happiness += 15
		events.append("\u2713 Slept")

	# --- LIKES/HATES TALLY for food & bed props too. Without this, a room
	# with just food+bed+storage (the tenant's actual requirements) barely
	# moved personality_match, since only "other" (wander-loop) props were
	# ever tallied -- even though food/junk are the tenant's #1 stated likes.
	# Balance fix, not a new system: same tally the wander loop already does.
	for p in food_props + bed_props:
		var req_tags: Array = PropDatabase.get_def(p.prop_id).get("tags", [])
		for t in req_tags:
			if likes.has(t):
				liked_hits += 1
			if hates.has(t):
				hated_hits += 1

	# --- WANDER / HAZARDS ---
	for p in other_props:
		if died or not is_instance_valid(p):
			continue
		if p.has_tag("trap"):
			liked_hits += 1  # goblins like traps, see below
		var tags: Array = PropDatabase.get_def(p.prop_id).get("tags", [])
		for t in tags:
			if likes.has(t):
				liked_hits += 1
			if hates.has(t):
				hated_hits += 1

		await _goblin.move_to(p.global_position)
		if p.has_tag("trap"):
			await _goblin.say("OOH, WHAT'S THAT?", 0.5)  # goblins LIKE traps -- that's the joke
			await _goblin.say("OH.", 0.35)
			events.append("\u26a0 Triggered the %s" % p.get_display_name())
			await _goblin.say("CLANK!", 0.6)
			var dir := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
			p.play_destroyed()
			await _goblin.play_death(dir)
			died = true
			cause = p.get_display_name()
			why = "The goblin loves traps and walked right into the %s you placed." % p.get_display_name()
			happiness = 0
			events.append("\U0001F480 Died")
		elif p.has_tag("bright_light"):
			await _goblin.play_squint_and_declare_sun()
			happiness -= 10
			events.append("\u26a0 Encountered bright light (%s)" % p.get_display_name())
		elif p.has_tag("expensive"):
			await _goblin.play_angry()
			happiness -= 10
			events.append("\u26a0 Got annoyed by the fancy %s" % p.get_display_name())
		elif p.has_tag("junk"):
			await _goblin.play_happy_dance()
			happiness += 5
			events.append("\u2713 Enjoyed the %s" % p.get_display_name())
		else:
			# No strong opinion on this one -- still a quick beat so the goblin
			# never just silently walks past something (LAW #5-friendly: no new
			# state, just a cosmetic line).
			const NEUTRAL_LINES := ["HM.", "NEAT.", "...", "OK."]
			await _goblin.say(NEUTRAL_LINES[randi() % NEUTRAL_LINES.size()], 0.35)

	if not died:
		if storage_count > 0:
			happiness += 10
			events.append("\u2713 Has storage")
		else:
			happiness -= 5
			events.append("\u26a0 No storage -- nowhere to put things")
		if not ate:
			happiness -= 15
			events.append("\u26a0 Went hungry -- no food available")
			await _goblin.say("...", 0.6)
		if not slept:
			happiness -= 10
			events.append("\u26a0 No bed available")
		happiness = clampi(happiness, 0, 100)
		if happiness >= 50:
			await _goblin.play_happy_dance()
			events.append("\u2713 Survived, happily")
		else:
			await _goblin.play_angry()
			events.append("\u2713 Survived, but unhappy")

	happiness = clampi(happiness, 0, 100)

	# --- SCORES ---
	var has_trap := false
	for p in other_props:
		if is_instance_valid(p) and p.has_tag("trap"):
			has_trap = true
	var survival_score: int = 0 if died else 100
	var comfort_score: int = 100 if slept else (40 if bed_props.size() > 0 else 0)
	var food_score: int = 100 if ate else (40 if food_props.size() > 0 else 0)
	var safety_score: int = 0 if died else (30 if has_trap else 100)
	var decoration_score: int = clampi(placed.size() * 10, 0, 100)
	var personality_score: int = clampi(50 + liked_hits * 10 - hated_hits * 15, 0, 100)

	var scores := {
		"survival": survival_score,
		"comfort": comfort_score,
		"food": food_score,
		"safety": safety_score,
		"decoration": decoration_score,
		"personality_match": personality_score,
		"happiness": happiness,
	}

	# --- GRADE: a single letter derived from the existing scores, not a new
	# scoring system. Survival dominates (a dead goblin can't get above a D)
	# since that's the one outcome the player can't argue with.
	var overall: float = (survival_score + comfort_score + food_score + safety_score + decoration_score + personality_score) / 6.0
	var grade := "F"
	if died:
		grade = "F" if overall < 20 else "D"
	elif overall >= 90:
		grade = "S"
	elif overall >= 80:
		grade = "A"
	elif overall >= 65:
		grade = "B"
	elif overall >= 50:
		grade = "C"
	elif overall >= 35:
		grade = "D"
	elif overall >= 20:
		grade = "E"
	else:
		grade = "F"

	# --- TENANT OUTCOME + RENT MULTIPLIER: a presentation/economy layer on
	# top of the existing grade. `success` stays tied to literal survival
	# (death-cause/result logic depends on it) -- this decides what the
	# tenant does once they DO survive, and how much of the base rent they
	# actually pay. Death always wins: 0 rent, existing DECEASED behavior,
	# no matter what grade the death landed on.
	var base_rent: int = int(tenant.get("rent", 0))
	var tenant_outcome := "TENANT DECEASED"
	var rent_multiplier := 0.0
	var final_rent := 0

	if not died:
		match grade:
			"S":
				tenant_outcome = "TENANT APPROVED -- PERFECT"
				rent_multiplier = 1.15
			"A":
				tenant_outcome = "TENANT APPROVED"
				rent_multiplier = 1.00
			"B":
				tenant_outcome = "TENANT APPROVED"
				rent_multiplier = 0.90
			"C":
				tenant_outcome = "TENANT APPROVED"
				rent_multiplier = 0.80
			"D":
				tenant_outcome = "TENANT ACCEPTED WITH COMPLAINTS"
				rent_multiplier = 0.65
			"E":
				tenant_outcome = "TENANT VERY POOR / RELUCTANT"
				rent_multiplier = 0.45
			"F":
				tenant_outcome = "TENANT REJECTED"
				rent_multiplier = 0.0
			_:
				tenant_outcome = "TENANT APPROVED"
				rent_multiplier = 1.0
		final_rent = int(round(base_rent * rent_multiplier))

	var result := {
		"success": not died,
		"rent": final_rent,
		"base_rent": base_rent,
		"rent_multiplier": rent_multiplier,
		"tenant_outcome": tenant_outcome,
		"ate": ate,
		"slept": slept,
		"has_storage": storage_count > 0,
		"safe": not died,
		"happiness": happiness,
		"room_quality": clampi(floori(placed.size() / 2.0) + 1, 1, 5),
		"cause": cause,
		"why": why,
		"events": events,
		"scores": scores,
		"grade": grade,
	}
	GameManager.report_result(result)
