class_name ProfileViewComponents
extends RefCounted

const StorybookUI = preload("res://scripts/ui/storybook_ui.gd")

static func category_progress(games: Array, level_for: Callable) -> float:
	if games.is_empty():
		return 0.0
	var total := 0.0
	for game in games:
		total += clampf(float(int(level_for.call(game["id"])) - 1) / 20.0, 0.0, 1.0)
	return total / games.size()

static func category_runs(games: Array, progress_for: Callable) -> int:
	var total := 0
	for game in games:
		total += progress_for.call(game["id"]).get("completed", []).size()
	return total

static func stat(value: String, caption: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 70)
	card.add_theme_stylebox_override("panel", StorybookUI.plaque_style(Color("f7d8eb"), Color("d16b9e"), 12))
	var label := Label.new()
	label.text = "%s\n%s" % [value, caption]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", StorybookUI.INK)
	card.add_child(label)
	return card


static func money_stat(amount: int, caption: String, penny_texture: Texture2D) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 70)
	card.add_theme_stylebox_override("panel", StorybookUI.plaque_style(Color("f7d8eb"), Color("d16b9e"), 12))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	card.add_child(row)
	var coin := TextureRect.new()
	coin.texture = penny_texture
	coin.custom_minimum_size = Vector2(34, 34)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(coin)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(stack)
	var value := Label.new()
	value.text = str(amount)
	value.add_theme_font_size_override("font_size", 22)
	value.add_theme_color_override("font_color", StorybookUI.INK)
	stack.add_child(value)
	var cap := Label.new()
	cap.text = caption
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 14)
	cap.add_theme_color_override("font_color", Color("254b54"))
	stack.add_child(cap)
	return card

static func section_title(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", StorybookUI.GOLD_BRIGHT)
	label.add_theme_color_override("font_outline_color", StorybookUI.PLUM)
	label.add_theme_constant_override("outline_size", 3)
	return label
