class_name MoneyCounterBase
extends ArcadeGameController

const OUTCOME_IGNORED := "ignored"
const OUTCOME_PROGRESS := "progress"
const OUTCOME_EXACT := "exact"
const OUTCOME_OVERSHOOT := "overshoot"

var level := 1
var target := 0
var total := 0
var started_ms := 0
var active := false
var failed := false
var money_game_id := ""
var money_denominations: Array[int] = []


func configure_money_counter(for_game_id: String, denominations: Array) -> void:
	money_game_id = for_game_id
	money_denominations.clear()
	for denomination in denominations:
		money_denominations.append(int(denomination))


func _begin_money_round(begin_run: bool) -> void:
	if begin_run:
		level_run.begin(money_game_id, level)
	else:
		level = level_run.level
	total = 0
	started_ms = level_run.started_ms
	active = level_run.active
	failed = false


func _apply_money_value(value: int, failure_reason: String) -> Dictionary:
	var transition := money_transition(active, total, target, value)
	if transition.get("outcome") == OUTCOME_IGNORED:
		return transition
	total = int(transition["total"])
	if str(transition["outcome"]) not in [OUTCOME_EXACT, OUTCOME_OVERSHOOT]:
		AudioService.play(&"coin")
	match str(transition["outcome"]):
		OUTCOME_EXACT:
			transition["reward"] = level_run.complete()
			active = level_run.active
			level += 1
		OUTCOME_OVERSHOOT:
			level_run.fail(failure_reason)
			active = level_run.active
			failed = level_run.outcome == LevelRunController.Outcome.FAILURE
	return transition


func _can_retry_money_failure() -> bool:
	return level_run.can_retry()


func _retry_money_failure() -> bool:
	if not level_run.can_retry():
		return false
	level = level_run.retry()
	return true


func _best_fitting_denomination() -> int:
	return best_fitting_denomination(money_denominations, target - total)


static func money_transition(is_active: bool, current_total: int, target_total: int, value: int) -> Dictionary:
	if not is_active:
		return {"outcome": OUTCOME_IGNORED, "total": current_total}
	var next_total := current_total + value
	if next_total == target_total:
		return {"outcome": OUTCOME_EXACT, "total": next_total}
	if next_total > target_total:
		return {"outcome": OUTCOME_OVERSHOOT, "total": next_total}
	return {"outcome": OUTCOME_PROGRESS, "total": next_total}


static func best_fitting_denomination(denominations: Array, remaining: int) -> int:
	var best := 0
	for denomination in denominations:
		var value := int(denomination)
		if value <= remaining and value > best:
			best = value
	return best
