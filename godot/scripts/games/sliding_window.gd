extends ArcadeGameController

const Rules = preload("res://scripts/games/gameplay_rules.gd")
const StorybookUI = preload("res://scripts/ui/storybook_ui.gd")
const GameWorldViewportScene = preload("res://scripts/ui/game_world_viewport.gd")
const RoomItemPreviewScene = preload("res://scripts/meta/room_item_preview_3d.gd")

const NODE_SIZE := Vector2(105, 105)
const NODE_GAP := 10.0
const ACTIVE_WINDOW_SIDE_PADDING := 24.0
const VERTICAL_FRAME_PADDING := 12.0

var level := 1
var level_data: Array[int] = []
var opponent_data: Array[int] = []
var window_size := 3
var window_pos := 0
var opponent_pos := 0
var active := false
var rival_elapsed := -500.0
var started_ms := 0
var value_buttons: Array[Button] = []
var rival_nodes: Array[PanelContainer] = []
var progress_label: Label
var rival_label: Label
var message_label: Label
var action_button: Button
var value_row: HBoxContainer
var rival_row: HBoxContainer
var track_viewport
var player_window_frame: PanelContainer
var rival_window_frame: PanelContainer
var player_marker: Control
var rival_marker: Control
var player_bar: ProgressBar
var rival_bar: ProgressBar
var lanes: Control
var layout_generation := 0


func _ready() -> void:
	level = AppState.current_level("sliding_window")
	_build_ui()
	_start_level(level)


func _process(delta: float) -> void:
	super(delta)
	if not active:
		return
	rival_elapsed += delta * 1000.0 * CompanionAbilityService.time_scale()
	var speed := Rules.rival_move_ms(level)
	while rival_elapsed >= speed:
		rival_elapsed -= speed
		if opponent_pos + window_size >= opponent_data.size():
			_fail("The rival beat you to the finish!")
			return
		opponent_pos += 1
		_update_rival()
		if opponent_pos + window_size >= opponent_data.size():
			_fail("The rival beat you to the finish!")
			return


func _start_level(for_level: int) -> void:
	_start_level_with_lifecycle(for_level, true)


func _start_level_with_lifecycle(for_level: int, begin_run: bool) -> void:
	layout_generation += 1
	if is_instance_valid(track_viewport):
		track_viewport.set_camera(Vector2.ZERO, 1.0, false)
	if begin_run:
		level_run.begin("sliding_window", for_level)
		level = level_run.level
	else:
		level = level_run.level
	var bounds := Rules.sliding_bounds(level)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	level_data.clear()
	opponent_data.clear()
	for index in Rules.sliding_length(level):
		level_data.append(rng.randi_range(bounds.x, bounds.y))
		opponent_data.append(rng.randi_range(bounds.x, bounds.y))
	window_size = Rules.sliding_window(level)
	window_pos = 0
	opponent_pos = 0
	rival_elapsed = -500.0
	started_ms = level_run.started_ms
	active = level_run.active
	action_button.hide()
	message_label.text = "Race the rival! Tap the biggest number in YOUR glowing window."
	_rebuild_tracks()
	_update_window()
	_update_rival()


func _choose(absolute_index: int) -> void:
	if is_instance_valid(track_viewport) and track_viewport.consume_press_suppression():
		return
	if not active:
		return
	if not _index_is_in_window(absolute_index):
		message_label.text = "Choose a number inside your glowing YOU window."
		return
	var maximum := _window_maximum()
	if level_data[absolute_index] != maximum:
		_fail("Wrong node selected! The maximum was %d." % maximum)
		return
	if window_pos + window_size < level_data.size():
		AudioService.play(&"correct")
	if window_pos + window_size >= level_data.size():
		var reward := level_run.complete()
		active = level_run.active
		message_label.text = "You won the race! +%d coins" % reward
		action_button.text = "Next Level"
		action_button.show()
		_set_buttons_enabled(false)
		_update_race_bars()
		return
	window_pos += 1
	message_label.text = "Great choice. Keep racing!"
	_update_window()


func _fail(reason: String) -> void:
	layout_generation += 1
	level_run.fail(reason)
	active = level_run.active
	message_label.text = reason
	action_button.text = "Retry"
	action_button.show()
	_set_buttons_enabled(false)
	_update_race_bars()


func can_show_hint() -> bool:
	return active


func _show_hint() -> void:
	if not active:
		return
	var maximum := _window_maximum()
	for index in value_buttons.size():
		value_buttons[index].modulate = Color("ffe172") if _index_is_in_window(index) and level_data[index] == maximum else Color.WHITE
	message_label.text = "The gold node is your current maximum."


func can_retry_failure() -> bool:
	return level_run.can_retry()


func retry_failure() -> void:
	if can_retry_failure():
		_start_level_with_lifecycle(level_run.retry(), false)


func _advance_level() -> void:
	match level_run.outcome:
		LevelRunController.Outcome.SUCCESS, LevelRunController.Outcome.FAILURE:
			_start_level_with_lifecycle(level_run.retry(), false)


func _index_is_in_window(absolute_index: int) -> bool:
	return absolute_index >= window_pos and absolute_index < window_pos + window_size


func _rival_index_in_window(absolute_index: int) -> bool:
	return absolute_index >= opponent_pos and absolute_index < opponent_pos + window_size


func _window_maximum() -> int:
	var maximum := level_data[window_pos]
	for index in range(window_pos + 1, window_pos + window_size):
		maximum = maxi(maximum, level_data[index])
	return maximum


func _rebuild_tracks() -> void:
	for button in value_buttons:
		if is_instance_valid(button):
			# queue_free alone leaves an old control participating in the HBox layout
			# until the end of the frame. Detach it now so camera placement sees only
			# the freshly created race track.
			if button.get_parent() == value_row:
				value_row.remove_child(button)
			button.queue_free()
	value_buttons.clear()
	for node in rival_nodes:
		if is_instance_valid(node):
			if node.get_parent() == rival_row:
				rival_row.remove_child(node)
			node.queue_free()
	rival_nodes.clear()
	for index in level_data.size():
		var button := Button.new()
		button.name = "TrackValue%d" % index
		button.custom_minimum_size = NODE_SIZE
		button.add_theme_font_size_override("font_size", 28)
		button.set_meta("sliding_window_node", true)
		button.pressed.connect(_choose.bind(index))
		value_row.add_child(button)
		value_buttons.append(button)
		var rival := _make_rival_node(index)
		rival_row.add_child(rival)
		rival_nodes.append(rival)
	_ensure_window_frames()
	_ensure_markers()


func _make_rival_node(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "RivalNode%d" % index
	panel.custom_minimum_size = NODE_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.name = "Value"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color("f7b6c8"))
	panel.add_child(label)
	return panel


func _ensure_window_frames() -> void:
	if not is_instance_valid(player_window_frame):
		player_window_frame = PanelContainer.new()
		player_window_frame.name = "PlayerWindowFrame"
		player_window_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		player_window_frame.add_theme_stylebox_override("panel", _frame_style(Color(0.13, 0.85, 0.55, 0.18), Color("62e6b5")))
		lanes.add_child(player_window_frame)
	if not is_instance_valid(rival_window_frame):
		rival_window_frame = PanelContainer.new()
		rival_window_frame.name = "RivalWindowFrame"
		rival_window_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rival_window_frame.add_theme_stylebox_override("panel", _frame_style(Color(0.95, 0.28, 0.45, 0.20), Color("f26fa7")))
		lanes.add_child(rival_window_frame)


func _ensure_markers() -> void:
	if not is_instance_valid(player_marker):
		player_marker = _make_racer_marker("YOU", true)
		lanes.add_child(player_marker)
	if not is_instance_valid(rival_marker):
		rival_marker = _make_racer_marker("RIVAL", false)
		lanes.add_child(rival_marker)


func _make_racer_marker(caption: String, is_player: bool) -> Control:
	var holder := VBoxContainer.new()
	holder.name = "%sMarker" % caption
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.custom_minimum_size = Vector2(96, 118)
	if is_player:
		var preview := RoomItemPreviewScene.new()
		preview.name = "PlayerUnicorn"
		preview.custom_minimum_size = Vector2(88, 72)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.setup({
			"id": "companion_%s" % AppState.equipped_companion(),
			"category": "companions",
			"animate": true,
			"presentation": "marketplace",
		})
		holder.add_child(preview)
	else:
		var badge := PanelContainer.new()
		badge.custom_minimum_size = Vector2(72, 72)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_stylebox_override("panel", StorybookUI.plaque_style(Color("7c2948"), Color("f26fa7"), 36))
		var face := Label.new()
		face.text = "👾"
		face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face.add_theme_font_size_override("font_size", 34)
		badge.add_child(face)
		holder.add_child(badge)
	# The lane labels and progress bars already identify the racers. Avoid the
	# redundant YOU caption directly under the player's unicorn marker.
	if not is_player:
		var tag := Label.new()
		tag.text = caption
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 14)
		tag.add_theme_color_override("font_color", Color("f69cff"))
		tag.add_theme_color_override("font_outline_color", Color("120d32"))
		tag.add_theme_constant_override("outline_size", 3)
		holder.add_child(tag)
	return holder


func _frame_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(4)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(border, 0.45)
	style.shadow_size = 10
	return style


func _update_window() -> void:
	progress_label.text = "LEVEL %d   •   YOUR WINDOW %d / %d" % [level, window_pos + 1, maxi(1, level_data.size() - window_size + 1)]
	for index in value_buttons.size():
		value_buttons[index].text = str(level_data[index])
		value_buttons[index].modulate = Color.WHITE
		_style_track_node(value_buttons[index], _index_is_in_window(index), index < window_pos)
	_update_race_bars()
	# Keep placement and camera targeting in the same deferred operation. The
	# first and last active nodes provide the exact full-window center, avoiding
	# a biased midpoint for even-sized windows.
	_layout_and_center_player_window.call_deferred(layout_generation, window_pos == 0)


func _update_rival() -> void:
	var finish := maxf(1.0, float(opponent_data.size() - window_size))
	var percent := int(100.0 * opponent_pos / finish)
	rival_label.text = "RIVAL  %d%%   •   moves every %.1fs" % [percent, Rules.rival_move_ms(level) / 1000.0]
	for index in rival_nodes.size():
		var panel := rival_nodes[index]
		var label := panel.get_node("Value") as Label
		label.text = str(opponent_data[index])
		var collected := index < opponent_pos
		var in_window := _rival_index_in_window(index)
		if collected:
			panel.add_theme_stylebox_override("panel", StorybookUI.button_style(Color("5a1d33"), Color("f26fa7"), 3, 14, 2))
			label.add_theme_color_override("font_color", Color("f7b6c8"))
		elif in_window and active:
			panel.add_theme_stylebox_override("panel", StorybookUI.button_style(Color("4a1830"), Color("ff7aa8"), 4, 16, 4))
			label.add_theme_color_override("font_color", Color("ffe0ea"))
		else:
			panel.add_theme_stylebox_override("panel", StorybookUI.button_style(Color("1a1230"), Color("5a4060"), 2, 14, 1))
			label.add_theme_color_override("font_color", Color("8a7394"))
	_update_race_bars()
	_layout_overlays.call_deferred(layout_generation)


func _update_race_bars() -> void:
	var finish := maxf(1.0, float(level_data.size() - window_size))
	if is_instance_valid(player_bar):
		player_bar.value = 100.0 * float(window_pos) / finish
	if is_instance_valid(rival_bar):
		rival_bar.value = 100.0 * float(opponent_pos) / finish


func _style_track_node(button: Button, in_window: bool, collected: bool) -> void:
	button.disabled = not in_window
	if collected:
		button.add_theme_color_override("font_disabled_color", Color("8bffcf"))
		button.add_theme_stylebox_override("disabled", StorybookUI.button_style(Color("134435"), Color("62e6b5"), 2, 14, 1))
	elif in_window:
		button.add_theme_color_override("font_color", StorybookUI.CREAM)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		button.add_theme_color_override("font_outline_color", StorybookUI.PLUM)
		button.add_theme_constant_override("outline_size", 2)
		button.add_theme_stylebox_override("normal", StorybookUI.button_style(Color("173f68"), Color("62e6b5"), 5, 18, 6))
		button.add_theme_stylebox_override("hover", StorybookUI.button_style(Color("24527b"), Color("8bffcf"), 5, 18, 7))
		button.add_theme_stylebox_override("pressed", StorybookUI.button_style(Color("102f55"), StorybookUI.GOLD_BRIGHT, 5, 18, 3))
		button.add_theme_stylebox_override("focus", StorybookUI.button_style(Color("24527b"), Color("8bffcf"), 5, 18, 7))
	else:
		button.add_theme_color_override("font_disabled_color", Color("a5aec8"))
		button.add_theme_stylebox_override("disabled", StorybookUI.button_style(Color("101933"), Color("46516c"), 2, 14, 1))


func _layout_overlays(generation: int) -> void:
	# Deferred rather than awaiting a frame: freed scenes never retain a suspended
	# instance coroutine while a route change is in progress.
	if generation != layout_generation or not is_inside_tree() or not is_instance_valid(lanes) or value_buttons.is_empty() or rival_nodes.is_empty():
		return
	_place_window(player_window_frame, value_buttons, window_pos)
	_place_window(rival_window_frame, rival_nodes, opponent_pos)
	_place_marker(player_marker, value_buttons, window_pos, -112.0)
	_place_marker(rival_marker, rival_nodes, opponent_pos, -112.0)


func _layout_and_center_player_window(generation: int, opening: bool) -> void:
	_layout_overlays(generation)
	if generation != layout_generation or not is_instance_valid(track_viewport) or not is_instance_valid(track_viewport.world) or value_buttons.is_empty() or rival_nodes.is_empty() or track_viewport.size.x <= 1.0 or track_viewport.size.y <= 1.0:
		return
	var player_bounds := _window_world_bounds(value_buttons, window_pos)
	var rival_bounds := _window_world_bounds(rival_nodes, opponent_pos)
	if player_bounds.size.x <= 0.0 or player_bounds.size.y <= 0.0:
		return
	var vertical_bounds := player_bounds.merge(rival_bounds)
	if is_instance_valid(player_marker):
		vertical_bounds = vertical_bounds.merge(_control_world_rect(player_marker))
	var available_width := maxf(1.0, track_viewport.size.x - ACTIVE_WINDOW_SIDE_PADDING * 2.0)
	var available_height := maxf(1.0, track_viewport.size.y - VERTICAL_FRAME_PADDING * 2.0)
	var fit_zoom := minf(available_width / player_bounds.size.x, available_height / maxf(1.0, vertical_bounds.size.y))
	fit_zoom = clampf(fit_zoom, track_viewport.min_zoom, track_viewport.max_zoom)
	# Starting or retrying discards stale user camera state. During play, retain a
	# wider (zoomed-out) user view but clamp closer zoom down to the required fit.
	var next_zoom := fit_zoom if opening else minf(track_viewport.zoom, fit_zoom)
	var target_center := Vector2(player_bounds.get_center().x, vertical_bounds.get_center().y)
	var next_pan: Vector2 = track_viewport.size * 0.5 - target_center * next_zoom
	track_viewport.set_camera(next_pan, next_zoom)


func _window_world_bounds(nodes: Array, start_index: int) -> Rect2:
	if nodes.is_empty():
		return Rect2()
	var first_index := clampi(start_index, 0, nodes.size() - 1)
	var last_index := clampi(start_index + window_size - 1, 0, nodes.size() - 1)
	return _control_world_rect(nodes[first_index] as Control).merge(_control_world_rect(nodes[last_index] as Control))


func _control_world_rect(control: Control) -> Rect2:
	if not is_instance_valid(control) or not is_instance_valid(track_viewport) or not is_instance_valid(track_viewport.world):
		return Rect2()
	var inverse: Transform2D = track_viewport.world.get_global_transform_with_canvas().affine_inverse()
	var global_rect := control.get_global_rect()
	var top_left: Vector2 = inverse * global_rect.position
	var bottom_right: Vector2 = inverse * global_rect.end
	return Rect2(top_left, bottom_right - top_left)


func _place_window(frame: PanelContainer, nodes: Array, start_index: int) -> void:
	if not is_instance_valid(frame) or nodes.is_empty():
		return
	var first_index := clampi(start_index, 0, nodes.size() - 1)
	var last_index := clampi(start_index + window_size - 1, 0, nodes.size() - 1)
	var first: Control = nodes[first_index]
	var last: Control = nodes[last_index]
	var inverse := lanes.get_global_transform_with_canvas().affine_inverse()
	var top_left := inverse * first.get_global_rect().position - Vector2(8, 8)
	var bottom_right := inverse * last.get_global_rect().end + Vector2(8, 8)
	frame.position = top_left
	frame.size = bottom_right - top_left
	frame.visible = active
	frame.move_to_front()


func _place_marker(marker: Control, nodes: Array, start_index: int, y_lift: float) -> void:
	if not is_instance_valid(marker) or nodes.is_empty():
		return
	var first_index := clampi(start_index, 0, nodes.size() - 1)
	var last_index := clampi(start_index + window_size - 1, 0, nodes.size() - 1)
	var first: Control = nodes[first_index]
	var last: Control = nodes[last_index]
	var active_center_global := Vector2((first.get_global_rect().position.x + last.get_global_rect().end.x) * 0.5, (first.get_global_rect().get_center().y + last.get_global_rect().get_center().y) * 0.5)
	var center := lanes.get_global_transform_with_canvas().affine_inverse() * active_center_global
	var marker_width := marker.size.x if marker.size.x > 0.0 else marker.custom_minimum_size.x
	marker.position = center + Vector2(-marker_width * 0.5, y_lift)
	marker.visible = active
	marker.move_to_front()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0a1732")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	root.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	var title := Label.new()
	title.text = "RACE THE UNICORN!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StorybookUI.apply_story_label(title, Color("65e7ff"), 34, true)
	root.add_child(title)
	progress_label = Label.new()
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StorybookUI.apply_story_label(progress_label, StorybookUI.CREAM, 18, true)
	root.add_child(progress_label)
	var instruction_plaque := PanelContainer.new()
	StorybookUI.apply_prompt_plaque(instruction_plaque, Color("ffe8fb"))
	root.add_child(instruction_plaque)
	var instruction := Label.new()
	instruction.text = "FIND THE MAXIMUM  •  BEAT THE RIVAL"
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StorybookUI.apply_story_label(instruction, Color("5b2a68"), 20, false)
	instruction_plaque.add_child(instruction)

	track_viewport = GameWorldViewportScene.new()
	track_viewport.name = "NumberTrackViewport"
	track_viewport.custom_minimum_size = Vector2(0, 360)
	track_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	track_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_viewport.min_zoom = 0.75
	track_viewport.max_zoom = 1.35
	root.add_child(track_viewport)

	lanes = Control.new()
	lanes.name = "RaceLanes"
	lanes.custom_minimum_size = Vector2(720, 320)
	track_viewport.mount(lanes)

	var lane_stack := VBoxContainer.new()
	lane_stack.position = Vector2(24, 120)
	lane_stack.add_theme_constant_override("separation", 28)
	lanes.add_child(lane_stack)

	var you_tag := Label.new()
	you_tag.text = "YOU"
	you_tag.add_theme_font_size_override("font_size", 16)
	you_tag.add_theme_color_override("font_color", Color("62e6b5"))
	lane_stack.add_child(you_tag)
	value_row = HBoxContainer.new()
	value_row.name = "FullNumberTrack"
	value_row.add_theme_constant_override("separation", int(NODE_GAP))
	lane_stack.add_child(value_row)

	var rival_tag := Label.new()
	rival_tag.text = "RIVAL BOT"
	rival_tag.add_theme_font_size_override("font_size", 16)
	rival_tag.add_theme_color_override("font_color", Color("f69cff"))
	lane_stack.add_child(rival_tag)
	rival_row = HBoxContainer.new()
	rival_row.name = "RivalNumberTrack"
	rival_row.add_theme_constant_override("separation", int(NODE_GAP))
	lane_stack.add_child(rival_row)

	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 6)
	root.add_child(bars)
	player_bar = _race_bar(Color("62e6b5"))
	bars.add_child(_bar_row("YOU", player_bar, Color("62e6b5")))
	rival_bar = _race_bar(Color("f26fa7"))
	bars.add_child(_bar_row("RIVAL", rival_bar, Color("f26fa7")))

	rival_label = Label.new()
	rival_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rival_label.add_theme_color_override("font_color", Color("f69cff"))
	root.add_child(rival_label)
	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_color_override("font_color", StorybookUI.CREAM)
	root.add_child(message_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(actions)
	var hint := StorybookUI.hint_highlight_button("Hint", 120, _show_hint)
	actions.add_child(hint)
	action_button = StorybookUI.progression_action_button("", 160, _advance_level)
	actions.add_child(action_button)
	var back := StorybookUI.category_back_button("Number Games", 170, return_to_category)
	actions.add_child(back)


func _race_bar(fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.value = 0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.10, 0.22, 0.95)
	bg.set_corner_radius_all(8)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill
	fill_style.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill_style)
	return bar


func _bar_row(caption: String, bar: ProgressBar, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 70
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	row.add_child(label)
	row.add_child(bar)
	return row


func _set_buttons_enabled(enabled: bool) -> void:
	for index in value_buttons.size():
		if enabled:
			_style_track_node(value_buttons[index], _index_is_in_window(index), index < window_pos)
		else:
			value_buttons[index].disabled = true
