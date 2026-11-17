class_name GameCatalogView
extends VBoxContainer

const StorybookUI = preload("res://scripts/ui/storybook_ui.gd")
const ArcadePictogramScene = preload("res://scripts/ui/arcade_pictogram.gd")

const PANEL := Color("14214a")
const PINK := Color("f26fa7")
const YELLOW := Color("ffd166")

var status_label: Label


func build_dashboard(category_callback: Callable) -> void:
	name = "GameCatalogView"
	add_theme_constant_override("separation", 14)
	var intro := Label.new()
	intro.name = "CatalogIntro"
	intro.text = "Choose a path"
	intro.add_theme_font_size_override("font_size", 28)
	intro.add_theme_color_override("font_color", Color("f7f1ff"))
	add_child(intro)
	for category in [
		{"name": "Number", "desc": "Logic & arithmetic", "color": StorybookUI.CYAN},
		{"name": "Word", "desc": "Vocabulary, spelling & rhymes", "color": PINK},
		{"name": "Mystery", "desc": "Detective word puzzles", "color": Color("9b8cff")},
		{"name": "Arcade", "desc": "Fast-action adventures", "color": Color("62e6a7")},
	]:
		var category_name := str(category["name"])
		var games := GameRegistry.games_in_category(category_name)
		var button := _category_card(category, GameRegistry.playable_count(category_name), games.size())
		button.pressed.connect(category_callback.bind(category_name))
		add_child(button)


func build_category(category: String, game_callback: Callable) -> void:
	name = "GameCatalogView"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.name = "CategoryContentScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = false
	scroll.scroll_deadzone = 8
	scroll.clip_contents = true
	add_child(scroll)
	var content := VBoxContainer.new()
	content.name = "CategoryContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	var grid := GridContainer.new()
	grid.name = "CategoryGameGrid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	for game in GameRegistry.games_in_category(category):
		var playable := not str(game["scene"]).is_empty()
		var button := _game_card(game, playable, AppState.current_level(game["id"]))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(game_callback.bind(game))
		grid.add_child(button)
	status_label = Label.new()
	status_label.name = "CategoryStatusLabel"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", YELLOW)
	content.add_child(status_label)


func show_game_status(message: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = message


func _category_card(definition: Dictionary, playable_count: int, game_count: int) -> Button:
	var category_name := str(definition["name"])
	var color: Color = definition["color"]
	var button := _button(category_name, color, 126)
	button.name = "CategoryCard_%s" % category_name
	button.tooltip_text = "%s Games. %s. %d of %d playable." % [category_name, definition["desc"], playable_count, game_count]
	_hide_native_button_text(button)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)
	var icon := ArcadePictogramScene.new()
	icon.name = "CategoryIcon"
	icon.custom_minimum_size = Vector2(82, 82)
	icon.setup(category_name.to_lower(), color)
	row.add_child(icon)
	var details := VBoxContainer.new()
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 4)
	row.add_child(details)
	details.add_child(_label("%s GAMES" % category_name.to_upper(), 23, StorybookUI.INK))
	details.add_child(_label(str(definition["desc"]), 19, Color(StorybookUI.INK, 0.82)))
	details.add_child(_label("%d / %d PLAYABLE" % [playable_count, game_count], 19, Color("254b54")))
	return button


func _game_card(game: Dictionary, playable: bool, level: int) -> Button:
	var title_text := str(game["title"])
	var game_id := str(game["id"])
	var color := _category_color(str(game["category"]))
	var status := "LEVEL %d" % level if playable else "COMING IN PORT"
	var button := _button(title_text, PANEL if playable else Color("111a35"), 184)
	button.name = "GameCard_%s" % game_id
	button.tooltip_text = "%s. %s." % [title_text, status]
	_hide_native_button_text(button)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)
	var icon := ArcadePictogramScene.new()
	icon.name = "GameIcon"
	icon.custom_minimum_size = Vector2(82, 82)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.setup(game_id, color)
	stack.add_child(icon)
	var title := _label(title_text.to_upper(), 20, StorybookUI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(title)
	stack.add_child(_label(status, 19, color, HORIZONTAL_ALIGNMENT_CENTER))
	return button


func _button(value: String, color: Color, height: float) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(0, height)
	button.add_theme_font_size_override("font_size", 18)
	StorybookUI.apply_button(button, color, StorybookUI.uses_dark_ink(color))
	return button


func _hide_native_button_text(button: Button) -> void:
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_outline_color"]:
		button.add_theme_color_override(state, Color.TRANSPARENT)
	button.add_theme_constant_override("outline_size", 0)


func _label(value: String, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(StorybookUI.PLUM, 0.72) if color.get_luminance() > 0.55 else Color(StorybookUI.CREAM, 0.46))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _category_color(category: String) -> Color:
	return {"Number": StorybookUI.CYAN, "Word": PINK, "Mystery": Color("9b8cff"), "Arcade": Color("62e6a7")}.get(category, YELLOW)
