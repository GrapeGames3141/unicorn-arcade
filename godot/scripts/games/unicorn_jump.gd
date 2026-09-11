extends ArcadeGameController

const Rules = preload("res://scripts/games/gameplay_rules.gd")
const StorybookUI = preload("res://scripts/ui/storybook_ui.gd")
const RoomItemPreviewScene = preload("res://scripts/meta/room_item_preview_3d.gd")
const RainbowJumpFXScene = preload("res://scripts/ui/rainbow_jump_fx.gd")
const GameWorldViewportScene = preload("res://scripts/ui/game_world_viewport.gd")
const STONE_CREAM = preload("res://assets/games/unicorn_jump/jump_stone_normal_cream_v1.png")
const STONE_LILAC = preload("res://assets/games/unicorn_jump/jump_stone_normal_lilac_v1.png")
const STONE_CURRENT = preload("res://assets/games/unicorn_jump/jump_stone_current_v1.png")
const STONE_VISITED = preload("res://assets/games/unicorn_jump/jump_stone_visited_v1.png")
const STONE_FINISH = preload("res://assets/games/unicorn_jump/jump_stone_finish_v1.png")

const PATH_WIDTH := 520.0
const BASE_STONE_SIZE := Vector2(150.0, 101.0)
const BASE_ROW_HEIGHT := 132.0
const BASE_TOP_CLEARANCE := 88.0
const COMPANION_DISPLAY_SIZE := Vector2(178.0, 138.0)
const COMPANION_CENTER_LIFT := Vector2(0.0, -42.0)
const INITIAL_TRAIL_MAX_ZOOM := 0.72
const INITIAL_TRAIL_MIN_ZOOM := 0.42

var level := 1
var level_data: Array[int] = []
var current_index := 0
var visited: Array[int] = []
var active := false
var started_ms := 0
var node_buttons: Array[TextureButton] = []
var connector_lines: Array[Line2D] = []
var status_label: Label
var jump_label: Label
var jump_mission_panel: PanelContainer
var jump_mission_value: Label
var jump_mission_caption: Label
var path_box: VBoxContainer
var world_viewport
## Kept as an alias so layout tests / dialogs can find the play surface.
var scroller: Control
var action_button: Button
var companion_preview: RoomItemPreview3D
var jump_in_progress := false
var fx_layer: RainbowJumpFX


func _ready() -> void:
	level = AppState.current_level("unicorn_jump")
	_build_ui()
	_start_level(level)


func generate_level_data(for_level: int, rng: RandomNumberGenerator = null) -> Array[int]:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var length := Rules.jump_path_length(for_level)
	var data: Array[int] = []
	data.resize(length)
	data.fill(0)
	var current := 0
	var last := 0
	var maximum := Rules.jump_max(for_level)
	var allow_negative := for_level >= 15
	var max_negative := Rules.jump_negative_max(for_level)
	while current < length:
		var do_trick := allow_negative and rng.randf() < 0.2 and length - current > 6
		if do_trick:
			var backward := rng.randi_range(1, max_negative)
			var forward := backward + rng.randi_range(1, 3)
			if current + forward < length and data[current + forward] == 0:
				data[current] = forward
				data[current + forward] = -backward
				current += forward - backward
				last = -999
				continue
		var jump := 1
		var attempts := 0
		while true:
			jump = rng.randi_range(1, maximum)
			attempts += 1
			if not ((jump == last and length - current > jump and attempts < 10) or (current + jump < length and data[current + jump] != 0)):
				break
		if current + jump > length:
			jump = length - current
		data[current] = jump
		current += jump
		last = jump
	for index in length:
		if data[index] == 0:
			if allow_negative and rng.randf() < 0.3:
				data[index] = -rng.randi_range(1, max_negative)
			else:
				data[index] = rng.randi_range(1, maximum)
	return data


func _start_level(for_level: int) -> void:
	_start_level_with_lifecycle(for_level, true)


func _start_level_with_lifecycle(for_level: int, begin_run: bool) -> void:
	if begin_run:
		level_run.begin("unicorn_jump", for_level)
		level = level_run.level
	else:
		level = level_run.level
	level_data = generate_level_data(level)
	current_index = 0
	visited = [0]
	started_ms = level_run.started_ms
	active = level_run.active
	jump_in_progress = false
	action_button.hide()
	status_label.text = "Count the current number of stones, then tap that exact landing."
	_rebuild_path()
	_update_path()


func _choose_node(index: int) -> void:
	if is_instance_valid(world_viewport) and world_viewport.consume_press_suppression():
		return
	if not active or jump_in_progress or index == current_index:
		return
	var expected := current_index + level_data[current_index]
	if index != expected:
		if CompanionAbilityService.consume_checkpoint_retry():
			status_label.text = "Sparkle saved your checkpoint! Count again from this stone."
			_bounce_stone(node_buttons[index])
			return
		level_run.fail("Wrong landing. Follow the jump value to stone %d." % (expected + 1))
		active = level_run.active
		status_label.text = "Wrong landing. Follow the jump value to stone %d." % (expected + 1)
		action_button.text = "Retry"
		action_button.show()
		_set_nodes_enabled(false)
		return
	jump_in_progress = true
	_set_nodes_enabled(false)
	await _animate_jump(current_index, index)
	current_index = index
	visited.append(index)
	if current_index == level_data.size():
		var reward := level_run.complete()
		active = level_run.active
		status_label.text = "Trail complete! +%d coins" % reward
		action_button.text = "Next Level"
		action_button.show()
		_set_nodes_enabled(false)
	else:
		status_label.text = "Perfect landing. Keep going!"
	_update_path()
	jump_in_progress = false
	if active:
		_set_nodes_enabled(true)


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
	if not active or current_index >= level_data.size():
		return
	var expected := current_index + level_data[current_index]
	if expected >= 0 and expected < node_buttons.size():
		var stone := node_buttons[expected]
		var start := node_buttons[current_index].get_global_rect().get_center()
		var finish := stone.get_global_rect().get_center()
		var arc := Line2D.new()
		arc.name = "CountedLandingArc"
		arc.width = 9.0
		arc.default_color = Color("ffe172")
		arc.joint_mode = Line2D.LINE_JOINT_ROUND
		arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
		arc.end_cap_mode = Line2D.LINE_CAP_ROUND
		var lift := maxf(68.0, absf(finish.x - start.x) * 0.23)
		arc.points = PackedVector2Array([_fx_local(start), _fx_local((start + finish) * 0.5 + Vector2(0, -lift)), _fx_local(finish)])
		fx_layer.add_child(arc)
		var tween := arc.create_tween()
		tween.tween_property(arc, "modulate:a", 0.0, 1.8).set_delay(0.55)
		tween.tween_callback(arc.queue_free)
		status_label.text = "Follow the rainbow arc and count each landing."

func can_show_hint() -> bool:
	return active and current_index >= 0 and current_index < level_data.size()


func _rebuild_path() -> void:
	for child in path_box.get_children():
		child.queue_free()
	node_buttons.clear()
	connector_lines.clear()
	var stone_size := BASE_STONE_SIZE
	var row_height := BASE_ROW_HEIGHT
	var top_clearance := Control.new()
	top_clearance.name = "TrailTopClearance"
	top_clearance.custom_minimum_size.y = BASE_TOP_CLEARANCE
	top_clearance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	path_box.add_child(top_clearance)
	for index in range(level_data.size() + 1):
		var row := Control.new()
		row.name = "TrailRow%d" % index
		row.custom_minimum_size = Vector2(PATH_WIDTH, row_height)
		var center_x := _stone_center_x(index)
		if index < level_data.size():
			var next_center_x := _stone_center_x(index + 1)
			var connector := Line2D.new()
			connector.name = "TrailConnector%d" % index
			connector.width = 8.0
			connector.default_color = Color("9788d8")
			connector.joint_mode = Line2D.LINE_JOINT_ROUND
			connector.begin_cap_mode = Line2D.LINE_CAP_ROUND
			connector.end_cap_mode = Line2D.LINE_CAP_ROUND
			connector.points = PackedVector2Array([
				Vector2(center_x, row_height * 0.56),
				Vector2((center_x + next_center_x) * 0.5, row_height * 0.92),
				Vector2(next_center_x, row_height * 1.36),
			])
			row.add_child(connector)
			connector_lines.push_back(connector)
		var button := TextureButton.new()
		button.name = "JumpStone%d" % index
		button.custom_minimum_size = stone_size
		button.size = stone_size
		button.position = Vector2(center_x - stone_size.x * 0.5, row_height * 0.22)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.texture_normal = _normal_stone_texture(index)
		button.tooltip_text = "Goal stone" if index == level_data.size() else "Landing stone %d" % (index + 1)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_choose_node.bind(index))
		var value_label := Label.new()
		value_label.name = "JumpValue"
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.add_theme_font_size_override("font_size", 23)
		value_label.add_theme_color_override("font_color", Color("382c60"))
		value_label.add_theme_color_override("font_outline_color", Color("fff5e9"))
		value_label.add_theme_constant_override("outline_size", 5)
		value_label.position.y = -5.0
		button.add_child(value_label)
		row.add_child(button)
		path_box.add_child(row)
		node_buttons.push_back(button)
	_ensure_companion()


func _update_path() -> void:
	jump_label.text = "LEVEL %d  •  STONE %d OF %d" % [level, current_index + 1, level_data.size() + 1]
	if current_index < level_data.size():
		var jump_value := int(level_data[current_index])
		jump_mission_panel.show()
		jump_mission_value.text = str(absi(jump_value))
		jump_mission_caption.text = "JUMP FORWARD %d STONES" % absi(jump_value) if jump_value >= 0 else "JUMP BACK %d STONES" % absi(jump_value)
	else:
		jump_mission_panel.hide()
	for index in node_buttons.size():
		var button := node_buttons[index]
		var value_label := button.get_node("JumpValue") as Label
		button.self_modulate = Color.WHITE
		if index == current_index:
			button.texture_normal = STONE_CURRENT
			value_label.text = ""
			value_label.add_theme_color_override("font_color", Color("173f68"))
			button.tooltip_text = "Current stone. %s" % _jump_instruction(level_data[index]) if index < level_data.size() else "Goal reached"
		elif index in visited:
			button.texture_normal = STONE_VISITED
			value_label.text = "✓"
			value_label.add_theme_color_override("font_color", Color("3a2868"))
			value_label.text = ""
		elif index == level_data.size():
			button.texture_normal = STONE_FINISH
			value_label.text = "★"
			value_label.add_theme_color_override("font_color", Color("50315d"))
			value_label.text = ""
		else:
			button.texture_normal = _normal_stone_texture(index)
			value_label.text = ""
			value_label.add_theme_color_override("font_color", Color("382c60"))
	for connector_index in connector_lines.size():
		var connector := connector_lines[connector_index]
		connector.default_color = Color("f2a5d4") if connector_index <= current_index else Color("9788d8")
	if is_instance_valid(companion_preview) and not jump_in_progress:
		companion_preview.position = _companion_world_position(current_index)
	await get_tree().process_frame
	await _focus_current_stone()


func _focus_current_stone() -> void:
	if not is_instance_valid(world_viewport) or current_index < 0 or current_index >= node_buttons.size():
		return
	var layout_attempts := 0
	while world_viewport.size.x <= 1.0 or world_viewport.size.y <= 1.0:
		if layout_attempts >= 8:
			return
		layout_attempts += 1
		await get_tree().process_frame
	if current_index == 0:
		world_viewport.set_camera(Vector2.ZERO, _initial_trail_zoom(), false)
	world_viewport.focus_control(node_buttons[current_index], Vector2(0.5, 0.34))


func _initial_trail_zoom() -> float:
	if not is_instance_valid(world_viewport) or node_buttons.is_empty():
		return INITIAL_TRAIL_MAX_ZOOM
	var forward_index := mini(current_index + 4, node_buttons.size() - 1)
	var span := maxf(BASE_ROW_HEIGHT, absf(_stone_world_center(forward_index).y - _stone_world_center(current_index).y))
	# Current is focused about one-third down the viewport, leaving roughly 60%
	# of its height for the next four landings. Clamp only for tiny viewports.
	var available := maxf(1.0, world_viewport.size.y * 0.60)
	return clampf(available / span, INITIAL_TRAIL_MIN_ZOOM, INITIAL_TRAIL_MAX_ZOOM)


func _insert_non_obstructing_dialog(dialog: Control) -> void:
	var layout := world_viewport.get_parent() as VBoxContainer if is_instance_valid(world_viewport) else null
	if layout == null:
		add_child(dialog)
		return
	layout.add_child(dialog)
	layout.move_child(dialog, world_viewport.get_index())
	dialog.tree_exited.connect(_restore_path_after_dialog)
	_update_path.call_deferred()


func _restore_path_after_dialog() -> void:
	_update_path.call_deferred()


func _ensure_companion() -> void:
	if is_instance_valid(companion_preview):
		return
	companion_preview = RoomItemPreviewScene.new()
	companion_preview.name = "ActiveCompanionOnStone"
	companion_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	companion_preview.z_index = 10
	companion_preview.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# Set the final canvas before setup creates the stretched SubViewport.
	companion_preview.size = COMPANION_DISPLAY_SIZE
	companion_preview.setup({
		"id": "companion_%s" % AppState.equipped_companion(),
		"category": "companions",
		"animate": true,
		"presentation": "marketplace",
	})
	world_viewport.world.add_child(companion_preview)
	companion_preview.position = _companion_world_position(current_index)
	companion_preview.set_motion_state(false)


func _stone_world_center(index: int) -> Vector2:
	return Vector2(
		_stone_center_x(index),
		BASE_TOP_CLEARANCE + index * BASE_ROW_HEIGHT + BASE_ROW_HEIGHT * 0.22 + BASE_STONE_SIZE.y * 0.5
	)


func _companion_world_position(index: int) -> Vector2:
	return _stone_world_center(index) + COMPANION_CENTER_LIFT - COMPANION_DISPLAY_SIZE * 0.5


func _normal_stone_texture(index: int) -> Texture2D:
	return STONE_CREAM if index % 2 == 0 else STONE_LILAC


func _stone_center_x(index: int) -> float:
	var phase := float(index) / maxf(1.0, float(level_data.size())) * PI * 3.2
	return PATH_WIDTH * 0.5 + sin(phase) * 118.0


func _animate_jump(from_index: int, to_index: int) -> void:
	if AppState.setting("reduced_motion", false):
		# A bound tween follows the game's pause state; a SceneTreeTimer keeps
		# running when only this game's subtree is disabled by a dialog.
		await create_tween().tween_interval(0.16).finished
		if is_instance_valid(companion_preview):
			companion_preview.position = _companion_world_position(to_index)
		return
	_ensure_companion()
	var start := _companion_world_position(from_index)
	var finish := _companion_world_position(to_index)
	companion_preview.position = start
	companion_preview.set_motion_state(true)
	fx_layer.clear_flight()
	var distance_stones := maxi(1, absi(to_index - from_index))
	var duration := minf(1.1, 0.62 + distance_stones * 0.06)
	var midpoint := (start + finish) * 0.5 + Vector2(0, -92.0 - distance_stones * 5.0)
	var tween := create_tween()
	tween.tween_method(func(progress: float) -> void:
		var first := start.lerp(midpoint, progress)
		var second := midpoint.lerp(finish, progress)
		var point := first.lerp(second, progress)
		companion_preview.position = point
		companion_preview.rotation = sin(progress * PI * 2.0) * 0.035
		var tail_world_point := point + companion_preview.size * Vector2(0.18, 0.56)
		fx_layer.set_flight_point(_fx_local(_world_to_global(tail_world_point)))
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	companion_preview.position = finish
	companion_preview.rotation = 0.0
	companion_preview.set_motion_state(false)
	fx_layer.clear_flight()
	var landing_world_point := finish + companion_preview.size * Vector2(0.30, 0.65)
	fx_layer.landing_burst(_fx_local(_world_to_global(landing_world_point)), true)


func _bounce_stone(button: TextureButton) -> void:
	var original := button.scale
	button.pivot_offset = button.size * 0.5
	var tween := button.create_tween()
	tween.tween_property(button, "scale", original * 1.12, 0.12).set_trans(Tween.TRANS_BACK)
	tween.tween_property(button, "scale", original, 0.18).set_trans(Tween.TRANS_BOUNCE)


func _fx_local(global_point: Vector2) -> Vector2:
	return fx_layer.get_global_transform_with_canvas().affine_inverse() * global_point


func _world_to_global(world_point: Vector2) -> Vector2:
	return world_viewport.world.get_global_transform_with_canvas() * world_point


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("11113d")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	var title := Label.new()
	title.text = "UNICORN JUMP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("f79cff"))
	title.add_theme_color_override("font_outline_color", Color("30134d"))
	title.add_theme_constant_override("outline_size", 6)
	root.add_child(title)
	jump_label = Label.new()
	jump_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jump_label.add_theme_font_size_override("font_size", 24)
	jump_label.add_theme_color_override("font_color", StorybookUI.CREAM)
	jump_label.add_theme_color_override("font_outline_color", Color("120d32"))
	jump_label.add_theme_constant_override("outline_size", 4)
	root.add_child(jump_label)
	jump_mission_panel = PanelContainer.new()
	jump_mission_panel.name = "JumpMissionBadge"
	jump_mission_panel.add_theme_stylebox_override("panel", StorybookUI.plaque_style(Color("ffe8fb"), Color("f26fa7"), 24))
	root.add_child(jump_mission_panel)
	var mission_stack := VBoxContainer.new()
	mission_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	jump_mission_panel.add_child(mission_stack)
	jump_mission_caption = Label.new()
	jump_mission_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jump_mission_caption.add_theme_font_size_override("font_size", 18)
	jump_mission_caption.add_theme_color_override("font_color", Color("5b2a68"))
	mission_stack.add_child(jump_mission_caption)
	jump_mission_value = Label.new()
	jump_mission_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jump_mission_value.add_theme_font_size_override("font_size", 72)
	jump_mission_value.add_theme_color_override("font_color", Color("173f68"))
	jump_mission_value.add_theme_color_override("font_outline_color", Color("fff5e9"))
	jump_mission_value.add_theme_constant_override("outline_size", 8)
	mission_stack.add_child(jump_mission_value)
	world_viewport = GameWorldViewportScene.new()
	world_viewport.name = "GameWorldViewport"
	# Begin wide enough to count several stones at once; players can still pan
	# and pinch all the way into the existing close view.
	world_viewport.min_zoom = INITIAL_TRAIL_MIN_ZOOM
	world_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	world_viewport.custom_minimum_size.y = 320
	root.add_child(world_viewport)
	scroller = world_viewport
	path_box = VBoxContainer.new()
	path_box.name = "TrailPath"
	path_box.custom_minimum_size.x = PATH_WIDTH
	path_box.add_theme_constant_override("separation", 0)
	world_viewport.mount(path_box)
	fx_layer = RainbowJumpFXScene.new()
	add_child(fx_layer)
	fx_layer.z_index = 100
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_outline_color", Color("120d32"))
	status_label.add_theme_constant_override("outline_size", 4)
	status_label.text = "Drag to look around  •  Pinch to zoom  •  Tap a landing stone"
	root.add_child(status_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)
	action_button = StorybookUI.progression_action_button("", 112, _advance_level)
	action_button.custom_minimum_size.y = 60
	actions.add_child(action_button)
	var back := StorybookUI.category_back_button("Number Games", 112, return_to_category)
	back.custom_minimum_size.y = 60
	actions.add_child(back)
	var hint := StorybookUI.hint_highlight_button("Hint", 112, func() -> void:
		if AppState.spend_hint(level): _show_hint()
	)
	hint.custom_minimum_size.y = 60
	actions.add_child(hint)


func _set_nodes_enabled(enabled: bool) -> void:
	for button in node_buttons:
		button.disabled = not enabled


func _jump_instruction(value: int) -> String:
	return "JUMP FORWARD %d" % value if value >= 0 else "JUMP BACK %d" % absi(value)
