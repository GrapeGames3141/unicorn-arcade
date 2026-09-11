class_name ProfileView
extends ScrollContainer

const StorybookUI = preload("res://scripts/ui/storybook_ui.gd")
const ArcadePictogramScene = preload("res://scripts/ui/arcade_pictogram.gd")
const ProgressRingScene = preload("res://scripts/ui/progress_ring.gd")

const PENNY_TEXTURE_PATH := "res://assets/games/currency/penny.png"
const PINK := Color("f26fa7")
const YELLOW := Color("ffd166")

signal build_complete

var category_filter := "All"
var content: VBoxContainer
var _is_current := Callable()
var _alley_callback := Callable()
var _logout_callback := Callable()
var _dialog_host: Node


func configure(
	filter: String,
	current: Callable,
	alley_callback: Callable,
	logout_callback: Callable,
	dialog_host: Node,
) -> void:
	category_filter = filter
	_is_current = current
	_alley_callback = alley_callback
	_logout_callback = logout_callback
	_dialog_host = dialog_host


func build() -> void:
	name = "ProfileContentScroll"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	follow_focus = false
	scroll_deadzone = 8
	clip_contents = true
	visible = false

	content = VBoxContainer.new()
	content.name = "ProfileContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	add_child(content)

	if not _page_is_current():
		return
	content.add_child(_build_unicorn_banner())
	content.add_child(_build_stat_strip())
	content.add_child(_section_title("MAGIC RINGS"))
	content.add_child(_build_progress_rings())
	content.add_child(_section_title("YOUR GAMES"))
	content.add_child(_build_category_chips())
	var game_grid := _build_game_grid()
	content.add_child(game_grid)
	_populate_game_grid(game_grid)
	content.add_child(_section_title("SETTINGS & LEARNING"))
	content.add_child(_build_settings())
	content.add_child(_build_logout_button())

	var bottom_pad := Control.new()
	bottom_pad.custom_minimum_size.y = 24
	content.add_child(bottom_pad)

	for _frame in 2:
		await get_tree().process_frame
	if not _page_is_current():
		return
	content.custom_minimum_size.y = content.get_combined_minimum_size().y
	show()
	build_complete.emit()


func apply_category_filter(category: String) -> void:
	var game_grid := content.find_child("ProfileGameGrid", true, false) as GridContainer
	var chips := content.find_child("ProfileCategoryChips", true, false) as HFlowContainer
	if not is_instance_valid(game_grid) or not is_instance_valid(chips):
		return

	var preserved_scroll := scroll_vertical
	category_filter = category
	_populate_game_grid(game_grid)
	for child in chips.get_children():
		var chip := child as Button
		if not is_instance_valid(chip):
			continue
		var chip_category := str(chip.get_meta("profile_category", ""))
		var active := chip_category == category_filter
		chip.button_pressed = active
		var fill := Color("22345f")
		if active:
			fill = StorybookUI.GOLD if chip_category == "All" else _category_color(chip_category)
		StorybookUI.apply_button(chip, fill, active and chip_category == "All", 14)
	scroll_vertical = preserved_scroll
	set_deferred("scroll_vertical", preserved_scroll)


func _page_is_current() -> bool:
	return (
		_is_current.is_valid()
		and bool(_is_current.call())
		and is_instance_valid(content)
		and content.is_inside_tree()
	)


func _build_unicorn_banner() -> PanelContainer:
	var companion := MetaCatalog.companion(AppState.equipped_companion())
	var ability_definition := CompanionAbilityService.definition()
	var banner := PanelContainer.new()
	banner.name = "EquippedUnicornBanner"
	banner.mouse_filter = Control.MOUSE_FILTER_PASS
	banner.custom_minimum_size.y = 268
	banner.add_theme_stylebox_override("panel", StorybookUI.plaque_style(Color("241c55"), PINK, 24))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	banner.add_child(stack)
	var eyebrow := Label.new()
	eyebrow.text = "EQUIPPED UNICORN"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 15)
	eyebrow.add_theme_color_override("font_color", StorybookUI.GOLD_BRIGHT)
	stack.add_child(eyebrow)

	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 14)
	stack.add_child(hero_row)
	var portrait := TextureRect.new()
	portrait.name = "ProfileCompanionPortrait"
	portrait.texture = load("res://assets/characters/unicorns/thumbnails/%s.png" % AppState.equipped_companion())
	portrait.custom_minimum_size = Vector2(188, 168)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.tooltip_text = "%s portrait" % str(companion.get("name", "Companion"))
	portrait.set_meta("source_model_id", AppState.equipped_companion())
	hero_row.add_child(portrait)

	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 8)
	hero_row.add_child(identity)
	identity.add_child(_label(AppState.player_name().to_upper(), 28, StorybookUI.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	identity.add_child(_label(str(companion.get("name", "Sparkle")).to_upper(), 24, PINK, HORIZONTAL_ALIGNMENT_CENTER))
	var power := Label.new()
	power.text = "%s %s\n%s" % [
		String.chr(0x2726),
		str(ability_definition.get("name", "Companion Power")).to_upper(),
		str(ability_definition.get("description", "")),
	]
	power.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	power.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power.add_theme_font_size_override("font_size", 17)
	power.add_theme_color_override("font_color", StorybookUI.MUTED)
	identity.add_child(power)

	var alley := _button("VISIT UNICORN ALLEY", Color("c45186"), 54)
	alley.name = "ProfileAlleyButton"
	alley.mouse_filter = Control.MOUSE_FILTER_PASS
	if _alley_callback.is_valid():
		alley.pressed.connect(_alley_callback)
	stack.add_child(alley)
	return banner


func _build_stat_strip() -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "ProfileStatStrip"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var cards := [
		ProfileViewComponents.money_stat(AppState.coins(), "COINS", load(PENNY_TEXTURE_PATH) as Texture2D),
		ProfileViewComponents.stat("%d" % AppState.completed_run_count(), "RUNS"),
		ProfileViewComponents.stat("%d / 6" % AppState.owned_companions().size(), "UNICORNS"),
		ProfileViewComponents.stat("%d" % AppState.data.get("inventory", {}).size(), "DECOR"),
	]
	for card in cards:
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
	return grid


func _build_progress_rings() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "ProfileProgressRings"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", StorybookUI.plaque_style(StorybookUI.NAVY, StorybookUI.GOLD, 20))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	card.add_child(grid)
	for category in ["Number", "Word", "Mystery", "Arcade"]:
		var games := GameRegistry.games_in_category(category)
		var ring := ProgressRingScene.new()
		ring.setup(
			ProfileViewComponents.category_progress(games, AppState.current_level),
			category.to_upper(),
			"%d RUNS" % ProfileViewComponents.category_runs(games, AppState.progress_for_game),
			_category_color(category),
		)
		ring.custom_minimum_size = Vector2(0, 148)
		ring.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(ring)
	return card


func _build_category_chips() -> HFlowContainer:
	var row := HFlowContainer.new()
	row.name = "ProfileCategoryChips"
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	for category in ["All", "Number", "Word", "Mystery", "Arcade"]:
		var chip := Button.new()
		chip.text = category.to_upper()
		chip.custom_minimum_size = Vector2(88, 48)
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.set_meta("profile_category", category)
		chip.toggle_mode = true
		chip.button_pressed = category_filter == category
		var fill := Color("22345f")
		if category_filter == category:
			fill = StorybookUI.GOLD if category == "All" else _category_color(category)
		StorybookUI.apply_button(chip, fill, category_filter == category and category == "All", 14)
		chip.pressed.connect(apply_category_filter.bind(category))
		row.add_child(chip)
	return row


func _build_game_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "ProfileGameGrid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	return grid


func _populate_game_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var categories := ["Number", "Word", "Mystery", "Arcade"]
	if category_filter != "All":
		categories = [category_filter]
	for category in categories:
		for game in GameRegistry.games_in_category(category):
			grid.add_child(_build_game_tile(game, category))
	# Reserve the all-games grid height, preventing a filter change from clamping
	# an otherwise retained scroll offset or shifting the revealed profile layout.
	var maximum_rows := ceili(float(GameRegistry.all_games().size()) / float(grid.columns))
	grid.custom_minimum_size.y = maximum_rows * 126.0 + maxf(0.0, maximum_rows - 1.0) * 10.0


func _build_game_tile(game: Dictionary, category: String) -> PanelContainer:
	var completed: Array = AppState.progress_for_game(game["id"]).get("completed", [])
	var level := AppState.current_level(game["id"])
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(0, 126)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.mouse_filter = Control.MOUSE_FILTER_PASS
	tile.add_theme_stylebox_override("panel", StorybookUI.plaque_style(StorybookUI.CREAM, _category_color(category), 14))
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 4)
	tile.add_child(stack)
	var pictogram := ArcadePictogramScene.new()
	pictogram.custom_minimum_size = Vector2(58, 58)
	pictogram.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pictogram.setup(str(game["id"]), _category_color(category))
	stack.add_child(pictogram)
	var title_line := Label.new()
	title_line.text = str(game["title"]).to_upper()
	title_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_line.add_theme_font_size_override("font_size", 15)
	title_line.add_theme_color_override("font_color", StorybookUI.INK)
	stack.add_child(title_line)
	var progress_line := Label.new()
	progress_line.text = "LV %d  %s  %d RUNS" % [level, String.chr(0x2022), completed.size()]
	if game["id"] == "mathtris":
		progress_line.text = "BEST %d  •  %d RUNS" % [int(AppState.progress_for_game("mathtris").get("best_score", 0)), completed.size()]
	progress_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_line.add_theme_font_size_override("font_size", 14)
	progress_line.add_theme_color_override("font_color", Color("254b54"))
	stack.add_child(progress_line)
	return tile


func _build_settings() -> PanelContainer:
	var settings_card := PanelContainer.new()
	settings_card.name = "ProfileSettings"
	settings_card.mouse_filter = Control.MOUSE_FILTER_PASS
	settings_card.add_theme_stylebox_override("panel", StorybookUI.plaque_style(StorybookUI.CREAM, StorybookUI.GOLD, 18))
	var settings_stack := VBoxContainer.new()
	settings_stack.add_theme_constant_override("separation", 8)
	settings_card.add_child(settings_stack)
	for setting_data in [
		{"key": "music", "label": "Music"},
		{"key": "sound", "label": "Sound effects"},
		{"key": "reduced_motion", "label": "Reduced motion"},
		{"key": "tutorials_enabled", "label": "Guided first three levels"},
	]:
		var toggle := CheckButton.new()
		toggle.text = setting_data["label"]
		toggle.button_pressed = bool(AppState.setting(setting_data["key"], setting_data["key"] != "reduced_motion"))
		toggle.custom_minimum_size.y = 56
		toggle.mouse_filter = Control.MOUSE_FILTER_PASS
		toggle.add_theme_font_size_override("font_size", 19)
		toggle.add_theme_color_override("font_color", StorybookUI.INK)
		toggle.toggled.connect(func(value: bool) -> void: AppState.set_setting(setting_data["key"], value))
		settings_stack.add_child(toggle)
	var feedback := Label.new()
	feedback.name = "ProfileSettingsFeedback"
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.add_theme_color_override("font_color", Color("254b54"))
	var reset_tutorials := _button("RESET ALL TUTORIALS", Color("6d3f83"), 60)
	reset_tutorials.name = "ProfileResetTutorialsButton"
	reset_tutorials.mouse_filter = Control.MOUSE_FILTER_PASS
	reset_tutorials.pressed.connect(_show_reset_tutorials_dialog.bind(feedback))
	settings_stack.add_child(reset_tutorials)
	settings_stack.add_child(feedback)
	return settings_card


func _build_logout_button() -> Button:
	var logout := _button("LOG OUT", Color("7c2948"), 60)
	logout.name = "ProfileLogoutButton"
	logout.mouse_filter = Control.MOUSE_FILTER_PASS
	logout.pressed.connect(_logout)
	return logout


func _show_reset_tutorials_dialog(feedback: Label) -> void:
	if not is_instance_valid(_dialog_host):
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Reset tutorials?"
	dialog.dialog_text = "The first three guided levels will be available again in every game."
	_dialog_host.add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		AppState.reset_tutorials()
		feedback.text = "Tutorial progress reset."
		dialog.queue_free()
	)
	dialog.popup_centered(Vector2i(520, 260))


func _logout() -> void:
	if AppState.logout() and _logout_callback.is_valid():
		_logout_callback.call()


func _section_title(value: String) -> Label:
	return ProfileViewComponents.section_title(value)


func _button(value: String, color: Color, height: float) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(0, height)
	button.add_theme_font_size_override("font_size", 18)
	StorybookUI.apply_button(button, color, StorybookUI.uses_dark_ink(color))
	return button


func _label(value: String, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
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
	return {
		"Number": StorybookUI.CYAN,
		"Word": PINK,
		"Mystery": Color("9b8cff"),
		"Arcade": Color("62e6a7"),
	}.get(category, YELLOW)
