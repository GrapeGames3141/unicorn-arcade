extends ArcadeGameController

## Pattern Parade: study a repeating or counting pattern and choose what comes
## next. Early levels use shapes; later levels add skip-counting numbers.
const StorybookUI = preload("res://scripts/ui/storybook_ui.gd")
const ShapeTileScene = preload("res://scripts/ui/shape_tile.gd")
const SHOWN_ITEMS := 6
const START_LIVES := 3
const SHAPE_UNITS := [
	[[0, 1]],
	[[0, 1], [0, 0, 1], [0, 1, 1]],
	[[0, 0, 1], [0, 1, 1], [0, 1, 2]],
	[[0, 1, 2], [0, 0, 1, 1], [0, 1, 0, 2]],
]

var game_id := "pattern_parade"
var level := 1
var active := false
var failed := false
var started_ms := 0
var round_index := 0
var target_rounds := 0
var lives := START_LIVES
var sequence: Array[String] = []
var answer := ""
var options: Array[String] = []
var uses_numbers := false
var rng := RandomNumberGenerator.new()
var pattern_row: HBoxContainer
var option_grid: GridContainer
var option_buttons: Array[Button] = []
var progress_label: Label
var message_label: Label


static func target_for_level(for_level: int) -> int:
	return mini(8, 3 + int(for_level / 2.0))


static func option_count_for_level(for_level: int) -> int:
	return 3 if for_level <= 2 else 4


## Returns {"sequence": Array[String], "answer": String, "numbers": bool}.
## Shape tokens are shape names; number tokens are digits.
static func build_pattern(for_level: int, round_number: int, random: RandomNumberGenerator) -> Dictionary:
	var number_round := for_level >= 5 and (for_level >= 9 or (for_level + round_number) % 2 == 0)
	var shown: Array[String] = []
	if number_round:
		var steps := [1, 2] if for_level < 7 else ([2, 5, 10] if for_level < 10 else [2, 3, 5, 10])
		var step: int = steps[random.randi_range(0, steps.size() - 1)]
		var descending := for_level >= 8 and random.randf() < 0.35
		var first := random.randi_range(1, 9) * (step if step >= 5 else 1)
		if descending:
			first += step * (SHOWN_ITEMS + 1)
		for index in SHOWN_ITEMS:
			shown.append(str(first + (-step if descending else step) * index))
		return {"sequence": shown, "answer": str(first + (-step if descending else step) * SHOWN_ITEMS), "numbers": true, "step": step}
	var units: Array = SHAPE_UNITS[clampi(int((for_level - 1) / 2.0), 0, SHAPE_UNITS.size() - 1)]
	var unit: Array = units[random.randi_range(0, units.size() - 1)]
	var shapes: Array = ShapeTile.SHAPES.duplicate()
	for index in range(shapes.size() - 1, 0, -1):
		var swap_index := random.randi_range(0, index)
		var value = shapes[index]
		shapes[index] = shapes[swap_index]
		shapes[swap_index] = value
	for index in SHOWN_ITEMS:
		shown.append(str(shapes[int(unit[index % unit.size()])]))
	return {"sequence": shown, "answer": str(shapes[int(unit[SHOWN_ITEMS % unit.size()])]), "numbers": false, "step": 0}


func _ready() -> void:
	rng.randomize()
	level = AppState.current_level(game_id)
	_build_ui()
	_start_level()


func set_random_seed(seed_value: int) -> void:
	rng.seed = seed_value


func _start_level() -> void:
	_start_level_with_lifecycle(true)


func _start_level_with_lifecycle(begin_run: bool) -> void:
	if begin_run:
		level_run.begin(game_id, level)
	else:
		level = level_run.level
	active = level_run.active
	failed = false
	started_ms = level_run.started_ms
	round_index = 0
	lives = START_LIVES
	target_rounds = target_for_level(level)
	message_label.text = "What comes next in the parade?"
	_show_round()


func _show_round() -> void:
	var pattern := build_pattern(level, round_index, rng)
	sequence.assign(pattern["sequence"])
	answer = str(pattern["answer"])
	uses_numbers = bool(pattern["numbers"])
	options = _build_options(int(pattern.get("step", 0)))
	for child in pattern_row.get_children():
		pattern_row.remove_child(child)
		child.queue_free()
	for token in sequence:
		pattern_row.add_child(_tile(token, false))
	var mystery := _tile("?", true)
	mystery.name = "PatternMystery"
	pattern_row.add_child(mystery)
	for index in option_buttons.size():
		var button := option_buttons[index]
		button.visible = index < options.size()
		if not button.visible:
			continue
		button.disabled = false
		button.set_meta("pattern_value", options[index])
		button.tooltip_text = options[index]
		var tile := button.get_child(0) as ShapeTile
		tile.set_highlighted(false)
		tile.modulate = Color.WHITE
		if uses_numbers:
			tile.show_label(options[index])
		else:
			tile.show_shape(options[index])
	_refresh_progress()


func _build_options(step: int) -> Array[String]:
	var wanted := option_count_for_level(level)
	var result: Array[String] = [answer]
	if uses_numbers:
		var correct := int(answer)
		for candidate in [correct + step, correct - step, correct + 1, correct - 1, correct + 2 * step, correct + 10]:
			if result.size() >= wanted:
				break
			if candidate > 0 and str(candidate) not in result:
				result.append(str(candidate))
	else:
		# Shapes already in the pattern make the most tempting wrong answers.
		for token in sequence:
			if result.size() < wanted and token not in result:
				result.append(token)
		var spare: Array = ShapeTile.SHAPES.duplicate()
		while result.size() < wanted and not spare.is_empty():
			var pick: String = spare.pop_at(rng.randi_range(0, spare.size() - 1))
			if pick not in result:
				result.append(pick)
	for index in range(result.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var value := result[index]
		result[index] = result[swap_index]
		result[swap_index] = value
	return result


func _tile(token: String, mystery: bool) -> ShapeTile:
	var tile: ShapeTile = ShapeTileScene.new()
	tile.custom_minimum_size = Vector2(0, 86)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if mystery:
		tile.tile_color = Color("ffe9a8")
		tile.show_label("?")
		tile.set_highlighted(true)
	elif uses_numbers:
		tile.show_label(token)
	else:
		tile.show_shape(token)
	return tile


func _choose(button: Button) -> void:
	if not active or gameplay_paused or button.disabled:
		return
	var value := str(button.get_meta("pattern_value", ""))
	if value == answer:
		round_index += 1
		if round_index >= target_rounds:
			var reward := level_run.complete()
			active = level_run.active
			_set_options_enabled(false)
			message_label.text = "Parade complete! +%d coins" % reward
			level += 1
			_refresh_progress()
		else:
			AudioService.play(&"correct")
			message_label.text = "Yes! That keeps the pattern going."
			_show_round()
		return
	lives -= 1
	button.disabled = true
	(button.get_child(0) as ShapeTile).modulate = Color(1, 1, 1, 0.35)
	if lives <= 0:
		level_run.fail("Out of hearts. Say the pattern out loud, then try again.")
		active = level_run.active
		failed = level_run.outcome == LevelRunController.Outcome.FAILURE
		_set_options_enabled(false)
		message_label.text = "Out of hearts. Say the pattern out loud, then try again."
	else:
		AudioService.play(&"wrong")
		message_label.text = "Not that one. Look at how the pattern repeats."
	_refresh_progress()


func _set_options_enabled(enabled: bool) -> void:
	for button in option_buttons:
		button.disabled = not enabled


func _refresh_progress() -> void:
	progress_label.text = "LEVEL %d   •   %d / %d   •   ♥ %d" % [level_run.level, round_index, target_rounds, maxi(0, lives)]


func build_objective_snapshot(_id: String, _level: int) -> Dictionary:
	return {"primary": "WHAT COMES NEXT?", "detail": "PATTERN %d OF %d • %d HEARTS" % [mini(round_index + 1, maxi(1, target_rounds)), target_rounds, maxi(0, lives)]}


func can_show_hint() -> bool:
	return active and not failed and not answer.is_empty()


func _show_hint() -> void:
	if not can_show_hint():
		return
	for button in option_buttons:
		if button.visible and str(button.get_meta("pattern_value", "")) == answer:
			(button.get_child(0) as ShapeTile).set_highlighted(true)
	message_label.text = "The glowing choice continues the pattern."


func can_retry_failure() -> bool:
	return level_run.can_retry()


func retry_failure() -> void:
	if level_run.can_retry():
		level = level_run.retry()
		_start_level_with_lifecycle(false)


func _advance_level() -> void:
	if level_run.outcome == LevelRunController.Outcome.RUNNING:
		_start_level_with_lifecycle(true)
		return
	level = level_run.retry()
	_start_level_with_lifecycle(false)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("08112f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	progress_label = Label.new()
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StorybookUI.apply_story_label(progress_label, StorybookUI.CREAM, 20, true)
	layout.add_child(progress_label)
	var plaque := PanelContainer.new()
	plaque.name = "PatternPlaque"
	StorybookUI.apply_prompt_plaque(plaque, Color("2a2063"))
	layout.add_child(plaque)
	pattern_row = HBoxContainer.new()
	pattern_row.name = "PatternRow"
	pattern_row.add_theme_constant_override("separation", 6)
	plaque.add_child(pattern_row)
	var prompt := Label.new()
	prompt.text = "Tap what comes next"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StorybookUI.apply_story_label(prompt, StorybookUI.CREAM, 22, true)
	layout.add_child(prompt)
	option_grid = GridContainer.new()
	option_grid.name = "PatternOptions"
	option_grid.columns = 2
	option_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_grid.add_theme_constant_override("h_separation", 12)
	option_grid.add_theme_constant_override("v_separation", 12)
	layout.add_child(option_grid)
	for index in 4:
		var button := Button.new()
		button.name = "PatternOption%d" % index
		button.set_meta("custom_game_art", true)
		button.custom_minimum_size = Vector2(0, 176)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.flat = true
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var tile: ShapeTile = ShapeTileScene.new()
		tile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.add_child(tile)
		button.pressed.connect(_choose.bind(button))
		option_grid.add_child(button)
		option_buttons.append(button)
	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	StorybookUI.apply_story_label(message_label, StorybookUI.GOLD_BRIGHT, 20, true)
	layout.add_child(message_label)
	var retry := StorybookUI.progression_action_button("Retry / Next", 170, _advance_level)
	retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.add_child(retry)
	retry.hide()
