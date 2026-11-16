extends Control

const Catalog = preload("res://scripts/meta_catalog.gd")
const Rules = preload("res://scripts/room_rules.gd")
const RoomItemPreviewScene = preload("res://scripts/meta/room_item_preview_3d.gd")
const FurnitureBagOverlay = preload("res://scripts/meta/furniture_bag_overlay.gd")
const StorybookUI = preload("res://scripts/ui/storybook_ui.gd")
const UnicornHeader = preload("res://scripts/ui/unicorn_header.gd")
const FURNITURE_BAG_ICON := preload("res://assets/ui/furniture_bag_v1.svg")

const NAVY := Color("08112f")
const PANEL := Color("14214a")
const PINK := Color("f26fa7")
const YELLOW := Color("ffd166")
const MUTED := Color("aab7e8")
const ROOM_BACKGROUNDS := {
	"sparkle": preload("res://assets/meta/environments/room_sparkle_production_v1.png"),
	"rainbow": preload("res://assets/meta/environments/room_rainbow_production_v1.png"),
	"star": preload("res://assets/meta/environments/room_star_production_v1.png"),
	"cloud": preload("res://assets/meta/environments/room_cloud_production_v1.png"),
	"dream": preload("res://assets/meta/environments/room_dream_production_v1.png"),
	"mystic": preload("res://assets/meta/environments/room_mystic_production_v1.png"),
}

var companion_id := "sparkle"
var grid_snap := true
var selected_id := ""
var dragging_id := ""
var reset_armed := false
var room_canvas: Control
var item_buttons := {}
var local_items: Array = []
var status_label: Label
var reset_button: Button
var bag_button: Button
var selection_toolbar: HBoxContainer
var bag_overlay: FurnitureBagOverlay
var bag_category := "all"
var roaming_actor: RoomItemPreview3D
var roam_target := Vector2.ZERO
var roam_pause := 0.0
var roam_rng := RandomNumberGenerator.new()
var roam_floor_y := 0.0


func _ready() -> void:
	roam_rng.randomize()
	companion_id = AppState.active_room_companion
	_build_editor()


func _process(delta: float) -> void:
	if not is_instance_valid(roaming_actor) or not is_instance_valid(room_canvas) or room_canvas.size.x < roaming_actor.size.x or room_canvas.size.y < roaming_actor.size.y:
		return
	if not dragging_id.is_empty() or not selected_id.is_empty() or is_instance_valid(bag_overlay) or AppState.setting("reduced_motion", false):
		return
	roam_pause -= delta
	if roam_target == Vector2.ZERO or roam_pause <= 0.0:
		roam_target = _safe_roam_target()
		roam_pause = roam_rng.randf_range(2.4, 5.5)
		_set_roaming_actor_facing(roam_target.x - roaming_actor.position.x)
		roaming_actor.set_motion_state(roaming_actor.position.distance_to(roam_target) >= 4.0)
	elif roaming_actor.position.distance_to(roam_target) < 4.0:
		roaming_actor.set_motion_state(false)
		return
	var before := roaming_actor.position
	roaming_actor.position = roaming_actor.position.move_toward(roam_target, delta * 42.0)
	if roaming_actor.position.distance_to(roam_target) < 4.0:
		roaming_actor.set_motion_state(false)
	roaming_actor.z_index = int(roaming_actor.position.y)
	if roaming_actor.position.x != before.x:
		_set_roaming_actor_facing(roaming_actor.position.x - before.x)


func _input(event: InputEvent) -> void:
	if dragging_id.is_empty() or not is_instance_valid(room_canvas):
		return
	var button := item_buttons.get(dragging_id) as Button
	if not is_instance_valid(button):
		return
	if event is InputEventScreenDrag:
		_move_dragged(dragging_id, event.position - room_canvas.global_position, button)
		room_canvas.accept_event()
	elif event is InputEventScreenTouch and not event.pressed:
		if _finish_item_drag():
			room_canvas.accept_event()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_move_dragged(dragging_id, event.position - room_canvas.global_position, button)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_commit_drag(dragging_id)

func _finish_item_drag() -> bool:
	if dragging_id.is_empty():
		return false
	_commit_drag(dragging_id)
	return true


func _clear_ui() -> void:
	# A rebuild queues the old canvas for deletion, so its actor remains valid
	# through this frame. Retire the reference and motion state explicitly or the
	# new canvas will reflow that stale actor instead of creating its own.
	if is_instance_valid(roaming_actor):
		roaming_actor.set_motion_state(false)
		roaming_actor.queue_free()
	roaming_actor = null
	roam_target = Vector2.ZERO
	roam_pause = 0.0
	roam_floor_y = 0.0
	for child in get_children():
		remove_child(child)
		child.queue_free()
	item_buttons.clear()
	selection_toolbar = null
	bag_overlay = null


func _build_editor() -> void:
	_clear_ui()
	local_items = AppState.room_items(companion_id)
	_ensure_companion_present()
	local_items = AppState.room_items(companion_id)
	local_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("z_index", 0)) < int(b.get("z_index", 0)))
	var definition := Catalog.companion(companion_id)
	var bg := ColorRect.new()
	bg.color = NAVY
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	StorybookUI.dress_dusk_backdrop(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	root.add_theme_constant_override("separation", 7)
	add_child(root)
	root.add_child(UnicornHeader.build("%s'S ROOM" % str(definition.get("name", companion_id)).to_upper(), "ALLEY", func() -> void: get_tree().change_scene_to_file("res://scenes/meta/unicorn_alley.tscn"), func() -> void: AppState.shell_view = "home"; get_tree().change_scene_to_file("res://scenes/main.tscn")))
	var tools := HBoxContainer.new()
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(tools)
	var snap := CheckButton.new()
	snap.text = "8% GRID SNAP"
	snap.button_pressed = grid_snap
	snap.toggled.connect(func(value: bool) -> void: grid_snap = value)
	tools.add_child(snap)
	reset_button = Button.new()
	reset_button.text = "RESET ROOM" if not reset_armed else "CONFIRM RESET?"
	reset_button.pressed.connect(_reset_room)
	tools.add_child(reset_button)
	var room_stage := Control.new()
	room_stage.custom_minimum_size = Vector2(420, 500)
	room_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(room_stage)
	room_canvas = Control.new()
	room_canvas.clip_contents = true
	room_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	room_canvas.gui_input.connect(_room_canvas_input)
	room_stage.add_child(room_canvas)
	var room_texture: Texture2D = ROOM_BACKGROUNDS.get(companion_id, ROOM_BACKGROUNDS["sparkle"])
	var room_bg := TextureRect.new()
	room_bg.texture = room_texture
	room_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	room_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room_canvas.add_child(room_bg)
	for item in local_items:
		_create_item_button(item)
	room_canvas.resized.connect(_on_room_canvas_resized)
	room_stage.resized.connect(_fit_room_canvas.bind(room_stage, room_texture.get_size()))
	_fit_room_canvas.call_deferred(room_stage, room_texture.get_size())
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", MUTED)
	status_label.text = "%d decorations placed. Tap an item for controls." % local_items.size()
	root.add_child(status_label)
	bag_button = Button.new()
	bag_button.name = "FurnitureBagButton"
	bag_button.text = "BAG"
	bag_button.tooltip_text = "Open furniture bag"
	bag_button.icon = FURNITURE_BAG_ICON
	bag_button.expand_icon = true
	bag_button.add_theme_constant_override("icon_max_width", 44)
	bag_button.custom_minimum_size = Vector2(118, 76)
	bag_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# Keep the room action above the system/ad boundary, inside the room stage's
	# 24px safe inset.  It intentionally belongs to the stage, not the page root.
	bag_button.offset_left = -142
	bag_button.offset_top = -100
	bag_button.offset_right = -24
	bag_button.offset_bottom = -24
	bag_button.add_theme_font_size_override("font_size", 18)
	StorybookUI.apply_button(bag_button, StorybookUI.NAVY, false, 22)
	bag_button.pressed.connect(_show_bag)
	bag_button.z_index = 300
	room_stage.add_child(bag_button)
	_position_items.call_deferred()


func _fit_room_canvas(stage: Control, source_size: Vector2) -> void:
	if not is_instance_valid(room_canvas) or stage.size.x < 1.0 or stage.size.y < 1.0:
		return
	var fit_scale := minf(stage.size.x / source_size.x, stage.size.y / source_size.y)
	room_canvas.size = source_size * fit_scale
	room_canvas.position = Vector2((stage.size.x - room_canvas.size.x) * 0.5, 12.0)
	_position_items()
	if not is_instance_valid(roaming_actor):
		_create_roaming_actor()
	else:
		_reflow_roaming_actor()


func _on_room_canvas_resized() -> void:
	_position_items()
	if is_instance_valid(roaming_actor):
		_reflow_roaming_actor()


func _create_item_button(item: Dictionary) -> void:
	var item_id := str(item.get("item_id", ""))
	var definition := _item_definition(item_id)
	var button := Button.new()
	button.text = ""
	button.tooltip_text = str(definition.get("name", item_id))
	button.custom_minimum_size = _item_base_size(item_id) * float(item.get("scale", 1.0))
	button.rotation_degrees = 0.0
	button.z_index = int(item.get("z_index", 0))
	button.mouse_default_cursor_shape = Control.CURSOR_DRAG
	_apply_item_button_style(button, str(definition.get("category", "cozy")), str(item.get("instance_id", "")) == selected_id)
	button.gui_input.connect(_item_input.bind(str(item.get("instance_id", "")), button))
	room_canvas.add_child(button)
	if item_id == "companion_%s" % companion_id:
		button.hide() # Actor below owns the room-scale presentation; this remains its saved home anchor.
	else:
		var art := RoomItemPreviewScene.new()
		art.name = "RoomItemPreview3D"
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(art)
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.setup(definition.merged({"id": item_id, "animate": false, "presentation": "room"}, true))
		art.set_display_yaw(float(item.get("rotation", 0)))
	item_buttons[str(item.get("instance_id", ""))] = button


func _create_roaming_actor() -> void:
	if not is_instance_valid(room_canvas) or room_canvas.size.x < 1.0 or room_canvas.size.y < 1.0:
		return
	roaming_actor = RoomItemPreviewScene.new()
	roaming_actor.name = "RoamingRoomCompanion"
	roaming_actor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	roaming_actor.custom_minimum_size = Vector2(148, 116)
	roaming_actor.size = roaming_actor.custom_minimum_size
	roaming_actor.pivot_offset = roaming_actor.size * 0.5
	roaming_actor.setup({"id": "companion_%s" % companion_id, "category": "companions", "animate": true, "presentation": "marketplace"})
	room_canvas.add_child(roaming_actor)
	var home := _local_item("room_companion_%s" % companion_id)
	roaming_actor.position = _roam_home_position(home)
	roam_floor_y = roaming_actor.position.y
	roam_target = roaming_actor.position
	_set_roaming_actor_facing(1.0)


func _set_roaming_actor_facing(horizontal_direction: float) -> void:
	if not is_instance_valid(roaming_actor) or is_zero_approx(horizontal_direction):
		return
	# RoomItemPreview3D faces screen-right without mirroring. Its centered pivot
	# keeps the actor anchored on the floor while a leftward route mirrors it.
	roaming_actor.pivot_offset = roaming_actor.size * 0.5
	var scale_magnitude := absf(roaming_actor.scale.x)
	if is_zero_approx(scale_magnitude):
		scale_magnitude = 1.0
	roaming_actor.scale.x = scale_magnitude if horizontal_direction > 0.0 else -scale_magnitude


func _roam_home_position(home: Dictionary) -> Vector2:
	var max_position := Vector2(maxf(0.0, room_canvas.size.x - roaming_actor.size.x), maxf(0.0, room_canvas.size.y - roaming_actor.size.y))
	var saved_center := Vector2(float(home.get("x", 50.0)) * room_canvas.size.x / 100.0, float(home.get("y", 65.0)) * room_canvas.size.y / 100.0)
	return (saved_center - roaming_actor.size * 0.5).clamp(Vector2.ZERO, max_position)


func _reflow_roaming_actor() -> void:
	if not is_instance_valid(roaming_actor):
		return
	var home := _local_item("room_companion_%s" % companion_id)
	var home_position := _roam_home_position(home)
	roam_floor_y = home_position.y
	var max_x := maxf(0.0, room_canvas.size.x - roaming_actor.size.x)
	roaming_actor.position = Vector2(clampf(roaming_actor.position.x, 0.0, max_x), roam_floor_y)
	roam_target = Vector2(clampf(roam_target.x, 0.0, max_x), roam_floor_y)
	roaming_actor.pivot_offset = roaming_actor.size * 0.5


func _safe_roam_target() -> Vector2:
	var horizontal_padding := minf(80.0, maxf(0.0, (room_canvas.size.x - roaming_actor.size.x) * 0.25))
	var max_x := maxf(0.0, room_canvas.size.x - roaming_actor.size.x)
	for attempt in 10:
		var candidate := Vector2(roam_rng.randf_range(horizontal_padding, maxf(horizontal_padding, max_x - horizontal_padding)), roam_floor_y)
		var rect := Rect2(candidate, roaming_actor.size)
		var blocked := false
		for instance_id in item_buttons:
			var placed := item_buttons[instance_id] as Button
			if is_instance_valid(placed) and placed.visible and rect.grow(18).intersects(placed.get_rect()): blocked = true; break
		if not blocked: return candidate
	return Vector2(clampf(roaming_actor.position.x, 0.0, max_x), roam_floor_y)


func _position_items() -> void:
	if not is_instance_valid(room_canvas):
		return
	for item in local_items:
		var instance_id := str(item.get("instance_id", ""))
		var button := item_buttons.get(instance_id) as Button
		if not is_instance_valid(button):
			continue
		button.position = Vector2(float(item.get("x", 50.0)) / 100.0 * room_canvas.size.x, float(item.get("y", 50.0)) / 100.0 * room_canvas.size.y) - button.size * 0.5
	_position_selection_toolbar.call_deferred()


func _item_input(event: InputEvent, instance_id: String, button: Button) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			button.accept_event()
			_begin_item_drag(instance_id)
		else:
			_commit_drag(instance_id)
	elif event is InputEventScreenTouch:
		if event.pressed:
			button.accept_event()
			_begin_item_drag(instance_id)
		else:
			_commit_drag(instance_id)


func _begin_item_drag(instance_id: String) -> void:
	selected_id = instance_id
	dragging_id = instance_id
	_mark_selected()


func _room_canvas_input(event: InputEvent) -> void:
	var pressed_blank: bool = event is InputEventScreenTouch and event.pressed
	pressed_blank = pressed_blank or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	if not pressed_blank:
		return
	_clear_selection()
	room_canvas.accept_event()


func _clear_selection() -> void:
	selected_id = ""
	dragging_id = ""
	if is_instance_valid(selection_toolbar):
		selection_toolbar.queue_free()
	selection_toolbar = null
	for instance_id in item_buttons:
		var item := _local_item(instance_id)
		var definition := _item_definition(str(item.get("item_id", "")))
		_apply_item_button_style(item_buttons[instance_id], str(definition.get("category", "cozy")), false)
	if is_instance_valid(status_label):
		status_label.text = "%d decorations placed. Tap an item for controls." % local_items.size()


func close_top_overlay() -> bool:
	if is_instance_valid(bag_overlay):
		_close_bag()
		return true
	if not selected_id.is_empty():
		_clear_selection()
		return true
	return false


func _move_dragged(instance_id: String, local_position: Vector2, button: Button) -> void:
	var item := _local_item(instance_id)
	if item.is_empty():
		return
	item["x"] = clampf(local_position.x / maxf(1.0, room_canvas.size.x) * 100.0, 0.0, 100.0)
	item["y"] = clampf(local_position.y / maxf(1.0, room_canvas.size.y) * 100.0, 0.0, 100.0)
	button.position = local_position - button.size * 0.5
	_position_selection_toolbar()


func _commit_drag(instance_id: String) -> void:
	var item := _local_item(instance_id)
	if not item.is_empty():
		item["x"] = Rules.snap(float(item["x"]), grid_snap)
		item["y"] = Rules.snap(float(item["y"]), grid_snap)
		AppState.place_room_item(companion_id, item)
	dragging_id = ""
	local_items = AppState.room_items(companion_id)
	_position_items()


func _mark_selected() -> void:
	var item := _local_item(selected_id)
	var definition := _item_definition(str(item.get("item_id", "")))
	if is_instance_valid(status_label):
		status_label.text = str(definition.get("name", "Selected"))
	for instance_id in item_buttons:
		var source := _local_item(instance_id)
		var source_def := _item_definition(str(source.get("item_id", "")))
		_apply_item_button_style(item_buttons[instance_id], str(source_def.get("category", "cozy")), instance_id == selected_id)
	_show_selection_toolbar()


func _show_selection_toolbar() -> void:
	if is_instance_valid(selection_toolbar):
		selection_toolbar.queue_free()
	selection_toolbar = HBoxContainer.new()
	selection_toolbar.name = "SelectionToolbar"
	selection_toolbar.z_index = 2000
	selection_toolbar.add_theme_constant_override("separation", 2)
	selection_toolbar.add_theme_stylebox_override("panel", StorybookUI.plaque_style(StorybookUI.NAVY, StorybookUI.GOLD, 12))
	room_canvas.add_child(selection_toolbar)
	var actions := [
		["REMOVE", "×", "Remove"],
		["ROTATE", "↻", "Rotate"],
		["SMALLER", "−", "Smaller"],
		["LARGER", "+", "Larger"],
		["BACK", "↓", "Send backward"],
		["FRONT", "↑", "Bring forward"],
	]
	for action in actions:
		var control := Button.new()
		control.text = action[1]
		control.tooltip_text = action[2]
		control.custom_minimum_size = Vector2(40, 38)
		control.add_theme_font_size_override("font_size", 22)
		control.disabled = _selection_action_is_at_boundary(action[0])
		StorybookUI.apply_button(control, StorybookUI.NAVY, false, 9)
		control.pressed.connect(_selection_action.bind(action[0]))
		selection_toolbar.add_child(control)
	_position_selection_toolbar.call_deferred()


func _position_selection_toolbar() -> void:
	if selected_id.is_empty() or not is_instance_valid(selection_toolbar) or not is_instance_valid(room_canvas):
		return
	var button := item_buttons.get(selected_id) as Button
	if not is_instance_valid(button):
		return
	var toolbar_size := selection_toolbar.get_combined_minimum_size()
	selection_toolbar.size = toolbar_size
	var target_x := button.position.x + button.size.x * 0.5 - toolbar_size.x * 0.5
	var target_y := button.position.y - toolbar_size.y - 7.0
	if target_y < 5.0:
		target_y = button.position.y + button.size.y + 7.0
	selection_toolbar.position = Vector2(
		clampf(target_x, 5.0, maxf(5.0, room_canvas.size.x - toolbar_size.x - 5.0)),
		clampf(target_y, 5.0, maxf(5.0, room_canvas.size.y - toolbar_size.y - 5.0))
	)


func _visible_decor_items() -> Array:
	var visible: Array = []
	for item in local_items:
		if not str(item.get("item_id", "")).begins_with("companion_"):
			visible.append(item)
	visible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("z_index", 0)) < int(b.get("z_index", 0)))
	return visible


func _selection_action_is_at_boundary(action: String) -> bool:
	var item := _local_item(selected_id)
	if item.is_empty():
		return true
	if action == "SMALLER":
		return float(item.get("scale", 1.0)) <= 0.5
	if action == "LARGER":
		return float(item.get("scale", 1.0)) >= 1.8
	if action not in ["BACK", "FRONT"]:
		return false
	var visible := _visible_decor_items()
	if visible.is_empty():
		return true
	var selected_index := _visible_decor_index(visible, selected_id)
	return selected_index <= 0 if action == "BACK" else selected_index >= visible.size() - 1


func _visible_decor_index(visible: Array, instance_id: String) -> int:
	for index in visible.size():
		if str(visible[index].get("instance_id", "")) == instance_id:
			return index
	return -1


func _selection_action(action: String) -> void:
	if selected_id.is_empty():
		if is_instance_valid(status_label):
			status_label.text = "Select an item first."
		return
	var item := _local_item(selected_id)
	if item.is_empty():
		return
	match action:
		"ROTATE":
			item["rotation"] = (int(item.get("rotation", 0)) + 45) % 360
			var button := item_buttons.get(selected_id) as Button
			var preview := button.get_node_or_null("RoomItemPreview3D") as RoomItemPreview3D if is_instance_valid(button) else null
			if is_instance_valid(preview):
				preview.set_display_yaw(float(item["rotation"]))
		"SMALLER": item["scale"] = clampf(float(item.get("scale", 1.0)) - 0.1, 0.5, 1.8)
		"LARGER": item["scale"] = clampf(float(item.get("scale", 1.0)) + 0.1, 0.5, 1.8)
		"BACK", "FRONT":
			if _selection_action_is_at_boundary(action):
				return
			_reorder_visible_decor(action.to_lower())
			_refresh_room_items()
			return
		"REMOVE":
			AppState.remove_room_item(companion_id, selected_id)
			selected_id = ""
			_build_editor()
			return
	AppState.place_room_item(companion_id, item)
	_refresh_room_items()


func _reorder_visible_decor(direction: String) -> void:
	var visible := _visible_decor_items()
	var selected_index := _visible_decor_index(visible, selected_id)
	var neighbor_index := selected_index + 1 if direction == "front" else selected_index - 1
	if selected_index < 0 or neighbor_index < 0 or neighbor_index >= visible.size():
		return
	var selected: Dictionary = visible[selected_index]
	var neighbor: Dictionary = visible[neighbor_index]
	var selected_z := int(selected.get("z_index", 0))
	selected["z_index"] = int(neighbor.get("z_index", 0))
	neighbor["z_index"] = selected_z
	AppState.place_room_item(companion_id, selected)
	AppState.place_room_item(companion_id, neighbor)


func _refresh_room_items() -> void:
	local_items = AppState.room_items(companion_id)
	local_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("z_index", 0)) < int(b.get("z_index", 0)))
	for item in local_items:
		var instance_id := str(item.get("instance_id", ""))
		var button := item_buttons.get(instance_id) as Button
		if not is_instance_valid(button):
			continue
		button.custom_minimum_size = _item_base_size(str(item.get("item_id", ""))) * float(item.get("scale", 1.0))
		button.size = button.custom_minimum_size
		button.rotation_degrees = 0.0
		var preview := button.get_node_or_null("RoomItemPreview3D") as RoomItemPreview3D
		if is_instance_valid(preview):
			preview.set_display_yaw(float(item.get("rotation", 0)))
		button.z_index = int(item.get("z_index", 0))
	_position_items()
	_mark_selected()


func _reset_room() -> void:
	if not reset_armed:
		reset_armed = true
		reset_button.text = "CONFIRM RESET?"
		status_label.text = "Tap again to return every item to the bag."
		return
	AppState.reset_room(companion_id)
	selected_id = ""
	reset_armed = false
	_build_editor()


func _show_bag() -> void:
	if is_instance_valid(bag_overlay):
		return
	if is_instance_valid(bag_button):
		bag_button.hide()
	if is_instance_valid(status_label):
		status_label.hide()
	bag_overlay = FurnitureBagOverlay.new()
	bag_overlay.item_selected.connect(_place_from_bag)
	bag_overlay.closed.connect(_close_bag)
	add_child(bag_overlay)
	bag_overlay.setup(companion_id, bag_category)


func _close_bag() -> void:
	if is_instance_valid(bag_overlay):
		bag_category = bag_overlay.category
		bag_overlay.queue_free()
	bag_overlay = null
	if is_instance_valid(bag_button):
		bag_button.show()
	if is_instance_valid(status_label):
		status_label.show()


func _place_from_bag(item_id: String) -> void:
	if is_instance_valid(bag_overlay) and bag_overlay.is_action_suppressed():
		return
	if is_instance_valid(bag_overlay):
		bag_category = bag_overlay.category
	var items := AppState.room_items(companion_id)
	var item := {
		"instance_id": "%d_%d" % [Time.get_ticks_msec(), randi_range(100, 999)],
		"item_id": item_id,
		"x": Rules.snap(50.0, grid_snap),
		"y": Rules.snap(62.0, grid_snap),
		"rotation": 0,
		"scale": 1.2 if item_id.begins_with("companion_") else 1.0,
		"z_index": Rules.next_z(items),
	}
	if AppState.place_room_item(companion_id, item):
		selected_id = str(item["instance_id"])
		_build_editor()


func _local_item(instance_id: String) -> Dictionary:
	for item in local_items:
		if str(item.get("instance_id", "")) == instance_id:
			return item
	return {}


func _item_definition(item_id: String) -> Dictionary:
	if item_id.begins_with("companion_"):
		var definition := Catalog.companion(item_id.trim_prefix("companion_"))
		return {"name": definition.get("name", "Companion"), "icon": "🦄", "category": "companions"}
	return Catalog.furniture_item(item_id)


func _item_base_size(item_id: String) -> Vector2:
	return Vector2(252, 180) if item_id.begins_with("companion_") else Vector2(104, 104)


func _ensure_companion_present() -> void:
	var companion_item_id := "companion_%s" % companion_id
	for item in local_items:
		if str(item.get("item_id", "")) == companion_item_id:
			return
	if AppState.available_count(companion_item_id) <= 0:
		return
	AppState.place_room_item(companion_id, {
		"instance_id": "room_companion_%s" % companion_id,
		"item_id": companion_item_id,
		"x": 50.0,
		"y": 61.0,
		"rotation": 0,
		"scale": 1.0,
		"z_index": Rules.next_z(local_items),
	})


func _item_style(category: String, selected: bool) -> StyleBoxFlat:
	var colors := {"companions": PINK, "nature": Color("62e6a7"), "lighting": YELLOW, "luxury": Color("d5a4ff"), "pets": Color("ff9f7c"), "electronics": StorybookUI.CYAN, "seasonal": Color("f59c5b"), "rugs": Color("c99cff"), "beds": Color("89a9ff"), "tables": Color("d49b6a"), "kitchen": Color("ffb66e"), "toys": Color("ff91bd"), "wall": Color("91c9ff"), "unicorn": Color("f68bd8"), "cozy": Color("9da9d9")}
	var color: Color = colors.get(category, Color("9da9d9"))
	var background := Color.TRANSPARENT if not selected else Color(color, 0.12)
	var style := _rounded_style(background, Color.WHITE if selected else Color("00000000"), 4 if selected else 0, 16)
	return style


func _apply_item_button_style(button: Button, category: String, selected: bool) -> void:
	var style := _item_style(category, selected)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, style)


func _rounded_style(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style
