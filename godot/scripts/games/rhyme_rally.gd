extends ArcadeGameController

const WordRules = preload("res://scripts/games/word_game_rules.gd")
const StorybookUI = preload("res://scripts/ui/storybook_ui.gd")

const CHALLENGES := [
	{"prompt": "cat", "answer": "hat", "options": ["hat", "dog", "cup", "pen"]},
	{"prompt": "sun", "answer": "fun", "options": ["fun", "cat", "bed", "log"]},
	{"prompt": "hop", "answer": "top", "options": ["top", "red", "sit", "map"]},
	{"prompt": "bug", "answer": "rug", "options": ["rug", "fan", "kit", "den"]},
	{"prompt": "pig", "answer": "wig", "options": ["wig", "box", "mud", "tub"]},
	{"prompt": "bee", "answer": "tree", "options": ["tree", "sky", "ant", "owl"]},
	{"prompt": "car", "answer": "star", "options": ["star", "moon", "blue", "rain"]},
	{"prompt": "cake", "answer": "lake", "options": ["lake", "milk", "frog", "wind"]},
	{"prompt": "ring", "answer": "king", "options": ["king", "gold", "ball", "song"]},
	{"prompt": "boat", "answer": "coat", "options": ["coat", "ship", "sand", "fish"]},
	{"prompt": "light", "answer": "night", "options": ["night", "cloud", "tree", "grass"]},
	{"prompt": "snail", "answer": "trail", "options": ["trail", "shell", "pond", "leaf"]},
	{"prompt": "sing", "answer": "wing", "options": ["wing", "drum", "note", "horn"]},
	{"prompt": "mouse", "answer": "house", "options": ["house", "cheese", "tail", "barn"]},
	{"prompt": "spoon", "answer": "moon", "options": ["moon", "fork", "plate", "bowl"]},
	{"prompt": "frog", "answer": "log", "options": ["log", "pond", "hop", "lily"]},
	{"prompt": "bright", "answer": "kite", "options": ["kite", "dark", "shade", "cloud"]},
	{"prompt": "snake", "answer": "rake", "options": ["rake", "grass", "hiss", "scale"]},
	{"prompt": "queen", "answer": "green", "options": ["green", "crown", "royal", "throne"]},
	{"prompt": "flower", "answer": "tower", "options": ["tower", "petal", "stem", "vase"]},
	{"prompt": "thunder", "answer": "wonder", "options": ["wonder", "storm", "flash", "rain"]},
	{"prompt": "feather", "answer": "weather", "options": ["weather", "bird", "soft", "fluff"]},
	{"prompt": "dragon", "answer": "wagon", "options": ["wagon", "fire", "scale", "knight"]},
	{"prompt": "balloon", "answer": "cartoon", "options": ["cartoon", "float", "string", "party"]},
]

var level := 1
var round_index := 0
var target_rounds := 0
var challenge: Dictionary = {}
var started_ms := 0
var failed := false
var active := false
var prompt_label: Label
var progress_label: Label
var message_label: Label
var option_buttons: Array[Button] = []
var rng := RandomNumberGenerator.new()


static func target_for_level(for_level: int) -> int:
	return mini(12, 3 + int(floor(1.2 * for_level)))


func _ready() -> void:
	rng.randomize()
	level = AppState.current_level("rhyme_rally")
	_build_ui()
	_start_level()


func set_random_seed(seed: int) -> void:
	rng.seed = seed


func _start_level() -> void:
	_start_level_with_lifecycle(true)


func _start_level_with_lifecycle(begin_run: bool) -> void:
	if begin_run:
		level_run.begin("rhyme_rally", level)
	else:
		level = level_run.level
	round_index = 0
	failed = false
	active = level_run.active
	target_rounds = target_for_level(level)
	started_ms = level_run.started_ms
	message_label.text = "Pick the word that rhymes. One wrong answer ends the level."
	_show_round()


func _show_round() -> void:
	var window := WordRules.selection_window(CHALLENGES.size(), level + round_index)
	challenge = CHALLENGES[rng.randi_range(window.x, window.y - 1)].duplicate(true)
	var options: Array = challenge["options"].duplicate()
	_shuffle_options(options)
	prompt_label.text = challenge["prompt"]
	progress_label.text = "%d / %d" % [round_index, target_rounds]
	for index in option_buttons.size():
		option_buttons[index].text = options[index]
		option_buttons[index].disabled = false
		option_buttons[index].modulate = Color.WHITE


func _shuffle_options(options: Array) -> void:
	for index in range(options.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var value = options[index]
		options[index] = options[swap_index]
		options[swap_index] = value


func _pick(answer: String) -> void:
	if not active:
		return
	if answer != challenge["answer"]:
		# Teach the right answer instead of only reporting the miss.
		var lesson := "\"%s\" rhymes with \"%s\". Try this level again!" % [str(challenge["answer"]).capitalize(), str(challenge["prompt"])]
		level_run.fail(lesson)
		active = level_run.active
		failed = level_run.outcome == LevelRunController.Outcome.FAILURE
		message_label.text = lesson
		_set_enabled(false)
		for button in option_buttons:
			button.modulate = Color("ffe172") if button.text == str(challenge["answer"]) else Color(1, 1, 1, 0.55)
		return
	round_index += 1
	if round_index < target_rounds:
		AudioService.play(&"correct")
	if round_index >= target_rounds:
		var reward := level_run.complete()
		active = level_run.active
		_set_enabled(false)
		message_label.text = "Rhyme Rally complete! +%d coins" % reward
		level += 1
	else:
		_show_round()


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


func _show_hint() -> void:
	if not active or failed:
		return
	for button in option_buttons:
		button.modulate = Color("ffe172") if button.text == str(challenge.get("answer", "")) else Color.WHITE
	message_label.text = "The glowing word rhymes with %s." % str(challenge.get("prompt", ""))

func can_show_hint() -> bool:
	return active and not failed and not challenge.is_empty()


func _request_hint() -> void:
	if not can_show_hint():
		return
	if AppState.spend_hint(level):
		_show_hint()


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
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 20)
	margin.add_child(layout)
	var title := Label.new()
	title.text = "RHYME RALLY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StorybookUI.apply_story_label(title, Color("f26fa7"), 38, true)
	layout.add_child(title)
	var prompt_plaque := PanelContainer.new()
	StorybookUI.apply_prompt_plaque(prompt_plaque, StorybookUI.CREAM)
	layout.add_child(prompt_plaque)
	var prompt_stack := VBoxContainer.new()
	prompt_plaque.add_child(prompt_stack)
	var instruction := Label.new()
	instruction.text = "What rhymes with"
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StorybookUI.apply_story_label(instruction, Color("59375c"), 20, false)
	prompt_stack.add_child(instruction)
	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StorybookUI.apply_story_label(prompt_label, Color("9c356d"), 64, false)
	prompt_stack.add_child(prompt_label)
	progress_label = Label.new()
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(progress_label)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	layout.add_child(grid)
	for index in 4:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 110)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 30)
		button.pressed.connect(func() -> void: _pick(button.text))
		grid.add_child(button)
		option_buttons.append(button)
	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 18)
	layout.add_child(message_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(actions)
	var retry := StorybookUI.progression_action_button("Retry / Next", 170, _advance_level)
	actions.add_child(retry)
	retry.hide()
	var hint := StorybookUI.hint_highlight_button("Hint", 120, _request_hint)
	actions.add_child(hint)
	var back := StorybookUI.category_back_button("Word Games", 160, return_to_category)
	actions.add_child(back)


func _set_enabled(enabled: bool) -> void:
	for button in option_buttons:
		button.disabled = not enabled
