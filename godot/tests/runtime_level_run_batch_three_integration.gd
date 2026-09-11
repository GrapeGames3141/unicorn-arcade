extends Node

const LevelRunController = preload("res://scripts/games/level_run_controller.gd")
const MATHTRIS_SCENE = preload("res://scenes/games/mathtris.tscn")
const WORD_SCENE = preload("res://scenes/games/word_game.tscn")


func _ready() -> void:
	_run.call_deferred()


func _mount(scene: PackedScene) -> Node:
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	return instance


func _unmount(instance: Node) -> void:
	remove_child(instance)
	instance.free()


func _records(game_id: String) -> int:
	return (AppState.progress_for_game(game_id).get("completed", []) as Array).size()


func _factory_check(game: Node, expected: Dictionary, issues: Array[String], label: String) -> void:
	var actions := {}
	for button in game.find_children("*", "Button", true, false):
		if button.has_meta("storybook_action"):
			actions[str(button.get_meta("storybook_action"))] = button
	for action in expected:
		var button := actions.get(action) as Button
		if not is_instance_valid(button) or not button.has_meta("storybook_game_action") or button.custom_minimum_size.x < float(expected[action]):
			issues.append("%s keeps %s factory metadata and width" % [label, action])


func _run() -> void:
	var prior_data := AppState.data.duplicate(true)
	var prior_game_id := AppState.selected_game_id
	var prior_category := AppState.selected_category
	var prior_shell := AppState.shell_view
	var prior_dirty := AppState._has_unsaved_changes
	var prior_ability := {"game_id": CompanionAbilityService.game_id, "level": CompanionAbilityService.level, "used": CompanionAbilityService.used, "assist_hint_armed": CompanionAbilityService.assist_hint_armed}
	var issues: Array[String] = []
	if SaveService.begin_test_session():
		AppState.data = SaveService.create_profile("Level Run Batch Three")
		AppState.data["player"]["equipped_companion"] = "sparkle"
		AppState._has_unsaved_changes = false
		await _test_mathtris(issues)
		await _test_word_games(issues)
		SaveService.end_test_session()
	else:
		issues.append("test session starts")
	AppState.data = prior_data
	AppState.selected_game_id = prior_game_id
	AppState.selected_category = prior_category
	AppState.shell_view = prior_shell
	AppState._has_unsaved_changes = prior_dirty
	CompanionAbilityService.game_id = prior_ability["game_id"]
	CompanionAbilityService.level = prior_ability["level"]
	CompanionAbilityService.used = prior_ability["used"]
	CompanionAbilityService.assist_hint_armed = prior_ability["assist_hint_armed"]
	if issues.is_empty():
		print("RUNTIME_LEVEL_RUN_BATCH_THREE_INTEGRATION_OK")
		get_tree().quit(0)
	else:
		push_error("Level run batch three assertions failed: %s" % "; ".join(issues))
		get_tree().quit(1)


func _test_mathtris(issues: Array[String]) -> void:
	AppState.selected_game_id = "mathtris"
	var game: Node = await _mount(MATHTRIS_SCENE)
	if not game.active or game.level_run.outcome != LevelRunController.Outcome.RUNNING or int(game.runtime_snapshot().get("outcome", -1)) != LevelRunController.Outcome.RUNNING or game.started_ms != game.level_run.started_ms or game.level != 1 or CompanionAbilityService.game_id != "mathtris" or CompanionAbilityService.level != 1:
		issues.append("Mathtris begins one synchronized endless run")
	_factory_check(game, {"hint_highlight": 110.0, "progression": 180.0}, issues, "Mathtris")
	if game.action_button.text != "PLAY AGAIN" or game.action_button.visible:
		issues.append("Mathtris preserves PLAY AGAIN progression copy and initial visibility")
	game.board = game._make_board()
	var match_cells: Array[Vector2i] = []
	for column in 5:
		game.board[13][column] = ["1", "+", "1", "=", "2"][column]
		match_cells.append(Vector2i(column, 13))
	var matches: Array[Dictionary] = [{"cells": match_cells, "tokens": ["1", "+", "1", "=", "2"]}]
	game.score = 600
	game._clear_matches(matches, 100, false)
	if game.level != 2 or game.level_run.level != 1:
		issues.append("Mathtris keeps score-derived difficulty separate from lifecycle level")
	var coins_before := AppState.coins()
	var records_before := _records("mathtris")
	game._game_over()
	game._game_over()
	if game.active or game.level_run.outcome != LevelRunController.Outcome.SUCCESS or AppState.coins() != coins_before + 11 or _records("mathtris") != records_before + 1 or game.action_button.text != "PLAY AGAIN" or not game.action_button.visible:
		issues.append("Mathtris top-out saves and rewards one endless run")
	if int(AppState.progress_for_game("mathtris").get("best_score", 0)) != 1100:
		issues.append("Mathtris retains the personal best")
	game._advance_game()
	if not game.active or int(game.runtime_snapshot().get("outcome", -1)) != LevelRunController.Outcome.RUNNING or game.level != 1 or game.level_run.level != 1 or CompanionAbilityService.game_id != "mathtris" or CompanionAbilityService.level != 1:
		issues.append("Mathtris typed PLAY AGAIN retries the run")
	_unmount(game)


func _word_game_ids() -> Array[String]:
	var ids: Array[String] = []
	for definition in GameRegistry.all_games():
		if str(definition.get("scene", "")) == "res://scenes/games/word_game.tscn":
			ids.append(str(definition["id"]))
	return ids


func _test_word_games(issues: Array[String]) -> void:
	var ids := _word_game_ids()
	if ids.is_empty():
		issues.append("shared Word Game IDs are registered")
	for game_id in ids:
		AppState.selected_game_id = game_id
		var game: Node = await _mount(WORD_SCENE)
		var original_level: int = game.level
		var initial_objective: Dictionary = game.runtime_snapshot()
		if not game.active or game.level_run.outcome != LevelRunController.Outcome.RUNNING or game.started_ms != game.level_run.started_ms or CompanionAbilityService.game_id != game_id or CompanionAbilityService.level != original_level or str(initial_objective.get("game_id", "")) != game_id or str(initial_objective.get("objective_primary", "")).is_empty():
			issues.append("%s starts with a synchronized word lifecycle" % game_id)
		_factory_check(game, {"category_back": 120.0, "hint_highlight": 140.0, "progression": 160.0}, issues, game_id)
		var category_back := game.find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return button.has_meta("storybook_action") and str(button.get_meta("storybook_action")) == "category_back")
		if category_back.is_empty() or (category_back[0] as Button).text != String.chr(0x2039) + " BACK":
			issues.append("%s preserves exact category-back copy" % game_id)
		if not game.hint_button.text.begins_with("FREE HINT"):
			issues.append("%s preserves paid-hint entry copy" % game_id)
		var coins_before := AppState.coins()
		var records_before := _records(game_id)
		game._complete_level()
		game._complete_level()
		var completed_snapshot: Dictionary = game.runtime_snapshot()
		if game.active or game.level_run.outcome != LevelRunController.Outcome.SUCCESS or int(completed_snapshot.get("outcome", -1)) != LevelRunController.Outcome.SUCCESS or game.level != original_level + 1 or AppState.coins() != coins_before + RewardService.level_reward(original_level) or _records(game_id) != records_before + 1 or game.retry_button.text != "NEXT LEVEL" or not game.retry_button.visible or str(completed_snapshot.get("game_id", "")) != game_id or str(completed_snapshot.get("objective_primary", "")).is_empty():
			issues.append("%s completion has one payout with immediate next-level snapshot" % game_id)
		game._advance_level()
		if not game.active or int(game.runtime_snapshot().get("outcome", -1)) != LevelRunController.Outcome.RUNNING or game.level != original_level + 1 or game.level_run.level != game.level or CompanionAbilityService.game_id != game_id or CompanionAbilityService.level != game.level:
			issues.append("%s typed success action begins its next run" % game_id)
		game._fail("test failure")
		if game.level_run.outcome != LevelRunController.Outcome.FAILURE or int(game.runtime_snapshot().get("outcome", -1)) != LevelRunController.Outcome.FAILURE or not game.can_retry_failure() or game.retry_button.text != "RETRY":
			issues.append("%s typed failure exposes same-level retry" % game_id)
		game.retry_failure()
		if not game.active or int(game.runtime_snapshot().get("outcome", -1)) != LevelRunController.Outcome.RUNNING or game.level != original_level + 1 or game.level_run.level != game.level:
			issues.append("%s typed retry remains on its current public level" % game_id)
		_unmount(game)
