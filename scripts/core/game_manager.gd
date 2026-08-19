extends Node
## Autoload singleton. Tracks the high-level game state machine, money,
## and the currently active monster application. Kept intentionally tiny
## for the one-room prototype.

enum State { BUILD, SIMULATING, RESULTS }

signal state_changed(new_state: State)
signal simulation_finished(result: Dictionary)
## Emitted when the player picks a room from the Request Board.
signal room_changed(room_id: String)
## Emitted whenever current_request_id actually changes value -- covers
## select_request() AND the automatic default-request load inside
## select_room()/_ready(), so TaskManager (and anything else that needs
## to react to "the active contract changed") has one reliable signal
## instead of needing to also watch room_changed (which only fires when
## the room itself differs, not when the request within the same room
## changes -- e.g. a future goblin_default -> goblin_sleepy pick).
signal request_changed(request_id: String)
## Emitted when lender_level increases (never on decrease -- it can't).
signal level_up(new_level: int)

const SAVE_PATH := "user://progression.save"
const SAVE_VERSION := 1

var current_state: State = State.BUILD
var money: int = 300
## Total gold ever earned (never decreases -- unlike `money`, which the
## player could eventually spend). Drives LenderProgression.level_for_earnings.
var lifetime_earnings: int = 0
var lender_level: int = 1
var tutorial_seen: bool = false
var first_launch: bool = true

## Active tenant profile (see TenantProfiles), kept in sync with
## current_room_id by select_room(). RoomSimulator/HUD/TenantApplication
## read this instead of GoblinData.DATA directly, so they work for any
## tenant a room's profile names -- not just the goblin.
var current_monster: Dictionary = {}

## Which room the player is currently working on. Keys into
## RoomProfiles.PROFILES (single source of truth for room data -- see
## scripts/data/room_profiles.gd).
var current_room_id: String = RoomProfiles.DEFAULT_ROOM_ID

## Active request/contract (see RequestData). Empty dict if the room has
## no request registered yet.
var current_request_id: String = ""
var current_request: Dictionary = {}


func select_room(room_id: String) -> void:
	_load_tenant_for_room(room_id)  # runs even if room_id == current (fresh application screen)
	_load_default_request_for_room(room_id)
	if room_id == current_room_id:
		return
	current_room_id = room_id
	room_changed.emit(room_id)


## Explicitly picks a request (e.g. from the future Request Board), and
## syncs room/tenant to match it. Rejects unknown/invalid requests
## (missing tenant or room) without touching existing state. Does NOT
## call select_room() -- that would re-trigger default-request loading
## and immediately clobber this explicit choice back to the room's
## first request.
func select_request(request_id: String) -> bool:
	if not RequestData.is_valid_request(request_id):
		push_error("GameManager.select_request: invalid request_id '%s'" % request_id)
		return false
	var previous_request_id := current_request_id
	var request := RequestData.get_request(request_id)
	var room_id: String = request.get("room_id", current_room_id)
	current_request = request
	current_request_id = current_request.get("request_id", "")
	current_monster = RequestData.resolve_tenant(current_request_id)
	if room_id != current_room_id:
		current_room_id = room_id
		room_changed.emit(room_id)
	if current_request_id != previous_request_id:
		request_changed.emit(current_request_id)
	return true


## True once a real request (not just a room-only entry) is the active
## selection -- e.g. from the Request Board via select_request(), or a
## room whose default request was auto-loaded by select_room(). Callers
## (main.gd's post-JobBoard routing) use this instead of re-deriving the
## request/room-only distinction themselves.
func has_current_request() -> bool:
	return not current_request_id.is_empty()


## Picks the first valid request registered for this room so
## current_request stays valid without callers needing to know request
## ids yet. Also resolves current_monster through the request (base
## tenant + request overrides) rather than the raw tenant profile.
func _load_default_request_for_room(room_id: String) -> void:
	var previous_request_id := current_request_id
	var ids := RequestData.requests_for_room(room_id)
	for id in ids:
		if RequestData.is_valid_request(id):
			current_request = RequestData.get_request(id)
			current_request_id = current_request.get("request_id", "")
			var resolved := RequestData.resolve_tenant(current_request_id)
			if not resolved.is_empty():
				current_monster = resolved
			if current_request_id != previous_request_id:
				request_changed.emit(current_request_id)
			return
	# No valid request for this room (e.g. wizard today) -- clear rather
	# than leave a stale request from whichever room was active before.
	current_request = {}
	current_request_id = ""
	if current_request_id != previous_request_id:
		request_changed.emit(current_request_id)


## Looks up the tenant this room's profile names (RoomProfiles.tenant_type)
## and loads its profile into current_monster. Rooms without a registered
## tenant yet (e.g. wizard, today) explicitly CLEAR current_monster rather
## than leaving a stale tenant behind -- switching from a room with a real
## tenant (goblin) to a room-only room must not leave the goblin's data
## sitting in current_monster for something downstream to read by mistake.
func _load_tenant_for_room(room_id: String) -> void:
	var profile := RoomProfiles.get_profile(room_id)
	var tenant_type: String = profile.get("tenant_type", "")
	if TenantProfiles.has_profile(tenant_type):
		current_monster = TenantProfiles.get_profile(tenant_type)
	else:
		current_monster = {}


func _ready() -> void:
	load_game()
	_load_tenant_for_room(current_room_id)
	_load_default_request_for_room(current_room_id)


## --- PROGRESSION API -------------------------------------------------

func add_money(amount: int) -> void:
	if amount <= 0:
		return
	money = max(0, money + amount)
	save_game()


## Returns false (no state change) if the player can't afford it.
func spend_money(amount: int) -> bool:
	if amount <= 0 or amount > money:
		return false
	money -= amount
	save_game()
	return true


## Bumps lifetime_earnings (never decreases) and re-derives lender_level,
## emitting level_up exactly once per level gained.
func add_lifetime_earnings(amount: int) -> void:
	if amount <= 0:
		return
	lifetime_earnings += amount
	var new_level := LenderProgression.level_for_earnings(lifetime_earnings)
	if new_level > lender_level:
		lender_level = new_level
		level_up.emit(lender_level)
	save_game()


func get_lender_level() -> int:
	return lender_level


## Absolute lifetime_earnings gold needed for the next level, or -1 if maxed.
func get_next_level_threshold() -> int:
	return LenderProgression.next_level_threshold(lender_level)


## 0..1 progress toward the next level, or 1.0 if maxed.
func get_level_progress() -> float:
	return LenderProgression.level_progress(lifetime_earnings)


func is_room_unlocked(room_id: String) -> bool:
	if not RoomProfiles.has_profile(room_id):
		return false
	return int(RoomProfiles.get_profile(room_id).get("unlock_level", 0)) <= lender_level


func is_tenant_unlocked(tenant_id: String) -> bool:
	if not TenantProfiles.has_profile(tenant_id):
		return false
	return int(TenantProfiles.get_profile(tenant_id).get("unlock_level", 0)) <= lender_level


## A request is only unlocked if its room, its tenant, AND its own
## unlock_level are all satisfied.
func is_request_unlocked(request_id: String) -> bool:
	if not RequestData.is_valid_request(request_id):
		return false
	var request := RequestData.get_request(request_id)
	if not is_room_unlocked(request.get("room_id", "")):
		return false
	if not is_tenant_unlocked(request.get("tenant_id", "")):
		return false
	return int(request.get("unlock_level", 0)) <= lender_level


## --- SAVE / LOAD -------------------------------------------------------

func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progression", "version", SAVE_VERSION)
	cfg.set_value("progression", "money", money)
	cfg.set_value("progression", "lifetime_earnings", lifetime_earnings)
	cfg.set_value("progression", "lender_level", lender_level)
	cfg.set_value("progression", "tutorial_seen", tutorial_seen)
	cfg.set_value("progression", "first_launch", first_launch)
	cfg.save(SAVE_PATH)


## Missing/corrupted/unreadable save -> keep clean defaults, no crash.
## Loaded values are clamped so a hand-edited or older save can't leave
## progression in an invalid state.
func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	money = max(0, int(cfg.get_value("progression", "money", money)))
	lifetime_earnings = max(0, int(cfg.get_value("progression", "lifetime_earnings", lifetime_earnings)))
	lender_level = max(1, int(cfg.get_value("progression", "lender_level", lender_level)))
	tutorial_seen = bool(cfg.get_value("progression", "tutorial_seen", tutorial_seen))
	first_launch = bool(cfg.get_value("progression", "first_launch", first_launch))
	# Older/corrupted saves could have a stale level for their earnings --
	# earnings (the raw, harder-to-corrupt-meaningfully number) wins.
	lender_level = max(lender_level, LenderProgression.level_for_earnings(lifetime_earnings))


func reset_progress() -> void:
	money = 300
	lifetime_earnings = 0
	lender_level = 1
	tutorial_seen = false
	first_launch = true
	save_game()


func set_state(new_state: State) -> void:
	current_state = new_state
	state_changed.emit(new_state)


func begin_test() -> void:
	set_state(State.SIMULATING)


func report_result(result: Dictionary) -> void:
	if result.get("success", false):
		var earned := int(result.get("rent", 0))
		# add_money/add_lifetime_earnings each save once; fine for an
		# end-of-contract event (not a hot path), and simpler than a
		# combined award() call for two independently useful primitives.
		add_money(earned)
		add_lifetime_earnings(earned)
	set_state(State.RESULTS)
	simulation_finished.emit(result)


func reset_for_retry() -> void:
	set_state(State.BUILD)
