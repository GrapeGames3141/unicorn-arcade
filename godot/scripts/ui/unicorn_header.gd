class_name UnicornHeader
extends RefCounted

const StorybookUI = preload("res://scripts/ui/storybook_ui.gd")
const CURRENCY_STAR := Color("ffd166")


static func build(title: String, back_text: String, back_action: Callable, home_action: Callable, trailing_text := "", trailing_action := Callable()) -> Panel:
	# Explicit slots keep the shared chrome stable when a device accessibility
	# setting raises a Button's minimum size. There are no Container subclasses
	# in this header, so a late minimum-size notification cannot reflow it.
	var panel := Panel.new()
	panel.name = "SharedUnicornHeader"
	panel.custom_minimum_size = Vector2(0, 64)
	panel.add_theme_stylebox_override("panel", StorybookUI.plaque_style(StorybookUI.NAVY, StorybookUI.GOLD, 16))
	var has_trailing_action := not trailing_text.is_empty() and trailing_action.is_valid()

	var home_mode := back_text.to_upper() == "HOME"
	if home_mode:
		var spacer := Control.new()
		spacer.name = "HeaderLeftSpacer"
		_anchor_rect(spacer, 0.0, 0.0, 6, 70, 4, 60)
		panel.add_child(spacer)
	else:
		var back := Button.new()
		back.name = "HeaderBackButton"
		back.set_meta("compact_header_control", true)
		back.set_meta("standard_game_chrome", true)
		back.text = "‹ " + back_text.to_upper()
		back.tooltip_text = back_text.capitalize()
		back.custom_minimum_size = Vector2(74, 48)
		back.add_theme_font_size_override("font_size", 16)
		StorybookUI.apply_button(back, Color("22345f"), false, 12)
		_compact_button(back)
		back.custom_minimum_size = Vector2(74, 48)
		_anchor_rect(back, 0.0, 0.0, 6, 80, 8, 56)
		back.pressed.connect(back_action)
		panel.add_child(back)

	var label := Label.new()
	label.name = "HeaderTitle"
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", StorybookUI.CREAM)
	label.add_theme_color_override("font_outline_color", StorybookUI.PLUM)
	label.add_theme_constant_override("outline_size", 2)
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if has_trailing_action:
		# Trailing headers have a deliberately centered title inside the usable
		# navigation lane, rather than clipping it behind the action cluster.
		_anchor_rect(label, 0.0, 1.0, 88, -206, 8, 56)
	else:
		_anchor_rect(label, 0.5, 0.5, -100, 100, 8, 56)
	panel.add_child(label)

	var actions := Control.new()
	actions.name = "HeaderActions"
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(actions)
	var home := Button.new()
	home.name = "HeaderHomeButton"
	home.set_meta("compact_header_control", true)
	home.set_meta("standard_game_chrome", true)
	home.tooltip_text = "Home"
	# Keep the authored house graphic as a fixed child. Assigning it to Button's
	# icon slot gives the control a 56px combined minimum on some Android themes.
	StorybookUI.apply_button(home, StorybookUI.HOME_FILL, true, 12)
	home.text = ""
	var home_texture := load(StorybookUI.UNICORN_HOUSE_HOME_ICON_PATH) as Texture2D
	var home_glyph := TextureRect.new()
	home_glyph.name = "HeaderHomeGlyph"
	home_glyph.texture = home_texture
	home_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home_glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	home_glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_anchor_rect(home_glyph, 0.5, 0.5, -17, 17, 7, 41)
	home.add_child(home_glyph)
	_compact_button(home)
	home.custom_minimum_size = Vector2(48, 48)
	if has_trailing_action:
		_anchor_rect(home, 1.0, 1.0, -202, -154, 8, 56)
	else:
		_anchor_rect(home, 1.0, 1.0, -144, -96, 8, 56)
	home.pressed.connect(home_action)
	actions.add_child(home)
	var coin_icon := Label.new()
	coin_icon.name = "SharedCoinIcon"
	coin_icon.text = "★"
	coin_icon.tooltip_text = "Coins"
	coin_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coin_icon.add_theme_font_size_override("font_size", 24)
	coin_icon.add_theme_color_override("font_color", CURRENCY_STAR)
	coin_icon.add_theme_color_override("font_outline_color", StorybookUI.PLUM)
	coin_icon.add_theme_constant_override("outline_size", 3)
	coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if has_trailing_action:
		_anchor_rect(coin_icon, 1.0, 1.0, -150, -128, 12, 52)
	else:
		_anchor_rect(coin_icon, 1.0, 1.0, -88, -66, 12, 52)
	actions.add_child(coin_icon)
	var coins := Label.new()
	coins.name = "SharedCoinBalance"
	coins.text = str(AppState.coins())
	coins.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coins.add_theme_font_size_override("font_size", 16)
	coins.add_theme_color_override("font_color", StorybookUI.CREAM)
	coins.add_theme_color_override("font_outline_color", StorybookUI.PLUM)
	coins.add_theme_constant_override("outline_size", 2)
	coins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if has_trailing_action:
		_anchor_rect(coins, 1.0, 1.0, -126, -74, 10, 54)
	else:
		_anchor_rect(coins, 1.0, 1.0, -62, -6, 10, 54)
	actions.add_child(coins)
	if has_trailing_action:
		var trailing := Button.new()
		trailing.name = "HeaderTrailingAction"
		trailing.set_meta("compact_header_control", true)
		trailing.set_meta("standard_game_chrome", true)
		trailing.text = trailing_text.to_upper()
		trailing.custom_minimum_size = Vector2(44, 48)
		trailing.add_theme_font_size_override("font_size", 14)
		StorybookUI.apply_button(trailing, Color("22345f"), false, 12)
		_compact_button(trailing)
		_anchor_rect(trailing, 1.0, 1.0, -68, -6, 8, 56)
		trailing.pressed.connect(trailing_action)
		actions.add_child(trailing)
	return panel


static func _anchor_rect(control: Control, left_anchor: float, right_anchor: float, left_offset: float, right_offset: float, top_offset: float, bottom_offset: float) -> void:
	control.anchor_left = left_anchor
	control.anchor_right = right_anchor
	control.anchor_top = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = left_offset
	control.offset_right = right_offset
	control.offset_top = top_offset
	control.offset_bottom = bottom_offset


static func _compact_button(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := button.get_theme_stylebox(state)
		if style is StyleBoxFlat:
			var compact := (style as StyleBoxFlat).duplicate() as StyleBoxFlat
			compact.content_margin_left = 4
			compact.content_margin_right = 4
			compact.content_margin_top = 2
			compact.content_margin_bottom = 2
			compact.shadow_size = 0
			compact.shadow_offset = Vector2.ZERO
			button.add_theme_stylebox_override(state, compact)
