extends ArcadeGameController

## Memory Meadow: flip two cards at a time and find every matching pair before
## the peeks run out.
const StorybookUI = preload("res://scripts/ui/storybook_ui.gd")
const ShapeTileScene = preload("res://scripts/ui/shape_tile.gd")
const MISMATCH_SECONDS := 0.85

var game_id := "memory_meadow"
var level := 1
var active := false
var failed := false
var started_ms := 0
var pair_count := 0
var matched_pairs := 0
var peeks_left := 0
var card_shapes: Array[String] = []
var card_buttons: Array[Button] = []
var card_tiles: Array[ShapeTile] = []
var matched: Array[bool] = []
var face_up: Array[int] = []
var rng := RandomNumberGenerator.new()
var grid: GridContainer
var progress_label: Label
var message_label: Label
var mismatch_timer: Timer


static func pairs_for_level(for_level: int) -> int:
	if for_level <= 1:
		return 3
	if for_level == 2:
		return 4
	if for_level <= 4:
		return 6
	return 8


static func peeks_for_level(for_level: int) -> int:
	# Every miss costs one peek. Generous early, tighter as the board grows.
	return pairs_for_level(for_level) + (4 if for_level <= 2 else 3)


static func columns_for_cards(card_count: int) -> int:
	return 3 if card_count <= 6 else 4


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
	pair_count = pairs_for_level(level)
	peeks_left = peeks_for_level(level)
	matched_pairs = 0
	face_up.clear()
	mismatch_timer.stop()
	_deal()
	message_label.text = "Flip two cards. Find every matching pair!"
	_refresh_progress()


func _deal() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	card_buttons.clear()
	card_tiles.clear()
	card_shapes.clear()
	matched.clear()
	var shapes: Array = ShapeTile.SHAPES.duplicate()
	_shuffle(shapes)
	for index in pair_count:
		card_shapes.append(str(shapes[index]))
		card_shapes.append(str(shapes[index]))
	_shuffle(card_shapes)
	grid.columns = columns_for_cards(card_shapes.size())
	for index in card_shapes.size():
		var button := Button.new()
		button.name = "MemoryCard%d" % index
		button.set_meta("custom_game_art", true)
		button.custom_minimum_size = Vector2(0, 196 if grid.columns == 3 else 150)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.flat = true
		button.tooltip_text = "Card %d" % (index + 1)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var tile: ShapeTile = ShapeTileScene.new()
		tile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tile.shape = card_shapes[index]
		tile.set_face_down(true)
		button.add_child(tile)
		button.pressed.connect(_flip.bind(index))
		grid.add_child(button)
		card_buttons.append(button)
		card_tiles.append(tile)
		matched.append(false)


func _shuffle(values: Array) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var value = values[index]
		values[index] = values[swap_index]
		values[swap_index] = value


func _flip(index: int) -> void:
	if not active or gameplay_paused or index < 0 or index >= card_shapes.size():
		return
	if matched[index] or index in face_up:
		return
	if face_up.size() >= 2:
		# A third tap skips the wait and turns the missed pair back over.
		_hide_mismatch()
	_clear_highlights()
	card_tiles[index].set_face_down(false)
	face_up.append(index)
	if face_up.size() < 2:
		return
	var first := face_up[0]
	var second := face_up[1]
	if card_shapes[first] == card_shapes[second]:
		matched[first] = true
		matched[second] = true
		card_buttons[first].disabled = true
		card_buttons[second].disabled = true
		face_up.clear()
		matched_pairs += 1
		if matched_pairs >= pair_count:
			var reward := level_run.complete()
			active = level_run.active
			message_label.text = "Every pair found! +%d coins" % reward
			level += 1
		else:
			AudioService.play(&"correct")
			message_label.text = "A match! Keep going."
	else:
		peeks_left -= 1
		if peeks_left <= 0:
			level_run.fail("Out of peeks. Try remembering where each picture hides.")
			active = level_run.active
			failed = level_run.outcome == LevelRunController.Outcome.FAILURE
			message_label.text = "Out of peeks. Try remembering where each picture hides."
		else:
			AudioService.play(&"wrong")
			message_label.text = "Not a match. Remember where they are!"
			mismatch_timer.start(MISMATCH_SECONDS)
	_refresh_progress()


func _hide_mismatch() -> void:
	mismatch_timer.stop()
	for index in face_up:
		if not matched[index]:
			card_tiles[index].set_face_down(true)
	face_up.clear()


func _clear_highlights() -> void:
	for tile in card_tiles:
		tile.set_highlighted(false)


func _refresh_progress() -> void:
	progress_label.text = "LEVEL %d   •   PAIRS %d / %d   •   PEEKS %d" % [level_run.level, matched_pairs, pair_count, maxi(0, peeks_left)]


func build_objective_snapshot(_id: String, _level: int) -> Dictionary:
	return {"primary": "FIND THE PAIRS", "detail": "%d OF %d PAIRS • %d PEEKS LEFT" % [matched_pairs, pair_count, maxi(0, peeks_left)]}


func can_show_hint() -> bool:
	return active and not failed and matched_pairs < pair_count


func _show_hint() -> void:
	if not can_show_hint():
		return
	_hide_mismatch()
	_clear_highlights()
	for first in card_shapes.size():
		if matched[first]:
			continue
		for second in range(first + 1, card_shapes.size()):
			if not matched[second] and card_shapes[second] == card_shapes[first]:
				card_tiles[first].set_highlighted(true)
				card_tiles[second].set_highlighted(true)
				message_label.text = "The two glowing cards are a pair."
				return


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
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)
	progress_label = Label.new()
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StorybookUI.apply_story_label(progress_label, StorybookUI.CREAM, 20, true)
	layout.add_child(progress_label)
	grid = GridContainer.new()
	grid.name = "MemoryGrid"
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	layout.add_child(grid)
	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	StorybookUI.apply_story_label(message_label, StorybookUI.GOLD_BRIGHT, 20, true)
	layout.add_child(message_label)
	var retry := StorybookUI.progression_action_button("Retry / Next", 170, _advance_level)
	retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.add_child(retry)
	retry.hide()
	mismatch_timer = Timer.new()
	mismatch_timer.one_shot = true
	mismatch_timer.timeout.connect(_hide_mismatch)
	add_child(mismatch_timer)
