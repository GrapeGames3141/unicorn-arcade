class_name StorybookUI
extends RefCounted

const NAVY := Color("17254d")
const NAVY_HOVER := Color("263a67")
const NAVY_PRESSED := Color("0b1433")
const GOLD := Color("e1ae4f")
const GOLD_BRIGHT := Color("f4d37f")
const CREAM := Color("fff3d6")
const INK := Color("172143")
const CYAN := Color("58d6e8")
const PLUM := Color("3c183d")
const MUTED := Color("c9d3ef")
const UNICORN_HOUSE_HOME_ICON_PATH := "res://assets/ui/home_glyph_v2.png"
## Home is the one header button drawn in gold so it is easy to spot.
const HOME_FILL := Color("f4c95d")
const MEADOW_BACKGROUND_PATH := "res://assets/meta/environments/magical_meadow_v1.png"
## One shared "meadow at dusk" backdrop keeps menus, shop, rooms, and games in
## the same world as the Home meadow while leaving cream text readable.
const DUSK_WASH := Color("1a1447")
const DUSK_MEADOW_ALPHA := 0.58
const DUSK_VEIL := Color(0.09, 0.06, 0.26, 0.36)


static func apply_button(button: BaseButton, fill: Color = NAVY, dark_text: bool = false, radius: int = 14) -> void:
	var text_color := INK if dark_text else CREAM
	var hover_text := INK if dark_text else Color.WHITE
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", hover_text)
	button.add_theme_color_override("font_pressed_color", hover_text)
	button.add_theme_color_override("font_focus_color", hover_text)
	button.add_theme_color_override("font_disabled_color", Color(text_color, 0.58))
	button.add_theme_color_override("font_outline_color", Color(CREAM if dark_text else PLUM, 0.76))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_stylebox_override("normal", button_style(fill, GOLD, 3, radius))
	button.add_theme_stylebox_override("hover", button_style(fill.lightened(0.09), CYAN, 4, radius))
	button.add_theme_stylebox_override("pressed", button_style(fill.darkened(0.11), GOLD_BRIGHT, 3, radius, 1))
	button.add_theme_stylebox_override("focus", button_style(fill.lightened(0.05), CYAN, 4, radius))
	button.add_theme_stylebox_override("disabled", button_style(fill.darkened(0.32), Color(GOLD, 0.42), 2, radius, 1))


static func apply_game_action(button: BaseButton, minimum_width: float = 150.0) -> void:
	apply_button(button, NAVY, false, 14)
	button.custom_minimum_size.x = maxf(button.custom_minimum_size.x, minimum_width)
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 58.0)
	# Games may ask for larger answer text; never shrink it back to the action size.
	var requested_font := button.get_theme_font_size("font_size") if button.has_theme_font_size_override("font_size") else 0
	button.add_theme_font_size_override("font_size", maxi(19, requested_font))
	button.set_meta("storybook_game_action", true)


static func category_back_button(text: String, minimum_width: float, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	apply_game_action(button, minimum_width)
	button.set_meta("storybook_action", "category_back")
	button.pressed.connect(callback)
	return button


static func progression_action_button(text: String, minimum_width: float, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	apply_game_action(button, minimum_width)
	button.set_meta("storybook_action", "progression")
	button.pressed.connect(callback)
	return button


static func hint_highlight_button(text: String, minimum_width: float, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	apply_game_action(button, minimum_width)
	button.set_meta("storybook_action", "hint_highlight")
	button.pressed.connect(callback)
	return button


static func apply_home_button(button: BaseButton, icon_width: int = 34) -> void:
	apply_button(button, HOME_FILL, true, 14)
	button.text = ""
	var home_icon := load(UNICORN_HOUSE_HOME_ICON_PATH) as Texture2D
	if home_icon != null:
		button.icon = home_icon
	else:
		button.text = "⌂"
	button.expand_icon = true
	if str(button.tooltip_text).is_empty():
		button.tooltip_text = "Home"
	button.custom_minimum_size = Vector2(maxi(48, icon_width + 14), 48)
	button.add_theme_constant_override("icon_max_width", icon_width)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := button.get_theme_stylebox(state)
		if style is StyleBoxFlat:
			var copy := (style as StyleBoxFlat).duplicate() as StyleBoxFlat
			copy.content_margin_left = 6
			copy.content_margin_right = 6
			copy.content_margin_top = 4
			copy.content_margin_bottom = 4
			button.add_theme_stylebox_override(state, copy)


static func apply_line_edit(line_edit: LineEdit) -> void:
	line_edit.add_theme_color_override("font_color", CREAM)
	line_edit.add_theme_color_override("font_placeholder_color", Color(MUTED, 0.92))
	line_edit.add_theme_color_override("caret_color", CYAN)
	line_edit.add_theme_stylebox_override("normal", input_style(NAVY, GOLD, 3))
	line_edit.add_theme_stylebox_override("focus", input_style(NAVY_HOVER, CYAN, 4))
	line_edit.add_theme_stylebox_override("read_only", input_style(NAVY_PRESSED, Color(GOLD, 0.38), 2))


static func button_style(fill: Color, border: Color = GOLD, width: int = 3, radius: int = 14, shadow_size: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(PLUM, 0.64)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


static func plaque_style(fill: Color = CREAM, border: Color = GOLD, radius: int = 14) -> StyleBoxFlat:
	var style := button_style(fill, border, 3, radius, 4)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


static func input_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := button_style(fill, border, width, 12, 3)
	style.content_margin_left = 18
	style.content_margin_right = 18
	return style


static func uses_dark_ink(fill: Color) -> bool:
	return fill.get_luminance() >= 0.43


static func apply_story_label(label: Label, color: Color = CREAM, font_size: int = 20, outlined: bool = true) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if outlined:
		label.add_theme_color_override("font_outline_color", PLUM)
		label.add_theme_constant_override("outline_size", 3)


static func apply_prompt_plaque(panel: PanelContainer, fill: Color = CREAM) -> void:
	panel.add_theme_stylebox_override("panel", plaque_style(fill, GOLD, 18))


static func dress_dusk_backdrop(background: ColorRect) -> void:
	background.color = DUSK_WASH
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if background.has_node("DuskMeadow"):
		return
	var meadow := TextureRect.new()
	meadow.name = "DuskMeadow"
	meadow.texture = load(MEADOW_BACKGROUND_PATH) as Texture2D
	meadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	meadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	meadow.modulate = Color(1, 1, 1, DUSK_MEADOW_ALPHA)
	meadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_child(meadow)
	var veil := ColorRect.new()
	veil.name = "DuskVeil"
	veil.color = DUSK_VEIL
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_child(veil)
