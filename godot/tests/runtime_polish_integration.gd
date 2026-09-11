extends Node

var issues: Array[String] = []
var checks := 0


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		issues.append(message)


func _mount(game_id: String) -> ArcadeGameController:
	AppState.selected_game_id = game_id
	var scene := load(str(GameRegistry.get_game(game_id)["scene"])) as PackedScene
	var game := scene.instantiate() as ArcadeGameController
	add_child(game)
	await get_tree().process_frame
	GameExperience.attached_scene = game
	GameExperience.attached_controller = game
	GameExperience.attached_game_id = game_id
	return game


func _unmount(game: Node) -> void:
	GameExperience.attached_scene = null
	GameExperience.attached_controller = null
	remove_child(game)
	game.free()


func _run() -> void:
	GameExperience.set_process(false)
	if not SaveService.begin_test_session():
		push_error("Polish tests require an isolated save session")
		get_tree().quit(1)
		return
	AppState.data = SaveService.create_profile("Polish Regression")
	AppState.data["settings"]["tutorials_enabled"] = false
	AppState._has_unsaved_changes = false
	await _test_modal_pause()
	await _test_jump_pause()
	await _test_dialog_teardown()
	await _test_swipe_input()
	await _test_mathtris_results()
	SaveService.end_test_session()
	if issues.is_empty():
		print("RUNTIME_POLISH_INTEGRATION_OK: %d checks" % checks)
		get_tree().quit(0)
	else:
		push_error("Polish regression failures: %s" % "; ".join(issues))
		get_tree().quit(1)


func _test_modal_pause() -> void:
	for game_id in ["sliding_window", "mathtris", "comet_math_rescue", "sight_spark", "unicorn_blast", "galaxy_unicorn"]:
		var game: ArcadeGameController = await _mount(game_id)
		if game_id == "sight_spark":
			game.flash_timer.start(0.03)
		GameExperience._show_leave_run_modal(false)
		var leave := game.get_node("LeaveRunOverlay")
		var elapsed := game.level_run.elapsed_ms()
		var before: Variant = _simulation_state(game, game_id)
		await get_tree().create_timer(0.07).timeout
		_check(game.gameplay_paused and not game.can_process(), "%s pauses its game subtree" % game_id)
		_check(leave.can_process(), "%s leave dialog stays interactive" % game_id)
		_check(game.level_run.elapsed_ms() == elapsed, "%s excludes modal time from the recorded run" % game_id)
		_check(_simulation_state(game, game_id) == before, "%s timers and simulation stay frozen" % game_id)
		GameExperience._show_profile_overlay()
		var profile := game.get_node("InGameProfileOverlay")
		leave.free()
		_check(game.gameplay_paused, "%s remains paused with a nested dialog" % game_id)
		GameExperience._notification(NOTIFICATION_APPLICATION_PAUSED)
		profile.free()
		_check(game.gameplay_paused, "%s remains paused while the application is backgrounded" % game_id)
		GameExperience._notification(NOTIFICATION_APPLICATION_RESUMED)
		_check(not game.gameplay_paused and game.can_process(), "%s resumes after the final pause reason clears" % game_id)
		await get_tree().create_timer(0.05).timeout
		_check(game.level_run.elapsed_ms() > elapsed, "%s elapsed time resumes" % game_id)
		if game_id == "sight_spark":
			_check(game.phase == "type", "Sight Spark's flash resumes after the dialog closes")
		GameExperience._maybe_show_tutorial(true)
		_check(game.gameplay_paused, "%s tutorial uses shared pause behavior" % game_id)
		game.find_child("GuidedTutorialOverlay", true, false).free()
		_check(not game.gameplay_paused, "%s closing a tutorial resumes the game" % game_id)
		_unmount(game)


func _simulation_state(game: Node, game_id: String) -> Variant:
	match game_id:
		"sliding_window": return [game.rival_elapsed, game.opponent_pos]
		"mathtris": return [game.fall_accumulator, game.falling.duplicate(true)]
		"comet_math_rescue": return [game.wave_elapsed_ms, game.lives]
		"sight_spark": return [game.phase, game.flash_timer.time_left]
		"unicorn_blast": return [game.spawn_elapsed, game.lives]
		"galaxy_unicorn": return [game.opening_timer, game.spawn_timer, game.player_x]
	return null


func _correct_card(game: Node) -> Button:
	for card in game.cards:
		if bool(card.get_meta("correct")):
			return card
	return null


func _test_dialog_teardown() -> void:
	var game: ArcadeGameController = await _mount("coin_count")
	GameExperience._show_leave_run_modal(false)
	_check(game.gameplay_paused, "A departing game starts paused with its dialog open")
	# Exercise navigation while the overlay still exists. Its tree_exited
	# callback must not query the detached scene's tree or rebuild its HUD.
	_unmount(game)


func _test_jump_pause() -> void:
	AppState.data["settings"]["reduced_motion"] = true
	var game: ArcadeGameController = await _mount("unicorn_jump")
	var destination: int = game.level_data[0]
	game._choose_node(destination)
	GameExperience._show_leave_run_modal(false)
	await get_tree().create_timer(0.25).timeout
	_check(game.current_index == 0 and game.jump_in_progress, "Reduced-motion jumps do not finish behind a dialog")
	game.find_child("LeaveRunOverlay", true, false).free()
	await get_tree().create_timer(0.25).timeout
	_check(game.current_index == destination and not game.jump_in_progress, "Reduced-motion jumps finish after resuming")
	_unmount(game)
	AppState.data["settings"]["reduced_motion"] = false


func _test_swipe_input() -> void:
	var game: ArcadeGameController = await _mount("math_swipe")
	game.target = 100
	for distance in [0, 10, 40, 80, 100]:
		var card := _correct_card(game)
		var before: int = game.completed
		var press := InputEventScreenTouch.new()
		press.index = 0
		press.pressed = true
		press.position = Vector2(30, 30)
		game._card_input(press, card)
		var release := InputEventScreenTouch.new()
		release.index = 0
		release.position = Vector2(30 + distance, 30)
		game._input(release)
		# A second event in the same frame must not count the answered card again.
		card.pressed.emit()
		game._submit(card)
		_check(game.completed == before + 1, "Math Swipe accepts %dpx touch once" % distance)
		await get_tree().process_frame
	# Dispatch mouse events through Godot's real GUI hit testing, including a
	# short drag that used to fall in the ignored 5–80 pixel range.
	for distance in [0, 40]:
		var mouse_card := _correct_card(game)
		var before_mouse: int = game.completed
		var start := mouse_card.get_global_rect().get_center()
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = start
		get_viewport().push_input(press)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.position = start + Vector2(distance, 0)
		get_viewport().push_input(release)
		_check(game.completed == before_mouse + 1, "Math Swipe accepts %dpx mouse gesture through GUI dispatch" % distance)
		await get_tree().process_frame
	# Exercise actual button focus and keyboard dispatch through the viewport.
	var keyboard_card := _correct_card(game)
	keyboard_card.grab_focus()
	var before_keyboard: int = game.completed
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	get_viewport().push_input(key)
	key = InputEventKey.new()
	key.keycode = KEY_ENTER
	get_viewport().push_input(key)
	_check(game.completed == before_keyboard + 1, "Math Swipe supports keyboard button activation")
	await get_tree().process_frame
	# Cancelling a touch must leave the question intact.
	var cancel_card := _correct_card(game)
	var before_cancel: int = game.completed
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	game._card_input(touch, cancel_card)
	touch = InputEventScreenTouch.new()
	touch.canceled = true
	game._input(touch)
	_check(game.completed == before_cancel, "Cancelled touches do not submit")
	# A deferred refresh from an old run must not overwrite a fresh question.
	game._submit(cancel_card)
	game._start_level(2)
	var problem: Dictionary = game.problem.duplicate(true)
	await get_tree().process_frame
	_check(game.problem == problem and game.completed == 0, "Stale refreshes cannot replace a new run's question")
	for card in game.cards:
		if not bool(card.get_meta("correct")):
			game._submit(card)
			break
	var solution := str(problem["display"]).replace("?", str(problem["correct"]))
	_check(game.message_label.text.contains(solution) and game.can_retry_failure(), "A wrong answer explains the complete equation before retry")
	_unmount(game)


func _test_mathtris_results() -> void:
	var game: ArcadeGameController = await _mount("mathtris")
	game.set_process(false)
	game.board = game._make_board()
	# Clearing row 13 drops a second equation into the scanned cascade row.
	var tokens := ["1", "+", "1", "=", "2"]
	var cells: Array[Vector2i] = []
	for column in 5:
		game.board[13][column] = tokens[column]
		game.board[12][column] = tokens[column]
		cells.append(Vector2i(column, 13))
	var matches: Array[Dictionary] = [{"cells": cells, "tokens": tokens}]
	game.score = 100
	game._clear_matches(matches, 100, true)
	_check(game.score > 700 and game.level == game.score / 700 + 1, "Mathtris stage includes cascade points immediately")
	var score: int = game.score
	var stage: int = game.level
	var coins := AppState.coins()
	game._game_over()
	game._game_over()
	var record := AppState.progress_for_game("mathtris")
	_check(record.get("completed", []).size() == 1, "Repeated top-out records only one run")
	_check(AppState.coins() == coins + mini(250, score / 100), "Mathtris pays once based on earned score")
	_check(int(record.get("best_score", 0)) == score and int(record.get("highest_stage", 0)) == stage, "Mathtris retains best score and highest stage")
	# The isolated save service intentionally does not read/write disk. Exercise
	# JSON round-tripping and profile normalization without touching real saves.
	SaveService._envelope = JSON.parse_string(JSON.stringify(SaveService._envelope))
	AppState.data = SaveService.select_profile("Polish Regression")
	var restored := AppState.progress_for_game("mathtris")
	var restored_run: Dictionary = restored.get("completed", [{}])[0]
	_check(int(restored.get("best_score", 0)) == score and int(restored.get("highest_stage", 0)) == stage and int(restored_run.get("score", 0)) == score and int(restored_run.get("time", -1)) == int(record["completed"][0]["time"]) and restored_run.get("mode") == "endless", "Endless results survive save/reload")
	game._advance_game()
	_check(game.active and game.level == 1 and game.score == 0, "PLAY AGAIN begins a fresh endless run")
	game._game_over()
	_check(AppState.coins() == coins + mini(250, score / 100), "An empty run awards no coins")
	_check(int(AppState.progress_for_game("mathtris").get("best_score", 0)) == score, "A lower score preserves the personal best")
	_unmount(game)
