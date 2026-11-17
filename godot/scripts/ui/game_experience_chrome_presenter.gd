class_name GameExperienceChromePresenter
extends RefCounted

const StorybookUI = preload("res://scripts/ui/storybook_ui.gd")
const CompanionAssets = preload("res://scripts/meta/companion_asset_catalog.gd")
const PENNY_TEXTURE_PATH := "res://assets/games/currency/penny.png"


func find_primary_layout(node: Node) -> VBoxContainer:
	for child in node.get_children():
		if child is VBoxContainer:
			return child
		var found := find_primary_layout(child)
		if found != null:
			return found
	return null


func apply_storybook_atmosphere(scene: Node) -> void:
	if not is_instance_valid(scene) or scene.has_node("StorybookAtmosphere"):
		return
	var atmosphere := Control.new()
	atmosphere.name = "StorybookAtmosphere"
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	atmosphere.z_index = -20
	var wash := ColorRect.new()
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	StorybookUI.dress_dusk_backdrop(wash)
	atmosphere.add_child(wash)
	scene.add_child(atmosphere)
	scene.move_child(atmosphere, 0)
	for child in scene.get_children():
		if child is ColorRect and child != wash:
			var rect := child as ColorRect
			if is_equal_approx(rect.anchor_right, 1.0) and is_equal_approx(rect.anchor_bottom, 1.0):
				rect.color = Color(rect.color, 0.12)
				break


func hide_legacy_chrome(layout: VBoxContainer, title: String) -> void:
	for child in layout.get_children().slice(0, mini(4, layout.get_child_count())):
		if child is HBoxContainer and contains_navigation(child):
			child.hide()
		elif child is Label:
			var copy := str((child as Label).text).strip_edges().to_upper()
			if copy == title.to_upper() or copy.begins_with("★") or copy.contains("UNICORN JUMP") or copy.contains("MATHTRIS") or copy.contains("COIN COUNT") or copy.contains("CASH COUNTER") or copy.contains("SLIDING WINDOW") or copy.contains("MATH SWIPE") or copy.contains("GALAXY UNICORN") or copy.contains("RHYME RALLY") or copy.contains("RACE THE UNICORN"):
				child.hide()


func contains_navigation(node: Node) -> bool:
	for child in node.get_children():
		if child is Button:
			var text := str((child as Button).text).to_upper()
			if "BACK" in text or "GAMES" in text or text == "ARCADE":
				return true
		elif child is Label and str((child as Label).text).begins_with("★"):
			return true
		if contains_navigation(child):
			return true
	return false


func build_header(title: String, coins: int, back_cb: Callable, home_cb: Callable, profile_cb: Callable) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "StandardGameHeader"
	panel.custom_minimum_size.y = 62
	panel.add_theme_stylebox_override("panel", StorybookUI.plaque_style(StorybookUI.NAVY, StorybookUI.GOLD, 18))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var back := header_button("‹", "Back to game category")
	back.name = "GameHeaderBack"
	back.add_theme_font_size_override("font_size", 32)
	back.pressed.connect(back_cb)
	row.add_child(back)
	var home := header_button("", "Home")
	home.name = "GameHeaderHome"
	StorybookUI.apply_home_button(home)
	home.pressed.connect(home_cb)
	row.add_child(home)
	var title_label := Label.new()
	title_label.text = title.to_upper()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", StorybookUI.CREAM)
	title_label.add_theme_color_override("font_outline_color", StorybookUI.PLUM)
	title_label.add_theme_constant_override("outline_size", 3)
	row.add_child(title_label)
	var profile := header_button("👤", "Open profile without leaving this game")
	profile.name = "GameHeaderProfile"
	profile.add_theme_font_size_override("font_size", 24)
	profile.pressed.connect(profile_cb)
	row.add_child(profile)
	var coin_button := header_button("", "Current coin balance")
	coin_button.name = "GameHeaderCoins"
	coin_button.custom_minimum_size = Vector2(96, 48)
	coin_button.disabled = true
	coin_button.icon = load(PENNY_TEXTURE_PATH) as Texture2D
	coin_button.expand_icon = true
	coin_button.add_theme_constant_override("icon_max_width", 30)
	# The balance is display-only; keep its coin bright instead of greyed out.
	coin_button.add_theme_color_override("icon_disabled_color", Color.WHITE)
	coin_button.add_theme_color_override("font_disabled_color", StorybookUI.GOLD_BRIGHT)
	row.add_child(coin_button)
	update_coin_button(coin_button, coins)
	return {"panel": panel, "coin_button": coin_button}


func header_button(text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(48, 48)
	button.add_theme_font_size_override("font_size", 18)
	StorybookUI.apply_button(button, Color("22345f"), false, 14)
	button.set_meta("standard_game_chrome", true)
	return button


func companion_thumbnail(companion_id: String, minimum_size: Vector2) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.name = "EquippedCompanionMascot"
	portrait.texture = load(CompanionAssets.thumbnail_path(companion_id)) as Texture2D
	portrait.custom_minimum_size = minimum_size
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return portrait


func build_objective_plaque(companion_id: String, ability_cb: Callable, hint_cb: Callable, tutorial_cb: Callable) -> Dictionary:
	var plaque := PanelContainer.new()
	plaque.name = "GameObjectivePlaque"
	plaque.custom_minimum_size.y = 92
	plaque.add_theme_stylebox_override("panel", StorybookUI.plaque_style(StorybookUI.CREAM, StorybookUI.GOLD, 18))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	plaque.add_child(row)
	var mascot := companion_thumbnail(companion_id, Vector2(96, 74))
	mascot.name = "EquippedCompanionMascot"
	row.add_child(mascot)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.custom_minimum_size.x = 0
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(copy)
	var objective_primary := Label.new()
	objective_primary.name = "ObjectivePrimary"
	objective_primary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_primary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_primary.add_theme_font_size_override("font_size", 28)
	objective_primary.add_theme_color_override("font_color", StorybookUI.INK)
	copy.add_child(objective_primary)
	var objective_detail := Label.new()
	objective_detail.name = "ObjectiveDetail"
	objective_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_detail.add_theme_font_size_override("font_size", 16)
	objective_detail.add_theme_color_override("font_color", Color("59375c"))
	copy.add_child(objective_detail)
	var ability_button := Button.new()
	ability_button.name = "CompanionAbility"
	ability_button.custom_minimum_size = Vector2(102, 54)
	ability_button.add_theme_font_size_override("font_size", 14)
	ability_button.pressed.connect(ability_cb)
	StorybookUI.apply_button(ability_button, Color("c45186"), false, 14)
	ability_button.set_meta("standard_game_chrome", true)
	row.add_child(ability_button)
	var hint_button := header_button("HINT", "Show one ordinary hint (free on level 1; 5 coins later)")
	hint_button.name = "OrdinaryHint"
	hint_button.pressed.connect(hint_cb)
	row.add_child(hint_button)
	var help := header_button("?", "Replay the tutorial")
	help.name = "ObjectiveTutorialHelp"
	help.pressed.connect(tutorial_cb)
	row.add_child(help)
	return {"panel": plaque, "objective_primary": objective_primary, "objective_detail": objective_detail, "ability_button": ability_button, "hint_button": hint_button}


func format_cents(cents: int) -> String:
	return "$%d.%02d" % [cents / 100, cents % 100]


func update_coin_button(button: Button, coins: int) -> void:
	if is_instance_valid(button):
		button.text = " %d" % coins


func update_ability_button(button: Button, definition: Dictionary, available: bool) -> void:
	if not is_instance_valid(button):
		return
	button.text = "%s\n%s" % [str(definition.get("name", "Companion")), "READY" if available else "USED"]
	button.tooltip_text = str(definition.get("description", ""))
	button.disabled = not available and bool(definition.get("active", false))


func hide_embedded_hint_controls(node: Node) -> void:
	for child in node.get_children():
		if child is Button and not child.has_meta("standard_game_chrome"):
			var label := str((child as Button).text).to_upper()
			if label.contains("HINT"):
				child.hide()
		hide_embedded_hint_controls(child)


func configure_comet_chrome(scene: Node, game_id: String) -> void:
	if game_id != "comet_math_rescue":
		return
	for node_name in ["CometEquationBanner", "CometRescueMeter"]:
		var duplicate_label := scene.get_node_or_null(node_name)
		if duplicate_label is CanvasItem:
			(duplicate_label as CanvasItem).hide()


func restyle_controls(node: Node) -> void:
	if node is Button:
		var button := node as Button
		if not button.has_meta("standard_game_chrome") and not button.has_meta("currency_art") and not button.has_meta("mathtris_tile") and not button.has_meta("sliding_window_node") and not button.has_meta("custom_game_art"):
			StorybookUI.apply_game_action(button, maxf(96.0, button.custom_minimum_size.x))
			button.custom_minimum_size.y = maxf(56.0, button.custom_minimum_size.y)
			var copy := button.text.to_upper()
			if copy == "ARCADE" or "BACK" in copy or ("GAMES" in copy and ("NUMBER" in copy or "WORD" in copy or "MYSTERY" in copy or "ARCADE" in copy)):
				button.hide()
	elif node is Label:
		var label := node as Label
		var copy := label.text.strip_edges().to_upper()
		if copy.begins_with("★") and not label.has_meta("keep_visible"):
			label.hide()
	for child in node.get_children():
		restyle_controls(child)


func polish_game_labels(node: Node) -> void:
	if node is Label and not (node as Label).has_meta("standard_game_chrome"):
		var label := node as Label
		if label.visible and label.get_theme_font_size("font_size") >= 18:
			if not label.has_theme_color_override("font_outline_color"):
				label.add_theme_color_override("font_outline_color", Color("120d32"))
				label.add_theme_constant_override("outline_size", maxi(2, label.get_theme_constant("outline_size")))
	for child in node.get_children():
		polish_game_labels(child)


func hide_game_scrollbars(node: Node) -> void:
	if node is ScrollContainer:
		var scroll := node as ScrollContainer
		if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	for child in node.get_children():
		hide_game_scrollbars(child)
