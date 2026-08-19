extends Node
## Data-driven meta-progression: the player is a "monster landlord" whose
## lender level gates which rooms/tenants/request tiers are available.
## Thresholds are lifetime-earnings gold amounts, not hardcoded per-room
## checks -- GameManager just asks LenderProgression for the level that
## matches its current lifetime_earnings.
##
## LEVELS is intentionally not tied to specific monster names beyond the
## comment -- unlocking is driven by RoomProfiles.unlock_level /
## TenantProfiles unlock_level / RequestData unlock_level matching the
## resolved level number, not by a switch statement here. Thresholds can
## change freely without touching gameplay code.
class_name LenderProgression

## level -> lifetime_earnings gold required to reach it.
## Levels beyond 1 are placeholders (no content is gated behind them yet --
## both current rooms are unlock_level 0). Kept only so the threshold curve
## exists for future worlds instead of being invented ad hoc later.
const LEVELS: Dictionary = {
	1: 0,
	2: 1000,
	3: 3000,
	4: 6000,
}

static func level_for_earnings(lifetime_earnings: int) -> int:
	var best := 1
	for level in LEVELS.keys():
		if lifetime_earnings >= int(LEVELS[level]) and level > best:
			best = level
	return best

## Gold still needed to reach the next level, or -1 if already at the top.
static func gold_to_next_level(lifetime_earnings: int) -> int:
	var current := level_for_earnings(lifetime_earnings)
	var next_level := current + 1
	if not LEVELS.has(next_level):
		return -1
	return max(0, int(LEVELS[next_level]) - lifetime_earnings)

## Absolute lifetime_earnings threshold for the level after `level`, or
## -1 if `level` is already the top defined level.
static func next_level_threshold(level: int) -> int:
	var next_level := level + 1
	if not LEVELS.has(next_level):
		return -1
	return int(LEVELS[next_level])

## 0..1 progress from this level's own threshold to the next one's, or
## 1.0 if already at the top defined level.
static func level_progress(lifetime_earnings: int) -> float:
	var current := level_for_earnings(lifetime_earnings)
	var next_level := current + 1
	if not LEVELS.has(next_level):
		return 1.0
	var span := int(LEVELS[next_level]) - int(LEVELS[current])
	if span <= 0:
		return 1.0
	return clampf(float(lifetime_earnings - int(LEVELS[current])) / float(span), 0.0, 1.0)
