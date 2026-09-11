class_name LevelRunController
extends RefCounted

enum Outcome { IDLE, RUNNING, SUCCESS, FAILURE }
var game_id := ""
var level := 1
var next_level := 1
var active := false
var outcome: Outcome = Outcome.IDLE
var started_ms := 0
var ended_ms := 0
var outcome_message := ""
var reward := 0
var _completed := false
var paused := false
var _pause_started_ms := 0
var _paused_ms := 0

func begin(next_game_id: String, next_level_value: int) -> void:
	game_id = next_game_id
	level = maxi(1, next_level_value)
	next_level = level
	active = true
	outcome = Outcome.RUNNING
	started_ms = Time.get_ticks_msec()
	ended_ms = 0
	outcome_message = ""
	reward = 0
	_completed = false
	paused = false
	_pause_started_ms = 0
	_paused_ms = 0
	CompanionAbilityService.begin_level(game_id, level)

func elapsed_ms() -> int:
	var now := Time.get_ticks_msec() if active else ended_ms
	var current_pause := maxi(0, now - _pause_started_ms) if paused else 0
	return maxi(0, now - started_ms - _paused_ms - current_pause)

func set_paused(value: bool) -> void:
	if not active or value == paused:
		return
	if value:
		_pause_started_ms = Time.get_ticks_msec()
	else:
		_paused_ms += maxi(0, Time.get_ticks_msec() - _pause_started_ms)
	paused = value

func finish_endless(score: int, stage: int) -> int:
	if _completed or not active:
		return reward
	_completed = true
	active = false
	outcome = Outcome.SUCCESS
	next_level = 1
	ended_ms = Time.get_ticks_msec()
	reward = AppState.complete_endless_run(game_id, score, stage, elapsed_ms())
	return reward

func complete() -> int:
	if _completed or not active:
		return reward
	_completed = true
	active = false
	outcome = Outcome.SUCCESS
	next_level = level + 1
	ended_ms = Time.get_ticks_msec()
	var frozen_elapsed := elapsed_ms()
	reward = AppState.complete_level(game_id, level, frozen_elapsed)
	return reward

func fail(message: String) -> void:
	if not active:
		return
	active = false
	outcome = Outcome.FAILURE
	outcome_message = message
	ended_ms = Time.get_ticks_msec()

func can_retry() -> bool:
	return outcome == Outcome.FAILURE

func retry() -> int:
	var selected := next_level if outcome == Outcome.SUCCESS else level
	begin(game_id, selected)
	return selected

func select_category() -> String:
	return str(GameRegistry.get_game(game_id).get("category", "Number"))
