extends "res://scripts/games/money_counter_base.gd"

const Rules = preload("res://scripts/games/word_game_rules.gd")
const StorybookUI = preload("res://scripts/ui/storybook_ui.gd")
const BILLS := [1, 5, 10, 20, 50, 100]
const BILL_ART := {
	1: "res://assets/games/currency/one_dollar.jpg",
	5: "res://assets/games/currency/five_dollar.png",
	10: "res://assets/games/currency/ten_dollar.png",
	20: "res://assets/games/currency/twenty_dollar.jpg",
	50: "res://assets/games/currency/fifty_dollar.png",
	100: "res://assets/games/currency/one_hundred_dollar.png",
}
const BILL_NAMES := {1: "ONE DOLLAR", 5: "FIVE DOLLARS", 10: "TEN DOLLARS", 20: "TWENTY DOLLARS", 50: "FIFTY DOLLARS", 100: "ONE HUNDRED DOLLARS"}
const NAVY := Color("08112f")
const YELLOW := Color("ffd166")

var rng := RandomNumberGenerator.new()
var target_label: Label
var total_label: Label
var level_label: Label
var coin_label: Label
var message_label: Label
var hint_button: Button
var retry_button: Button
var bill_buttons: Array[Button] = []


static func target_bounds(for_level: int) -> Vector2i:
	return Rules.cash_target_bounds(for_level)


func _ready() -> void:
	rng.randomize()
	configure_money_counter("cash_counter", BILLS)
	level = AppState.current_level("cash_counter")
	_build_ui()
	_start_round()


func _start_round() -> void:
	_start_round_with_lifecycle(true)


func _start_round_with_lifecycle(begin_run: bool) -> void:
	_begin_money_round(begin_run)
	var bounds := target_bounds(level)
	target = rng.randi_range(bounds.x, bounds.y)
	level_label.text = "LEVEL %d" % level
	target_label.text = "TARGET  $%d" % target
	total_label.text = "$0"
	message_label.text = "Tap bills. Exact wins; overshoot ends the round."
	hint_button.text = "FREE HINT" if level == 1 else "HINT  ★5"
	retry_button.hide()
	_set_buttons_enabled(true)


func _add_bill(value: int) -> void:
	var transition := _apply_money_value(value, "Overshot target—try this level again.")
	if transition.get("outcome") == OUTCOME_IGNORED:
		return
	total_label.text = "$%d" % total
	if transition.get("outcome") == OUTCOME_EXACT:
		var reward := int(transition.get("reward", 0))
		message_label.text = "Perfect! +%d coins" % reward
		coin_label.text = "★ %d" % AppState.coins()
		retry_button.text = "NEXT LEVEL"
		retry_button.show()
		_set_buttons_enabled(false)
	elif transition.get("outcome") == OUTCOME_OVERSHOOT:
		message_label.text = "Overshot target—try this level again."
		retry_button.text = "RETRY"
		retry_button.show()
		_set_buttons_enabled(false)


func can_show_hint() -> bool:
	return active


func can_retry_failure() -> bool:
	return _can_retry_money_failure()


func retry_failure() -> void:
	if _retry_money_failure():
		_start_round_with_lifecycle(false)


func _advance_round() -> void:
	if level_run.outcome == LevelRunController.Outcome.RUNNING:
		return
	level = level_run.retry()
	_start_round_with_lifecycle(false)


func _show_hint() -> void:
	if not active:
		return
	var best := _best_fitting_denomination()
	message_label.text = "Try a $%d bill next." % best
	coin_label.text = "★ %d" % AppState.coins()


func _go_back() -> void:
	return_to_category()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = NAVY
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
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	var back := StorybookUI.category_back_button("‹ BACK", 120, _go_back)
	header.add_child(back)
	var title := Label.new()
	title.text = "CASH COUNTER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", StorybookUI.CYAN)
	header.add_child(title)
	coin_label = Label.new()
	coin_label.text = "★ %d" % AppState.coins()
	coin_label.add_theme_color_override("font_color", YELLOW)
	coin_label.add_theme_color_override("font_outline_color", StorybookUI.PLUM)
	coin_label.add_theme_constant_override("outline_size", 3)
	coin_label.add_theme_font_size_override("font_size", 24)
	header.add_child(coin_label)
	layout.add_child(header)
	level_label = Label.new()
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StorybookUI.apply_story_label(level_label, Color("c8d2ff"), 20, true)
	layout.add_child(level_label)
	var target_plaque := PanelContainer.new()
	StorybookUI.apply_prompt_plaque(target_plaque, StorybookUI.CREAM)
	layout.add_child(target_plaque)
	var target_stack := VBoxContainer.new()
	target_plaque.add_child(target_stack)
	target_label = Label.new()
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StorybookUI.apply_story_label(target_label, Color("254b54"), 32, false)
	target_stack.add_child(target_label)
	total_label = Label.new()
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StorybookUI.apply_story_label(total_label, Color("172143"), 72, false)
	target_stack.add_child(total_label)
	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size = Vector2(0, 52)
	message_label.add_theme_font_size_override("font_size", 17)
	layout.add_child(message_label)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	layout.add_child(grid)
	for bill in BILLS:
		var button := Button.new()
		button.text = "$%d %s" % [bill, BILL_NAMES[bill]]
		button.tooltip_text = "%s US bill" % BILL_NAMES[bill].to_lower()
		button.set_meta("currency_art", true)
		button.custom_minimum_size = Vector2(0, 126)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			button.add_theme_color_override(color_name, Color.TRANSPARENT)
		button.add_theme_stylebox_override("normal", StorybookUI.button_style(Color("fff7dc"), StorybookUI.GOLD, 3, 14))
		button.add_theme_stylebox_override("hover", StorybookUI.button_style(Color("ffffff"), StorybookUI.CYAN, 4, 14))
		button.add_theme_stylebox_override("pressed", StorybookUI.button_style(Color("e8ddbd"), StorybookUI.GOLD, 3, 14))
		var art := TextureRect.new()
		art.name = "OfficialBillPortrait"
		art.texture = load(BILL_ART[bill])
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 7)
		button.add_child(art)
		var badge := Label.new()
		badge.text = "$%d" % bill
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		badge.add_theme_font_size_override("font_size", 20)
		badge.add_theme_color_override("font_color", Color("172143"))
		badge.add_theme_color_override("font_outline_color", StorybookUI.CREAM)
		badge.add_theme_constant_override("outline_size", 4)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.add_child(badge)
		button.pressed.connect(_add_bill.bind(bill))
		grid.add_child(button)
		bill_buttons.append(button)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	layout.add_child(actions)
	hint_button = StorybookUI.hint_highlight_button("HINT", 130, _show_hint)
	actions.add_child(hint_button)
	retry_button = StorybookUI.progression_action_button("RETRY", 150, _advance_round)
	actions.add_child(retry_button)


func _set_buttons_enabled(enabled: bool) -> void:
	for button in bill_buttons:
		button.disabled = not enabled
	hint_button.disabled = not enabled
