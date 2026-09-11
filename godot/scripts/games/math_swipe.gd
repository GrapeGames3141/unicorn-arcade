extends ArcadeGameController

const Rules = preload("res://scripts/games/gameplay_rules.gd")
const StorybookUI = preload("res://scripts/ui/storybook_ui.gd")
const EquationGenerator = preload("res://scripts/games/equation_generator.gd")

var level := 1
var target := 0
var completed := 0
var active := false
var started_ms := 0
var problem: Dictionary = {}
var cards: Array[Button] = []
var _gesture_card: Button
var _pointer_id := -2
var _answer_pending := false
var _round_generation := 0
var problem_label: Label
var progress_label: Label
var message_label: Label
var action_button: Button


func _ready() -> void:
	level = AppState.current_level("math_swipe")
	_build_ui()
	_start_level(level)


func _start_level(for_level: int) -> void:
	_start_level_with_lifecycle(for_level, true)


func _start_level_with_lifecycle(for_level: int, begin_run: bool) -> void:
	_round_generation += 1
	level = for_level
	if begin_run:
		level_run.begin("math_swipe", level)
	else:
		level = level_run.level
	target = Rules.math_swipe_target(level)
	completed = 0
	started_ms = level_run.started_ms
	active = level_run.active
	action_button.hide()
	message_label.text = "Swipe in any direction, or tap, to choose."
	_new_problem()


func generate_problem(for_level: int, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var core := EquationGenerator.math_swipe_core(for_level, rng)
	var operation := str(core["operation"])
	var num1 := int(core["left"])
	var num2 := int(core["right"])
	var answer := int(core["answer"])
	var missing := rng.randi_range(0, 2)
	var correct: int = [num1, num2, answer][missing]
	var display := "? %s %d = %d" % [operation, num2, answer]
	if missing == 1:
		display = "%d %s ? = %d" % [num1, operation, answer]
	elif missing == 2:
		display = "%d %s %d = ?" % [num1, operation, num2]
	var wrong: int = correct
	while wrong == correct or wrong < 0:
		var offset := rng.randi_range(-3, 3)
		wrong = correct + (1 if offset == 0 else offset)
	return {"display": display, "correct": correct, "wrong": wrong, "operation": operation}


func _new_problem() -> void:
	_answer_pending = false
	_gesture_card = null
	_pointer_id = -2
	problem = generate_problem(level)
	problem_label.text = problem["display"]
	progress_label.text = "LEVEL %d     %d / %d" % [level, completed, target]
	var correct_left := randf() > 0.5
	for index in cards.size():
		var is_correct := (index == 0) == correct_left
		cards[index].text = str(problem["correct"] if is_correct else problem["wrong"])
		cards[index].set_meta("correct", is_correct)
		cards[index].disabled = false
		cards[index].modulate = Color.WHITE


func _submit(card: Button) -> void:
	if not active or gameplay_paused or _answer_pending or card.disabled:
		return
	_answer_pending = true
	_set_cards_enabled(false)
	if bool(card.get_meta("correct")):
		completed += 1
		if completed >= target:
			var reward := level_run.complete()
			active = level_run.active
			message_label.text = "Level complete! +%d coins" % reward
			action_button.text = "Next Level"
			action_button.show()
			_set_cards_enabled(false)
		else:
			message_label.text = "Correct!"
			_refresh_question.call_deferred(_round_generation)
	else:
		level_run.fail("Wrong answer! Try this level again.")
		active = level_run.active
		message_label.text = "Wrong answer! Try this level again."
		action_button.text = "Retry"
		action_button.show()
		_set_cards_enabled(false)


func _refresh_question(generation: int) -> void:
	if generation == _round_generation and active:
		_new_problem()


func can_retry_failure() -> bool:
	return level_run.can_retry()


func retry_failure() -> void:
	if can_retry_failure():
		_start_level_with_lifecycle(level_run.retry(), false)


func _advance_level() -> void:
	match level_run.outcome:
		LevelRunController.Outcome.SUCCESS, LevelRunController.Outcome.FAILURE:
			_start_level_with_lifecycle(level_run.retry(), false)


func _show_hint() -> void:
	if not active:
		return
	for card in cards:
		card.modulate = Color("ffe172") if bool(card.get_meta("correct", false)) else Color.WHITE
	message_label.text = "The glowing card completes the equation."

func can_show_hint() -> bool:
	return active


func _card_input(event: InputEvent, card: Button) -> void:
	if not active or gameplay_paused or _answer_pending or card.disabled:
		return
	var pointer := -2
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pointer = -1
	elif event is InputEventScreenTouch and event.pressed:
		pointer = event.index
	if pointer != -2:
		if _pointer_id == -2:
			_gesture_card = card
			_pointer_id = pointer
		card.accept_event()


func _input(event: InputEvent) -> void:
	if _pointer_id == -2:
		return
	var released: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _pointer_id == -1
	if event is InputEventScreenTouch:
		released = event.index == _pointer_id and not event.pressed
	if not released:
		return
	var card := _gesture_card
	_gesture_card = null
	_pointer_id = -2
	get_viewport().set_input_as_handled()
	if event is InputEventScreenTouch and event.canceled:
		return
	if is_instance_valid(card):
		_submit(card)


func set_pause_reason(reason: StringName, value: bool) -> void:
	super.set_pause_reason(reason, value)
	if gameplay_paused:
		_gesture_card = null
		_pointer_id = -2


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("100b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 26)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)
	var title := Label.new()
	title.text = "MATH SWIPE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StorybookUI.apply_story_label(title, Color("61e7ff"), 38, true)
	root.add_child(title)
	progress_label = Label.new()
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StorybookUI.apply_story_label(progress_label, StorybookUI.CREAM, 18, true)
	root.add_child(progress_label)
	var prompt_plaque := PanelContainer.new()
	StorybookUI.apply_prompt_plaque(prompt_plaque, StorybookUI.CREAM)
	root.add_child(prompt_plaque)
	var prompt_stack := VBoxContainer.new()
	prompt_plaque.add_child(prompt_stack)
	var prompt := Label.new()
	prompt.text = "SOLVE THE EQUATION"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StorybookUI.apply_story_label(prompt, Color("59375c"), 16, false)
	prompt_stack.add_child(prompt)
	problem_label = Label.new()
	problem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	problem_label.custom_minimum_size.y = 90
	StorybookUI.apply_story_label(problem_label, Color("172143"), 48, false)
	prompt_stack.add_child(problem_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	root.add_child(row)
	for index in 2:
		var card := Button.new()
		card.custom_minimum_size = Vector2(220, 260)
		card.add_theme_font_size_override("font_size", 72)
		StorybookUI.apply_button(card, Color("241c55"), false, 22)
		card.gui_input.connect(_card_input.bind(card))
		card.pressed.connect(_submit.bind(card))
		row.add_child(card)
		cards.append(card)
	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 18)
	root.add_child(message_label)
	action_button = StorybookUI.progression_action_button("", 160, _advance_level)
	root.add_child(action_button)
	var hint := StorybookUI.hint_highlight_button("Hint", 140, func() -> void: if AppState.spend_hint(level): _show_hint())
	root.add_child(hint)
	var back := StorybookUI.category_back_button("Number Games", 170, return_to_category)
	root.add_child(back)


func _set_cards_enabled(enabled: bool) -> void:
	for card in cards:
		card.disabled = not enabled
