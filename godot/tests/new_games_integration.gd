extends Node

## Plays Memory Meadow, Pattern Parade, and Bubble Count through a win, a loss,
## a retry, and a hint using their real input handlers.
const LevelRunController = preload("res://scripts/games/level_run_controller.gd")
const MEMORY_SCENE = preload("res://scenes/games/memory_meadow.tscn")
const PATTERN_SCENE = preload("res://scenes/games/pattern_parade.tscn")
const BUBBLE_SCENE = preload("res://scenes/games/bubble_count.tscn")
const PatternParade = preload("res://scripts/games/pattern_parade.gd")
const BubbleCount = preload("res://scripts/games/bubble_count.gd")
const MemoryMeadow = preload("res://scripts/games/memory_meadow.gd")

var failures: Array[String] = []
var checks := 0


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _ready() -> void:
	_run.call_deferred()


func _mount(scene: PackedScene, game_id: String) -> Node:
	AppState.selected_game_id = game_id
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	return instance


func _unmount(instance: Node) -> void:
	remove_child(instance)
	instance.free()


func _records(game_id: String) -> int:
	return (AppState.progress_for_game(game_id).get("completed", []) as Array).size()


func _run() -> void:
	SaveService.begin_test_session()
	AppState.set_player_name("New Games Test")
	for id in ["memory_meadow", "pattern_parade", "bubble_count"]:
		var record := GameRegistry.get_game(id)
		_check(not record.is_empty() and ResourceLoader.exists(str(record.get("scene", ""))), "%s is registered with a scene" % id)
		_check(TutorialCatalog.lessons(id, 1).size() == 3 and TutorialCatalog.lessons(id, 3).size() == 3, "%s has guided lessons" % id)
	await _test_memory()
	await _test_pattern()
	await _test_bubbles()
	_test_rules()
	SaveService.end_test_session()
	if failures.is_empty():
		print("NEW_GAMES_INTEGRATION_OK: %d checks" % checks)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("NEW_GAMES_INTEGRATION_FAILED: %d of %d" % [failures.size(), checks])
		get_tree().quit(1)


func _pair_indexes(game: Node) -> Array:
	var seen := {}
	var pairs: Array = []
	for index in game.card_shapes.size():
		var shape: String = game.card_shapes[index]
		if seen.has(shape):
			pairs.append([seen[shape], index])
		else:
			seen[shape] = index
	return pairs


func _test_memory() -> void:
	var game: Node = await _mount(MEMORY_SCENE, "memory_meadow")
	var level: int = game.level
	_check(game.active and game.level_run.outcome == LevelRunController.Outcome.RUNNING and CompanionAbilityService.game_id == "memory_meadow", "Memory Meadow starts a synchronized run")
	_check(game.card_buttons.size() == game.pair_count * 2 and game.card_shapes.size() == game.pair_count * 2, "Memory Meadow deals two cards per pair")
	var pairs := _pair_indexes(game)
	_check(pairs.size() == game.pair_count, "every dealt shape appears exactly twice")
	# A deliberate miss costs one peek and turns both cards back over.
	var peeks_before: int = game.peeks_left
	var miss_a: int = pairs[0][0]
	var miss_b: int = pairs[1][0]
	game.card_buttons[miss_a].pressed.emit()
	game.card_buttons[miss_b].pressed.emit()
	_check(game.peeks_left == peeks_before - 1 and game.face_up.size() == 2 and game.matched_pairs == 0, "a mismatch costs one peek and stays visible briefly")
	game._hide_mismatch()
	_check(game.face_up.is_empty() and game.card_tiles[miss_a].face_down and game.card_tiles[miss_b].face_down, "mismatched cards turn back over")
	_check(game.can_show_hint(), "Memory Meadow offers a hint during play")
	game._show_hint()
	var glowing: int = game.card_tiles.filter(func(tile) -> bool: return tile.highlighted).size()
	_check(glowing == 2, "the hint highlights exactly one pair")
	var coins_before := AppState.coins()
	var records_before := _records("memory_meadow")
	for pair in pairs:
		game.card_buttons[pair[0]].pressed.emit()
		game.card_buttons[pair[1]].pressed.emit()
	_check(not game.active and game.level_run.outcome == LevelRunController.Outcome.SUCCESS and game.matched_pairs == game.pair_count, "matching every pair completes the level")
	_check(AppState.coins() == coins_before + RewardService.level_reward(level) and _records("memory_meadow") == records_before + 1, "Memory Meadow pays the standard reward once")
	_check(game.trigger_progression_action() and game.active and game.level_run.level == level + 1, "the outcome action advances to the next level")
	# Burn every peek to fail.
	for attempt in 40:
		if not game.active:
			break
		var fresh := _pair_indexes(game)
		game.card_buttons[fresh[0][0]].pressed.emit()
		game.card_buttons[fresh[1][0]].pressed.emit()
		game._hide_mismatch()
	_check(not game.active and game.level_run.outcome == LevelRunController.Outcome.FAILURE and game.can_retry_failure(), "running out of peeks fails the level with a retry")
	_check(game.request_retry() and game.active and game.peeks_left == MemoryMeadow.peeks_for_level(game.level) and game.matched_pairs == 0, "retry redeals the same level")
	_unmount(game)


func _pattern_button(game: Node, correct: bool) -> Button:
	for button in game.option_buttons:
		if button.visible and not button.disabled and (str(button.get_meta("pattern_value")) == game.answer) == correct:
			return button
	return null


func _test_pattern() -> void:
	var game: Node = await _mount(PATTERN_SCENE, "pattern_parade")
	var level: int = game.level
	_check(game.active and game.sequence.size() == PatternParade.SHOWN_ITEMS and game.options.has(game.answer), "Pattern Parade shows a pattern whose answer is offered")
	_check(game.options.size() == PatternParade.option_count_for_level(level) and game.pattern_row.get_child_count() == PatternParade.SHOWN_ITEMS + 1, "the row ends with a mystery tile and the right number of choices")
	var unique := {}
	for option in game.options:
		unique[option] = true
	_check(unique.size() == game.options.size(), "choices are never duplicated")
	var wrong := _pattern_button(game, false)
	wrong.pressed.emit()
	_check(game.lives == PatternParade.START_LIVES - 1 and game.active and wrong.disabled and game.round_index == 0, "a wrong pick costs a heart without ending the level")
	game._show_hint()
	var glowing: int = game.option_buttons.filter(func(button: Button) -> bool: return button.visible and (button.get_child(0) as ShapeTile).highlighted).size()
	_check(glowing == 1, "the hint highlights only the correct choice")
	var coins_before := AppState.coins()
	for round_number in game.target_rounds:
		_pattern_button(game, true).pressed.emit()
	_check(not game.active and game.level_run.outcome == LevelRunController.Outcome.SUCCESS and AppState.coins() == coins_before + RewardService.level_reward(level), "finishing every pattern completes and rewards the level")
	_check(game.trigger_progression_action() and game.active and game.lives == PatternParade.START_LIVES, "the next level starts with full hearts")
	# A round with three choices only has two wrong ones, so hearts can run
	# out across rounds as well as within one.
	for attempt in 12:
		if not game.active:
			break
		var next_wrong := _pattern_button(game, false)
		if next_wrong != null and game.round_index < game.target_rounds - 1:
			next_wrong.pressed.emit()
		elif next_wrong != null:
			next_wrong.pressed.emit()
		else:
			_pattern_button(game, true).pressed.emit()
	_check(not game.active and game.level_run.outcome == LevelRunController.Outcome.FAILURE, "three wrong picks fail the level")
	_check(game.request_retry() and game.active and game.round_index == 0, "retry restarts the same level")
	_unmount(game)


func _test_bubbles() -> void:
	var game: Node = await _mount(BUBBLE_SCENE, "bubble_count")
	var level: int = game.level
	_check(game.active and game.bubbles.size() == BubbleCount.bubble_total(level) and game.order.size() == game.bubbles.size(), "Bubble Count spawns one bubble per number")
	var area: Vector2 = game._play_size()
	var inside := true
	for bubble in game.bubbles:
		var position: Vector2 = bubble["position"]
		if position.x < 0.0 or position.y < 0.0 or position.x > area.x or position.y > area.y:
			inside = false
	_check(inside, "bubbles start inside the play area")
	# Tap the wrong bubble through the real pointer path.
	var last: Dictionary = game.bubbles.filter(func(bubble: Dictionary) -> bool: return int(bubble["value"]) == game.order[game.order.size() - 1])[0]
	game.tap_at(last["position"])
	_check(game.lives == BubbleCount.START_LIVES - 1 and game.next_index == 0 and game.active, "popping out of order costs a heart")
	game._show_hint()
	_check(game.hint_value == game.order[0], "the hint marks the next number")
	var coins_before := AppState.coins()
	for value in game.order.duplicate():
		var target: Dictionary = game.bubbles.filter(func(bubble: Dictionary) -> bool: return int(bubble["value"]) == value)[0]
		game.pop_value(int(target["value"]))
	_check(not game.active and game.level_run.outcome == LevelRunController.Outcome.SUCCESS and AppState.coins() == coins_before + RewardService.level_reward(level), "popping every bubble in order completes and rewards the level")
	_check(game.trigger_progression_action() and game.active and game.next_index == 0, "the next level respawns bubbles")
	for frame in 30:
		await get_tree().process_frame
	var contained := true
	var separated := true
	area = game._play_size()
	for first in game.bubbles.size():
		var position: Vector2 = game.bubbles[first]["position"]
		var radius: float = game.bubbles[first]["radius"]
		if position.x < radius - 1.0 or position.y < radius - 1.0 or position.x > area.x - radius + 1.0 or position.y > area.y - radius + 1.0:
			contained = false
		for second in range(first + 1, game.bubbles.size()):
			if position.distance_to(game.bubbles[second]["position"]) < radius * 1.2:
				separated = false
	_check(contained, "drifting bubbles stay inside the play area")
	_check(separated, "bubbles bounce apart instead of stacking")
	for miss in BubbleCount.START_LIVES:
		game.pop_value(game.order[game.order.size() - 1])
	_check(not game.active and game.level_run.outcome == LevelRunController.Outcome.FAILURE, "three wrong pops fail the level")
	_check(game.request_retry() and game.active and game.lives == BubbleCount.START_LIVES, "retry restores hearts")
	_unmount(game)


func _test_rules() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var sound := true
	for level in range(1, 16):
		for round_number in 6:
			var pattern := PatternParade.build_pattern(level, round_number, rng)
			var shown: Array = pattern["sequence"]
			if shown.size() != PatternParade.SHOWN_ITEMS or str(pattern["answer"]).is_empty():
				sound = false
			if bool(pattern["numbers"]):
				var step := int(shown[1]) - int(shown[0])
				for index in range(1, shown.size()):
					if int(shown[index]) - int(shown[index - 1]) != step:
						sound = false
				if int(pattern["answer"]) - int(shown[shown.size() - 1]) != step or int(pattern["answer"]) <= 0:
					sound = false
	_check(sound, "every generated pattern is consistent and has a positive answer")
	_check(PatternParade.build_pattern(1, 0, rng)["numbers"] == false, "level 1 uses shape patterns")
	var ordered := true
	for level in range(1, 16):
		var values := BubbleCount.values_for_level(level, rng)
		if values.size() != BubbleCount.bubble_total(level):
			ordered = false
		for index in range(1, values.size()):
			if values[index] - values[index - 1] != BubbleCount.step_for_level(level):
				ordered = false
	_check(ordered, "bubble numbers always rise by the level's step")
	_check(MemoryMeadow.pairs_for_level(1) == 3 and MemoryMeadow.pairs_for_level(9) == 8 and MemoryMeadow.pairs_for_level(9) <= ShapeTile.SHAPES.size(), "memory boards grow from 3 to 8 pairs and never exceed the shape set")
	for shape in ShapeTile.SHAPES:
		_check(shape == "flower" or ShapeTile.shape_points(shape, 30.0).size() >= 3, "%s has drawable geometry" % shape)
